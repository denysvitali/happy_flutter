import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import '../encryption/aes_gcm.dart';
import '../encryption/base64.dart';
import '../encryption/crypto_secret_box.dart';
import '../encryption/encryption_manager.dart';
import '../models/built_in_profiles.dart';
import '../models/codex_usage_summary.dart';
import '../models/machine.dart';
import '../models/settings.dart';
import '../rpc/rpc_types.dart';
import '../services/logger_service.dart';
import '../services/storage_service.dart';
import '../utils/invalidate_sync.dart';
import '../utils/path_utils.dart' show resolveAbsolutePath;
import '../utils/sync_domain.dart';
import '../utils/wire_parsers.dart';
import 'sync_exceptions.dart';
import 'sync_progress.dart';

// ---------------------------------------------------------------------------
// Isolate helpers for machine payload decryption
// ---------------------------------------------------------------------------

class _MachineIsolateItem {
  const _MachineIsolateItem({
    required this.id,
    required this.secretKey,
    required this.isAes,
    required this.metadataVersion,
    required this.daemonStateVersion,
    this.encryptedMetadata,
    this.encryptedDaemonState,
  });

  final String id;
  final Uint8List secretKey;
  final bool isAes;
  final Uint8List? encryptedMetadata;
  final int metadataVersion;
  final Uint8List? encryptedDaemonState;
  final int daemonStateVersion;
}

class _MachineIsolateResult {
  const _MachineIsolateResult({
    required this.id,
    this.metadata,
    this.daemonState,
  });

  final String id;
  final Map<String, dynamic>? metadata;
  final dynamic daemonState;
}

/// Decrypt machine metadata and daemonState.
/// AES-256-GCM items run in a background isolate on native; on web they
/// decrypt on the main thread. NaCl always stays on main thread.
Future<List<_MachineIsolateResult>> _decryptMachinesInIsolate(
  List<_MachineIsolateItem> items,
) async {
  // Collect AES payloads for batch isolate decryption.
  final aesPayloads = <Uint8List>[];
  final aesKeys = <Uint8List>[];
  final aesMapping = <(int, int)>[];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    if (!item.isAes) continue;

    final encMeta = item.encryptedMetadata;
    if (encMeta != null && encMeta.isNotEmpty && encMeta[0] == 0) {
      aesPayloads.add(encMeta.sublist(1));
      aesKeys.add(item.secretKey);
      aesMapping.add((i, 0));
    }

    final encDs = item.encryptedDaemonState;
    if (encDs != null && encDs.isNotEmpty && encDs[0] == 0) {
      aesPayloads.add(encDs.sublist(1));
      aesKeys.add(item.secretKey);
      aesMapping.add((i, 1));
    }
  }

  Map<(int, int), dynamic>? aesResultMap;
  if (aesPayloads.isNotEmpty && !kIsWeb) {
    try {
      final aesResults = await Isolate.run(
        () => AesGcmEncryption.decryptMultiKeyBatch(
          aesPayloads,
          aesKeys,
        ),
      );
      aesResultMap = {
        for (var i = 0; i < aesMapping.length; i++)
          aesMapping[i]: aesResults[i],
      };
    } catch (e) {
      logger.warning('Machine AES isolate failed, '
          'falling back to main thread: $e');
    }
  }

  final results = <_MachineIsolateResult>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    Map<String, dynamic>? metadata;
    dynamic daemonState;

    if (item.isAes && aesResultMap != null) {
      final metaResult = aesResultMap[(i, 0)];
      if (metaResult is Map<String, dynamic>) {
        metadata = metaResult;
      }
      daemonState = aesResultMap[(i, 1)];
    } else {
      final encMeta = item.encryptedMetadata;
      if (encMeta != null) {
        try {
          if (item.isAes) {
            if (encMeta.isNotEmpty && encMeta[0] == 0) {
              final d = await AesGcmEncryption.decrypt(
                encMeta.sublist(1),
                item.secretKey,
              );
              if (d is Map<String, dynamic>) metadata = d;
            }
          } else {
            final d = await CryptoSecretBox.decrypt(
              encMeta,
              item.secretKey,
              scope: 'machine:${item.id}:metadata',
            );
            if (d is Map<String, dynamic>) metadata = d;
          }
        } catch (e) {
          logger.warning('Failed to decrypt machine metadata: $e');
        }
      }

      final encDs = item.encryptedDaemonState;
      if (encDs != null) {
        try {
          if (item.isAes) {
            if (encDs.isNotEmpty && encDs[0] == 0) {
              daemonState = await AesGcmEncryption.decrypt(
                encDs.sublist(1),
                item.secretKey,
              );
            }
          } else {
            daemonState = await CryptoSecretBox.decrypt(
              encDs,
              item.secretKey,
              scope: 'machine:${item.id}:daemon-state',
            );
          }
        } catch (e) {
          logger.warning('Failed to decrypt machine daemon state: $e');
        }
      }
    }

    results.add(
      _MachineIsolateResult(
        id: item.id,
        metadata: metadata,
        daemonState: daemonState,
      ),
    );
  }
  return results;
}

int? _asSessionInt(dynamic value) {
  return WireParsers.parseInt(value);
}

int? _clampTimestampToNow(int? value, int nowMs) {
  if (value == null) return null;
  return value > nowMs ? nowMs : value;
}

// ---------------------------------------------------------------------------
// MachineManager
// ---------------------------------------------------------------------------

/// Owns machine-related state and methods extracted from the Sync god object.
///
/// This class manages:
/// - Machine catalog fetching and decryption
/// - Machine-activity ephemeral updates
/// - Machine RPC calls (bash, readFile, usage limits, codex models/usage)
/// - Session creation and worktree creation
/// - Profile/model resolution helpers for spawning
class MachineManager {
  MachineManager({
    required this.encryption,
    required Settings Function() settingsSnapshotGetter,
    required InvalidateSync Function() machinesSyncGetter,
    required void Function(Set<SyncDomain>) onDataChanged,
    required Future<void> Function(String sessionId) fetchSingleSession,
    required Future<void> Function() refreshSessions,
    required Future<void> Function(String machineId)? ensureMachineReachable,
    required bool Function(Object) isTransientRpcError,
    required bool Function(Object) isRpcMethodNotAvailable,
    required bool Function(Object) isTransientConnectionError,
    void Function(String sessionId)? onSessionVisible,
    Future<dynamic> Function(
      String machineId,
      String method,
      Map<String, dynamic> params, {
      Duration? timeout,
    })?
        machineRPCOverride,
    void Function()? onFetchMachinesStarted,
    void Function(SyncProgress)? onSyncProgress,
  })  : _settingsSnapshotGetter = settingsSnapshotGetter,
        _machinesSyncGetter = machinesSyncGetter,
        _onDataChanged = onDataChanged,
        _fetchSingleSession = fetchSingleSession,
        _refreshSessions = refreshSessions,
        _onSessionVisible = onSessionVisible,
        _machineRPCOverride = machineRPCOverride,
        _ensureMachineReachable = ensureMachineReachable,
        _isTransientRpcError = isTransientRpcError,
        _isRpcMethodNotAvailable = isRpcMethodNotAvailable,
        _isTransientConnectionError = isTransientConnectionError,
        _onFetchMachinesStarted = onFetchMachinesStarted,
        _onSyncProgress = onSyncProgress;

  // ── Dependencies ────────────────────────────────────────────────────────

  final Encryption encryption;
  final Settings Function() _settingsSnapshotGetter;
  Settings get _settingsSnapshot => _settingsSnapshotGetter();

  final InvalidateSync Function() _machinesSyncGetter;
  InvalidateSync get _machinesSync => _machinesSyncGetter();

  final void Function(Set<SyncDomain>) _onDataChanged;
  // ignore: unused_field
  final Future<void> Function(String sessionId) _fetchSingleSession;
  final Future<void> Function() _refreshSessions;
  // ignore: unused_field
  final void Function(String sessionId)? _onSessionVisible;

  final Future<dynamic> Function(
    String machineId,
    String method,
    Map<String, dynamic> params, {
    Duration? timeout,
  })? _machineRPCOverride;

  final Future<void> Function(String machineId)? _ensureMachineReachable;
  final bool Function(Object) _isTransientRpcError;
  final bool Function(Object) _isRpcMethodNotAvailable;
  final bool Function(Object) _isTransientConnectionError;
  final void Function()? _onFetchMachinesStarted;
  // ignore: unused_field
  final void Function(SyncProgress)? _onSyncProgress;

  // ── State ───────────────────────────────────────────────────────────────

  final Map<String, Machine> _machines = <String, Machine>{};
  final Map<String, Uint8List> _machineDataKeys = {};
  final Map<String, int> _machineOfflineWarnedAtMs = {};
  Timer? _machinesRefreshDebounceTimer;
  // ignore: unused_field
  final Set<String> _pendingUpdateMachineIds = {};

  /// Shared ephemeral timestamp map (also used by session ephemeral handling).
  final Map<String, int> _lastEphemeralAt = {};

  // ── Constants ─────────────────────────────────────────────────────────

  static const Duration _machinesRefreshDebounce =
      Duration(milliseconds: 250);
  // ignore: unused_field
  static const Duration _machinesSyncMinInterval = Duration(seconds: 1);

  static const _worktreeAdjectives = [
    'clever',
    'happy',
    'swift',
    'bright',
    'calm',
    'bold',
    'quiet',
    'brave',
    'wise',
    'eager',
    'gentle',
    'quick',
    'sharp',
    'smooth',
    'fresh',
  ];

  static const _worktreeNouns = [
    'ocean',
    'forest',
    'cloud',
    'star',
    'river',
    'mountain',
    'valley',
    'bridge',
    'beacon',
    'harbor',
    'garden',
    'meadow',
    'canyon',
    'island',
    'desert',
  ];

  // ── Public API ──────────────────────────────────────────────────────────

  Map<String, Machine> get machines => Map.unmodifiable(_machines);
  Map<String, int> get lastEphemeralAt => _lastEphemeralAt;

  Machine? getMachine(String machineId) => _machines[machineId];

  /// Schedule a machines refresh with debounce.
  void scheduleMachinesRefresh() {
    _machinesRefreshDebounceTimer?.cancel();
    _machinesRefreshDebounceTimer = Timer(_machinesRefreshDebounce, () {
      _machinesRefreshDebounceTimer = null;
      _machinesSync.invalidate();
    });
  }

  /// Flush any pending machines refresh immediately.
  Future<void> flushScheduledMachinesRefresh() async {
    _machinesRefreshDebounceTimer?.cancel();
    _machinesRefreshDebounceTimer = null;
    await _machinesSync.invalidateAndAwait();
  }

  // ── fetchMachines ───────────────────────────────────────────────────────

  /// Fetch machines from server, decrypt keys and metadata.
  Future<void> fetchMachines() async {
    logger.info('Fetching machines...');
    _onFetchMachinesStarted?.call();

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/machines');

      if (apiClient.isSuccess(response)) {
        final rawData = response.data;
        final List data;
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map<String, dynamic> &&
            rawData['machines'] is List) {
          data = rawData['machines'] as List;
        } else {
          logger.warning(
            'Unexpected response format for machines: '
            '${rawData?.runtimeType}',
          );
          return;
        }

        // Initialize machine encryptions -- decrypt all keys in parallel.
        final machineKeys = <String, Uint8List?>{};
        final machineDecryptTasks =
            <({String machineId, String dataEncryptionKey})>[];

        for (final machine in data) {
          final machineId = machine['id'] as String;
          final dataEncryptionKey = machine['dataEncryptionKey'] as String?;

          if (dataEncryptionKey != null) {
            machineDecryptTasks.add((
              machineId: machineId,
              dataEncryptionKey: dataEncryptionKey,
            ));
          } else {
            machineKeys[machineId] = null;
          }
        }

        if (machineDecryptTasks.isNotEmpty) {
          final decryptedKeys = await Future.wait(
            machineDecryptTasks.map(
              (t) => encryption
                  .decryptEncryptionKey(t.dataEncryptionKey)
                  .catchError((Object e) {
                logger.info(
                  '[Encryption] DEK decryption threw for machine '
                  '${t.machineId}: $e '
                  '-- falling back to legacy encryption.',
                );
                return null;
              }),
            ),
          );

          for (var i = 0; i < machineDecryptTasks.length; i++) {
            final machineId = machineDecryptTasks[i].machineId;
            final decryptedKey = decryptedKeys[i];
            if (decryptedKey != null) {
              machineKeys[machineId] = decryptedKey;
              _machineDataKeys[machineId] = decryptedKey;
            } else {
              logger.info(
                '[Encryption] DEK decryption failed for machine '
                '$machineId (returned null) -- falling back to legacy '
                'encryption. Run `happy auth debug` to diagnose key '
                'mismatch.',
              );
              machineKeys[machineId] = null;
            }
          }
        }

        await encryption.initializeMachines(machineKeys);

        // Build isolate payloads for machine decryption.
        final legacyKey = encryption.legacySecretKey;
        final machineIsolateItems = <_MachineIsolateItem>[];
        for (final machine in data) {
          final machineId = machine['id'] as String;
          if (!machineKeys.containsKey(machineId)) continue;

          final dataKey = machineKeys[machineId];
          final rawMeta = machine['metadata'];
          final encMeta = (rawMeta is String && rawMeta.isNotEmpty)
              ? Base64Utils.decode(rawMeta, Encoding.base64)
              : null;
          final rawDs = machine['daemonState'] as String?;
          final encDs = (rawDs != null && rawDs.isNotEmpty)
              ? Base64Utils.decode(rawDs, Encoding.base64)
              : null;

          machineIsolateItems.add(
            _MachineIsolateItem(
              id: machineId,
              secretKey: dataKey ?? legacyKey,
              isAes: dataKey != null,
              encryptedMetadata: encMeta,
              metadataVersion: _asSessionInt(machine['metadataVersion']) ?? 0,
              encryptedDaemonState: encDs,
              daemonStateVersion:
                  _asSessionInt(machine['daemonStateVersion']) ?? 0,
            ),
          );
        }

        final machineIsolateResults = await _decryptMachinesInIsolate(
          machineIsolateItems,
        );
        final machineResultById = {
          for (final r in machineIsolateResults) r.id: r,
        };

        final decryptedMachines = <Machine>[];
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final machine in data) {
          final machineId = machine['id'] as String;
          final result = machineResultById[machineId];
          if (result == null) continue;

          final isActive = machine['active'] as bool? ?? false;
          final serverActiveAt = _clampTimestampToNow(
            _asSessionInt(machine['activeAt']),
            now,
          );
          int activeAt;
          if (isActive) {
            final fallback = serverActiveAt ?? now;
            activeAt = now - fallback > 60000 ? now : fallback;
          } else {
            activeAt = serverActiveAt ?? 0;
          }

          decryptedMachines.add(
            Machine(
              id: machineId,
              seq: _asSessionInt(machine['seq']) ?? 0,
              createdAt: _asSessionInt(machine['createdAt']) ?? 0,
              updatedAt: _asSessionInt(machine['updatedAt']) ?? 0,
              active: isActive,
              activeAt: activeAt,
              metadata: result.metadata != null
                  ? MachineMetadata.fromJson(result.metadata!)
                  : null,
              metadataVersion: _asSessionInt(machine['metadataVersion']) ?? 0,
              daemonState: result.daemonState,
              daemonStateVersion:
                  _asSessionInt(machine['daemonStateVersion']) ?? 0,
            ),
          );
        }

        if (decryptedMachines.isEmpty) {
          logger.warning(
            'fetchMachines: full fetch returned 0 machines -- '
            'possible auth/server issue, skipping update',
          );
          return;
        }

        _machines
          ..clear()
          ..addEntries(
            decryptedMachines.map((machine) => MapEntry(machine.id, machine)),
          );
        logger.info(
          'Fetched and decrypted ${decryptedMachines.length} machines',
        );
        _onDataChanged({SyncDomain.machines});
      } else {
        logger.warning('Failed to fetch machines: ${response.statusCode}');
      }
    } catch (error, stack) {
      if (_isTransientConnectionError(error)) {
        logger.warning('Error fetching machines', error, stack);
        unawaited(Sentry.captureException(error, stackTrace: stack));
      } else {
        logger.error('Error fetching machines', error, stack);
      }
    }
  }

  // ── handleEphemeralUpdate ───────────────────────────────────────────────

  /// Handle ephemeral updates from the socket.
  ///
  /// The [markSessionOnline] and [markSessionOffline] callbacks are used
  /// to update session state that lives outside this manager.
  void handleEphemeralUpdate(
    dynamic data, {
    required void Function(
      String sessionId, {
      bool? thinking,
      int? activeAt,
      bool keepThinking,
    }) markSessionOnline,
    required void Function(String sessionId) markSessionOffline,
    required String? visibleSessionId,
    required void Function(String sessionId) invalidateMessagesSync,
  }) {
    final payload = _normalizeSocketPayload(
      data,
      handlerName: 'handleEphemeralUpdate',
    );
    if (payload == null) return;

    final type = payload['type'] as String? ?? payload['t'] as String?;

    // Machine-activity ephemeral -- the CLI daemon sends machine-alive
    // every 20s and the server broadcasts this ephemeral.
    if (type == 'machine-activity' || type == 'machine_activity') {
      final machineId = payload['id'] as String?;
      if (machineId == null) return;

      final machine = _machines[machineId];
      final eventActiveAt = payload['activeAt'] is int
          ? payload['activeAt'] as int
          : payload['activeAt'] is double
              ? (payload['activeAt'] as double).toInt()
              : null;
      final active = payload['active'] as bool?;
      final now = DateTime.now().millisecondsSinceEpoch;
      final activeAt =
          _clampTimestampToNow(eventActiveAt, now) ??
          ((active ?? false) ? now : null);
      final ageMs = (activeAt != null) ? now - activeAt : null;
      final ageLabel = ageMs == null
          ? 'null'
          : ageMs < 1000
              ? '${ageMs}ms'
              : '${(ageMs / 1000).toStringAsFixed(1)}s';
      final source = eventActiveAt != null ? 'event' : 'synth';
      logger.debug(
        '[machine-activity] machineId=$machineId '
        'inMap=${machine != null} active=$active '
        'activeAt=$activeAt age=$ageLabel source=$source',
      );
      if (machine == null) {
        logger.info(
          '[machine-activity] unknown machineId=$machineId '
          '-- scheduling machines refresh',
        );
        scheduleMachinesRefresh();
        return;
      }
      if (activeAt != null || active != null) {
        _machines[machineId] = machine.copyWith(
          active: active ?? machine.active,
          activeAt: activeAt ?? machine.activeAt,
        );
        if (ageMs != null && ageMs > 5 * 1000) {
          logger.info(
            '[machine-activity] patched in-memory '
            'machineId=$machineId age=$ageLabel '
            '(server cached activeAt; UI will recover on next fetch)',
          );
        }
        _onDataChanged({SyncDomain.machines});
      }
      return;
    }

    // The remaining types (alive-batch, activity, session-alive) touch
    // session state and are forwarded to the caller via callbacks.
    // Parse the sessionId first.
    final sessionId = payload['id'] as String? ?? payload['sid'] as String?;
    if (sessionId == null) return;

    if (type == 'alive-batch') {
      final sessions = payload['sessions'] as List?;
      if (sessions == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      var anyChanged = false;
      for (final s in sessions) {
        if (s is! Map) continue;
        final sid = s['id'] as String?;
        if (sid == null) continue;
        _lastEphemeralAt[sid] = now;
        final activeAt = s['activeAt'] as int?;
        final thinking = s['thinking'] as bool? ?? false;
        markSessionOnline(
          sid,
          thinking: thinking,
          activeAt: activeAt,
          keepThinking: false,
        );
        anyChanged = true;
      }
      if (anyChanged) {
        _onDataChanged({SyncDomain.sessions});
      }
      return;
    }

    if (type == 'activity') {
      final thinking = payload['thinking'] as bool? ?? false;
      final activeAt = payload['activeAt'] as int?;
      final isActive = payload['active'] as bool? ?? true;

      if (isActive) {
        _lastEphemeralAt[sessionId] =
            DateTime.now().millisecondsSinceEpoch;
        markSessionOnline(
          sessionId,
          thinking: thinking,
          activeAt: activeAt,
          keepThinking: false,
        );
      } else {
        markSessionOffline(sessionId);
      }
      return;
    }

    if (type == 'session-alive' || type == 'session_alive') {
      _lastEphemeralAt[sessionId] = DateTime.now().millisecondsSinceEpoch;
      markSessionOnline(
        sessionId,
        keepThinking: true,
      );
      return;
    }

    // Only invalidate if this session is currently open.
    if (sessionId == visibleSessionId) {
      invalidateMessagesSync(sessionId);
    }
  }

  // ── createSession ───────────────────────────────────────────────────────

  /// Create a session on a target machine/path and return the new session ID.
  Future<String> createSession({
    required String machineId,
    required String path,
    required String agent,
    bool approvedNewDirectoryCreation = false,
    String? sessionId,
    String? profileId,
    String? message,
    String? modelMode,
  }) async {
    final createStopwatch = Stopwatch()..start();
    final requestedSessionId = sessionId ?? _createClientSessionId();

    // Fail fast if the machine is offline.
    final machine = _machines[machineId];
    if (machine != null) {
      if (!machine.active) {
        throw StateError('Machine is offline');
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      const onlineThresholdMs = 120 * 1000;
      if (now - machine.activeAt >= onlineThresholdMs) {
        final lastWarnedAt = _machineOfflineWarnedAtMs[machineId] ?? 0;
        if (now - lastWarnedAt > 60000) {
          _machineOfflineWarnedAtMs[machineId] = now;
          final deltaSec = ((now - machine.activeAt) / 1000).round();
          logger.warning(
            'Machine appears offline '
            '(machineId=$machineId, delta=${deltaSec}s)',
          );
        }
        throw StateError('Machine is offline');
      }
    }

    // Pre-flight liveness probe.
    await _ensureMachineReachable?.call(machineId);

    final resolvedPath =
        (machine != null && machine.metadata?.homeDir != null)
            ? resolveAbsolutePath(path, homeDir: machine.metadata!.homeDir)
            : path;

    final selectedProfileId =
        profileId ??
        resolveSelectedProfileIdForAgent(_settingsSnapshot, agent);
    final selectedProfile =
        selectedProfileId != null ? _resolveProfile(selectedProfileId) : null;
    final normalizedModelMode = _normalizeModelModeForAgent(modelMode, agent);
    final spawnProfileResolution = _resolveEffectiveProfileForSpawn(
      profile: selectedProfile,
      modelMode: normalizedModelMode,
      agent: agent,
    );
    final effectiveProfileId = spawnProfileResolution.profile != null
        ? selectedProfileId
        : null;
    final effectiveModelMode = spawnProfileResolution.modelMode;
    // ignore: unused_local_variable
    final _ = effectiveProfileId;
    final _ = effectiveModelMode;

    final hydratedProfile = spawnProfileResolution.profile != null
        ? await _hydrateProfileForSpawn(spawnProfileResolution.profile!)
        : null;
    final profileEnvVars = hydratedProfile != null
        ? _profileEnvironmentVariables(hydratedProfile)
        : null;
    final permMode =
        spawnProfileResolution.profile?.defaultPermissionMode ??
        _settingsSnapshot.lastUsedPermissionMode;
    final envVars = _spawnEnvironmentVariables(profileEnvVars);
    if (message != null && message.isNotEmpty) {
      envVars['HAPPY_INITIAL_PROMPT'] = message;
    }

    final req = SpawnSessionRequest(
      type: 'spawn-in-directory',
      directory: resolvedPath,
      sessionId: requestedSessionId,
      approvedNewDirectoryCreation: true,
      agent: agent,
      permissionMode: permMode,
      model: _getModelOverride(
        agent: agent,
        profile: spawnProfileResolution.profile,
        modelMode: effectiveModelMode,
      ),
      environmentVariables: envVars,
    );

    logger.info(
      '[createSession] START machine=$machineId '
      'session=$requestedSessionId '
      'agent=$agent model=$effectiveModelMode '
      'path=$resolvedPath hasInitialMessage=${message?.isNotEmpty ?? false}',
    );

    late final SpawnSessionResponse result;
    final rpcStopwatch = Stopwatch()..start();
    try {
      result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      logger.info(
        '[createSession] RPC END type=${result.type} '
        'elapsedMs=${rpcStopwatch.elapsedMilliseconds}',
      );
    } catch (error, stack) {
      logger.warning(
        '[createSession] RPC FAILED '
        'elapsedMs=${rpcStopwatch.elapsedMilliseconds}: $error',
        error,
        stack,
      );
      rethrow;
    }

    if (result.type == 'success') {
      final newSessionId = result.sessionId;
      if (newSessionId == null || newSessionId.isEmpty) {
        throw StateError('Machine returned empty session ID');
      }

      final dek = result.dataEncryptionKey;
      if (dek != null && dek.isNotEmpty) {
        final decryptedKey = await encryption.decryptEncryptionKey(dek);
        if (decryptedKey != null) {
          await _ensureSessionEncryptionInitialized(newSessionId, decryptedKey);
        }
      }

      logger.info(
        '[createSession] END session=$newSessionId '
        'elapsedMs=${createStopwatch.elapsedMilliseconds}',
      );
      return newSessionId;
    }

    if (result.type == 'requestToApproveDirectoryCreation') {
      return createSession(
        machineId: machineId,
        path: resolvedPath,
        approvedNewDirectoryCreation: true,
        sessionId: requestedSessionId,
        agent: agent,
        profileId: profileId,
        message: message,
        modelMode: modelMode,
      );
    }

    final errorMsg = result.errorMessage ?? 'unknown error';

    if (errorMsg.contains('webhook timeout')) {
      logger.info(
        '[createSession] spawn webhook timeout for '
        'machine=$machineId path=$resolvedPath -- waiting for late session',
      );
      await Future<void>.delayed(const Duration(seconds: 5));
      await _refreshSessions();

      // Note: _sessions is not owned by MachineManager, so we cannot
      // inspect it directly here. The caller should handle webhook-timeout
      // recovery via the returned error or by checking sessions after the
      // refresh. For now, throw the error and let the caller retry.
      throw StateError(
        'Session creation timed out (webhook timeout). '
        'A session may have been created — please check your session list.',
      );
    }

    throw StateError(errorMsg);
  }

  // ── Machine RPC methods ───────────────────────────────────────────────

  /// Execute a bash command on a machine.
  Future<BashResponse> machineBash({
    required String machineId,
    required String command,
    required String cwd,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'bash',
        BashRequest(command: command, cwd: cwd).toJson(),
        BashResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineBash: socket not connected');
      } else if (_isTransientRpcError(error)) {
        logger.info('machineBash: transient RPC failure -- $error');
      } else {
        logger.error('machineBash error', error, stackTrace);
      }
    }
    return const BashResponse(success: false, stderr: 'RPC call failed');
  }

  /// Read a file from a machine via encrypted RPC.
  Future<ReadFileResponse> machineReadFile({
    required String machineId,
    required String filePath,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'readFile',
        ReadFileRequest(path: filePath).toJson(),
        ReadFileResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineReadFile: socket not connected');
      } else if (_isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineReadFile: RPC method not available '
          '(daemon too old) -- $error',
        );
        return const ReadFileResponse(
          success: false,
          error: 'File viewing requires a newer machine agent',
        );
      } else if (_isTransientRpcError(error)) {
        logger.info('machineReadFile: transient RPC failure -- $error');
      } else {
        logger.error('machineReadFile error', error, stackTrace);
      }
    }
    return const ReadFileResponse(success: false, error: 'RPC call failed');
  }

  /// Fetch Claude Code usage limits from a machine via encrypted RPC.
  Future<ClaudeUsageLimitsResponse> machineGetClaudeUsageLimits({
    required String machineId,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'get-claude-usage-limits',
        <String, dynamic>{},
        ClaudeUsageLimitsResponse.fromJson,
        timeout: const Duration(seconds: 15),
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetClaudeUsageLimits: machine offline');
        return const ClaudeUsageLimitsResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (_isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetClaudeUsageLimits: RPC method not available '
          '(daemon too old)',
        );
        return const ClaudeUsageLimitsResponse(
          success: false,
          error: 'RPC method not available',
        );
      } else if (_isTransientRpcError(error)) {
        logger.info(
          'machineGetClaudeUsageLimits: transient RPC failure -- $error',
        );
      } else {
        logger.error('machineGetClaudeUsageLimits error', error, stackTrace);
      }
    }
    return const ClaudeUsageLimitsResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Fetch the Codex model catalog from the machine's installed Codex CLI.
  Future<CodexModelsResponse> machineGetCodexModels({
    required String machineId,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'get-codex-models',
        <String, dynamic>{},
        CodexModelsResponse.fromJson,
      );
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetCodexModels: machine offline');
        return const CodexModelsResponse(
          success: false,
          models: [],
          error: 'machine offline',
        );
      } else if (_isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetCodexModels: RPC method not available '
          '(daemon too old)',
        );
        return const CodexModelsResponse(
          success: false,
          models: [],
          error: 'RPC method not available',
        );
      } else if (_isTransientRpcError(error)) {
        logger.info('machineGetCodexModels: transient RPC failure -- $error');
      } else {
        logger.error('machineGetCodexModels error', error, stackTrace);
      }
    }
    return const CodexModelsResponse(
      success: false,
      models: [],
      error: 'RPC call failed',
    );
  }

  /// Fetch Codex usage data from the machine's local Codex auth state.
  Future<CodexUsageSummaryResponse> machineGetCodexUsage({
    required String machineId,
  }) async {
    final machine = _machines[machineId];
    final cwd = machine?.metadata?.homeDir ?? '/';

    const codexUsageBashScript = r"""
python3 <<'PY'
import json
import os
import urllib.error
import urllib.request


def fail(message):
    print(json.dumps({'success': False, 'error': message}))
    raise SystemExit(0)


try:
    with open(os.path.expanduser('~/.codex/auth.json'), 'r',
              encoding='utf-8') as auth_file:
        auth = json.load(auth_file)
except Exception as exc:
    fail(f'Failed to read Codex auth.json: {exc}')

def find_access_token(value):
    if isinstance(value, dict):
        preferred_keys = (
            'accessToken',
            'access_token',
            'token',
            'idToken',
            'id_token',
        )
        for key in preferred_keys:
            token = value.get(key)
            if isinstance(token, str) and token:
                return token
        for nested in value.values():
            token = find_access_token(nested)
            if token:
                return token
    elif isinstance(value, list):
        for nested in value:
            token = find_access_token(nested)
            if token:
                return token
    return None


access_token = find_access_token(auth)
if not access_token:
    fail('No Codex access token found in auth.json')

request = urllib.request.Request(
    'https://chatgpt.com/backend-api/wham/usage',
    headers={
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'codex-cli',
    },
)

try:
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.loads(response.read().decode('utf-8'))
except urllib.error.HTTPError as exc:
    body = exc.read().decode('utf-8', errors='replace')
    fail(f'Codex usage request failed ({exc.code}): {body}')
except Exception as exc:
    fail(f'Failed to fetch Codex usage: {exc}')

if isinstance(payload, dict) and isinstance(payload.get('data'), dict):
    payload = payload['data']

if not isinstance(payload, dict):
    fail('Codex usage response was not an object')

print(json.dumps({'success': True, 'data': payload}))
PY
""";

    CodexUsageSummaryResponse parseRpcResponse(Map<String, dynamic> raw) {
      final data = raw.containsKey('data') ? raw['data'] : raw;
      final summary = data is Map<String, dynamic>
          ? CodexUsageSummary.fromJson(data)
          : data is Map
              ? CodexUsageSummary.fromJson(Map<String, dynamic>.from(data))
              : null;
      final hasSummary = summary?.hasUsageData ?? false;
      return CodexUsageSummaryResponse(
        success: raw['success'] == true || hasSummary,
        data: hasSummary ? summary : null,
        error: raw['error'] as String?,
      );
    }

    Future<CodexUsageSummaryResponse> fetchFromBash() async {
      final response = await machineBash(
        machineId: machineId,
        command: codexUsageBashScript,
        cwd: cwd,
      );

      if (!response.success) {
        return CodexUsageSummaryResponse(
          success: false,
          error: response.stderr.isNotEmpty ? response.stderr : response.error,
        );
      }

      try {
        final raw = jsonDecode(response.stdout) as Map<String, dynamic>;
        final success = raw['success'] == true;
        final data = raw['data'] ?? raw;
        final summary = data is Map<String, dynamic>
            ? CodexUsageSummary.fromJson(data)
            : data is Map
                ? CodexUsageSummary.fromJson(Map<String, dynamic>.from(data))
                : null;
        final hasSummary = summary?.hasUsageData ?? false;
        if (!success) {
          return CodexUsageSummaryResponse(
            success: false,
            error: raw['error'] as String?,
          );
        }
        return CodexUsageSummaryResponse(
          success: true,
          data: hasSummary ? summary : null,
          error: raw['error'] as String?,
        );
      } catch (error, stackTrace) {
        logger.error('machineGetCodexUsage parse error', error, stackTrace);
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'Failed to parse Codex usage response',
        );
      }
    }

    try {
      final response = await _typedMachineRPC(
        machineId,
        'get-codex-usage',
        <String, dynamic>{},
        parseRpcResponse,
        timeout: const Duration(seconds: 20),
      );
      if (!response.success) {
        return response;
      }
      if (response.data == null) {
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'Codex usage data missing',
        );
      }
      return response;
    } catch (error, stackTrace) {
      if (error is StateError && error.message.contains('not connected')) {
        logger.info('machineGetCodexUsage: machine offline');
        return const CodexUsageSummaryResponse(
          success: false,
          error: 'machine offline',
        );
      } else if (_isRpcMethodNotAvailable(error)) {
        logger.info(
          'machineGetCodexUsage: RPC method not available '
          '(daemon too old); falling back to machineBash',
        );
      } else if (_isTransientRpcError(error)) {
        logger.info('machineGetCodexUsage: transient RPC failure -- $error');
      } else {
        logger.error('machineGetCodexUsage RPC error', error, stackTrace);
      }
    }

    return fetchFromBash();
  }

  // ── createWorktree ──────────────────────────────────────────────────────

  /// Create a git worktree on a machine under `.dev/worktree/<name>`
  /// relative to [basePath] and return the absolute path to the new worktree.
  Future<String> createWorktree({
    required String machineId,
    required String basePath,
  }) async {
    final machine = _machines[machineId];
    final resolvedBasePath = (machine?.metadata?.homeDir != null)
        ? resolveAbsolutePath(basePath, homeDir: machine!.metadata!.homeDir)
        : basePath;

    final gitCheck = await machineBash(
      machineId: machineId,
      command: 'git rev-parse --git-dir',
      cwd: resolvedBasePath,
    );
    if (!gitCheck.success) {
      throw StateError('Not a Git repository');
    }

    final name = _generateWorktreeName();
    final worktreePath = '.dev/worktree/$name';
    var result = await machineBash(
      machineId: machineId,
      command: 'git worktree add -b $name $worktreePath',
      cwd: resolvedBasePath,
    );
    if (result.success) {
      return '$resolvedBasePath/$worktreePath';
    }

    if (result.stderr.contains('already exists')) {
      for (var i = 2; i <= 4; i++) {
        final newName = '$name-$i';
        final newPath = '.dev/worktree/$newName';
        result = await machineBash(
          machineId: machineId,
          command: 'git worktree add -b $newName $newPath',
          cwd: resolvedBasePath,
        );
        if (result.success) {
          return '$resolvedBasePath/$newPath';
        }
      }
    }

    throw StateError(
      result.stderr.isNotEmpty ? result.stderr : 'Failed to create worktree',
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  String _createClientSessionId() {
    final random = Random.secure();
    const alphabet = '0123456789abcdef';
    final chars = StringBuffer('c');
    for (var i = 0; i < 24; i++) {
      chars.write(alphabet[random.nextInt(alphabet.length)]);
    }
    return chars.toString();
  }

  String _generateWorktreeName() {
    final rand = Random();
    final adj = _worktreeAdjectives[rand.nextInt(_worktreeAdjectives.length)];
    final noun = _worktreeNouns[rand.nextInt(_worktreeNouns.length)];
    return '$adj-$noun';
  }

  Map<String, dynamic>? _normalizeSocketPayload(
    dynamic data, {
    required String handlerName,
  }) {
    if (data is Map<String, dynamic>) return data;
    if (data is List && data.isNotEmpty && data.first is Map) {
      return data.first as Map<String, dynamic>;
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          return decoded.first as Map<String, dynamic>;
        }
      } catch (_) {
        // ignore
      }
    }
    logger.warning(
      '$handlerName: unexpected payload type ${data.runtimeType}',
    );
    return null;
  }

  // ── Profile / model resolution helpers ──────────────────────────────────

  AIBackendProfile? _resolveProfile(String id) {
    for (final p in _settingsSnapshot.profiles) {
      if (p.id == id) return p;
    }
    return getBuiltInProfile(id);
  }

  Future<AIBackendProfile> _hydrateProfileForSpawn(
    AIBackendProfile profile,
  ) async {
    final hydrated = await SettingsStorage().hydrateProfileApiKeys(profile.id);
    return hydrated ?? profile;
  }

  Map<String, String> _profileEnvironmentVariables(AIBackendProfile profile) {
    final envVars = <String, String>{};

    for (final v in profile.environmentVariables) {
      envVars[v.name] = v.value;
    }

    final anthropic = profile.anthropicConfig;
    if (anthropic != null) {
      if (anthropic.baseUrl != null) {
        envVars['ANTHROPIC_BASE_URL'] = anthropic.baseUrl!;
      }
      if (anthropic.authToken != null) {
        envVars['ANTHROPIC_AUTH_TOKEN'] = anthropic.authToken!;
      }
      if (anthropic.model != null) {
        envVars['ANTHROPIC_MODEL'] = anthropic.model!;
      }
    }

    final openai = profile.openaiConfig;
    if (openai != null) {
      if (openai.apiKey != null) {
        envVars['OPENAI_API_KEY'] = openai.apiKey!;
      }
      if (openai.baseUrl != null) {
        envVars['OPENAI_BASE_URL'] = openai.baseUrl!;
      }
      if (openai.model != null) {
        envVars['OPENAI_MODEL'] = openai.model!;
      }
    }

    final azure = profile.azureOpenAIConfig;
    if (azure != null) {
      if (azure.apiKey != null) {
        envVars['AZURE_OPENAI_API_KEY'] = azure.apiKey!;
      }
      if (azure.endpoint != null) {
        envVars['AZURE_OPENAI_ENDPOINT'] = azure.endpoint!;
      }
      if (azure.apiVersion != null) {
        envVars['AZURE_OPENAI_API_VERSION'] = azure.apiVersion!;
      }
      if (azure.deploymentName != null) {
        envVars['AZURE_OPENAI_DEPLOYMENT_NAME'] = azure.deploymentName!;
      }
    }

    final together = profile.togetherAIConfig;
    if (together != null) {
      if (together.apiKey != null) {
        envVars['TOGETHER_API_KEY'] = together.apiKey!;
      }
      if (together.model != null) {
        envVars['TOGETHER_MODEL'] = together.model!;
      }
    }

    final tmux = profile.tmuxConfig;
    if (tmux != null) {
      if (tmux.sessionName != null) {
        envVars['TMUX_SESSION_NAME'] = tmux.sessionName!;
      }
      if (tmux.tmpDir != null) {
        envVars['TMUX_TMPDIR'] = tmux.tmpDir!;
      }
      if (tmux.updateEnvironment != null) {
        envVars['TMUX_UPDATE_ENVIRONMENT'] =
            tmux.updateEnvironment.toString();
      }
    }

    return envVars;
  }

  Map<String, String> _spawnEnvironmentVariables(Map<String, String>? base) {
    return <String, String>{...?base};
  }

  ({AIBackendProfile? profile, String? modelMode})
      _resolveEffectiveProfileForSpawn({
    required AIBackendProfile? profile,
    required String? modelMode,
    required String? agent,
  }) {
    if (profile == null) {
      return (profile: null, modelMode: modelMode);
    }
    if (!profile.compatibility.supportsAgent(agent ?? 'claude')) {
      logger.warning(
        '[createSession] profile ${profile.id} is not compatible with '
        'agent=$agent; spawning without profile env vars',
      );
      return (profile: null, modelMode: modelMode);
    }
    final baseUrl = _anthropicBaseUrlForProfile(profile);
    if (agent == 'claude' &&
        _isClaudeModelAlias(modelMode ?? '') &&
        _isThirdPartyAnthropicBaseUrl(baseUrl)) {
      logger.warning(
        '[createSession] dropping incompatible Claude model override '
        'profile=${profile.id} modelMode=$modelMode baseUrl=$baseUrl',
      );
      return (profile: profile, modelMode: 'default');
    }
    return (profile: profile, modelMode: modelMode);
  }

  String? _normalizeModelModeForAgent(String? modelMode, String? agent) {
    if (modelMode == null || modelMode == 'default') {
      return modelMode;
    }
    if (agent != 'claude' && _isClaudeModelAlias(modelMode)) {
      return 'default';
    }
    if (agent == 'claude' && _isNonClaudeModelMode(modelMode)) {
      return 'default';
    }
    return modelMode;
  }

  bool _isClaudeModelAlias(String modelMode) {
    final separator = modelMode.lastIndexOf(':');
    final slug = separator > 0 ? modelMode.substring(0, separator) : modelMode;
    return slug == 'opus' ||
        slug == 'sonnet' ||
        slug == 'haiku' ||
        slug == 'fable' ||
        slug.startsWith('claude-') ||
        slug.contains('/claude-');
  }

  bool _isThirdPartyAnthropicBaseUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return false;
    return !_isOfficialAnthropicBaseUrl(raw);
  }

  bool _isOfficialAnthropicBaseUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.host.toLowerCase() != 'api.anthropic.com') return false;
    final normalizedPath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return normalizedPath.isEmpty || normalizedPath == '/v1';
  }

  String? _anthropicBaseUrlForProfile(AIBackendProfile profile) {
    final configBaseUrl = profile.anthropicConfig?.baseUrl;
    if (configBaseUrl != null && configBaseUrl.isNotEmpty) {
      return _extractDefaultEnvValue(configBaseUrl);
    }
    for (final env in profile.environmentVariables) {
      if (env.name == 'ANTHROPIC_BASE_URL' && env.value.isNotEmpty) {
        return _extractDefaultEnvValue(env.value);
      }
    }
    return null;
  }

  String _extractDefaultEnvValue(String value) {
    final match = RegExp(r'^\$\{[^:}]+:-(.*)\}\$').firstMatch(value);
    return match?.group(1) ?? value;
  }

  bool _isNonClaudeModelMode(String modelMode) {
    if (modelMode.startsWith('gpt-')) return true;
    if (modelMode.startsWith('gemini-')) return true;
    if (modelMode.contains(':')) {
      final slug = modelMode.substring(0, modelMode.indexOf(':'));
      if (slug.startsWith('gpt-') || slug.startsWith('gemini-')) return true;
      return false;
    }
    return false;
  }

  String? _agentForProfile(AIBackendProfile? profile) {
    if (profile == null) return null;
    final compatibility = profile.compatibility;
    if (compatibility.codex && !compatibility.claude) return 'codex';
    if (compatibility.gemini && !compatibility.claude) return 'gemini';
    if (compatibility.pi && !compatibility.claude) return 'pi';
    return 'claude';
  }

  String? _getModelOverride({
    String? agent,
    AIBackendProfile? profile,
    String? modelMode,
  }) {
    final effectiveAgent = agent ?? _agentForProfile(profile);
    final normalized = _normalizeModelModeForAgent(modelMode, effectiveAgent);
    if (normalized != null && normalized != 'default') {
      return normalized;
    }
    return null;
  }

  // ── Typed machine RPC wrapper ───────────────────────────────────────────

  Future<Resp> _typedMachineRPC<Resp>(
    String machineId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final override = _machineRPCOverride;
    final raw = override != null
        ? await override(machineId, method, params, timeout: timeout)
        : await _machineRPC(machineId, method, params, timeout: timeout);
    if (raw == null) {
      throw StateError(
        'Machine RPC $method returned null -- '
        'test override may be misconfigured',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Machine RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    final error = raw['error'];
    if (method == 'spawn-happy-session' &&
        error is String &&
        error.contains('provider_model_mismatch')) {
      throw IncompatibleProviderAndModelError(
        error.replaceFirst('provider_model_mismatch: ', ''),
      );
    }
    return fromJson(raw);
  }

  /// Raw machine RPC. Throws if no override or dependency is provided.
  Future<dynamic> _machineRPC(
    String machineId,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    throw StateError(
      'machineRPC not configured. Provide a machineRPCOverride or '
      'wire this manager to a real RPC implementation.',
    );
  }

  Future<void> _ensureSessionEncryptionInitialized(
    String sessionId,
    Uint8List decryptedKey,
  ) async {
    // This is a placeholder that mirrors the Sync method.
    // In the full extraction, the caller (Sync) should handle this
    // via a callback or by exposing the encryption manager directly.
    // For now, encryption.initializeSessions handles this when fetchSessions
    // runs, and the DEK is cached in _machineDataKeys for later use.
    logger.info(
      '[MachineManager] Session encryption key prepared for $sessionId',
    );
  }
}

