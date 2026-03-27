import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../api/api_client.dart';
import '../api/kv_api.dart';
import '../api/push_api.dart';
import '../api/sessions_api.dart';
import '../api/socket_io_client.dart';
import '../encryption/aes_gcm.dart';
import '../encryption/artifact_encryption.dart';
import '../encryption/base64.dart';
import '../encryption/crypto_secret_box.dart';
import '../encryption/encryption_cache.dart';
import '../encryption/encryption_manager.dart';
import '../encryption/session_encryption.dart';
import '../models/api_update.dart';
import '../models/artifact.dart';
import '../models/auth.dart';
import '../models/built_in_profiles.dart';
import '../models/feed.dart';
import '../models/friend.dart';
import '../models/machine.dart';
import '../models/message.dart';
import '../models/profile.dart';
import '../models/purchases.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../models/todo.dart';
import '../rpc/rpc_types.dart';
import '../services/message_cache_service.dart';
import '../services/message_outbox.dart';
import '../services/network_monitor_service.dart';
import '../services/mmkv_storage.dart';
import '../services/server_config.dart';
import '../utils/invalidate_sync.dart';
import '../utils/parse_token.dart';
import '../utils/wire_parsers.dart';
import 'logger_service.dart';
import 'notification_service.dart';
import 'inline_message_processor.dart';
import 'message_cursor_manager.dart';
import 'sidechain_grouper.dart';
import 'tool_result_processor.dart';

// ── Isolate helpers: machine payload decryption ──────────────────────────

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

// ── Isolate helpers: artifact payload decryption ──────────────────────────

class _ArtifactIsolateItem {
  const _ArtifactIsolateItem({
    required this.id,
    required this.secretKey,
    required this.encryptedHeader,
    this.encryptedBody,
  });

  final String id;
  final Uint8List secretKey;
  final Uint8List encryptedHeader;
  final Uint8List? encryptedBody;
}

class _ArtifactIsolateResult {
  const _ArtifactIsolateResult({required this.id, this.header, this.body});

  final String id;
  final Map<String, dynamic>? header;
  final Map<String, dynamic>? body;
}

/// Decrypt machine metadata and daemonState.
/// AES-256-GCM items run in a background isolate; NaCl stays on main thread.
/// (isAes=false, legacy machines).
Future<List<_MachineIsolateResult>> _decryptMachinesInIsolate(
  List<_MachineIsolateItem> items,
) async {
  // Collect AES payloads for batch isolate decryption.
  // Each entry maps back to (itemIndex, 0=metadata | 1=daemonState).
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

  // Run AES batch in a background isolate (pure Dart — no FFI).
  Map<(int, int), dynamic>? aesResultMap;
  if (aesPayloads.isNotEmpty) {
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

  // Build results. AES items use isolate results; NaCl and
  // isolate-fallback items decrypt on the main thread.
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
      // NaCl (legacy) or AES isolate fallback.
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
            );
            if (d is Map<String, dynamic>) metadata = d;
          }
        } catch (e) {
          logger.warning(
            'Failed to decrypt machine metadata: $e',
          );
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
            );
          }
        } catch (e) {
          logger.warning(
            'Failed to decrypt machine daemon state: $e',
          );
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

/// Decrypt artifact headers and bodies in a background isolate.
/// Artifacts always use AES-256-GCM (pure Dart — fully isolate-safe).
Future<List<_ArtifactIsolateResult>> _decryptArtifactsInIsolate(
  List<_ArtifactIsolateItem> items,
) async {
  // Collect all payloads for batch isolate decryption.
  // Each entry maps to (itemIndex, 0=header | 1=body).
  final payloads = <Uint8List>[];
  final keys = <Uint8List>[];
  final mapping = <(int, int)>[];

  for (var i = 0; i < items.length; i++) {
    final item = items[i];

    final hRaw = item.encryptedHeader;
    if (hRaw.isNotEmpty && hRaw[0] == 0) {
      payloads.add(hRaw.sublist(1));
      keys.add(item.secretKey);
      mapping.add((i, 0));
    }

    final bRaw = item.encryptedBody;
    if (bRaw != null && bRaw.isNotEmpty && bRaw[0] == 0) {
      payloads.add(bRaw.sublist(1));
      keys.add(item.secretKey);
      mapping.add((i, 1));
    }
  }

  // Run batch in background isolate.
  Map<(int, int), dynamic>? resultMap;
  if (payloads.isNotEmpty) {
    try {
      final batchResults = await Isolate.run(
        () => AesGcmEncryption.decryptMultiKeyBatch(
          payloads,
          keys,
        ),
      );
      resultMap = {
        for (var i = 0; i < mapping.length; i++)
          mapping[i]: batchResults[i],
      };
    } catch (e) {
      logger.warning('Artifact AES isolate failed, '
          'falling back to main thread: $e');
    }
  }

  // Build results — fall back to main-thread decrypt on failure.
  final results = <_ArtifactIsolateResult>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    Map<String, dynamic>? header;
    Map<String, dynamic>? body;

    if (resultMap != null) {
      final hResult = resultMap[(i, 0)];
      if (hResult is Map<String, dynamic>) header = hResult;
      final bResult = resultMap[(i, 1)];
      if (bResult is Map<String, dynamic>) {
        body = {'body': bResult['body'] as String?};
      }
    } else {
      // Isolate fallback — main thread.
      final hRaw = item.encryptedHeader;
      if (hRaw.isNotEmpty && hRaw[0] == 0) {
        try {
          final d = await AesGcmEncryption.decrypt(
            hRaw.sublist(1),
            item.secretKey,
          );
          if (d is Map<String, dynamic>) header = d;
        } catch (e) {
          logger.warning(
            'Failed to decrypt artifact header: $e',
          );
        }
      }

      final bRaw = item.encryptedBody;
      if (bRaw != null && bRaw.isNotEmpty && bRaw[0] == 0) {
        try {
          final d = await AesGcmEncryption.decrypt(
            bRaw.sublist(1),
            item.secretKey,
          );
          if (d is Map<String, dynamic>) {
            body = {'body': d['body'] as String?};
          }
        } catch (e) {
          logger.warning(
            'Failed to decrypt artifact body: $e',
          );
        }
      }
    }

    results.add(
      _ArtifactIsolateResult(
        id: item.id,
        header: header,
        body: body,
      ),
    );
  }
  return results;
}

int? _asSessionInt(dynamic value) {
  return WireParsers.parseInt(value);
}

bool? _asSessionBool(dynamic value) {
  return WireParsers.parseBool(value);
}

int _parseCreatedAtMs(dynamic raw) {
  if (raw is int) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed.millisecondsSinceEpoch;
    }
  }
  return DateTime.now().millisecondsSinceEpoch;
}

// Global singleton instance
class Sync {
  factory Sync() => _instance;
  Sync._();
  static final Sync _instance = Sync._();

  // Constants
  static const int sessionReadyTimeoutMs = 3000;

  /// Number of recent messages to load on first open of a session.
  static const int initialLoad = 200;
  static const Set<String> _supportedPermissionModes = {
    'default',
    'acceptEdits',
    'bypassPermissions',
    'plan',
    'read-only',
    'safe-yolo',
    'yolo',
  };
  static const String _appendSystemPrompt = '''
# Options

You have a way to give a user a easy way to answer your questions if you know
possible answers. To provide this, you need to output in your final response
an XML:

<options>
    <option>Option 1</option>
    ...
    <option>Option N</option>
</options>

You must output this in the very end of your response, not inside of any
other text. Do not wrap it into a codeblock. Always dedicate "<options>" and
"</options>" to a dedicated line. Never output anything like "custom", user
always have an option to send a custom message. Do not enumerate options in
both text and options block.
Always prefer to use the options mode to the text mode. Try to keep options
minimal, better to clarify in a next steps.

# Plan mode with options

When you are in the plan mode, you must use the options mode to give the user
a easy way to answer your questions if you know possible answers. Do not
assume what is needed, when there is discrepancy between what you need and
what you have, you must use the options mode.
''';

  // Core dependencies
  late Encryption encryption;
  late String serverID;
  late String anonID;
  late AuthCredentials credentials;
  final EncryptionCache encryptionCache = EncryptionCache();
  final SidechainGrouper _sidechainGrouper = SidechainGrouper();
  final ToolResultProcessor _toolResultProcessor =
      ToolResultProcessor();
  final MessageCursorManager _cursorManager =
      MessageCursorManager();

  // Data key storage
  final Map<String, Uint8List> _sessionDataKeys = {};
  final Map<String, String> _sessionEncryptedDataKeys = {};
  final Map<String, Uint8List> _machineDataKeys = {};
  final Map<String, Uint8List> _artifactDataKeys = {};

  // Sync managers
  late InvalidateSync sessionsSync;
  final Map<String, InvalidateSync> messagesSync = {};
  // _sessionLastSeq and _sessionFirstLoadedSeq are managed
  // by _cursorManager. Aliases kept for internal access.
  Map<String, int> get _sessionLastSeq =>
      _cursorManager.lastSeq;
  Map<String, int> get _sessionFirstLoadedSeq =>
      _cursorManager.firstLoadedSeq;

  /// The session the user is currently viewing.  Updated by
  /// [onSessionVisible].  Used by [fetchMessages] to bail out
  /// early when the user navigates away mid-fetch.
  String? _visibleSessionId;

  /// Sessions currently being paginated backwards (older-message loads).
  final Set<String> _loadingOlderMessages = {};

  /// Sessions that received socket messages while non-visible.
  /// Used to force a server fetch (instead of stale cache restore) when
  /// the user opens a session that had pending socket messages.
  final Set<String> _sessionsWithPendingSocketMessages = {};

  /// Permission IDs for which a local notification has already been
  /// fired.  Prevents duplicate notifications across repeated
  /// [fetchSessions] calls.
  ///
  /// Capped at [_maxNotifiedPermissionIds] to prevent unbounded growth
  /// across a long session; oldest entries are evicted when the cap is
  /// reached.  Active (unresolved) permissions are re-added on next
  /// [_checkForNewPermissionRequests] call if needed.
  final Set<String> _notifiedPermissionIds = {};
  static const int _maxNotifiedPermissionIds = 500;

  /// Dedup set + FIFO queue for inline socket messages.  Keyed by
  /// `"$sessionId:$messageId:$seq"` to skip duplicate `new-message`
  /// events that the server broadcasts multiple times.
  /// Queue provides O(1) FIFO eviction; Set provides O(1) lookup.
  final Set<String> _recentInlineMessageKeys = {};
  final Queue<String> _recentInlineMessageKeyOrder = Queue<String>();
  static const int _maxRecentInlineKeys = 500;

  /// Per-session serial queue for inline message processing.
  final InlineMessageProcessor _inlineProcessor =
      InlineMessageProcessor();

  /// Timer for deferred sidechain re-grouping.  After each inline
  /// sidechain message is processed, we schedule a short delayed
  /// sweep to catch any messages that were orphaned due to transient
  /// chain gaps (e.g. a message arrived before its parent was
  /// processed on a previous run).
  final Map<String, Timer> _sidechainRegroupTimers = {};
  late InvalidateSync settingsSync;
  late InvalidateSync profileSync;
  late InvalidateSync purchasesSync;
  late InvalidateSync machinesSync;
  late InvalidateSync pushTokenSync;
  late InvalidateSync nativeUpdateSync;
  late InvalidateSync artifactsSync;
  late InvalidateSync friendsSync;
  late InvalidateSync friendRequestsSync;
  late InvalidateSync feedSync;
  late InvalidateSync todosSync;
  late InvalidateSync sessionGitStatusSync;

  // State tracking
  bool revenueCatInitialized = false;
  bool isInitialized = false;
  bool _isReady = false;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _registeredPushToken;
  String? _nativeUpdateUrl;

  // Pending settings
  Map<String, dynamic> pendingSettings = {};
  final Map<String?, TodoList> _todoLists = <String?, TodoList>{};
  final List<UserProfile> _friends = <UserProfile>[];
  final List<FriendRequest> _friendRequests = <FriendRequest>[];
  final List<FeedItem> _feedItems = <FeedItem>[];
  final List<DecryptedArtifact> _artifacts = <DecryptedArtifact>[];
  final Map<String, List<Map<String, dynamic>>> _sessionMessages = {};
  Map<String, List<Map<String, dynamic>>>? _sessionMessagesCache;
  final Map<String, List<Map<String, dynamic>>> _sessionMessagesViewCache = {};
  final Map<String, Map<String, dynamic>> _sessionUsage = {};
  Settings _settingsSnapshot = Settings();
  int _settingsVersion = 0;
  Purchases _purchases = Purchases.defaults;
  Map<String, Session> _sessions = <String, Session>{};
  int? _lastSessionsFetchedAt;
  bool _forceFullFetchNext = false;
  int? _lastInvalidateAllSyncsAtMs;
  /// Timestamp of last resume() call for debouncing rapid pause/resume cycles.
  int? _lastResumeAtMs;
  /// Minimum interval between resume() calls — prevents socket reconnect loops
  /// when the app cycles between paused and resumed states repeatedly.
  static const int _resumeDebounceWindowMs = 2000;
  /// Delay before firing network invalidations on resume. Cancelled by
  /// suspend() so that rapid foreground/background cycling does not produce
  /// wasted HTTP requests that the OS aborts mid-flight.
  Timer? _deferredResumeInvalidationTimer;
  Timer? _sessionsRefreshDebounceTimer;
  final Set<String> _pendingNewSessionIds = <String>{};
  final Map<String, Machine> _machines = <String, Machine>{};
  // Timers that drop presence back to 'offline' if no activity arrives.
  final Map<String, Timer> _presenceTimers = {};
  Profile? _profile;
  final Map<String, GitStatus> _sessionGitStatus = <String, GitStatus>{};

  // Change notification streams
  final _dataChangeController = StreamController<void>.broadcast();
  final _sessionMessageChangeController = StreamController<String>.broadcast();
  Timer? _dataChangeDebounceTimer;
  final Map<String, Timer> _sessionMessageDebounceTimers = {};
  /// Monotonic counter incremented on every data change. Providers compare
  /// this against their last-seen value to skip expensive equality checks
  /// when nothing has changed.
  int _dataChangeCounter = 0;
  Timer? _saveSeqDebounceTimer;
  Timer? _saveSessionsCacheDebounceTimer;
  final Map<String, Timer> _saveMsgsDebounceTimers = {};
  final Map<String, Timer> _postSendCatchUpTimers = {};
  final Set<String> _sessionsNeedingTailRefresh = <String>{};

  /// Sessions that received `new-message` socket events while they were
  /// not visible. When the user navigates to one of these sessions,
  /// [onSessionVisible] forces a tail-refresh so [fetchMessages] bypasses
  /// the `cursorSeq >= serverLastSeq` skip and fetches any messages that
  /// were dropped while the session was in the background.
  final Set<String> _sessionsWithPendingUpdates = <String>{};
  final Map<String, int> _sessionUnreadCounts = <String, int>{};

  /// Session IDs that triggered `update-session` since the last debounced
  /// sessions refresh.  Used to suppress duplicate log entries when the
  /// server broadcasts dozens of identical events per second.
  final Set<String> _pendingUpdateSessionIds = <String>{};

  // sessionId → epoch-ms of last local spawn. Lets _resolveSendTargetSession
  // skip auto-restore while the daemon's lifecycle update propagates (< 5 s).
  final Map<String, int> _sessionSpawnedAt = {};
  // Track sessions currently undergoing auto-restore to prevent concurrent
  // RPCs.
  final Set<String> _autoRestoreInFlight = {};

  // sessionId → epoch-ms of last ephemeral event (keep-alive or activity).
  // Used by _resolveSendTargetSession to avoid trusting stale 'online'
  // presence after a daemon restart (full-fetch timer reset can leave dead
  // sessions appearing online for up to 60 s).
  final Map<String, int> _lastEphemeralAt = {};

  /// Sessions that have been archived locally but the server hasn't confirmed
  /// yet (replication lag). These are filtered from the active sessions list
  /// to prevent the "archive then reappear" bug.
  final Set<String> _optimisticallyArchivedSessions = {};

  /// Tool results that arrived before their corresponding tool-call message.
  /// Maps sessionId → list of pending tool results. Applied when the tool-call
  /// message arrives via inline processing or HTTP fetch.
  final Map<String, List<Map<String, dynamic>>> _pendingToolResults = {};
  @visibleForTesting
  bool? testSocketConnectedOverride;
  @visibleForTesting
  void Function(String event, dynamic data)? testSocketSendOverride;
  @visibleForTesting
  Future<void>? lastCompleteSendFuture;

  Map<String?, TodoList> get todoLists => Map.unmodifiable(_todoLists);
  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get friendRequests => List.unmodifiable(_friendRequests);
  List<FeedItem> get feedItems => List.unmodifiable(_feedItems);
  List<DecryptedArtifact> get artifacts => List.unmodifiable(_artifacts);

  /// Get usage data for a session (contextSize, inputTokens, outputTokens).
  Map<String, Map<String, dynamic>> get sessionUsage =>
      Map.unmodifiable(_sessionUsage);
  Settings get settingsSnapshot => _settingsSnapshot;
  int get settingsVersion => _settingsVersion;
  Purchases get purchases => _purchases;
  Map<String, Session> get sessions => Map.unmodifiable(_sessions);

  /// Per-session message seq cursors. Exposed for debug UI.
  Map<String, int> get sessionMessageCursors =>
      Map.unmodifiable(_sessionLastSeq);

  @visibleForTesting
  Map<String, Session> get testSessions => _sessions;

  @visibleForTesting
  void testNotifyDataChanged() => _notifyDataChanged();

  @visibleForTesting
  int? get testLastSessionsFetchedAt => _lastSessionsFetchedAt;

  @visibleForTesting
  set testLastSessionsFetchedAt(int? value) => _lastSessionsFetchedAt = value;

  @visibleForTesting
  bool get testForceFullFetchNext => _forceFullFetchNext;

  @visibleForTesting
  set testForceFullFetchNext(bool value) => _forceFullFetchNext = value;

  @visibleForTesting
  int? get testLastInvalidateAllSyncsAtMs => _lastInvalidateAllSyncsAtMs;

  @visibleForTesting
  set testLastInvalidateAllSyncsAtMs(int? value) =>
      _lastInvalidateAllSyncsAtMs = value;

  @visibleForTesting
  bool get testIsInitialized => isInitialized;

  @visibleForTesting
  set testIsInitialized(bool value) => isInitialized = value;

  @visibleForTesting
  void testInvalidateAllSyncs({
    bool force = false,
    bool resetSessionDeltaCursor = false,
  }) => _invalidateAllSyncs(
    force: force,
    resetSessionDeltaCursor: resetSessionDeltaCursor,
  );

  @visibleForTesting
  void testSetSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    _sessionMessages[sessionId] = List<Map<String, dynamic>>.from(messages);
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.remove(sessionId);
  }

  @visibleForTesting
  Future<void> testPrimeSessionFromSpawnResult({
    required String requestedSessionId,
    required String restoredSessionId,
    required Session seedSession,
    required SpawnSessionResponse result,
  }) => _primeSessionFromSpawnResult(
    requestedSessionId: requestedSessionId,
    restoredSessionId: restoredSessionId,
    seedSession: seedSession,
    result: result,
  );

  @visibleForTesting
  void testGroupSidechainMessages(String sessionId) {
    _groupSidechainMessages(sessionId);
  }

  @visibleForTesting
  void testApplyToolResults(
    String sessionId,
    List<Map<String, dynamic>> toolResults,
  ) {
    _applyToolResults(sessionId, toolResults);
  }

  @visibleForTesting
  Set<String> get testSessionsWithPendingUpdates =>
      _sessionsWithPendingUpdates;

  @visibleForTesting
  set testVisibleSessionId(String? value) => _visibleSessionId = value;

  @visibleForTesting
  void testNotifySessionMessagesChanged(String sessionId) {
    if (!_sessionMessageChangeController.isClosed) {
      _sessionMessageChangeController.add(sessionId);
    }
  }

  /// Overrides the HTTP fetch path in [fetchMessages] for integration tests.
  /// When set, [fetchMessages] calls this instead of making a real HTTP request.
  /// The callback receives (sessionId, afterSeq, limit) and returns the parsed
  /// response map.
  @visibleForTesting
  Future<Map<String, dynamic>>? Function(
    String sessionId,
    int afterSeq,
    int limit,
  )? testFetchMessagesOverride;

  /// Overrides the HTTP fetch path in [fetchOlderMessages] for integration
  /// tests. When set, [fetchOlderMessages] calls this instead of making a real
  /// HTTP request. The callback receives (sessionId, afterSeq, limit) and
  /// returns the parsed response map.
  @visibleForTesting
  Future<Map<String, dynamic>>? Function(
    String sessionId,
    int afterSeq,
    int limit,
  )? testFetchOlderMessagesOverride;

  /// Sets the in-memory seq cursor for a session (bypasses the normal
  /// inline-processing path that normally updates this from socket events).
  @visibleForTesting
  void testSetSessionLastSeq(String sessionId, int seq) {
    _sessionLastSeq[sessionId] = seq;
  }

  /// Test helper: directly set _sessionsWithPendingSocketMessages.
  @visibleForTesting
  void testSetPendingSocketMessages(Set<String> sessionIds) {
    _sessionsWithPendingSocketMessages.addAll(sessionIds);
  }

  /// Test helper: check if a session has pending socket messages.
  @visibleForTesting
  bool testHasPendingSocketMessage(String sessionId) =>
      _sessionsWithPendingSocketMessages.contains(sessionId);

  /// Test helper: clear _sessionsWithPendingSocketMessages.
  @visibleForTesting
  void testClearSessionsWithPendingSocketMessages() =>
      _sessionsWithPendingSocketMessages.clear();

  /// Test helper: reset _lastResumeAtMs to bypass resume debounce in tests.
  @visibleForTesting
  void testResetLastResumeAtMs() => _lastResumeAtMs = null;

  /// Test helper: check if _pendingUpdateSessionIds is empty.
  @visibleForTesting
  bool testPendingUpdateSessionIdsEmpty() =>
      _pendingUpdateSessionIds.isEmpty;

  /// Test helper: get _visibleSessionId.
  @visibleForTesting
  String? testGetVisibleSessionId() => _visibleSessionId;

  /// Test helper: check if inline queue contains a session.
  @visibleForTesting
  bool testInlineQueueContains(String sessionId) =>
      _inlineProcessor.contains(sessionId);

  /// Test helper: get pending tool results for a session.
  @visibleForTesting
  List<Map<String, dynamic>> testPendingToolResults(String sessionId) =>
      _pendingToolResults[sessionId] ?? [];

  /// Test helper: get _sessionsNeedingTailRefresh as a set.
  @visibleForTesting
  Set<String> testSessionsNeedingTailRefresh() =>
      Set<String>.from(_sessionsNeedingTailRefresh);

  /// Test helper: add a session to _sessionsNeedingTailRefresh.
  @visibleForTesting
  void testAddSessionsNeedingTailRefresh(String sessionId) {
    _sessionsNeedingTailRefresh.add(sessionId);
  }

  /// Test helper: get _sessionMessages for a session (null if none).
  @visibleForTesting
  List<Map<String, dynamic>>? testSessionMessages(String sessionId) =>
      _sessionMessages[sessionId];

  /// Test helper: get the first loaded seq for a session (null if not set).
  @visibleForTesting
  int? testSessionFirstLoadedSeq(String sessionId) =>
      _sessionFirstLoadedSeq[sessionId];

  /// Test helper: set the first loaded seq for a session.
  @visibleForTesting
  void testSetSessionFirstLoadedSeq(String sessionId, int seq) {
    _sessionFirstLoadedSeq[sessionId] = seq;
  }

  /// Test helper: get _sessionSpawnedAt map.
  @visibleForTesting
  Map<String, int> get testSessionSpawnedAt => _sessionSpawnedAt;

  /// Test helper: set a spawn timestamp for a session.
  @visibleForTesting
  void testSetSessionSpawnedAt(String sessionId, int epochMs) {
    _sessionSpawnedAt[sessionId] = epochMs;
  }

  /// Test helper: clear all spawn timestamps.
  @visibleForTesting
  void testClearSessionSpawnedAt() => _sessionSpawnedAt.clear();

  /// Test helper: record a recent ephemeral event for a session so
  /// that [_isSessionReady] trusts its 'online' presence.
  @visibleForTesting
  void testSetLastEphemeralAt(String sessionId, int epochMs) {
    _lastEphemeralAt[sessionId] = epochMs;
  }

  /// Test helper: invoke [_checkForNewPermissionRequests].
  @visibleForTesting
  void testCheckForNewPermissionRequests(Iterable<Session> sessions) =>
      _checkForNewPermissionRequests(sessions);

  /// Test helper: read [_notifiedPermissionIds].
  @visibleForTesting
  Set<String> get testNotifiedPermissionIds => _notifiedPermissionIds;

  /// Test helper: get _autoRestoreInFlight set.
  @visibleForTesting
  Set<String> get testAutoRestoreInFlight => _autoRestoreInFlight;

  /// Test helper: override _typedMachineRPC for testing createSession
  /// and auto-restore without a real socket connection.
  @visibleForTesting
  Future<dynamic> Function(
    String machineId,
    String method,
    Map<String, dynamic> params,
  )? testMachineRPCOverride;

  /// Test helper: set the _isReady flag.
  @visibleForTesting
  set testIsReady(bool value) => _isReady = value;

  /// Test helper: override fetchSingleSession for testing sendMessage
  /// encryption recovery without a real API call.
  @visibleForTesting
  Future<Session?> Function(String sessionId)? testFetchSingleSessionOverride;

  /// Test helper: override _getSpawnEnvVarsForSession to avoid MMKV
  /// dependency in tests that exercise auto-restore / createSession.
  @visibleForTesting
  Future<({Map<String, String> envVars, AIBackendProfile? profile})>
      Function(String sessionId)? testGetSpawnEnvVarsOverride;

  /// Test helper: invoke [_getModelOverride] which is private.
  @visibleForTesting
  String? testGetModelOverride({AIBackendProfile? profile}) =>
      _getModelOverride(profile: profile);

  /// Test helper: set [_settingsSnapshot] for model override tests.
  @visibleForTesting
  set testSettingsSnapshot(Settings value) =>
      _settingsSnapshot = value;

  Map<String, Machine> get machines => Map.unmodifiable(_machines);
  Profile? get profile => _profile;
  bool get isReady => _isReady;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get nativeUpdateUrl => _nativeUpdateUrl;
  bool get hasNativeUpdate => _nativeUpdateUrl != null;
  Map<String, GitStatus> get sessionGitStatus =>
      Map.unmodifiable(_sessionGitStatus);
  Map<String, List<Map<String, dynamic>>> get sessionMessages {
    _sessionMessagesCache ??= Map.unmodifiable(
      _sessionMessages.map(
        (key, value) =>
            MapEntry(key, List<Map<String, dynamic>>.unmodifiable(value)),
      ),
    );
    return _sessionMessagesCache!;
  }

  /// Returns the messages for a single session without copying all sessions.
  List<Map<String, dynamic>> messagesForSession(String sessionId) =>
      _sessionMessagesViewCache.putIfAbsent(
        sessionId,
        () => List<Map<String, dynamic>>.unmodifiable(
          _sessionMessages[sessionId] ?? const <Map<String, dynamic>>[],
        ),
      );

  /// Returns the timestamp of the last message in a session, or null if
  /// there are no messages.
  int? getLastMessageTimestamp(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return null;
    // Messages are stored in ascending seq order, so the last one has the
    // highest seq (most recent).
    final lastMessage = messages.last;
    return lastMessage['createdAt'] as int?;
  }

  /// Returns a brief preview of the last message in a session.
  ///
  /// Scans from the end to find the last assistant or human message
  /// with non-empty text content. Strips markdown, collapses
  /// whitespace, and truncates to [_kPreviewMaxLen] characters.
  /// Returns null when no suitable preview is available.
  String? getLastMessagePreview(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return null;
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final role = msg['role'] as String?;
      if (role != MessageRole.agent && role != MessageRole.user) continue;
      final text = msg['text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        return _cleanPreviewText(text.trim());
      }
    }
    return null;
  }

  /// Returns the role ([MessageRole.user] or [MessageRole.agent]) of
  /// the message used by [getLastMessagePreview], or null.
  String? getLastMessageRole(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return null;
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final role = msg['role'] as String?;
      if (role != MessageRole.agent && role != MessageRole.user) continue;
      final text = msg['text'] as String?;
      if (text != null && text.trim().isNotEmpty) return role;
    }
    return null;
  }

  static const _kPreviewMaxLen = 120;

  /// Strips markdown formatting, collapses whitespace, and truncates
  /// [raw] to a clean single-line preview string.
  static String _cleanPreviewText(String raw) {
    var text = raw;
    // Fenced code blocks
    text = text.replaceAll(
      RegExp(r'```[\s\S]*?```', multiLine: true),
      ' [code]',
    );
    // Inline code
    text = text.replaceAll(RegExp(r'`[^`]+`'), ' [code]');
    // Images: ![alt](url)
    text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), ' [image]');
    // Links: [text](url)
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    // Bold/italic markers
    text = text.replaceAll(RegExp(r'\*{1,3}'), '');
    text = text.replaceAll(RegExp(r'_{1,3}'), '');
    // Strikethrough
    text = text.replaceAll(RegExp(r'~~'), '');
    // Headings
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Blockquotes
    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    // HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    // Collapse whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Truncate
    if (text.length > _kPreviewMaxLen) {
      text = '${text.substring(0, _kPreviewMaxLen)}…';
    }
    return text;
  }

  /// Returns true when there are older messages available for [sessionId]
  /// that have not yet been loaded.
  bool hasOlderMessages(String sessionId) {
    final firstLoaded = _sessionFirstLoadedSeq[sessionId];
    return firstLoaded != null && firstLoaded > 1;
  }

  /// Returns true while an older-message page fetch is in progress for
  /// [sessionId].
  bool isLoadingOlderMessages(String sessionId) =>
      _loadingOlderMessages.contains(sessionId);

  /// Returns the unread message count for [sessionId].
  int getUnreadCount(String sessionId) =>
      _sessionUnreadCounts[sessionId] ?? 0;

  /// Stream that emits when session/machine/general data changes.
  Stream<void> get onDataChanged => _dataChangeController.stream;

  /// Monotonic counter incremented on every data change notification.
  /// Providers compare this to skip expensive equality checks.
  int get dataChangeCounter => _dataChangeCounter;

  /// Stream that emits the sessionId when messages for that session change.
  Stream<String> get onSessionMessagesChanged =>
      _sessionMessageChangeController.stream;

  /// Returns true for transient network errors that are not actionable
  /// (e.g. DNS failure, timeout, Cronet aborting a connection because the
  /// app was backgrounded).
  static bool _isTransientConnectionError(Object error) {
    final msg = error.toString();
    return msg.contains('ERR_CONNECTION_ABORTED') ||
        msg.contains('ERR_CONNECTION_RESET') ||
        msg.contains('ERR_NAME_NOT_RESOLVED') ||
        msg.contains('ERR_CONNECTION_TIMED_OUT') ||
        msg.contains('ERR_NETWORK_CHANGED') ||
        msg.contains('ERR_INTERNET_DISCONNECTED') ||
        msg.contains('ERR_ADDRESS_UNREACHABLE') ||
        msg.contains('Failed host lookup') ||
        msg.contains('No address associated') ||
        msg.contains('Connection closed') ||
        msg.contains('Software caused connection abort');
  }

  bool _isSocketConnected() {
    return testSocketConnectedOverride ??
        socketIoClient.connectionStatus == ConnectionStatus.connected;
  }

  void _socketSend(String event, dynamic data) {
    if (testSocketSendOverride != null) {
      testSocketSendOverride!(event, data);
    } else {
      socketIoClient.send(event, data);
    }
  }

  /// Initialize sync with credentials and encryption
  Future<void> create(
    AuthCredentials credentials,
    Encryption encryption,
  ) async {
    if (isInitialized) {
      logger.info('Sync already initialized');
      return;
    }

    this.credentials = credentials;
    this.encryption = encryption;
    anonID = encryption.anonId;
    serverID = parseToken(credentials.token);
    await _init();

    // Await initial syncs
    await settingsSync.awaitQueue();
    await profileSync.awaitQueue();
    await purchasesSync.awaitQueue();

    isInitialized = true;
  }

  /// Restore sync state from disk (app restart)
  Future<void> restore(
    AuthCredentials credentials,
    Encryption encryption,
  ) async {
    if (isInitialized) {
      logger.info('Sync already initialized');
      return;
    }

    this.credentials = credentials;
    this.encryption = encryption;
    anonID = encryption.anonId;
    serverID = parseToken(credentials.token);
    await _init();
    // isInitialized is set early inside _init() after cache restore.
  }

  /// Internal initialization
  Future<void> _init() async {
    // Restore persisted message cursors
    _sessionLastSeq
      ..clear()
      ..addAll(MMKVStorage().getSessionLastSeq());
    _sessionFirstLoadedSeq
      ..clear()
      ..addAll(MMKVStorage().getSessionFirstLoadedSeq());
    await _restoreSessionsCache();

    // Restore cached settings so that loadFromSync() serves the user's
    // last-known settings instead of defaults before syncSettings()
    // completes.  Without this, there is a race between checkAuth()
    // (which calls loadFromSync → reads _settingsSnapshot) and
    // _initializeTheme() (which loads from MMKV).  If checkAuth wins,
    // the Riverpod state briefly reverts to Settings() defaults.
    _settingsSnapshot = await MMKVStorage().getSettings();

    // Bulk-restore cached messages for all sessions so that
    // getLastMessagePreview() works immediately on cold start.
    // Deferred off the synchronous _init() critical path — sessions can
    // render from the session cache before per-session message caches are
    // warm.  Messages are loaded lazily when the user opens a chat.
    unawaited(_restoreAllCachedMessagesAsync());

    // Initialize sync managers
    sessionsSync = InvalidateSync(fetchSessions, name: 'fetchSessions');
    settingsSync = InvalidateSync(syncSettings, name: 'syncSettings');
    profileSync = InvalidateSync(fetchProfile, name: 'fetchProfile');
    purchasesSync = InvalidateSync(syncPurchases, name: 'syncPurchases');
    machinesSync = InvalidateSync(fetchMachines, name: 'fetchMachines');
    pushTokenSync = InvalidateSync(syncPushToken, name: 'syncPushToken');
    nativeUpdateSync =
        InvalidateSync(fetchNativeUpdate, name: 'fetchNativeUpdate');
    artifactsSync =
        InvalidateSync(fetchArtifactsList, name: 'fetchArtifactsList');
    friendsSync = InvalidateSync(fetchFriends, name: 'fetchFriends');
    friendRequestsSync =
        InvalidateSync(fetchFriendRequests, name: 'fetchFriendRequests');
    feedSync = InvalidateSync(fetchFeed, name: 'fetchFeed');
    todosSync = InvalidateSync(fetchTodos, name: 'fetchTodos');
    sessionGitStatusSync =
        InvalidateSync(_fetchSessionGitStatus, name: 'fetchSessionGitStatus');

    // Mark initialized early so that provider loadFromSync() can serve
    // cached sessions and messages immediately, before network syncs
    // complete.  Screens subscribing to onDataChanged will pick up the
    // cached snapshot within the debounce window (~100ms).
    isInitialized = true;
    _notifyDataChanged();

    // Setup socket connection
    final serverUrl = getServerUrl();
    socketIoClient.connect(
      serverUrl: serverUrl,
      token: credentials.token,
      clientType: 'user-scoped',
    );

    // Subscribe to updates
    subscribeToUpdates();

    // Invalidate all syncs. Preserve the sessions delta cursor when a cached
    // session snapshot exists so cold launches can use incremental sync.
    _invalidateAllSyncs(
      force: true,
      resetSessionDeltaCursor: _lastSessionsFetchedAt == null,
    );

    // Wait for sessions and machines to load before marking as ready.
    try {
      await Future.wait([sessionsSync.awaitQueue(), machinesSync.awaitQueue()]);
      _isReady = true;
    } catch (error) {
      logger.warning('Failed initial ready sync', error);
    }

    // Configure and restore the message outbox after sync is ready so
    // the encryption context is available for re-sends.
    messageOutbox.configure(
      deliver: _deliverOutboxEntry,
      onStatusChanged: (sessionId, localId, status) {
        _updateMessageSendStatus(sessionId, localId, status);
        if (!_sessionMessageChangeController.isClosed) {
          _sessionMessageChangeController.add(sessionId);
        }
      },
    );
    unawaited(messageOutbox.restoreAndFlush());
  }

  /// Invalidate all sync managers
  static const int _invalidateAllSyncsCooldownMs = 5000;

  /// Phases for selective sync invalidation to prevent thundering herd
  static const _criticalSyncPhase = 0;
  static const _deferredSyncPhase = 1;
  Timer? _deferredSyncsTimer;

  void _invalidateAllSyncs({
    bool force = false,
    bool resetSessionDeltaCursor = false,
    @visibleForTesting int? phase,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastRunMs = _lastInvalidateAllSyncsAtMs;
    if (!force &&
        lastRunMs != null &&
        nowMs - lastRunMs < _invalidateAllSyncsCooldownMs) {
      logger.info('Skipping duplicate global sync invalidation');
      return;
    }
    _lastInvalidateAllSyncsAtMs = nowMs;

    if (resetSessionDeltaCursor) {
      _lastSessionsFetchedAt = null;
    }

    // Phase 0: Critical syncs (sessions, machines) - immediate invalidation
    // These are essential for core app functionality and navigation
    if (phase == null || phase == _criticalSyncPhase) {
      sessionsSync.invalidate();
      machinesSync.invalidate();

      // Settings, profile, and purchases are also critical for UI
      settingsSync.invalidate();
      profileSync.invalidate();
      purchasesSync.invalidate();

      // Push token and native update are low-priority but fast
      pushTokenSync.invalidate();
      nativeUpdateSync.invalidate();

      logger.info(
        'Invalidated critical syncs '
        '(sessions, machines, settings, profile, purchases)',
      );
    }

    // Phase 1: Deferred syncs - invalidate after 2-3 second staggered delay
    // These are non-critical and can be loaded lazily when accessed
    if (phase == null || phase == _deferredSyncPhase) {
      _deferredSyncsTimer?.cancel();
      _deferredSyncsTimer = Timer(
        const Duration(milliseconds: 2500),
        () {
          // Only invalidate if sync is still initialized to avoid
          // errors after logout/dispose
          if (!isInitialized) return;
          logger.info(
            'Invalidating deferred syncs '
            '(friends, feed, todos, artifacts, git status)',
          );
          friendsSync.invalidate();
          friendRequestsSync.invalidate();
          feedSync.invalidate();
          todosSync.invalidate();
          artifactsSync.invalidate();
          sessionGitStatusSync.invalidate();
        },
      );
    }
  }

  /// Leading-edge + trailing-edge debounced data change notification.
  ///
  /// The counter is incremented immediately so that callers like
  /// `loadFromSync()` can detect the change without waiting for the
  /// debounce timer.
  ///
  /// The stream emission uses a leading+trailing pattern: the first
  /// call in a quiet window fires immediately (so the UI updates
  /// promptly), then subsequent calls within 250ms are coalesced
  /// into a single trailing emission.  This prevents the old
  /// cancel-and-restart pattern from deferring the emission
  /// indefinitely during sustained streaming (events every 20-50ms).
  void _notifyDataChanged() {
    _dataChangeCounter++;
    // If no timer is running, fire immediately (leading edge) and
    // start a cooldown window.
    if (_dataChangeDebounceTimer == null ||
        !_dataChangeDebounceTimer!.isActive) {
      if (!_dataChangeController.isClosed) {
        _dataChangeController.add(null);
      }
      _dataChangePendingTrailing = false;
      _dataChangeDebounceTimer =
          Timer(const Duration(milliseconds: 250), () {
        // Trailing edge: emit once more if calls arrived during
        // the cooldown window.
        if (_dataChangePendingTrailing &&
            !_dataChangeController.isClosed) {
          _dataChangeController.add(null);
        }
        _dataChangePendingTrailing = false;
      });
    } else {
      // Timer is active — mark that a trailing emission is needed.
      _dataChangePendingTrailing = true;
    }
  }
  bool _dataChangePendingTrailing = false;

  /// Immediately emit data change notification, bypassing debounce.
  /// Use sparingly when listeners need to be notified synchronously.
  void _flushDataChanged() {
    _dataChangeDebounceTimer?.cancel();
    _dataChangeCounter++;
    if (!_dataChangeController.isClosed) {
      _dataChangeController.add(null);
    }
  }

  /// Debounced session-message change notification.
  /// Coalesces rapid token-level updates into one emission per 200ms window
  /// per session, preventing the chat screen from rebuilding on every token.
  void _notifySessionMessagesChanged(String sessionId) {
    _sessionMessageDebounceTimers[sessionId]?.cancel();
    _sessionMessageDebounceTimers[sessionId] = Timer(
      const Duration(milliseconds: 200),
      () {
        _sessionMessageDebounceTimers.remove(sessionId);
        if (!_sessionMessageChangeController.isClosed) {
          _sessionMessageChangeController.add(sessionId);
        }
      },
    );
    // Persist updated messages to MMKV for instant cold-start load.
    _scheduleSaveMessages(sessionId);
  }

  /// Advance the message seq cursor for [sessionId] and keep
  /// [Session.lastSeq] in sync so that gap detection and tail-load
  /// calculations use a current value (the sessions API may lag behind
  /// the actual cursor because inline socket messages advance it
  /// faster than [fetchSessions] runs).
  void _advanceSeqCursor(String sessionId, int newSeq) {
    if (!_cursorManager.advanceSeqCursor(
      sessionId,
      newSeq,
    )) {
      return;
    }
    _scheduleSaveSeq();

    // Keep session.lastSeq in sync so
    // _tailAfterSeqForSession and gapTooLarge use the
    // authoritative cursor, not the stale value from the
    // last fetchSessions response.
    final session = _sessions[sessionId];
    if (session != null &&
        (session.lastSeq ?? 0) < newSeq) {
      _sessions[sessionId] =
          session.copyWith(lastSeq: newSeq);
    }
  }

  /// Debounced MMKV persist for session seq cursors.
  ///
  /// [saveSessionLastSeq] does a synchronous jsonEncode + MMKV disk write on
  /// the main thread. Called on every pagination page during [fetchMessages],
  /// it was the single biggest cause of jank when opening large sessions.
  /// We debounce to a 500ms window so rapid page fetches batch into one write.
  void _scheduleSaveSeq() {
    _saveSeqDebounceTimer?.cancel();
    _saveSeqDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
    });
  }

  /// Debounced MMKV persist for a single session's message list.
  ///
  /// Batches rapid upserts (e.g. streaming tokens) into one disk write
  /// per session every 500 ms, keeping only the last ~200 messages in
  /// the persisted copy. The in-memory list retains all messages.
  void _scheduleSaveMessages(String sessionId) {
    // Always use the debounce path. The previous immediate-persist for
    // 'sending' messages ran jsonEncode on the full 200-message list
    // synchronously on the main thread for every streaming token.
    // The 500ms debounce is short enough that messages survive brief
    // backgrounding, and _flushPendingMessageSaves() handles app
    // lifecycle transitions.
    _saveMsgsDebounceTimers[sessionId]?.cancel();
    _saveMsgsDebounceTimers[sessionId] = Timer(
      const Duration(milliseconds: 500),
      () {
        _saveMsgsDebounceTimers.remove(sessionId);
        final msgs = _sessionMessages[sessionId];
        if (msgs != null) {
          // Strip sidechain messages before persisting — if the deferred
          // regroup timer hasn't fired yet, orphaned isSidechain entries
          // can slip into the list.  Persisting them causes "invisible
          // messages" on cold-start restore because ChatScreen filters
          // them out in _buildMessageList.
          final clean = msgs
              .where((m) => m['isSidechain'] != true)
              .toList();
          MessageCacheService().saveMessages(sessionId, clean);
        }
      },
    );
  }

  /// Immediately flush all pending debounced message saves so the MMKV
  /// cache is not stale when the app is backgrounded or killed.
  void _flushPendingMessageSaves() {
    if (_saveMsgsDebounceTimers.isEmpty) return;
    for (final entry in _saveMsgsDebounceTimers.entries) {
      entry.value.cancel();
      final msgs = _sessionMessages[entry.key];
      if (msgs != null) {
        final clean = msgs
            .where((m) => m['isSidechain'] != true)
            .toList();
        MessageCacheService().saveMessages(entry.key, clean);
      }
    }
    _saveMsgsDebounceTimers.clear();
  }

  void _scheduleSaveSessionsCache() {
    _saveSessionsCacheDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      _persistSessionsCache,
    );
  }

  Future<void> _restoreSessionsCache() async {
    final cache = MMKVStorage().getSessionsCache();
    if (cache == null) return;

    try {
      final sessionsRaw = cache['sessions'];
      final encryptedKeysRaw = cache['encryptedDataKeys'];
      final lastFetchedAt = cache['lastFetchedAt'];

      if (sessionsRaw is List) {
        final restoredSessions = <Session>[];
        for (final item in sessionsRaw) {
          if (item is Map<String, dynamic>) {
            restoredSessions.add(Session.fromJson(item));
          } else if (item is Map) {
            restoredSessions.add(
              Session.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
        _sessions = {
          for (final session in restoredSessions) session.id: session,
        };
      }

      if (encryptedKeysRaw is Map) {
        final sessionKeys = <String, Uint8List?>{};
        _sessionEncryptedDataKeys.clear();
        // Collect all entries first, then decrypt in parallel instead of
        // sequentially awaiting each one.
        final entries = encryptedKeysRaw.entries
            .where(
              (e) =>
                  e.key is String &&
                  e.value is String &&
                  (e.value as String).isNotEmpty,
            )
            .map((e) => (e.key as String, e.value as String))
            .toList();
        for (final (id, key) in entries) {
          _sessionEncryptedDataKeys[id] = key;
        }
        if (entries.isNotEmpty) {
          final decrypted = await Future.wait(
            entries.map(
              (e) => encryption.decryptEncryptionKey(e.$2),
            ),
          );
          for (var i = 0; i < decrypted.length; i++) {
            final dk = decrypted[i];
            if (dk == null) continue;
            final sessionId = entries[i].$1;
            _sessionDataKeys[sessionId] = dk;
            sessionKeys[sessionId] = dk;
          }
        }
        if (sessionKeys.isNotEmpty) {
          await encryption.initializeSessions(sessionKeys);
        }
      }

      // Intentionally NOT restoring _lastSessionsFetchedAt from cache.
      // On cold start, we need a FULL session fetch (not delta) to get
      // accurate lastSeq values. The server's changedSince filter may only
      // track metadata changes, not new messages, so a delta fetch would
      // miss sessions that only received messages while the app was closed.
      // _lastSessionsFetchedAt = _asInt(lastFetchedAt);
      _lastSessionsFetchedAt = null;
      if (_sessions.isNotEmpty) {
        logger.info(
          'Restored ${_sessions.length} cached sessions '
          '(forcing full fetch on startup)',
        );
      }
    } catch (error, stack) {
      logger.warning('Failed to restore sessions cache', error, stack);
      _sessions.clear();
      _sessionDataKeys.clear();
      _sessionEncryptedDataKeys.clear();
      _lastSessionsFetchedAt = null;
      MMKVStorage().clearSessionsCache();
    }
  }

  /// Cached per-session JSON + object reference from the last persist.
  /// On each persist, only sessions whose object reference differs from
  /// the cached one are re-serialized via `toJson()`.
  final Map<String, (Session, Map<String, dynamic>)>
      _sessionJsonCache = {};

  void _persistSessionsCache() {
    _saveSessionsCacheDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer = null;

    // Incrementally update only sessions whose object changed.
    for (final entry in _sessions.entries) {
      final cached = _sessionJsonCache[entry.key];
      if (cached == null || !identical(cached.$1, entry.value)) {
        _sessionJsonCache[entry.key] =
            (entry.value, entry.value.toJson());
      }
    }
    // Remove stale entries for deleted sessions.
    _sessionJsonCache.removeWhere(
      (id, _) => !_sessions.containsKey(id),
    );

    MMKVStorage().saveSessionsCache({
      'lastFetchedAt': _lastSessionsFetchedAt,
      'sessions': [
        for (final e in _sessionJsonCache.values) e.$2,
      ],
      'encryptedDataKeys':
          Map<String, String>.from(_sessionEncryptedDataKeys),
    });
  }

  /// Restores cached messages for all sessions from MMKV into
  /// [_sessionMessages].  Called once during [_init] so that
  /// [getLastMessagePreview] and [messagesForSession] return data
  /// immediately on cold start, without waiting for any HTTP fetch.
  /// Async wrapper that defers [_restoreAllCachedMessages] off the
  /// synchronous [_init] critical path.  Sessions can render from the
  /// session cache before per-session message caches are warm.  Messages
  /// are loaded lazily when the user opens a chat.
  Future<void> _restoreAllCachedMessagesAsync() async {
    _restoreAllCachedMessages();
  }

  void _restoreAllCachedMessages() {
    var firstLoadedChanged = false;
    for (final sessionId in _sessions.keys) {
      if (_sessionMessages.containsKey(sessionId)) continue;
      final cached = MessageCacheService().getMessages(sessionId);
      if (cached.isNotEmpty) {
        // Strip any orphaned sidechain messages that were persisted
        // before the deferred regroup timer could clean them up (e.g.
        // app was killed while the 500ms save debounce was pending).
        // ChatScreen's _buildMessageList filters isSidechain == true,
        // so leaving them in the restored list causes "invisible"
        // messages that occupy space but never render.
        final clean = cached.any((m) => m['isSidechain'] == true)
            ? cached.where((m) => m['isSidechain'] != true).toList()
            : cached;
        if (clean.isNotEmpty) {
          _sessionMessages[sessionId] = clean;
          _sessionMessagesViewCache.remove(sessionId);
          // Notify UI so ChatScreen refreshes with cached messages.
          // The 100ms debounce in _notifySessionMessagesChanged coalesces
          // rapid restores into a single notification.
          _notifySessionMessagesChanged(sessionId);

          // The MMKV cache only stores the most recent ~100 messages.
          // _sessionFirstLoadedSeq (restored from MMKV earlier) may
          // still say 0 ("loaded from beginning") or be null, which
          // tells hasOlderMessages() there is nothing older.  That
          // was true before the restart when all messages were in
          // memory, but now we only have ~100.  Recalculate from the
          // lowest seq actually present so the user can scroll up to
          // load older history.
          int? minSeq;
          for (final m in clean) {
            final seq = m['seq'] as int?;
            if (seq != null && (minSeq == null || seq < minSeq)) {
              minSeq = seq;
            }
          }
          if (minSeq != null && minSeq > 1) {
            _sessionFirstLoadedSeq[sessionId] = minSeq;
            firstLoadedChanged = true;
          }
        }
      }
    }
    _sessionMessagesCache = null;
    if (firstLoadedChanged) {
      MMKVStorage().saveSessionFirstLoadedSeq(
        Map.unmodifiable(_sessionFirstLoadedSeq),
      );
    }
  }

  Future<void> _primeSessionFromSpawnResult({
    required String requestedSessionId,
    required String restoredSessionId,
    required Session seedSession,
    required SpawnSessionResponse result,
  }) async {
    if (result.dataEncryptionKey != null &&
        result.dataEncryptionKey!.isNotEmpty) {
      _sessionEncryptedDataKeys[restoredSessionId] = result.dataEncryptionKey!;
      final decryptedKey = await encryption.decryptEncryptionKey(
        result.dataEncryptionKey!,
      );
      if (decryptedKey != null) {
        _sessionDataKeys[restoredSessionId] = decryptedKey;
        await encryption.initializeSessions({restoredSessionId: decryptedKey});
      } else {
        logger.warning(
          '[sendMessage] auto-restore DEK decrypt failed '
          'session=$restoredSessionId',
        );
      }
    }

    _sessionSpawnedAt[restoredSessionId] =
        DateTime.now().millisecondsSinceEpoch;

    if (_sessions.containsKey(restoredSessionId)) {
      _scheduleSaveSessionsCache();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _sessions[restoredSessionId] = Session(
      id: restoredSessionId,
      seq: 0,
      createdAt: now,
      updatedAt: now,
      active: true,
      activeAt: now,
      metadata: Metadata(
        host: seedSession.metadata?.host ?? '',
        machineId: seedSession.metadata?.machineId,
        path: result.directory ?? seedSession.metadata?.path,
        flavor: seedSession.metadata?.flavor,
        lifecycleState: 'starting',
      ),
      metadataVersion: 0,
      agentStateVersion: 0,
      thinking: false,
      presence: requestedSessionId == restoredSessionId
          ? seedSession.presence
          : 'offline',
      permissionMode: seedSession.permissionMode,
      modelMode: seedSession.modelMode,
    );
    _scheduleSaveSessionsCache();
    _notifyDataChanged();
  }

  /// Subscribe to socket updates
  void subscribeToUpdates() {
    socketIoClient
      ..onMessage('update', handleUpdate)
      ..onMessage('ephemeral', handleEphemeralUpdate)
      ..onReconnected(() {
        logger.info('Socket reconnected');
        _invalidateAllSyncs();
        // Only re-fetch messages for the currently visible session.
        // All other sessions will be lazily refreshed when the user
        // navigates to them via onSessionVisible(). Invalidating every
        // messagesSync entry caused a thundering herd of concurrent
        // fetchMessages calls on reconnect, blocking the main thread.
        // IMPORTANT: Chain after sessionsSync invalidation so fetchMessages
        // runs AFTER fetchSessions has updated serverLastSeq. Without this,
        // fetchMessages may see stale serverLastSeq and skip via early exit.
        if (_visibleSessionId != null) {
          unawaited(sessionsSync.invalidateAndAwait().then((_) {
            if (_visibleSessionId != null) {
              messagesSync[_visibleSessionId]?.invalidate();
            }
          }));
        }
      })
      ..onStatusChange((status) {
        _connectionStatus = status;
      });
  }

  /// Handle incoming updates
  Future<void> handleUpdate(dynamic data) async {
    final payload = _normalizeSocketPayload(data, handlerName: 'handleUpdate');
    if (payload == null) {
      return;
    }

    ApiUpdate? update;
    try {
      update = ApiUpdate.fromJson(payload);

      // Skip Sentry breadcrumbs for high-frequency streaming events.
      // new-message arrives at 10-50/sec during AI responses — recording
      // each one floods Sentry's ring buffer and wastes allocations.
      if (update.type != 'new-message') {
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'sync update: ${update.type}',
          category: 'sync.update',
          level: SentryLevel.info,
          data: <String, dynamic>{
            'type': update.type,
            if (update.data['sid'] is String)
              'sessionId': update.data['sid'] as String,
            if (update.data['id'] is String)
              'entityId': update.data['id'] as String,
          },
        ));
      }

      switch (update.type) {
        case 'new-message':
          _handleNewMessage(update.data);
          break;
        case 'new-session':
          _handleNewSession(update.data);
          break;
        case 'delete-session':
          _handleDeleteSession(update.data);
          break;
        case 'update-session':
          _handleUpdateSession(update.data);
          break;
        case 'update-account':
          _handleUpdateAccount(update.data);
          break;
        case 'update-machine':
          _handleUpdateMachine(update.data);
          break;
        case 'relationship-updated':
          _handleRelationshipUpdated(update.data);
          break;
        case 'new-artifact':
          _handleNewArtifact(update.data);
          break;
        case 'update-artifact':
          _handleUpdateArtifact(update.data);
          break;
        case 'delete-artifact':
          _handleDeleteArtifact(update.data);
          break;
        case 'new-feed-post':
          _handleNewFeedPost(update.data);
          break;
        case 'kv-batch-update':
          _handleKvBatchUpdate(update.data);
          break;
      }

    } catch (error, stack) {
      logger.error('Failed to handle update', error, stack);
    }
  }

  /// Socket payloads can arrive as a single-element list depending on the
  /// socket.io transport/codec path. Normalize to a map for parsers.
  Map<String, dynamic>? _normalizeSocketPayload(
    dynamic data, {
    required String handlerName,
  }) {
    dynamic payload = data;
    if (payload is List) {
      if (payload.length == 1) {
        payload = payload.first;
      } else {
        logger.warning(
          '$handlerName: unexpected list payload length=${payload.length}',
        );
        return null;
      }
    }

    if (payload is Map<String, dynamic>) {
      return payload;
    }
    if (payload is Map) {
      final normalized = <String, dynamic>{};
      for (final entry in payload.entries) {
        if (entry.key is String) {
          normalized[entry.key as String] = entry.value;
        }
      }
      return normalized;
    }

    logger.warning(
      '$handlerName: unexpected data type: ${payload.runtimeType}',
    );
    return null;
  }

  /// Handle new message update
  void _handleNewMessage(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String? ?? data['id'] as String?;
    // Do NOT invalidate sessionsSync here — message events fire on every
    // streaming token and would cause dozens of sessions re-fetches per
    // response. Sessions are updated by _handleUpdateSession (session-level
    // state changes) and by the reconnect / resume handlers.
    if (sessionId == null) return;

    final isVisible = sessionId == _visibleSessionId;

    // Recreate per-session sync lazily for the visible session if needed.
    if (!messagesSync.containsKey(sessionId) && isVisible) {
      messagesSync[sessionId] = InvalidateSync(
        () => fetchMessages(sessionId),
        minInterval: _messagesSyncMinInterval,
        name: 'fetchMessages:$sessionId',
      );
    }

    // Deduplicate ALL socket events, not just visible ones.  The server
    // often broadcasts the same new-message event 7-8 times.  Without
    // dedup for non-visible sessions, a background session with an
    // active AI response floods the logger and triggers hundreds of
    // wasteful fetchMessages calls that immediately skip.
    final embeddedMessage = data['message'] as Map<String, dynamic>?;
    if (embeddedMessage != null) {
      final msgId = embeddedMessage['id'] as String?;
      final msgSeq = embeddedMessage['seq'];
      final dedupKey = '$sessionId:$msgId:$msgSeq';
      if (!_recentInlineMessageKeys.add(dedupKey)) {
        return; // already seen
      }
      _recentInlineMessageKeyOrder.addLast(dedupKey);
      while (_recentInlineMessageKeyOrder.length >
          _maxRecentInlineKeys) {
        _recentInlineMessageKeys.remove(
          _recentInlineMessageKeyOrder.removeFirst(),
        );
      }
    }

    if (isVisible) {
      if (embeddedMessage != null) {
        // Serialize inline processing per session so sidechain messages
        // (which form a parentUuid chain) are always upserted and grouped
        // in arrival order.  Without this, concurrent decryptions can
        // finish out of order, breaking the chain and leaving messages
        // orphaned outside their parent Task.
        _inlineProcessor.enqueue(
          sessionId,
          () => _processInlineMessage(
            sessionId,
            embeddedMessage,
          ),
        );
      } else {
        // Visible session with no embedded message — HTTP fetch.
        messagesSync[sessionId]?.invalidate();
      }
      logger.info('New message received: $sessionId');
    } else {
      // Non-visible session: mark dirty so onSessionVisible() triggers
      // a fetch when the user navigates to it.
      //
      // Update session.lastSeq so the delta-fetch path in fetchMessages
      // can detect the gap (serverLastSeq > cursorSeq).  Do NOT advance
      // _sessionLastSeq — the messages aren't stored in _sessionMessages,
      // so the cursor must stay at its pre-navigation position.  Advancing
      // the cursor would make cursor == server, hiding the gap and forcing
      // a destructive full tail-refresh on every navigation.
      final msgSeq = embeddedMessage?['seq'] as int?;
      if (msgSeq != null) {
        final session = _sessions[sessionId];
        if (session != null && (session.lastSeq ?? 0) < msgSeq) {
          _sessions[sessionId] = session.copyWith(lastSeq: msgSeq);
        }
      }
      final isNew = _sessionsWithPendingUpdates.add(sessionId);
      if (isNew) {
        logger.info(
          '[handleNewMessage] NON-VISIBLE session=$sessionId '
          'msgSeq=$msgSeq embedded=${embeddedMessage != null} '
          '— pendingUpdates added',
        );
      }
      // Track that this session received socket messages while non-visible
      // so onSessionVisible() knows to force a server fetch instead of
      // restoring stale cache.
      _sessionsWithPendingSocketMessages.add(sessionId);
      final newUnread =
          (_sessionUnreadCounts[sessionId] ?? 0) + 1;
      _sessionUnreadCounts[sessionId] = newUnread;

      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Background message received',
        category: 'chat.background',
        level: SentryLevel.info,
        data: <String, dynamic>{
          'sessionId': sessionId,
          'msgSeq': msgSeq,
          'unreadCount': newUnread,
          'hasEmbedded': embeddedMessage != null,
          'isFirstPending': isNew,
        },
      ));
    }
  }

  /// Decrypt and upsert a single message received inline from the socket
  /// event, bypassing the HTTP fetch round-trip.
  ///
  /// Falls back to [InvalidateSync.invalidate] on failure or when the
  /// message produces no displayable content.
  Future<void> _processInlineMessage(
    String sessionId,
    Map<String, dynamic> wireMessage,
  ) async {
    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      messagesSync[sessionId]?.invalidate();
      _notifySessionMessagesChanged(sessionId);
      return;
    }

    try {
      final processed = await sessionEncryption.decryptAndProcessMessages([
        wireMessage,
      ], sessionId);

      if (processed.messages.isEmpty && processed.toolResults.isEmpty) {
        // Nothing displayable from inline processing.  Do NOT advance
        // the seq cursor here — doing so causes the fallback HTTP fetch
        // (below) to be skipped by fetchMessages' "already caught up"
        // guard, permanently losing the message.  Keeping the cursor
        // unchanged lets the fetch retrieve the message from the server.
        if (processed.droppedReasons.isNotEmpty) {
          for (final reason in processed.droppedReasons) {
            logger.warning(
              '[inline] $sessionId dropped: $reason',
            );
          }
        }
        messagesSync[sessionId]?.invalidate();
        _notifySessionMessagesChanged(sessionId);
        return;
      }

      if (processed.messages.isNotEmpty) {
        _upsertSessionMessages(sessionId, processed.messages);
      }
      if (processed.toolResults.isNotEmpty) {
        _applyToolResults(sessionId, processed.toolResults);
      }
      // Apply any pending tool results that arrived before these messages.
      // This handles the case where a tool-call-result arrives via socket
      // before the tool-call message itself.
      final pending = _pendingToolResults.remove(sessionId);
      if (pending != null && pending.isNotEmpty) {
        _applyToolResults(sessionId, pending);
      }
      for (final u in processed.usageUpdates) {
        _updateSessionUsage(
          u['sessionId'] as String,
          u['usage'] as Map<String, dynamic>,
          u['timestamp'] as int,
        );
      }
      _applyPermissionRequests(sessionId);

      // Only run the expensive multi-pass sidechain grouper when the
      // incoming messages actually contain sidechain content. For
      // ordinary streaming tokens (the 99% case) this skips all four
      // passes + the O(n) orphan scan entirely.
      final hasSidechain = processed.messages.any(
        (m) => m['isSidechain'] == true,
      );
      if (hasSidechain) {
        final inlineChangedIds = {
          for (final m in processed.messages)
            if (m['id'] is String) m['id'] as String,
        };
        _groupSidechainMessages(
          sessionId,
          changedIds: inlineChangedIds,
        );
        _scheduleSidechainRegroup(sessionId);
      }

      // Advance the seq cursor so future incremental fetches don't
      // re-download this message.
      _advanceSeqCursor(sessionId, processed.maxSeq);

      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
      // Remove the completed Future from the queue so new messages can
      // start fresh processing without chaining onto a resolved Future.
      // The queue entry is also removed on error (below) for symmetry.
      _inlineProcessor.clearSession(sessionId);
    } catch (error, stack) {
      logger.warning(
        'Inline message processing failed — HTTP fetch will retry',
        error,
        stack,
      );
      // Remove the failed Future from the queue so subsequent messages
      // can re-enter the inline fast path instead of being silently
      // dropped by chaining onto a rejected Future.
      _inlineProcessor.clearSession(sessionId);
      messagesSync[sessionId]?.invalidate();
      _notifySessionMessagesChanged(sessionId);
    }
  }

  /// Handle new session update
  void _handleNewSession(Map<String, dynamic> data) {
    final sessionId = data['id'] as String? ?? data['sid'] as String?;
    logger.info('New session received: $sessionId');
    if (sessionId != null && sessionId.isNotEmpty) {
      _pendingNewSessionIds.add(sessionId);
    }
    _scheduleSessionsRefresh();
  }

  /// Handle session deletion
  void _handleDeleteSession(Map<String, dynamic> data) {
    final sessionId = data['sid'] as String?;
    if (sessionId != null) {
      // Clear _visibleSessionId if this was the visible session to prevent
      // stale references pointing to a deleted session.
      if (sessionId == _visibleSessionId) {
        _visibleSessionId = null;
      }
      messagesSync.remove(sessionId)?.dispose();
      _postSendCatchUpTimers.remove(sessionId)?.cancel();
      _loadingOlderMessages.remove(sessionId);
      _sessionMessages.remove(sessionId);
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
      _todoLists.remove(sessionId);
      _sessions.remove(sessionId);
      _presenceTimers.remove(sessionId)?.cancel();
      _sessionDataKeys.remove(sessionId);
      _sessionEncryptedDataKeys.remove(sessionId);
      _sessionsNeedingTailRefresh.remove(sessionId);
      _sessionsWithPendingUpdates.remove(sessionId);
      _sessionsWithPendingSocketMessages.remove(sessionId);
      _sessionSpawnedAt.remove(sessionId);
      _autoRestoreInFlight.remove(sessionId);
      _pendingToolResults.remove(sessionId);
      if (isInitialized) {
        _sessionLastSeq.remove(sessionId);
        MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
        _sessionFirstLoadedSeq.remove(sessionId);
        MMKVStorage().saveSessionFirstLoadedSeq(
          Map.unmodifiable(_sessionFirstLoadedSeq),
        );
        _saveMsgsDebounceTimers.remove(sessionId)?.cancel();
        MessageCacheService().clearMessages(sessionId);
        encryption.removeSessionEncryption(sessionId);
      }
    }
    _scheduleSaveSessionsCache();
    sessionsSync.invalidate();
    logger.info(
      'Session deletion received'
      '${sessionId != null ? ': $sessionId' : ''}',
    );
  }

  /// Handle session update
  ///
  /// Applies delta patches directly to the in-memory session for unencrypted
  /// fields (presence, active, activeAt, title, thinking).  Only falls back
  /// to [sessionsSync.invalidate()] for encrypted fields (metadata, agentState)
  /// that require decryption.  This eliminates the ~4 fetchSessions() HTTP
  /// calls/sec that were happening during active streaming even with debouncing.
  void _handleUpdateSession(Map<String, dynamic> data) {
    final sessionId = data['id'] as String?;
    if (sessionId == null) return;

    // Apply delta patch directly to the in-memory session for unencrypted fields.
    // This updates the UI immediately without waiting for a debounced HTTP fetch.
    // Ephemeral events (handleEphemeralUpdate) already handle presence/typing
    // directly -- the update-session event carries the same data plus metadata.
    final session = _sessions[sessionId];
    if (session != null) {
      final presence = data['presence'] as String?;
      final active = data['active'] as bool?;
      final activeAt = data['activeAt'] is int
          ? data['activeAt'] as int
          : data['activeAt'] is double
              ? (data['activeAt'] as double).toInt()
              : null;
      final title = data['title'] as String?;
      final thinking = data['thinking'] as bool?;
      final thinkingAt = data['thinkingAt'] is int
          ? data['thinkingAt'] as int
          : data['thinkingAt'] is double
              ? (data['thinkingAt'] as double).toInt()
              : null;

      // Only update if at least one unencrypted field is present.
      if (presence != null ||
          active != null ||
          activeAt != null ||
          title != null ||
          thinking != null ||
          thinkingAt != null) {
        _sessions[sessionId] = session.copyWith(
          presence: presence ?? session.presence,
          active: active ?? session.active,
          activeAt: activeAt ?? session.activeAt,
          thinking: thinking ?? session.thinking,
          thinkingAt: thinkingAt,
        );
        _notifyDataChanged();
      }
    }

    // Schedule a debounced refresh as a safety net for encrypted fields
    // (metadata, agentState) that we can't decrypt inline here.  The refresh
    // is also needed for new sessions that aren't in _sessions yet.
    _scheduleSessionsRefresh();

    // Only log the first occurrence per session within a debounce window.
    // The server broadcasts dozens of identical update-session events per
    // second during streaming (typing/tool state changes).
    if (_pendingUpdateSessionIds.add(sessionId)) {
      logger.info('Session update received: $sessionId');
    }
  }

  static const Duration _sessionsRefreshDebounce = Duration(milliseconds: 250);

  /// Minimum interval between consecutive message fetches for a session.
  /// Prevents rapid-fire HTTP refetches when many socket events arrive
  /// in quick succession (e.g. during streaming).
  static const Duration _messagesSyncMinInterval = Duration(milliseconds: 500);

  void _scheduleSessionsRefresh() {
    _sessionsRefreshDebounceTimer?.cancel();
    _sessionsRefreshDebounceTimer = Timer(
      _sessionsRefreshDebounce,
      () => unawaited(_flushScheduledSessionsRefresh()),
    );
  }

  Future<void> _flushScheduledSessionsRefresh() async {
    _sessionsRefreshDebounceTimer?.cancel();
    _sessionsRefreshDebounceTimer = null;
    _pendingUpdateSessionIds.clear();

    await sessionsSync.invalidateAndAwait();

    if (_pendingNewSessionIds.isEmpty) {
      return;
    }

    final sessionIdsNeedingFullFetch = _pendingNewSessionIds
        .where(
          (sessionId) => encryption.getSessionEncryption(sessionId) == null,
        )
        .toList();
    _pendingNewSessionIds.clear();

    if (sessionIdsNeedingFullFetch.isEmpty) {
      return;
    }

    // A newly created session can miss the first delta fetch due to clock skew
    // or replication lag. Retry once with a full fetch so its encryption key is
    // initialized before the user opens it.
    _forceFullFetchNext = true;
    await sessionsSync.invalidateAndAwait();
  }

  /// Handle account update
  void _handleUpdateAccount(Map<String, dynamic> data) {
    logger.info('Account update received');
    profileSync.invalidate();
    settingsSync.invalidate();
  }

  /// Handle machine update
  void _handleUpdateMachine(Map<String, dynamic> data) {
    logger.info('Machine update received');
    machinesSync.invalidate();
  }

  /// Handle relationship update
  void _handleRelationshipUpdated(Map<String, dynamic> data) {
    logger.info('Relationship update received');
    friendsSync.invalidate();
    friendRequestsSync.invalidate();
    feedSync.invalidate();
  }

  /// Handle new artifact update
  void _handleNewArtifact(Map<String, dynamic> data) {
    logger.info('New artifact received');
    artifactsSync.invalidate();
  }

  /// Handle artifact update
  void _handleUpdateArtifact(Map<String, dynamic> data) {
    logger.info('Artifact update received');
    artifactsSync.invalidate();
  }

  /// Handle artifact deletion
  void _handleDeleteArtifact(Map<String, dynamic> data) {
    logger.info('Artifact deletion received');
    artifactsSync.invalidate();
  }

  /// Handle new feed post
  void _handleNewFeedPost(Map<String, dynamic> data) {
    logger.info('New feed post received');
    feedSync.invalidate();
  }

  /// Check if data contains a key matching the search string
  /// without full JSON serialization.
  bool _containsKeyRecursive(dynamic data, String key) {
    if (data is Map) {
      for (final k in data.keys) {
        if (k is String && k.toLowerCase().contains(key)) {
          return true;
        }
        if (_containsKeyRecursive(data[k], key)) {
          return true;
        }
      }
    } else if (data is List) {
      for (final item in data) {
        if (_containsKeyRecursive(item, key)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Handle KV batch update (for todos)
  void _handleKvBatchUpdate(Map<String, dynamic> data) {
    bool hasTodoEntry(List<dynamic> list) => list.any(
      (entry) =>
          entry is Map<String, dynamic> &&
          ((entry['key'] as String?)?.startsWith('todo') ?? false),
    );

    final changes = data['changes'];
    if (changes is List && hasTodoEntry(changes)) {
      todosSync.invalidate();
      logger.info('KV batch update received (todos)');
      return;
    }

    final operations = data['operations'];
    if (operations is List && hasTodoEntry(operations)) {
      todosSync.invalidate();
      logger.info('KV batch update received (todos)');
      return;
    }

    if (_containsKeyRecursive(data, 'todo')) {
      todosSync.invalidate();
      logger.info('KV batch update received (todos-fallback)');
      return;
    }

    logger.info('KV batch update received (non-todo)');
  }

  /// Handle ephemeral updates
  void handleEphemeralUpdate(dynamic data) {
    final payload = _normalizeSocketPayload(
      data,
      handlerName: 'handleEphemeralUpdate',
    );
    if (payload == null) {
      return;
    }

    final type = payload['type'] as String? ?? payload['t'] as String?;
    // Activity events use 'id'; fall back to 'sid' for other shapes.
    final sessionId = payload['id'] as String? ?? payload['sid'] as String?;
    if (sessionId == null) {
      return;
    }

    void markOnline({
      bool? thinking,
      int? activeAt,
      required bool keepThinking,
    }) {
      final session = _sessions[sessionId];
      if (session == null) return;

      _lastEphemeralAt[sessionId] =
          DateTime.now().millisecondsSinceEpoch;

      final nextThinking = keepThinking ? session.thinking : thinking ?? false;
      final nextThinkingAt = keepThinking
          ? session.thinkingAt
          : (nextThinking
                ? (activeAt ??
                    DateTime.now().millisecondsSinceEpoch)
                : null);

      _sessions[sessionId] = session.copyWith(
        thinking: nextThinking,
        thinkingAt: nextThinkingAt,
        presence: 'online',
      );
      _notifyDataChanged();

      _presenceTimers[sessionId]?.cancel();
      _presenceTimers[sessionId] = Timer(const Duration(seconds: 60), () {
        _presenceTimers.remove(sessionId);
        final current = _sessions[sessionId];
        if (current != null && current.presence == 'online') {
          _sessions[sessionId] = current.copyWith(
            presence: 'offline',
            thinking: false,
          );
          _notifyDataChanged();
        }
      });
    }

    if (type == 'activity') {
      final session = _sessions[sessionId];
      if (session != null) {
        final thinking = payload['thinking'] as bool? ?? false;
        final activeAt = payload['activeAt'] as int?;
        // The server can push active:false to explicitly mark a session
        // offline (matches ApiEphemeralActivityUpdateSchema in the
        // reference implementation).
        final isActive = payload['active'] as bool? ?? true;

        if (isActive) {
          markOnline(
            thinking: thinking,
            activeAt: activeAt,
            keepThinking: false,
          );
        } else {
          // Session explicitly went offline — cancel any timer and
          // immediately mark it inactive.
          _presenceTimers[sessionId]?.cancel();
          _presenceTimers.remove(sessionId);
          _sessions[sessionId] = session.copyWith(
            presence: 'offline',
            thinking: false,
            thinkingAt: null,
          );
          _notifyDataChanged();
        }
      }
      return;
    }

    if (type == 'session-alive' || type == 'session_alive') {
      markOnline(keepThinking: true);
      return;
    }

    // Only invalidate if this session is currently open — ephemeral updates
    // for non-visible sessions are not urgent and can wait until the user
    // navigates to them. Invalidating all sessions caused a thundering herd
    // of fetchMessages calls (one per active typing/tool event × every session
    // the user had previously opened), blocking the main thread.
    if (sessionId == _visibleSessionId && messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId]?.invalidate();
    }
  }

  /// Fetch sessions from server
  Future<void> fetchSessions() async {
    logger.info('Fetching sessions...');

    final fetchStartMs = DateTime.now().millisecondsSinceEpoch;
    final forceFullFetch = _forceFullFetchNext;
    if (forceFullFetch) _forceFullFetchNext = false;
    final changedSince = forceFullFetch ? null : _lastSessionsFetchedAt;

    try {
      final apiClient = ApiClient();
      final allSessions = await SessionsApi(
        client: apiClient,
      ).fetchSessions(limit: 50, changedSince: changedSince);

      logger.info(
        'fetchSessions: received ${allSessions.length} sessions '
        '(changedSince=$changedSince)',
      );

      if (allSessions.isEmpty) {
        if (changedSince != null) {
          // Delta fetch with no changes — update timestamp and return.
          _lastSessionsFetchedAt = fetchStartMs;
          _scheduleSaveSessionsCache();
          logger.info('fetchSessions: no changes since delta fetch');
        } else {
          logger.warning(
            'fetchSessions: full fetch returned 0 sessions — '
            'possible auth/server issue',
          );
        }
        return;
      }

      // Initialize session encryptions — decrypt all keys in parallel
      // for better performance, then assign results back.
      final sessionKeys = <String, Uint8List?>{};

      // Collect valid sessions with their encryption keys.
      final sessionDecryptTasks = <({
        String sessionId,
        String dataEncryptionKey,
      })>[];
      for (final session in allSessions) {
        if (session is! Map<String, dynamic>) {
          logger.warning(
            'Skipping session with invalid payload type',
            'Session data: $session',
          );
          continue;
        }

        final sessionId = WireParsers.parseString(session['id']);
        if (sessionId == null || sessionId.isEmpty) {
          logger.warning(
            'Skipping session with missing/empty ID',
            'Session data: $session',
          );
          continue;
        }

        final dataEncryptionKey = WireParsers.parseString(
          session['dataEncryptionKey'],
        );

        if (dataEncryptionKey != null) {
          _sessionEncryptedDataKeys[sessionId] = dataEncryptionKey;
          sessionDecryptTasks.add((
            sessionId: sessionId,
            dataEncryptionKey: dataEncryptionKey,
          ));
        } else {
          _sessionEncryptedDataKeys.remove(sessionId);
          sessionKeys[sessionId] = null;
        }
      }

      // Decrypt all session keys in parallel.
      if (sessionDecryptTasks.isNotEmpty) {
        final decryptedKeys = await Future.wait(
          sessionDecryptTasks.map(
            (t) => encryption
                .decryptEncryptionKey(t.dataEncryptionKey)
                .catchError((Object e) {
              logger.info(
                '[Encryption] DEK decryption threw for session '
                '${t.sessionId}: $e '
                '— falling back to legacy encryption.',
              );
              return null;
            }),
          ),
        );

        for (var i = 0; i < sessionDecryptTasks.length; i++) {
          final sessionId = sessionDecryptTasks[i].sessionId;
          final decryptedKey = decryptedKeys[i];
          if (decryptedKey != null) {
            sessionKeys[sessionId] = decryptedKey;
            _sessionDataKeys[sessionId] = decryptedKey;
          } else {
            logger.warning(
              '[Encryption] DEK decryption failed for session $sessionId '
              '(returned null) — falling back to legacy encryption. '
              'Run `happy auth debug` and test the printed vector in '
              'Flutter to confirm key mismatch.',
            );
            sessionKeys[sessionId] = null;
          }
        }
      }

      await encryption.initializeSessions(sessionKeys);

      // Decrypt sessions — yield between each so the looper stays
      // responsive even when processing many sessions.
      final decryptedSessions = <Session>[];
      for (final session in allSessions) {
        // Yield to event queue before each session decrypt.
        await Future<void>.delayed(Duration.zero);

        if (session is! Map<String, dynamic>) {
          logger.warning(
            'Skipping session with invalid payload type',
            'Session data: $session',
          );
          continue;
        }

        final sessionId = WireParsers.parseString(session['id']);
        if (sessionId == null || sessionId.isEmpty) {
          logger.warning(
            'Skipping session with missing/empty ID',
            'Session data: $session',
          );
          continue;
        }
        final sessionEncryption = encryption.getSessionEncryption(sessionId);

        // Always add the session, even if encryption isn't available.
        // This prevents the "Session not loaded" bug where sessions are
        // silently skipped when sessionEncryption is null.
        //
        // Use safe casts with defaults to prevent session from being silently
        // skipped when server returns malformed data. Previously, direct casts
        // like `session['seq'] as int` would throw TypeError on null/wrong type
        // and the session would be silently dropped.
        try {
          // Safe casts with defaults for required fields
          final seq = _asSessionInt(session['seq']) ?? 0;
          final createdAt =
              _asSessionInt(session['createdAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          final updatedAt =
              _asSessionInt(session['updatedAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          final active = _asSessionBool(session['active']) ?? false;
          final activeAt =
              _asSessionInt(session['activeAt']) ??
              DateTime.now().millisecondsSinceEpoch;
          final metadataVersion =
              _asSessionInt(session['metadataVersion']) ?? 0;
          final agentStateVersion =
              _asSessionInt(session['agentStateVersion']) ?? 0;
          final lastSeq = _asSessionInt(session['lastSeq']);

          Map<String, dynamic>? metadata;
          Map<String, dynamic>? agentState;

          if (sessionEncryption != null) {
            // Decrypt metadata
            try {
              metadata = await sessionEncryption.decryptMetadata(
                metadataVersion,
                WireParsers.parseString(session['metadata']) ?? '',
              );
            } catch (e) {
              logger.warning('Failed to decrypt session metadata', e);
            }

            // Decrypt agent state
            try {
              agentState = await sessionEncryption.decryptAgentState(
                agentStateVersion,
                WireParsers.parseString(session['agentState']),
              );
            } catch (e) {
              logger.warning('Failed to decrypt session agentState', e);
            }
          }

          Metadata? parsedMetadata;
          if (metadata != null) {
            try {
              parsedMetadata = Metadata.fromJson(metadata);
            } catch (e) {
              logger.warning(
                'Failed to parse session metadata for $sessionId',
                e,
              );
            }
          }

          AgentState? parsedAgentState;
          if (agentState != null && agentState.isNotEmpty) {
            try {
              parsedAgentState = AgentState.fromJson(agentState);
            } catch (e) {
              logger.warning(
                'Failed to parse session agentState for $sessionId',
                e,
              );
            }
          }

          // Create session object
          final processedSession = Session(
            id: sessionId,
            seq: seq,
            createdAt: createdAt,
            updatedAt: updatedAt,
            active: active,
            activeAt: activeAt,
            metadata: parsedMetadata,
            metadataVersion: metadataVersion,
            agentState: parsedAgentState,
            agentStateVersion: agentStateVersion,
            thinking: false,
            thinkingAt: null,
            // REST fetches cannot tell us whether the CLI process is
            // actually running — the server's `active` flag is
            // persistent (true until archived) and stale.  Default
            // to 'offline'; only real-time WebSocket activity events
            // should promote a session to 'online'.  For delta
            // fetches, preserve the existing presence if known.
            presence: _sessions[sessionId]?.presence ?? 'offline',
            lastSeq: lastSeq,
          );

          decryptedSessions.add(processedSession);
        } catch (error) {
          // Log error in ALL builds (not just debug) so we can detect
          // malformed session data in production
          logger.error('Failed to process session $sessionId', error);
        }
      }

      if (changedSince == null) {
        // Full fetch: selectively cancel presence timers. Preserve timers
        // for sessions that remain 'online' so their countdown from the
        // last keep-alive is maintained.  Without this, dead sessions
        // (e.g. after a daemon restart) get a fresh 60-second timer that
        // delays offline detection and allows messages to be sent to a
        // session with no running process.
        // Atomic update: build new map then swap to avoid the clear()
        // window where concurrent operations see an empty _sessions.
        final newSessions = Map<String, Session>.fromEntries(
          decryptedSessions.map((s) => MapEntry(s.id, s)),
        );
        // Preserve recently-spawned optimistic sessions that the server
        // hasn't propagated yet (replication lag). Without this, the full
        // fetch wipes the placeholder added by createSession(), causing
        // "Session not loaded" errors when the user tries to send a
        // message immediately after creating a session.
        final now = DateTime.now().millisecondsSinceEpoch;
        final preservedSessions = <String>[];
        for (final entry in _sessionSpawnedAt.entries) {
          final sid = entry.key;
          final spawnedAt = entry.value;
          if (!newSessions.containsKey(sid) &&
              _sessions.containsKey(sid) &&
              now - spawnedAt < 60000) {
            newSessions[sid] = _sessions[sid]!;
            preservedSessions.add(sid);
          }
        }
        if (preservedSessions.isNotEmpty) {
          logger.info(
            '[fetchSessions] Preserved ${preservedSessions.length} '
            'optimistic sessions from full fetch: $preservedSessions',
          );
        }
        // Cancel timers for sessions that were removed or went offline.
        // Keep timers for sessions that remain 'online' so their original
        // countdown from the last keep-alive is preserved.
        final staleTimerIds = <String>[];
        for (final entry in _presenceTimers.entries) {
          final newSession = newSessions[entry.key];
          if (newSession == null ||
              newSession.presence != 'online') {
            entry.value.cancel();
            staleTimerIds.add(entry.key);
          }
        }
        for (final id in staleTimerIds) {
          _presenceTimers.remove(id);
        }
        _sessions = newSessions;
      } else {
        // Delta fetch: merge updated sessions, cancel their stale timers.
        for (final session in decryptedSessions) {
          _sessions[session.id] = session;
          _presenceTimers.remove(session.id)?.cancel();
        }
      }

      // Clear optimistic archive flags for sessions that the server has
      // confirmed as inactive (active: false) or that are no longer in the
      // list. This prevents the "archive then reappear" bug.
      for (final session in decryptedSessions) {
        if (!session.active) {
          _optimisticallyArchivedSessions.remove(session.id);
        }
      }
      // On full fetch, clear any optimistic archives for sessions not in
      // the response (deleted or truly archived on server).
      if (changedSince == null) {
        _optimisticallyArchivedSessions.removeWhere(
          (sessionId) => !_sessions.containsKey(sessionId),
        );
      }

      // Start 60 s staleness timers for sessions that came back 'online'
      // but don't already have a running timer.  Existing timers (from
      // keep-alives) are preserved so their original countdown is
      // maintained — this prevents dead sessions from getting a fresh
      // 60 s window after every fetch.
      for (final s in decryptedSessions) {
        if (s.presence == 'online' &&
            !_presenceTimers.containsKey(s.id)) {
          _presenceTimers[s.id] = Timer(const Duration(seconds: 60), () {
            _presenceTimers.remove(s.id);
            final current = _sessions[s.id];
            if (current != null && current.presence == 'online') {
              _sessions[s.id] = current.copyWith(
                presence: 'offline',
                thinking: false,
              );
              _notifyDataChanged();
            }
          });
        }
      }

      // Re-apply permission data only for sessions that changed,
      // not all sessions — avoids O(sessions × messages) on every fetch.
      for (final session in decryptedSessions) {
        if (_sessionMessages.containsKey(session.id)) {
          _applyPermissionRequests(session.id);
          _notifySessionMessagesChanged(session.id);
        }
      }

      // Fire local notifications for any new permission requests.
      _checkForNewPermissionRequests(decryptedSessions);

      logger.info('Fetched and decrypted ${decryptedSessions.length} sessions');
      _lastSessionsFetchedAt = fetchStartMs;
      _scheduleSaveSessionsCache();
      _notifyDataChanged();
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Error fetching sessions', error, stack);
    }
  }

  /// Fetch a single session by ID from the server, decrypt it, and add it to
  /// the local cache. Returns the session if found, or null otherwise.
  /// This avoids a full session list re-fetch when only one session is needed.
  Future<Session?> fetchSingleSession(String sessionId) async {
    final override = testFetchSingleSessionOverride;
    if (override != null) return override(sessionId);
    try {
      final apiClient = ApiClient();
      final raw = await SessionsApi(client: apiClient).fetchSessionById(
        sessionId,
      );
      if (raw == null) return null;

      // Initialize encryption for this session.
      final dataEncryptionKey = WireParsers.parseString(
        raw['dataEncryptionKey'],
      );
      Uint8List? sessionKey;
      if (dataEncryptionKey != null) {
        _sessionEncryptedDataKeys[sessionId] = dataEncryptionKey;
        try {
          sessionKey = await encryption.decryptEncryptionKey(dataEncryptionKey);
          if (sessionKey != null) {
            _sessionDataKeys[sessionId] = sessionKey;
          }
        } catch (e) {
          logger.info(
            '[Encryption] DEK decryption threw for single session '
            '$sessionId: $e — falling back to legacy encryption.',
          );
        }
      } else {
        _sessionEncryptedDataKeys.remove(sessionId);
      }
      await encryption.initializeSessions({sessionId: sessionKey});

      final sessionEncryption = encryption.getSessionEncryption(sessionId);

      // Decrypt metadata and agent state.
      final metadataVersion = _asSessionInt(raw['metadataVersion']) ?? 0;
      final agentStateVersion = _asSessionInt(raw['agentStateVersion']) ?? 0;

      Map<String, dynamic>? metadata;
      Map<String, dynamic>? agentState;
      if (sessionEncryption != null) {
        try {
          metadata = await sessionEncryption.decryptMetadata(
            metadataVersion,
            WireParsers.parseString(raw['metadata']) ?? '',
          );
        } catch (e) {
          logger.warning('fetchSingleSession: decrypt metadata failed', e);
        }
        try {
          agentState = await sessionEncryption.decryptAgentState(
            agentStateVersion,
            WireParsers.parseString(raw['agentState']),
          );
        } catch (e) {
          logger.warning('fetchSingleSession: decrypt agentState failed', e);
        }
      }

      Metadata? parsedMetadata;
      if (metadata != null) {
        try {
          parsedMetadata = Metadata.fromJson(metadata);
        } catch (e) {
          logger.warning(
            'fetchSingleSession: parse metadata failed for $sessionId',
            e,
          );
        }
      }

      AgentState? parsedAgentState;
      if (agentState != null && agentState.isNotEmpty) {
        try {
          parsedAgentState = AgentState.fromJson(agentState);
        } catch (e) {
          logger.warning(
            'fetchSingleSession: parse agentState failed for $sessionId',
            e,
          );
        }
      }

      final session = Session(
        id: sessionId,
        seq: _asSessionInt(raw['seq']) ?? 0,
        createdAt:
            _asSessionInt(raw['createdAt']) ??
            DateTime.now().millisecondsSinceEpoch,
        updatedAt:
            _asSessionInt(raw['updatedAt']) ??
            DateTime.now().millisecondsSinceEpoch,
        active: _asSessionBool(raw['active']) ?? false,
        activeAt:
            _asSessionInt(raw['activeAt']) ??
            DateTime.now().millisecondsSinceEpoch,
        metadata: parsedMetadata,
        metadataVersion: metadataVersion,
        agentState: parsedAgentState,
        agentStateVersion: agentStateVersion,
        thinking: false,
        presence: _sessions[sessionId]?.presence ?? 'offline',
        lastSeq: _asSessionInt(raw['lastSeq']),
      );

      _sessions[sessionId] = session;
      _notifyDataChanged();
      _scheduleSaveSessionsCache();
      return session;
    } catch (error, stack) {
      logger.error('fetchSingleSession failed for $sessionId', error, stack);
      return null;
    }
  }

  /// Fetch machines from server
  Future<void> fetchMachines() async {
    logger.info('Fetching machines...');

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get('/v1/machines');

      if (apiClient.isSuccess(response)) {
        // Machines response may be a list directly or wrapped in an object
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

        // Initialize machine encryptions — decrypt all keys in parallel
        // for better performance, then assign results back.
        final machineKeys = <String, Uint8List?>{};

        // Collect machines with their encryption keys.
        final machineDecryptTasks = <({
          String machineId,
          String dataEncryptionKey,
        })>[];
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

        // Decrypt all machine keys in parallel.
        if (machineDecryptTasks.isNotEmpty) {
          final decryptedKeys = await Future.wait(
            machineDecryptTasks.map(
              (t) => encryption
                  .decryptEncryptionKey(t.dataEncryptionKey)
                  .catchError((Object e) {
                logger.info(
                  '[Encryption] DEK decryption threw for machine '
                  '${t.machineId}: $e '
                  '— falling back to legacy encryption.',
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
              logger.warning(
                '[Encryption] DEK decryption failed for machine $machineId '
                '(returned null) — falling back to legacy encryption. '
                'Run `happy auth debug` to diagnose key mismatch.',
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

        // Decrypt all machine payloads (AES in background isolate).
        final machineIsolateResults =
            await _decryptMachinesInIsolate(machineIsolateItems);
        final machineResultById = {
          for (final r in machineIsolateResults) r.id: r,
        };

        final decryptedMachines = <Machine>[];
        for (final machine in data) {
          final machineId = machine['id'] as String;
          final result = machineResultById[machineId];
          if (result == null) continue;

          decryptedMachines.add(
            Machine(
              id: machineId,
              seq: _asSessionInt(machine['seq']) ?? 0,
              createdAt: _asSessionInt(machine['createdAt']) ?? 0,
              updatedAt: _asSessionInt(machine['updatedAt']) ?? 0,
              active: machine['active'] as bool? ?? false,
              activeAt: _asSessionInt(machine['activeAt']) ?? 0,
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

        // Guard against a transient empty response wiping out known
        // machines — mirrors fetchSessions() which returns early on an
        // empty full-fetch rather than clearing _sessions.
        if (decryptedMachines.isEmpty) {
          logger.warning(
            'fetchMachines: full fetch returned 0 machines — '
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
        _notifyDataChanged();
      } else {
        logger.warning('Failed to fetch machines: ${response.statusCode}');
      }
    } catch (error, stack) {
      logger.error('Error fetching machines', error, stack);
    }
  }

  /// Fetch artifacts list from server
  Future<void> fetchArtifactsList() async {
    logger.info('Fetching artifacts...');
    try {
      final api = ApiClient();
      final response = await api.get('/v1/artifacts');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch artifacts: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawArtifacts = (data is Map<String, dynamic>)
          ? data['artifacts']
          : data;
      if (rawArtifacts is! List) {
        _artifacts.clear();
        return;
      }

      // Phase 1: Decrypt artifact data keys on the main thread.
      // CryptoBox.decrypt is fast (single NaCl call per artifact).
      final keyedArtifacts = <({Artifact artifact, Uint8List key})>[];
      final decryptedArtifacts = <DecryptedArtifact>[];
      for (final raw in rawArtifacts) {
        await Future<void>.delayed(Duration.zero); // yield to event queue
        if (raw is! Map<String, dynamic>) continue;
        try {
          final artifact = Artifact.fromJson(raw);
          final decryptedKey = await encryption.decryptEncryptionKey(
            artifact.dataEncryptionKey,
          );
          if (decryptedKey != null) {
            _artifactDataKeys[artifact.id] = decryptedKey;
            keyedArtifacts.add((artifact: artifact, key: decryptedKey));
          } else {
            decryptedArtifacts.add(
              DecryptedArtifact(
                id: artifact.id,
                headerVersion: artifact.headerVersion,
                bodyVersion: artifact.bodyVersion,
                seq: artifact.seq,
                createdAt: artifact.createdAt,
                updatedAt: artifact.updatedAt,
                isDecrypted: false,
              ),
            );
          }
        } catch (error) {
          logger.warning('Failed to parse artifact key', error);
        }
      }

      // Phase 2: Decrypt headers + bodies off the main thread.
      // AES-GCM pure-Dart decryption can be slow for many artifacts.
      if (keyedArtifacts.isNotEmpty) {
        final artifactIsolateItems = keyedArtifacts.map((e) {
          final encHeader = Base64Utils.decode(
            e.artifact.header,
            Encoding.base64,
          );
          final encBody = e.artifact.body != null
              ? Base64Utils.decode(e.artifact.body!, Encoding.base64)
              : null;
          return _ArtifactIsolateItem(
            id: e.artifact.id,
            secretKey: e.key,
            encryptedHeader: encHeader,
            encryptedBody: encBody,
          );
        }).toList();

        final artifactIsolateResults =
            await _decryptArtifactsInIsolate(artifactIsolateItems);
        final artifactResultById = {
          for (final r in artifactIsolateResults) r.id: r,
        };

        for (final e in keyedArtifacts) {
          final artifact = e.artifact;
          final result = artifactResultById[artifact.id];
          final header = result?.header;
          final body = result?.body;
          decryptedArtifacts.add(
            DecryptedArtifact(
              id: artifact.id,
              title: header?['title'] as String?,
              sessions: (header?['sessions'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList(),
              draft: header?['draft'] as bool?,
              body: body?['body'] as String?,
              headerVersion: artifact.headerVersion,
              bodyVersion: artifact.bodyVersion,
              seq: artifact.seq,
              createdAt: artifact.createdAt,
              updatedAt: artifact.updatedAt,
              isDecrypted: header != null,
            ),
          );
        }
      }

      _artifacts
        ..clear()
        ..addAll(decryptedArtifacts);
      logger.info('Fetched artifacts: ${_artifacts.length}');
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Failed to fetch artifacts',
        error,
        stack,
      );
    }
  }

  /// Fetch a single artifact with full body decrypted.
  Future<DecryptedArtifact?> fetchArtifactWithBody(String id) async {
    try {
      final api = ApiClient();
      final response = await api.get('/v1/artifacts/$id');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch artifact: ${response.statusCode}');
        return null;
      }
      final raw = response.data;
      if (raw is! Map<String, dynamic>) return null;
      final artifact = Artifact.fromJson(raw);
      final decryptedKey =
          _artifactDataKeys[artifact.id] ??
          await encryption.decryptEncryptionKey(artifact.dataEncryptionKey);
      if (decryptedKey == null) return null;
      _artifactDataKeys[artifact.id] = decryptedKey;
      final artifactEncryption = ArtifactEncryption(decryptedKey);
      final header = await artifactEncryption.decryptHeader(artifact.header);
      final body = artifact.body != null
          ? await artifactEncryption.decryptBody(artifact.body!)
          : null;
      return DecryptedArtifact(
        id: artifact.id,
        title: header?['title'] as String?,
        body: body?['body'] as String?,
        headerVersion: artifact.headerVersion,
        bodyVersion: artifact.bodyVersion,
        seq: artifact.seq,
        createdAt: artifact.createdAt,
        updatedAt: artifact.updatedAt,
        isDecrypted: header != null,
      );
    } catch (error, stack) {
      logger.error('Failed to fetch artifact', error, stack);
      return null;
    }
  }

  /// Create a new artifact with optional title and body.
  /// Returns the new artifact's ID.
  Future<String> createArtifact(String? title, String? body) async {
    final dek = ArtifactEncryption.generateDataEncryptionKey();
    final artifactEncryption = ArtifactEncryption(dek);
    final encryptedDek = await encryption.encryptEncryptionKey(dek);
    final encryptedDekB64 = Base64Utils.encode(encryptedDek, Encoding.base64);
    final encryptedHeader = await artifactEncryption.encryptHeader({
      'title': title,
    });
    final encryptedBody = await artifactEncryption.encryptBody({
      'body': body ?? '',
    });
    final artifactId = encryption.generateId();
    final request = ArtifactCreateRequest(
      id: artifactId,
      header: encryptedHeader,
      body: encryptedBody,
      dataEncryptionKey: encryptedDekB64,
    );
    final api = ApiClient();
    final response = await api.post(
      '/v1/artifacts',
      data: request.toJson(),
    );
    if (!api.isSuccess(response)) {
      throw StateError('Failed to create artifact: ${response.statusCode}');
    }
    _artifactDataKeys[artifactId] = dek;
    artifactsSync.invalidate();
    return artifactId;
  }

  /// Update an existing artifact's title and/or body.
  Future<void> updateArtifact(String id, String? title, String? body) async {
    final dek = _artifactDataKeys[id];
    if (dek == null) {
      throw StateError('No decryption key found for artifact $id');
    }
    final artifactEncryption = ArtifactEncryption(dek);
    final existing = _artifacts.firstWhere(
      (a) => a.id == id,
      orElse: () => throw StateError('Artifact $id not found in cache'),
    );
    final encryptedHeader = await artifactEncryption.encryptHeader({
      'title': title,
    });
    final encryptedBody = await artifactEncryption.encryptBody({
      'body': body ?? '',
    });
    final request = ArtifactUpdateRequest(
      header: encryptedHeader,
      expectedHeaderVersion: existing.headerVersion,
      body: encryptedBody,
      expectedBodyVersion: existing.bodyVersion,
    );
    final api = ApiClient();
    final response = await api.post(
      '/v1/artifacts/$id',
      data: request.toJson(),
    );
    if (!api.isSuccess(response)) {
      throw StateError('Failed to update artifact: ${response.statusCode}');
    }
    artifactsSync.invalidate();
  }

  /// Delete an artifact by ID.
  Future<void> deleteArtifact(String id) async {
    final api = ApiClient();
    final response = await api.delete('/v1/artifacts/$id');
    if (!api.isSuccess(response)) {
      throw StateError('Failed to delete artifact: ${response.statusCode}');
    }
    _artifactDataKeys.remove(id);
    _artifacts.removeWhere((a) => a.id == id);
    _notifyDataChanged();
  }

  /// Fetch friends list from server
  Future<void> fetchFriends() async {
    logger.info('Fetching friends...');
    try {
      final api = ApiClient();
      final response = await api.get('/v1/friends');
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch friends: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawFriends = (data is Map<String, dynamic>)
          ? data['friends']
          : data;
      if (rawFriends is! List) {
        _friends.clear();
        _friendRequests.clear();
        return;
      }

      final parsedFriends = <UserProfile>[];
      for (final raw in rawFriends) {
        if (raw is Map<String, dynamic>) {
          parsedFriends.add(_mapFriendProfile(raw));
        }
      }

      _friends
        ..clear()
        ..addAll(parsedFriends);
      _friendRequests
        ..clear()
        ..addAll(_deriveFriendRequests(parsedFriends));

      logger.info(
        'Fetched friends: ${_friends.length}, '
        'pending requests: ${_friendRequests.length}',
      );
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Failed to fetch friends',
        error,
        stack,
      );
    }
  }

  /// Fetch friend requests from server.
  /// Friends and requests are both returned by fetchFriends() from /v1/friends,
  /// so this is a no-op to avoid a double network request.
  Future<void> fetchFriendRequests() async {}

  /// Fetch feed items from server
  Future<void> fetchFeed() async {
    logger.info('Fetching feed...');
    try {
      final api = ApiClient();
      final response = await api.get(
        '/v1/feed',
        queryParameters: <String, dynamic>{'limit': 50},
      );
      if (!api.isSuccess(response)) {
        logger.warning('Failed to fetch feed: ${response.statusCode}');
        return;
      }

      final data = response.data;
      final rawItems = (data is Map<String, dynamic>) ? data['items'] : data;
      if (rawItems is! List) {
        _feedItems.clear();
        return;
      }

      final parsed = <FeedItem>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          parsed.add(_mapFeedItem(raw));
        }
      }

      _feedItems
        ..clear()
        ..addAll(parsed);
      logger.info('Fetched feed items: ${_feedItems.length}');
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Failed to fetch feed', error, stack);
    }
  }

  /// Fetch todos from server
  Future<void> fetchTodos() async {
    logger.info('Fetching todos...');
    try {
      final items = await KvApi().getByPrefix('todo.', limit: 1000);
      final decryptedByKey = <String, Map<String, dynamic>>{};

      final results = await Future.wait(
        items.map((item) async {
          try {
            final decrypted = await encryption.decryptRaw(item.value);
            if (decrypted is Map<String, dynamic>) {
              return MapEntry(item.key, decrypted);
            }
          } catch (error) {
            logger.warning(
              'Failed to decrypt todo item'
              ' ${item.key}: $error',
            );
          }
          return null;
        }),
      );
      for (final entry in results) {
        if (entry != null) {
          decryptedByKey[entry.key] = entry.value;
        }
      }

      final parsedTodoLists = parseTodoListsFromDecryptedKv(decryptedByKey);
      _todoLists
        ..clear()
        ..addAll(parsedTodoLists);

      final totalItems = parsedTodoLists.values
          .expand((list) => list.items)
          .toSet()
          .length;
      logger.info(
        'Fetched todos: ${parsedTodoLists.length} list(s),'
        ' $totalItems item(s)',
      );
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Failed to fetch todos', error, stack);
    }
  }

  /// Fetch session git status from server
  /// Git status is managed locally and updated via socket events
  Future<void> _fetchSessionGitStatus() async {
    // Git status is currently managed locally via the provider
    // This sync can be extended to fetch from server when needed
    logger.info('Session git status sync triggered');
  }

  @visibleForTesting
  Map<String?, TodoList> parseTodoListsFromDecryptedKv(
    Map<String, Map<String, dynamic>> decryptedByKey,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final todosById = <String, TodoItem>{};
    var undoneOrder = <String>[];
    var doneOrder = <String>[];

    for (final entry in decryptedByKey.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'todo.index') {
        final rawUndone = value['undoneOrder'];
        if (rawUndone is List) {
          undoneOrder = rawUndone.whereType<String>().toList();
        }

        final rawCompleted = value['completedOrder'];
        if (rawCompleted is List) {
          doneOrder = rawCompleted.whereType<String>().toList();
        } else {
          final rawDone = value['doneOrder'];
          if (rawDone is List) {
            doneOrder = rawDone.whereType<String>().toList();
          }
        }
        continue;
      }

      if (!key.startsWith('todo.')) {
        continue;
      }

      final todoId = key.substring(5);
      if (todoId.isEmpty || todoId == 'index') {
        continue;
      }

      final mapped = _mapDecryptedTodoItem(
        todoId,
        value,
        createdFallbackAt: now,
      );
      todosById[todoId] = mapped;
    }

    undoneOrder = undoneOrder.where(todosById.containsKey).toList();
    doneOrder = doneOrder.where(todosById.containsKey).toList();

    final orderedIds = <String>{...undoneOrder, ...doneOrder};
    for (final entry in todosById.entries) {
      if (!orderedIds.contains(entry.key)) {
        if (entry.value.status == TodoState.completed ||
            entry.value.status == TodoState.canceled) {
          doneOrder.add(entry.key);
        } else {
          undoneOrder.add(entry.key);
        }
      }
    }

    final allOrderedIds = <String>[...undoneOrder, ...doneOrder];
    final grouped = <String?, List<TodoItem>>{null: <TodoItem>[]};
    var order = 0;

    for (final todoId in allOrderedIds) {
      final base = todosById[todoId];
      if (base == null) {
        continue;
      }

      final item = base.copyWith(order: order++);
      grouped[null]!.add(item);

      final sessionId = item.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        grouped.putIfAbsent(sessionId, () => <TodoItem>[]).add(item);
      }
    }

    final result = <String?, TodoList>{};
    for (final entry in grouped.entries) {
      result[entry.key] = TodoList(
        sessionId: entry.key,
        items: entry.value,
        updatedAt: now,
      );
    }
    return result;
  }

  TodoItem _mapDecryptedTodoItem(
    String todoId,
    Map<String, dynamic> raw, {
    required int createdFallbackAt,
  }) {
    final content =
        (raw['content'] as String?) ?? (raw['title'] as String?) ?? '';

    final rawStatus = raw['status'];
    final status = _mapTodoStatus(rawStatus, raw['done']);

    final linkedSessions = raw['linkedSessions'];
    var sessionId = raw['sessionId'] as String?;
    if ((sessionId == null || sessionId.isEmpty) &&
        linkedSessions is Map<String, dynamic> &&
        linkedSessions.isNotEmpty) {
      sessionId = linkedSessions.keys.first;
    }

    final dependenciesRaw = raw['dependencies'];
    final dependencies = dependenciesRaw is List
        ? dependenciesRaw.whereType<String>().toList()
        : <String>[];

    return TodoItem(
      id: (raw['id'] as String?) ?? todoId,
      content: content,
      status: status,
      priority: (raw['priority'] as String?) ?? 'medium',
      order: 0,
      parentId: raw['parentId'] as String?,
      dependencies: dependencies,
      dueAt: _asInt(raw['dueAt']),
      createdAt: _asInt(raw['createdAt']) ?? createdFallbackAt,
      updatedAt: _asInt(raw['updatedAt']) ?? createdFallbackAt,
      sessionId: sessionId,
      completedAt: _asInt(raw['completedAt']),
    );
  }

  TodoState _mapTodoStatus(dynamic rawStatus, dynamic rawDone) {
    if (rawStatus is String) {
      return TodoState.fromString(rawStatus);
    }

    if (rawDone is bool) {
      return rawDone ? TodoState.completed : TodoState.pending;
    }

    return TodoState.pending;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }

  @visibleForTesting
  UserProfile mapFriendProfile(Map<String, dynamic> raw) {
    return _mapFriendProfile(raw);
  }

  UserProfile _mapFriendProfile(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? (raw['uid'] as String?) ?? 'unknown';
    final firstName = (raw['firstName'] as String?) ?? '';
    final lastName = raw['lastName'] as String?;
    final username = (raw['username'] as String?) ?? '';
    final avatarRaw = raw['avatar'];
    AvatarRef? avatar;
    if (avatarRaw is Map<String, dynamic>) {
      avatar = AvatarRef.fromJson(avatarRaw);
    }

    return UserProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      avatar: avatar,
      bio: raw['bio'] as String?,
      status: RelationshipStatus.fromString(raw['status'] as String? ?? 'none'),
    );
  }

  List<FriendRequest> _deriveFriendRequests(List<UserProfile> profiles) {
    return profiles
        .where((profile) => profile.status == RelationshipStatus.pending)
        .map(
          (profile) => FriendRequest(
            id: 'friend-request-${profile.id}',
            fromUserId: profile.id,
            fromUserName: profile.name ?? profile.id,
            fromUserAvatarUrl: profile.avatarUrl,
            toUserId: serverID,
            createdAt: 0,
            status: 'pending',
          ),
        )
        .toList();
  }

  @visibleForTesting
  FeedItem mapFeedItem(Map<String, dynamic> raw) {
    return _mapFeedItem(raw);
  }

  FeedItem _mapFeedItem(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? '';
    final createdAt =
        _asInt(raw['createdAt']) ?? DateTime.now().millisecondsSinceEpoch;
    final bodyRaw = raw['body'];
    final bodyMap = bodyRaw is Map<String, dynamic>
        ? bodyRaw
        : <String, dynamic>{};
    final kind = bodyMap['kind'] as String? ?? 'text';
    var userId = raw['userId'] as String? ?? 'system';

    // Derive userId from uid in body for relationship events
    if (kind == 'friend_request' || kind == 'friend_accepted') {
      userId = (bodyMap['uid'] as String?) ?? userId;
    }

    final body = FeedBody(
      kind: kind,
      uid: bodyMap['uid'] as String?,
      text: bodyMap['text'] as String?,
    );

    return FeedItem(
      id: id,
      userId: userId,
      userName: raw['userName'] as String?,
      userAvatarUrl: raw['userAvatarUrl'] as String?,
      body: body,
      createdAt: createdAt,
      read: raw['read'] as bool? ?? false,
      sessionId: raw['sessionId'] as String?,
      repeatKey: raw['repeatKey'] as String?,
      cursor: raw['cursor'] as String?,
      counter: raw['counter'] as int?,
    );
  }

  /// Sync settings with server
  Future<void> syncSettings() async {
    logger.info('Syncing settings...');

    try {
      final apiClient = ApiClient();

      // Apply pending settings
      if (pendingSettings.isNotEmpty) {
        final mergedSettings = Settings.fromJson({
          ..._settingsSnapshot.toJson(),
          ...pendingSettings,
        });
        final encryptedPending = await encryption.encryptRaw(
          mergedSettings.toJson(),
        );

        final updateResponse = await apiClient.post(
          '/v1/account/settings',
          data: {
            'settings': encryptedPending,
            'expectedVersion': _settingsVersion,
          },
        );

        final updateData = updateResponse.data as Map<String, dynamic>?;
        final updateSuccess = updateData?['success'] == true;
        if (apiClient.isSuccess(updateResponse) && updateSuccess) {
          _settingsSnapshot = mergedSettings;
          pendingSettings.clear();
        } else if (updateData?['error'] == 'version-mismatch') {
          final currentSettingsEncrypted =
              updateData?['currentSettings'] as String?;
          final currentVersion = _asInt(updateData?['currentVersion']) ?? 0;
          final serverSettingsMap = currentSettingsEncrypted != null
              ? await encryption.decryptRaw(currentSettingsEncrypted)
                    as Map<String, dynamic>?
              : null;
          final serverSettings = Settings.fromJson(serverSettingsMap ?? {});
          _settingsSnapshot = Settings.fromJson({
            ...serverSettings.toJson(),
            ...pendingSettings,
          });
          _settingsVersion = currentVersion;
          _notifyDataChanged();
        }
      }

      // Fetch latest settings
      final response = await apiClient.get('/v1/account/settings');

      if (apiClient.isSuccess(response)) {
        final data = response.data as Map<String, dynamic>;
        final encryptedSettings = data['settings'] as String?;

        if (encryptedSettings != null) {
          final decrypted =
              await encryption.decryptRaw(encryptedSettings)
                  as Map<String, dynamic>?;
          if (decrypted != null) {
            _settingsSnapshot = Settings.fromJson(decrypted);
            _settingsVersion =
                _asInt(data['settingsVersion']) ?? _settingsVersion;
            _notifyDataChanged();
            // Persist to MMKV so the next cold start has fresh data.
            unawaited(
              MMKVStorage().saveSettings(_settingsSnapshot),
            );
          }
        } else {
          _settingsSnapshot = Settings();
          _settingsVersion =
              _asInt(data['settingsVersion']) ?? _settingsVersion;
          _notifyDataChanged();
        }
      } else {
        logger.warning('Failed to fetch settings: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Error syncing settings',
        error,
        stack,
      );
    }
  }

  /// Sync purchases — piggybacks on [profileSync] since [fetchProfile]
  /// already extracts purchases from the same endpoint.  Avoids a
  /// duplicate HTTP request to `/v1/account/profile`.
  Future<void> syncPurchases() async {
    await profileSync.awaitQueue();
  }

  /// Fetch profile from server. Also extracts and stores purchases data from
  /// the same response to avoid a second identical HTTP call from
  /// [syncPurchases].
  Future<void> fetchProfile() async {
    logger.info('Fetching profile...');

    try {
      final apiClient = ApiClient();

      final response = await apiClient.get('/v1/account/profile');

      if (apiClient.isSuccess(response)) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          _profile = Profile.fromJson(data);
          _purchases = Purchases.parse(data['purchases']);
        } else {
          logger.warning(
            'Failed to fetch profile: invalid response type '
            '${data.runtimeType}',
          );
        }
      } else {
        logger.warning('Failed to fetch profile: ${response.statusCode}');
      }
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Error fetching profile',
        error,
        stack,
      );
    }
  }

  /// Fetch native app update status
  Future<void> fetchNativeUpdate() async {
    logger.info('Fetching native update...');
    if (kIsWeb) {
      _nativeUpdateUrl = null;
      return;
    }

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    if (platform == null) {
      _nativeUpdateUrl = null;
      return;
    }

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/v1/version',
        data: <String, dynamic>{
          'platform': platform,
          'version': const String.fromEnvironment(
            'FLUTTER_BUILD_NAME',
            defaultValue: '1.0.0',
          ),
          'app_id': const String.fromEnvironment(
            'FLUTTER_APPLICATION_ID',
            defaultValue: 'happy.flutter',
          ),
        },
      );
      if (!apiClient.isSuccess(response)) {
        _nativeUpdateUrl = null;
        return;
      }

      final data = response.data as Map<String, dynamic>?;
      final updateUrl =
          data?['updateUrl'] as String? ?? data?['update_url'] as String?;
      _nativeUpdateUrl = updateUrl != null && updateUrl.isNotEmpty
          ? updateUrl
          : null;
    } catch (error, stack) {
      if (_isTransientConnectionError(error)) {
        logger.info(
          'Native update fetch aborted (transient): $error',
        );
      } else {
        logger.error(
          'Failed to fetch native update',
          error,
          stack,
        );
      }
      _nativeUpdateUrl = null;
    }
  }

  /// Register or refresh device push token
  Future<void> syncPushToken() async {
    logger.info('Syncing push token...');
    if (kIsWeb) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        logger.info('Skipping push token sync: Firebase is not initialized');
        return;
      }

      final messaging = FirebaseMessaging.instance;
      var notificationSettings = await messaging.getNotificationSettings();
      if (notificationSettings.authorizationStatus ==
          AuthorizationStatus.notDetermined) {
        notificationSettings = await messaging.requestPermission();
      }
      if (notificationSettings.authorizationStatus ==
              AuthorizationStatus.denied ||
          notificationSettings.authorizationStatus ==
              AuthorizationStatus.notDetermined) {
        return;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      if (_registeredPushToken == token) {
        return;
      }

      await PushApi().registerToken(token);
      _registeredPushToken = token;
    } catch (error, stack) {
      logger.error('Failed to sync push token', error, stack);
    }
  }

  /// Refresh machines from server
  Future<void> refreshMachines() async {
    // Route through machinesSync so concurrent calls are coalesced rather than
    // firing two parallel GET /v1/machines requests.
    await machinesSync.invalidateAndAwait();
  }

  /// Refresh sessions from server
  Future<void> refreshSessions() async {
    await sessionsSync.invalidateAndAwait();
  }

  /// Mark a session as optimistically archived.
  ///
  /// Call this after a successful archive API call. The session will be
  /// filtered from the active list until the server confirms with
  /// `active: false`. This prevents the "archive then reappear" bug caused
  /// by server replication lag.
  void markSessionArchived(String sessionId) {
    _optimisticallyArchivedSessions.add(sessionId);
    _notifyDataChanged();
  }

  /// Mark a session as optimistically unarchived.
  ///
  /// Call this after a successful unarchive API call. Removes the session
  /// from the optimistic archive filter so it can appear in the active list.
  void markSessionUnarchived(String sessionId) {
    _optimisticallyArchivedSessions.remove(sessionId);
    _notifyDataChanged();
  }

  /// Returns whether a session is optimistically archived.
  ///
  /// Use this to filter sessions from the active list.
  bool isSessionOptimisticallyArchived(String sessionId) {
    return _optimisticallyArchivedSessions.contains(sessionId);
  }

  /// Returns a copy of all optimistically archived session IDs.
  ///
  /// Use this for filtering in widget build methods.
  Set<String> getOptimisticallyArchivedIds() {
    return Set<String>.from(_optimisticallyArchivedSessions);
  }

  /// Refresh friends and pending requests from server.
  Future<void> refreshFriends() async {
    await friendsSync.invalidateAndAwait();
    // friendRequestsSync is a no-op (requests come with friends).
  }

  /// Refresh feed items from server.
  Future<void> refreshFeed() async {
    await feedSync.invalidateAndAwait();
  }

  /// Delete a session.
  Future<bool> deleteSession(String sessionId) async {
    try {
      final api = ApiClient();
      final response = await api.delete('/v1/sessions/$sessionId');
      if (!api.isSuccess(response)) {
        return false;
      }

      _handleDeleteSession(<String, dynamic>{'sid': sessionId});
      return true;
    } catch (error, stack) {
      logger.error('Failed to delete session $sessionId', error, stack);
      return false;
    }
  }

  /// Create a session on a target machine/path and return the new session ID.
  ///
  /// Sends a `spawn-happy-session` RPC to the machine daemon, which starts a
  /// new Claude Code agent in [path].  If the directory does not yet exist the
  /// daemon returns a `requestToApproveDirectoryCreation` result; passing
  /// [approvedNewDirectoryCreation] = true tells it to create the directory.
  ///
  /// The active profile's environment variables (API keys, model config, etc.)
  /// and the last-used agent type are automatically read from settings and
  /// forwarded to the daemon so it can configure the agent correctly.
  ///
  /// Throws a [StateError] with a human-readable message on failure.
  Future<String> createSession({
    required String machineId,
    required String path,
    bool approvedNewDirectoryCreation = false,
    /// Explicit profile ID for this session. Takes precedence over
    /// [_settingsSnapshot.lastUsedProfile]. Should be passed when creating a
    /// session so the correct profile env vars are used, rather than relying
    /// on [lastUsedProfile] which can change over time.
    String? profileId,
    /// Optional initial message to pipe directly to the agent's stdin
    /// on startup via the HAPPY_INITIAL_PROMPT env var.  Bypasses the
    /// WebSocket message chain which is unreliable for the very first
    /// message on freshly-spawned sessions.
    String? message,
  }) async {
    if (!isInitialized) {
      throw StateError('Sync is not initialized');
    }
    if (!_isSocketConnected()) {
      throw StateError('Not connected to server');
    }

    // Derive agent type and environment variables from the profile.
    // Use explicit profileId if provided, otherwise fall back to
    // [_settingsSnapshot.lastUsedProfile].
    final effectiveProfileId =
        profileId ?? _settingsSnapshot.lastUsedProfile;
    final profile = effectiveProfileId != null
        ? _resolveProfile(effectiveProfileId)
        : null;
    final profileEnvVars =
        profile != null ? _profileEnvironmentVariables(profile) : null;
    final agent = _settingsSnapshot.lastUsedAgent;
    final permMode =
        profile?.defaultPermissionMode ??
        _settingsSnapshot.lastUsedPermissionMode;
    // Pass the user's last-used model so the daemon writes it into session
    // metadata.  Profile env vars are always forwarded as-is — the profile
    // defines the backend (API keys, base URLs, model names) and stripping
    // model env vars would break profiles that configure a specific model
    // (e.g. Z.AI's GLM-4.6 via ANTHROPIC_MODEL).
    final envVars = _spawnEnvironmentVariables(profileEnvVars);
    if (message != null && message.isNotEmpty) {
      envVars['HAPPY_INITIAL_PROMPT'] = message;
    }
    final req = SpawnSessionRequest(
      type: 'spawn-in-directory',
      directory: path,
      approvedNewDirectoryCreation: true, // Always approve like React Native
      agent: agent,
      permissionMode: permMode,
      model: _getModelOverride(profile: profile),
      environmentVariables: envVars,
    );

    final result = await _typedMachineRPC(
      machineId,
      'spawn-happy-session',
      req.toJson(),
      SpawnSessionResponse.fromJson,
      timeout: const Duration(seconds: 60),
    );

    if (result.type == 'success') {
      final sessionId = result.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        throw StateError('Machine returned empty session ID');
      }

      // Initialize encryption from the DEK included in the spawn response,
      // avoiding the sync race condition where delta fetches miss the new
      // session's dataEncryptionKey.
      final dek = result.dataEncryptionKey;
      if (dek != null && dek.isNotEmpty) {
        final decryptedKey = await encryption.decryptEncryptionKey(dek);
        if (decryptedKey != null) {
          await encryption.initializeSessions({sessionId: decryptedKey});
        }
      }
      _sessionSpawnedAt[sessionId] = DateTime.now().millisecondsSinceEpoch;
      logger.info(
        '[createSession] Registered session $sessionId in _sessionSpawnedAt',
      );

      // Force a full fetch (not delta) to ensure the newly created session
      // is included in the results. This prevents a race condition where
      // server clock skew causes the session to be excluded from delta
      // fetches (changedSince > session.updatedAt).
      _forceFullFetchNext = true;
      await refreshSessions();

      // Optimistic insert: if the server's /v2/sessions endpoint hasn't
      // propagated the new session yet (replication lag between the RPC
      // endpoint that created it and the REST endpoint that lists it),
      // add a placeholder directly to _sessions. This prevents
      // "Session X not loaded" errors in sendMessage(). The placeholder
      // will be replaced with full server data on the next successful
      // fetch that includes this session.
      if (!_sessions.containsKey(sessionId)) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _sessions[sessionId] = Session(
          id: sessionId,
          seq: 0,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadata: Metadata(
            host: '',
            machineId: machineId,
            path: path,
            lifecycleState: 'starting',
          ),
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
      }
      // Flush data change notification immediately so the counter is
      // incremented before loadFromSync() is called. This ensures the
      // sessions list updates without requiring a pull-to-refresh.
      _flushDataChanged();

      // Pre-initialise messagesSync so the chat screen doesn't need to
      // wait for onSessionVisible() — prevents a window where the user
      // navigates to the chat screen before the sync entry exists.
      if (!messagesSync.containsKey(sessionId)) {
        onSessionVisible(sessionId);
      }

      // Optimistic insert: show the initial message immediately in the
      // chat screen while the daemon child pipes it to Claude via stdin.
      if (message != null && message.isNotEmpty) {
        _upsertSessionMessages(sessionId, [
          <String, dynamic>{
            'id': 'initial-${DateTime.now().millisecondsSinceEpoch}',
            'seq': 0,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'role': 'user',
            'kind': 'text',
            'content': message,
            'sendStatus': 'sending',
          },
        ]);
        _notifySessionMessagesChanged(sessionId);
      }

      return sessionId;
    }

    if (result.type == 'requestToApproveDirectoryCreation') {
      return createSession(
        machineId: machineId,
        path: path,
        approvedNewDirectoryCreation: true,
      );
    }

    final errorMsg = result.errorMessage ?? 'unknown error';

    // The daemon waits 15 s for the agent's startup webhook before returning
    // an error.  The agent often connects to the server ~2 s after that
    // deadline, so the session IS created even though the RPC returned an
    // error.  Retry once: wait briefly, force a full session refresh, then
    // look for a recently-created session on this machine + path.
    if (errorMsg.contains('webhook timeout')) {
      logger.info(
        '[createSession] spawn webhook timeout for '
        'machine=$machineId path=$path — waiting for late session',
      );
      await Future<void>.delayed(const Duration(seconds: 5));
      _forceFullFetchNext = true;
      await refreshSessions();

      final now = DateTime.now().millisecondsSinceEpoch;
      final candidates =
          _sessions.values
              .where(
                (s) {
                  final ageMs = now - s.createdAt;
                  final matchesMachineId = s.metadata?.machineId == machineId;
                  final matchesPath = s.metadata?.path == path;
                  final recent = ageMs < 90000;
                  final isMatch = matchesMachineId && matchesPath && recent;
                  if (matchesPath && ageMs < 120000) {
                    logger.info(
                      '[createSession] checking session ${s.id}: '
                      'machineId=${s.metadata?.machineId} '
                      '(matches=$matchesMachineId) '
                      'path=${s.metadata?.path} '
                      '(matches=$matchesPath) '
                      'age=${(ageMs / 1000).toStringAsFixed(1)}s '
                      '(recent=$recent) '
                      'isMatch=$isMatch',
                    );
                  }
                  return isMatch;
                },
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      logger.info(
        '[createSession] found ${candidates.length} candidate sessions '
        'matching machine=$machineId path=$path',
      );

      if (candidates.isNotEmpty) {
        final found = candidates.first;
        logger.info(
          '[createSession] recovered session ${found.id} '
          'after webhook timeout',
        );
        _sessionSpawnedAt[found.id] = found.createdAt;
        _notifyDataChanged();
        return found.id;
      }

      logger.warning(
        '[createSession] session not found after webhook timeout retry '
        'machine=$machineId path=$path',
      );
    }

    throw StateError(errorMsg);
  }

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
    } catch (error) {
      logger.error('machineBash error', error);
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
    } catch (error) {
      logger.error('machineReadFile error', error);
    }
    return const ReadFileResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Fetch Claude Code usage limits from a machine via encrypted RPC.
  ///
  /// The machine daemon reads `~/.claude/.credentials.json` and calls the
  /// Anthropic OAuth usage API, returning the raw JSON payload.
  Future<ClaudeUsageLimitsResponse> machineGetClaudeUsageLimits({
    required String machineId,
  }) async {
    try {
      return await _typedMachineRPC(
        machineId,
        'get-claude-usage-limits',
        <String, dynamic>{},
        ClaudeUsageLimitsResponse.fromJson,
      );
    } catch (error) {
      logger.warning('machineGetClaudeUsageLimits error', error);
    }
    return const ClaudeUsageLimitsResponse(
      success: false,
      error: 'RPC call failed',
    );
  }

  /// Create a git worktree on a machine under `.dev/worktree/<name>` relative
  /// to [basePath] and return the absolute path to the new worktree.
  ///
  /// Mirrors React Native's `createWorktree` utility.
  /// Throws [StateError] if [basePath] is not a git repository or the
  /// worktree creation fails after retries.
  Future<String> createWorktree({
    required String machineId,
    required String basePath,
  }) async {
    final gitCheck = await machineBash(
      machineId: machineId,
      command: 'git rev-parse --git-dir',
      cwd: basePath,
    );
    if (!gitCheck.success) {
      throw StateError('Not a Git repository');
    }

    final name = _generateWorktreeName();
    final worktreePath = '.dev/worktree/$name';
    var result = await machineBash(
      machineId: machineId,
      command: 'git worktree add -b $name $worktreePath',
      cwd: basePath,
    );
    if (result.success) {
      return '$basePath/$worktreePath';
    }

    if (result.stderr.contains('already exists')) {
      for (var i = 2; i <= 4; i++) {
        final newName = '$name-$i';
        final newPath = '.dev/worktree/$newName';
        result = await machineBash(
          machineId: machineId,
          command: 'git worktree add -b $newName $newPath',
          cwd: basePath,
        );
        if (result.success) {
          return '$basePath/$newPath';
        }
      }
    }

    throw StateError(
      result.stderr.isNotEmpty ? result.stderr : 'Failed to create worktree',
    );
  }

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

  String _generateWorktreeName() {
    final rand = Random();
    final adj = _worktreeAdjectives[rand.nextInt(_worktreeAdjectives.length)];
    final noun = _worktreeNouns[rand.nextInt(_worktreeNouns.length)];
    return '$adj-$noun';
  }

  /// Convert an [AIBackendProfile] into a flat map of environment variables
  /// that will be forwarded to the machine daemon when spawning a session.
  ///
  /// Resolve a profile by ID: custom profiles first, then built-in.
  AIBackendProfile? _resolveProfile(String id) {
    for (final p in _settingsSnapshot.profiles) {
      if (p.id == id) return p;
    }
    return getBuiltInProfile(id);
  }

  /// Mirrors React Native's `getProfileEnvironmentVariables` in settings.ts.
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
        envVars['TMUX_UPDATE_ENVIRONMENT'] = tmux.updateEnvironment.toString();
      }
    }

    return envVars;
  }

  /// Build daemon spawn environment variables with safe defaults.
  Map<String, String> _spawnEnvironmentVariables(Map<String, String>? base) {
    return <String, String>{...?base};
  }

  /// Never pass --model when spawning sessions. The model is always
  /// determined by profile env vars (ANTHROPIC_MODEL, OPENAI_MODEL, etc.)
  /// or the CLI's own defaults. Passing --model causes stale model names
  /// (e.g. GLM-5) to leak across profile switches.
  String? _getModelOverride({AIBackendProfile? profile}) => null;

  /// Get environment variables and profile for spawning a session, using the
  /// profile associated with the session if available. Does NOT fall back to
  /// [lastUsedProfile] — if no profile is saved for the session, returns
  /// empty env vars and null profile to avoid using a wrong profile after
  /// profile switches.
  Future<({Map<String, String> envVars, AIBackendProfile? profile})>
      _getSpawnEnvVarsForSession(String sessionId) async {
    final override = testGetSpawnEnvVarsOverride;
    if (override != null) return override(sessionId);
    // Get the profile ID that was saved for this specific session.
    final profileId = await MMKVStorage().getSessionProfile(sessionId);
    if (profileId != null) {
      final profile = _resolveProfile(profileId);
      if (profile != null) {
        return (
          envVars: _spawnEnvironmentVariables(
            _profileEnvironmentVariables(profile),
          ),
          profile: profile,
        );
      }
    }
    // No profile saved for this session — return empty env vars rather than
    // falling back to lastUsedProfile which may have changed since creation.
    return (envVars: _spawnEnvironmentVariables(null), profile: null);
  }

  Future<
    ({String sessionId, Session session, SessionEncryption sessionEncryption})
  >
  _resolveSendTargetSession({
    required String sessionId,
    required Session session,
    required SessionEncryption sessionEncryption,
    required String effectivePermissionMode,
  }) async {
    final lifecycleState = session.metadata?.lifecycleState;
    final agentIsStartingOrRunning =
        lifecycleState == 'starting' || lifecycleState == 'running';
    // Guard against stale lifecycleState: if the agent process crashed without
    // updating metadata to "archived", lifecycleState stays "running" even
    // though the session is offline.  Only trust lifecycleState if the
    // timestamp is recent (< 2 minutes).
    final lifecycleStateSince = session.metadata?.lifecycleStateSince;
    final lifecycleRecent =
        lifecycleStateSince != null &&
        DateTime.now().millisecondsSinceEpoch - lifecycleStateSince < 120000;
    final spawnedAt = _sessionSpawnedAt[sessionId];
    final recentlySpawned =
        spawnedAt != null &&
        DateTime.now().millisecondsSinceEpoch - spawnedAt < 120000;
    // When lifecycleState is explicitly 'archived', the agent process is
    // gone.  Don't trust a stale presence='online' — fall through to
    // auto-restore instead.
    final isArchived = lifecycleState == 'archived';
    // Don't trust presence='online' by itself — after a daemon restart a
    // full session fetch resets all presence-expiry timers, leaving dead
    // sessions with stale 'online' presence for up to 60 s.  Cross-check
    // with the last ephemeral event (keep-alive / activity) timestamp so
    // we only trust presence that is backed by a recent real-time signal.
    final lastEphemeral = _lastEphemeralAt[sessionId];
    final recentEphemeral =
        lastEphemeral != null &&
        DateTime.now().millisecondsSinceEpoch - lastEphemeral < 90000;
    final isOnlineTrusted = session.isOnline && recentEphemeral;
    final looksReady =
        !isArchived &&
        (isOnlineTrusted ||
            (agentIsStartingOrRunning && lifecycleRecent) ||
            recentlySpawned);
    logger.info(
      '[sendMessage] _resolveSendTargetSession '
      'session=$sessionId looksReady=$looksReady '
      '(isOnline=${session.isOnline}, '
      'isOnlineTrusted=$isOnlineTrusted, '
      'lifecycleState=$lifecycleState, '
      'lifecycleRecent=$lifecycleRecent, '
      'recentlySpawned=$recentlySpawned, '
      'agentStateVersion=${session.agentStateVersion})',
    );
    if (looksReady) {
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }

    final machineId = session.metadata?.machineId;
    final path = session.metadata?.path;
    if (machineId == null ||
        machineId.isEmpty ||
        path == null ||
        path.isEmpty) {
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }

    logger.info(
      '[sendMessage] session=$sessionId appears offline '
      '(presence=${session.presence}, lifecycleState=$lifecycleState); '
      'attempting auto-restore',
    );

    if (_autoRestoreInFlight.contains(sessionId)) {
      logger.info(
        '[sendMessage] auto-restore already in-flight for '
        'session=$sessionId, skipping duplicate',
      );
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    }
    _autoRestoreInFlight.add(sessionId);
    try {
      // Resolve profile env vars for this session before spawning.
      final spawnResult =
          await _getSpawnEnvVarsForSession(sessionId);
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        agent: session.metadata?.flavor ?? 'claude',
        permissionMode: effectivePermissionMode,
        model: _getModelOverride(profile: spawnResult.profile),
        environmentVariables: spawnResult.envVars,
      );
      final result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      if (result.type != 'success') {
        logger.warning(
          '[sendMessage] auto-restore not successful '
          'session=$sessionId type=${result.type ?? 'null'} '
          'error=${result.errorMessage ?? 'unknown'}',
        );
        return (
          sessionId: sessionId,
          session: session,
          sessionEncryption: sessionEncryption,
        );
      }

      final restoredSessionId = result.sessionId;
      if (restoredSessionId == null || restoredSessionId.isEmpty) {
        logger.warning(
          '[sendMessage] auto-restore returned empty session id '
          'for requested=$sessionId',
        );
        return (
          sessionId: sessionId,
          session: session,
          sessionEncryption: sessionEncryption,
        );
      }

      await _primeSessionFromSpawnResult(
        requestedSessionId: sessionId,
        restoredSessionId: restoredSessionId,
        seedSession: session,
        result: result,
      );
      if (restoredSessionId != sessionId) {
        logger.info(
          '[sendMessage] auto-restore redirected session '
          '$sessionId -> $restoredSessionId',
        );
        // Keep the list fresh, but do not force a full /v2/sessions reload.
        sessionsSync.invalidate();
      }

      var restoredSession = _sessions[restoredSessionId];
      if (restoredSession == null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        restoredSession = Session(
          id: restoredSessionId,
          seq: 0,
          createdAt: now,
          updatedAt: now,
          active: true,
          activeAt: now,
          metadata: Metadata(
            host: session.metadata?.host ?? '',
            machineId: machineId,
            path: path,
            flavor: session.metadata?.flavor,
            lifecycleState: 'starting',
          ),
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
        _sessions[restoredSessionId] = restoredSession;
        _notifyDataChanged();
      }

      var restoredSessionEncryption = encryption.getSessionEncryption(
        restoredSessionId,
      );
      if (restoredSessionEncryption == null && restoredSessionId == sessionId) {
        restoredSessionEncryption = sessionEncryption;
      }
      if (restoredSessionEncryption == null) {
        await sessionsSync.invalidateAndAwait();
        restoredSessionEncryption = encryption.getSessionEncryption(
          restoredSessionId,
        );
      }
      if (restoredSessionEncryption == null) {
        logger.warning(
          '[sendMessage] auto-restore missing encryption for '
          'session=$restoredSessionId; using original session',
        );
        return (
          sessionId: sessionId,
          session: session,
          sessionEncryption: sessionEncryption,
        );
      }

      return (
        sessionId: restoredSessionId,
        session: restoredSession,
        sessionEncryption: restoredSessionEncryption,
      );
    } catch (error, stack) {
      // Transient network errors during auto-restore are expected
      // when the device is offline — log at info to avoid Sentry noise.
      if (_isTransientConnectionError(error)) {
        logger.info(
          '[sendMessage] auto-restore failed (transient) '
          'session=$sessionId: $error',
        );
      } else {
        logger
          ..warning(
            '[sendMessage] auto-restore failed for session=$sessionId',
            error,
          )
          ..warning(
            '[sendMessage] auto-restore stacktrace '
            'for session=$sessionId',
            stack,
          );
      }
      return (
        sessionId: sessionId,
        session: session,
        sessionEncryption: sessionEncryption,
      );
    } finally {
      _autoRestoreInFlight.remove(sessionId);
    }
  }

  /// Send message to session.
  ///
  /// Returns the target session ID synchronously after the optimistic
  /// message is inserted and the UI is notified. The actual REST POST
  /// and socket emit run in the background — callers should NOT await
  /// this method if they want instant feedback.
  ///
  /// The optimistic message carries a `'sendStatus'` field:
  /// - `'sending'` — immediately after insert
  /// - `'sent'`    — after server ACK
  /// - `'failed'`  — on error (message is kept so the user can see it)
  Future<String> sendMessage(
    String sessionId,
    String text, {
    String? displayText,
    String? permissionMode,
    String? modelMode,
  }) async {
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      logger.info(
        '[sendMessage] encryption missing for session=$sessionId, '
        'attempting recovery',
      );
      // Try fetching just this session before doing a full list re-fetch.
      await fetchSingleSession(sessionId);
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        throw StateError('Session encryption not initialized for $sessionId');
      }
    }

    var session = _sessions[sessionId];
    if (session == null) {
      // Try fetching just this session instead of a full list re-fetch.
      session = await fetchSingleSession(sessionId);
      if (session == null) {
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        session = _sessions[sessionId];
      }
    }
    if (session == null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      session = Session(
        id: sessionId,
        seq: 0,
        createdAt: now,
        updatedAt: now,
        active: true,
        activeAt: now,
        metadata: Metadata(host: '', lifecycleState: 'starting'),
        metadataVersion: 0,
        agentStateVersion: 0,
        thinking: false,
        presence: 'offline',
      );
      _sessions[sessionId] = session;
      _notifyDataChanged();
    }

    final requestedPermissionMode = permissionMode;
    final sandboxEnabled = session.metadata?.sandboxEnabled ?? false;
    final storedPermissionMode = session.permissionMode;
    final effectivePermissionMode =
        requestedPermissionMode != null && requestedPermissionMode != 'default'
        ? requestedPermissionMode
        : (storedPermissionMode != null && storedPermissionMode != 'default')
        ? storedPermissionMode
        : (sandboxEnabled ? 'bypassPermissions' : 'default');

    final sendTarget = await _resolveSendTargetSession(
      sessionId: sessionId,
      session: session,
      sessionEncryption: sessionEncryption,
      effectivePermissionMode: effectivePermissionMode,
    );
    final targetSessionId = sendTarget.sessionId;
    session = sendTarget.session;
    sessionEncryption = sendTarget.sessionEncryption;

    final wirePermissionMode =
        _supportedPermissionModes.contains(effectivePermissionMode)
        ? effectivePermissionMode
        : 'default';
    if (wirePermissionMode != effectivePermissionMode) {
      logger.warning(
        '[sendMessage] unsupported permission mode '
        '"$effectivePermissionMode" for session=$sessionId; '
        'falling back to "$wirePermissionMode"',
      );
    }
    final flavor = session.metadata?.flavor;
    final isGemini = flavor == 'gemini';
    final requestedModelMode = modelMode;
    final effectiveModelMode =
        requestedModelMode != null && requestedModelMode != 'default'
        ? requestedModelMode
        : isGemini
        ? 'gemini-2.5-pro'
        : 'default';
    final localId = encryption.generateId();
    final sentFrom = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'mac',
      _ => 'web',
    };
    final model = effectiveModelMode != 'default' ? effectiveModelMode : null;

    final rawRecord = <String, dynamic>{
      'role': 'user',
      'content': <String, dynamic>{'type': 'text', 'text': text},
      'meta': <String, dynamic>{
        'sentFrom': sentFrom,
        'permissionMode': wirePermissionMode,
        'model': model,
        'fallbackModel': null,
        'appendSystemPrompt': _appendSystemPrompt,
        'displayText': ?displayText,
      },
    };
    logger.info(
      '[sendMessage] START session=$targetSessionId '
      'localId=$localId '
      'requestedSession=$sessionId '
      'mode=$wirePermissionMode '
      'model=${model ?? 'default'} '
      'textLen=${text.length}',
    );

    // Start a Sentry transaction covering the entire send flow.
    final sendTransaction = Sentry.startTransaction(
      'chat.sendMessage',
      'task',
      bindToScope: false,
    )
      ..setData('sessionId', targetSessionId)
      ..setData('localId', localId)
      ..setData('textLength', text.length)
      ..setData('permissionMode', wirePermissionMode)
      ..setData('model', model ?? 'default');

    // Ensure catch-up polling is active for this session. Without this,
    // if sendMessage() is called before onSessionVisible() (e.g. from the
    // sessions list before the chat screen initialises), _startPostSendCatchUp
    // silently no-ops and the agent response never appears.
    if (!messagesSync.containsKey(targetSessionId)) {
      onSessionVisible(targetSessionId);
    }

    // ── Optimistic insert — UI sees the message immediately ──
    // This runs BEFORE encryption so the user gets instant feedback on tap.
    _upsertSessionMessages(targetSessionId, [
      {
        'id': localId,
        'localId': localId,
        'seq': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'role': 'user',
        'kind': 'text',
        'content': text,
        'raw': rawRecord,
        'sendStatus': 'sending',
      },
    ]);
    // Notify listeners so the chat screen renders it NOW.
    if (!_sessionMessageChangeController.isClosed) {
      _sessionMessageChangeController.add(targetSessionId);
    }

    // Encrypt after the optimistic insert so the user sees instant feedback.
    // The encrypted record is only needed for the HTTP POST to the server.
    final encryptSpan = sendTransaction.startChild(
      'chat.encrypt',
      description: 'Encrypt message for session',
    );
    final encryptedRawRecord = await sessionEncryption.encryptRawRecord(
      rawRecord,
    );
    encryptSpan.finish();

    // ── Background: REST POST + socket emit ──
    // Fire-and-forget — the caller returns targetSessionId immediately.
    // lastCompleteSendFuture is exposed for tests to synchronise on.
    final completeSendFuture = _completeSend(
      targetSessionId: targetSessionId,
      localId: localId,
      text: text,
      rawRecord: rawRecord,
      encryptedRawRecord: encryptedRawRecord,
      transaction: sendTransaction,
    );
    lastCompleteSendFuture = completeSendFuture;
    unawaited(completeSendFuture);

    return targetSessionId;
  }

  /// Background half of [sendMessage]: waits for agent, POSTs to REST,
  /// emits socket event, and updates the optimistic message status.
  Future<void> _completeSend({
    required String targetSessionId,
    required String localId,
    required String text,
    required Map<String, dynamic> rawRecord,
    required String encryptedRawRecord,
    required ISentrySpan transaction,
  }) async {
    final apiClient = ApiClient();
    var sent = false;
    var catchUpStopAfterSeq = (_sessionLastSeq[targetSessionId] ?? 0) + 1;
    try {
      // Wait for agent readiness. Use a longer timeout for sessions we
      // just spawned, since the agent needs time to connect Socket.IO
      // and update lifecycleState before it can receive messages.
      final waitSpan = transaction.startChild(
        'chat.waitForAgent',
        description: 'Wait for agent readiness',
      );
      final spawnedAt = _sessionSpawnedAt[targetSessionId];
      final recentlySpawned =
          spawnedAt != null &&
          DateTime.now().millisecondsSinceEpoch - spawnedAt < 30000;
      final ready = await waitForAgentReady(
        targetSessionId,
        recentlySpawned ? 15000 : sessionReadyTimeoutMs,
      );
      waitSpan
        ..setData('ready', ready)
        ..setData('recentlySpawned', recentlySpawned)
        ..finish(
            status: ready
                ? const SpanStatus.ok()
                : const SpanStatus.deadlineExceeded(),
          );
      if (!ready) {
        logger.info(
          '[sendMessage] agent not ready for '
          '$targetSessionId, sending anyway',
        );
      }

      final socketConnected = _isSocketConnected();
      logger.info(
        '[sendMessage] socketConnected=$socketConnected '
        'socketStatus=${socketIoClient.connectionStatus} '
        'session=$targetSessionId',
      );
      final postSpan = transaction.startChild(
        'http.client',
        description:
            'POST /v3/sessions/$targetSessionId/messages',
      );
      final response = await apiClient.post(
        '/v3/sessions/$targetSessionId/messages',
        data: {
          'messages': [
            {'content': encryptedRawRecord, 'localId': localId},
          ],
        },
      );
      postSpan
        ..setData('statusCode', response.statusCode ?? 0)
        ..finish(
            status: apiClient.isSuccess(response)
                ? const SpanStatus.ok()
                : SpanStatus.fromHttpStatusCode(
                    response.statusCode ?? 500,
                  ),
          );
      logger.info(
        '[sendMessage] POST '
        '/v3/sessions/$targetSessionId/messages '
        'status=${response.statusCode} '
        'localId=$localId',
      );

      if (apiClient.isSuccess(response)) {
        final data = response.data as Map<String, dynamic>?;
        final serverMessages = (data?['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        logger.info(
          '[sendMessage] response contained '
          '${serverMessages.length} message(s) localId=$localId',
        );

        Map<String, dynamic>? ackedServerMsg;
        for (final msg in serverMessages) {
          if (msg['localId'] == localId) {
            ackedServerMsg = msg;
            break;
          }
        }

        if (ackedServerMsg != null) {
          sent = true;
          final serverId = ackedServerMsg['id'] as String?;
          final serverSeq = _asInt(ackedServerMsg['seq']);
          final serverCreatedAt = _asInt(ackedServerMsg['createdAt']);
          if (serverSeq != null) {
            catchUpStopAfterSeq = serverSeq;
          }
          logger.info(
            '[sendMessage] ACK localId=$localId '
            'serverId=${serverId ?? 'null'} '
            'seq=${serverSeq ?? -1}',
          );
          if (serverId != null &&
              serverSeq != null &&
              serverCreatedAt != null) {
            _upsertSessionMessages(targetSessionId, [
              {
                'id': serverId,
                'localId': localId,
                'seq': serverSeq,
                'createdAt': serverCreatedAt,
                'role': 'user',
                'kind': 'text',
                'content': text,
                'raw': rawRecord,
                'sendStatus': 'sent',
              },
            ]);
            _notifySessionMessagesChanged(targetSessionId);
          } else {
            // Mark sent even without full server fields.
            _updateMessageSendStatus(targetSessionId, localId, 'sent');
            _notifySessionMessagesChanged(targetSessionId);
            logger.warning(
              '[sendMessage] server ack missing '
              'id/seq/createdAt '
              'session=$targetSessionId localId=$localId',
            );
          }

          final socketNow = _isSocketConnected();
          if (socketNow) {
            logger.info(
              '[sendMessage] emitting socket message event '
              'session=$targetSessionId localId=$localId',
            );
            _socketSend('message', {
              'sid': targetSessionId,
              'message': encryptedRawRecord,
              'localId': localId,
            });
          } else {
            logger.warning(
              '[sendMessage] socket not connected, skipping '
              'daemon notification '
              'session=$targetSessionId localId=$localId',
            );
          }
        } else {
          logger.warning(
            '[sendMessage] REST send had no localId ack; '
            'falling back to socket emit '
            'session=$targetSessionId localId=$localId',
          );
          if (socketConnected) {
            _socketSend('message', {
              'sid': targetSessionId,
              'message': encryptedRawRecord,
              'localId': localId,
            });
            sent = true;
            _updateMessageSendStatus(targetSessionId, localId, 'sent');
            _notifySessionMessagesChanged(targetSessionId);
          } else {
            throw StateError(
              'Failed to send message: '
              'server did not acknowledge message',
            );
          }
        }

        if (sent && messagesSync.containsKey(targetSessionId)) {
          _startPostSendCatchUp(
            targetSessionId,
            stopAfterSeq: catchUpStopAfterSeq,
          );
        }
      } else {
        logger.error(
          '[sendMessage] FAILED: status=${response.statusCode} '
          'session=$targetSessionId '
          'body=${response.data}',
        );
        throw StateError('Failed to send message: ${response.statusCode}');
      }
      await transaction.finish(status: const SpanStatus.ok());
    } catch (e, stack) {
      logger.error('[sendMessage] error sending', e, stack);
      transaction.setData('error', e.toString());
      await transaction.finish(status: const SpanStatus.internalError());
      if (!sent) {
        // Queue in the outbox for automatic retry with backoff.
        final entry = OutboxEntry(
          localId: localId,
          sessionId: targetSessionId,
          text: text,
          encryptedContent: encryptedRawRecord,
          rawRecord: rawRecord,
          queuedAt: DateTime.now().millisecondsSinceEpoch,
        );
        unawaited(messageOutbox.add(entry));
        // The outbox onStatusChanged callback sets 'pending' status.
      }
    }
    // Notify so the UI picks up status changes (sent/failed/pending).
    if (!_sessionMessageChangeController.isClosed) {
      _sessionMessageChangeController.add(targetSessionId);
    }
  }

  /// Outbox delivery callback: re-attempt a single queued message.
  ///
  /// Returns `true` on success, `false` to schedule a retry.
  Future<bool> _deliverOutboxEntry(OutboxEntry entry) async {
    if (!isInitialized) return false;

    final apiClient = ApiClient();
    try {
      final response = await apiClient.post(
        '/v3/sessions/${entry.sessionId}/messages',
        data: {
          'messages': [
            {
              'content': entry.encryptedContent,
              'localId': entry.localId,
            },
          ],
        },
      );

      if (!apiClient.isSuccess(response)) {
        logger.warning(
          '[MessageOutbox] re-send failed '
          'status=${response.statusCode} '
          'localId=${entry.localId}',
        );
        return false;
      }

      final data = response.data as Map<String, dynamic>?;
      final serverMessages =
          (data?['messages'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();

      Map<String, dynamic>? ackedMsg;
      for (final msg in serverMessages) {
        if (msg['localId'] == entry.localId) {
          ackedMsg = msg;
          break;
        }
      }

      if (ackedMsg != null) {
        final serverId = ackedMsg['id'] as String?;
        final serverSeq = _asInt(ackedMsg['seq']);
        final serverCreatedAt = _asInt(ackedMsg['createdAt']);
        if (serverId != null &&
            serverSeq != null &&
            serverCreatedAt != null) {
          _upsertSessionMessages(entry.sessionId, [
            {
              'id': serverId,
              'localId': entry.localId,
              'seq': serverSeq,
              'createdAt': serverCreatedAt,
              'role': 'user',
              'kind': 'text',
              'content': entry.text,
              'raw': entry.rawRecord,
              'sendStatus': 'sent',
            },
          ]);
        }
        if (_isSocketConnected()) {
          _socketSend('message', {
            'sid': entry.sessionId,
            'message': entry.encryptedContent,
            'localId': entry.localId,
          });
        }
        if (messagesSync.containsKey(entry.sessionId)) {
          _startPostSendCatchUp(
            entry.sessionId,
            stopAfterSeq: serverSeq ?? 0,
          );
        }
        logger.info(
          '[MessageOutbox] delivered localId=${entry.localId} '
          'session=${entry.sessionId}',
        );
        return true;
      }

      // Server accepted but no localId ack. Trust the HTTP 200 since the
      // server uses idempotent storage (ON CONFLICT DO NOTHING).
      logger.warning(
        '[MessageOutbox] no localId ack '
        'localId=${entry.localId} — HTTP 200 accepted, treating as delivered',
      );
      return true;
    } catch (e, stack) {
      // Exceptions during local processing (after HTTP 200 was received)
      // do NOT count as delivery failures — the server has already stored
      // the message. Only non-2xx responses count as real failures.
      // Counting exceptions as failures risks permanently losing a message
      // that the server already has (e.g., after 3 retries the client marks
      // it as failed even though the server stored it).
      logger.error(
        '[MessageOutbox] local processing threw after HTTP 200 '
        'localId=${entry.localId} — server has message, treating as delivered',
        e,
        stack,
      );
      return true;
    }
  }

  /// Update the `sendStatus` field of an optimistic message in-place.
  void _updateMessageSendStatus(
    String sessionId,
    String localId,
    String status,
  ) {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null) return;
    for (var i = 0; i < msgs.length; i++) {
      final m = msgs[i];
      if (m['localId'] == localId || m['id'] == localId) {
        msgs[i] = {...m, 'sendStatus': status};
        _sessionMessagesCache = null;
        _sessionMessagesViewCache.remove(sessionId);
        break;
      }
    }
  }

  /// Retry a failed message send.
  ///
  /// Re-queues the message in the outbox with reset retry count.
  /// The message must have a 'raw' field containing the original
  /// unencrypted message record.
  Future<void> retryFailedMessage(
    String sessionId,
    String localId,
  ) async {
    final msgs = _sessionMessages[sessionId];
    if (msgs == null) {
      logger.warning(
        '[retryFailedMessage] session not found: $sessionId',
      );
      return;
    }

    // Find the failed message
    Map<String, dynamic>? failedMessage;
    for (final m in msgs) {
      if (m['localId'] == localId || m['id'] == localId) {
        failedMessage = m;
        break;
      }
    }

    if (failedMessage == null) {
      logger.warning(
        '[retryFailedMessage] message not found: sessionId=$sessionId localId=$localId',
      );
      return;
    }

    // Get the raw record from the message
    final raw = failedMessage['raw'];
    if (raw == null || raw is! Map<String, dynamic>) {
      logger.warning(
        '[retryFailedMessage] message missing raw data: localId=$localId',
      );
      return;
    }

    final text = failedMessage['text'] as String? ??
        failedMessage['content'] as String? ?? '';

    // Get session encryption
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      logger.info(
        '[retryFailedMessage] encryption missing for session=$sessionId, '
        'attempting recovery',
      );
      await fetchSingleSession(sessionId);
      sessionEncryption = encryption.getSessionEncryption(sessionId);
    }
    if (sessionEncryption == null) {
      logger.warning(
        '[retryFailedMessage] cannot get encryption for session=$sessionId',
      );
      return;
    }

    // Re-encrypt the raw record
    final encryptedRawRecord = await sessionEncryption.encryptRawRecord(raw);

    // Create and queue the outbox entry
    final entry = OutboxEntry(
      localId: localId,
      sessionId: sessionId,
      text: text,
      encryptedContent: encryptedRawRecord,
      rawRecord: raw,
      queuedAt: DateTime.now().millisecondsSinceEpoch,
      retryCount: 0, // Reset retry count
    );

    // Update status to 'sending' before queuing
    _updateMessageSendStatus(sessionId, localId, 'sending');

    // Add to outbox
    await messageOutbox.add(entry);

    logger.info(
      '[retryFailedMessage] queued for retry: sessionId=$sessionId localId=$localId',
    );

    // Notify listeners
    _notifySessionMessagesChanged(sessionId);
  }

  void _startPostSendCatchUp(String sessionId, {required int stopAfterSeq}) {
    _postSendCatchUpTimers.remove(sessionId)?.cancel();
    final deadline = DateTime.now().add(const Duration(seconds: 30));

    // Immediate fetch so we do not wait for the first timer tick.
    messagesSync[sessionId]?.invalidate();

    _postSendCatchUpTimers[sessionId] = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        if (!isInitialized ||
            !messagesSync.containsKey(sessionId) ||
            DateTime.now().isAfter(deadline)) {
          timer.cancel();
          _postSendCatchUpTimers.remove(sessionId);
          logger.info(
            '[sendMessage] catch-up polling ended '
            'session=$sessionId reason=timeout_or_inactive',
          );
          return;
        }

        final currentSeq = _sessionLastSeq[sessionId] ?? 0;
        if (currentSeq > stopAfterSeq) {
          timer.cancel();
          _postSendCatchUpTimers.remove(sessionId);
          logger.info(
            '[sendMessage] catch-up polling ended '
            'session=$sessionId reason=seq_advanced '
            'stopAfter=$stopAfterSeq current=$currentSeq',
          );
          return;
        }

        // Skip polling for non-visible sessions — socket events already
        // trigger message fetches via _handleNewMessage, so the periodic
        // poll is redundant and wastes HTTP round-trips (each returning 0
        // messages).  When the user navigates back, onSessionVisible()
        // triggers a fresh fetch to pick up anything missed.
        // However, if socket events were missed (connection drop), the
        // invalidation below ensures catch-up via HTTP on next poll.
        messagesSync[sessionId]?.invalidate();
        if (sessionId != _visibleSessionId) {
          return;
        }
      },
    );
  }

  /// RPC call for machines - uses machine-specific encryption.
  Future<dynamic> machineRPC(
    String machineId,
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final machineEncryption = encryption.getMachineEncryption(machineId);
    if (machineEncryption == null) {
      throw StateError('Machine encryption not found for $machineId');
    }

    final encrypted = await machineEncryption.encryptRaw(params);
    final result = await socketIoClient.emitWithAck('rpc-call', {
      'method': '$machineId:$method',
      'params': encrypted,
    }, timeout: timeout);

    if (result is Map && result['ok'] == true) {
      final encryptedResult = result['result'] as String?;
      if (encryptedResult == null) {
        throw StateError('Machine RPC $method returned null result');
      }
      final decrypted = await machineEncryption.decryptRaw(encryptedResult);
      if (decrypted == null) {
        logger.warning('machineRPC $method: decryption returned null');
      }
      return decrypted;
    }
    // Log the failure reason if available
    final errorMsg = result is Map ? result['error'] : result;
    throw StateError('Machine RPC $method failed: $errorMsg');
  }

  /// RPC call for sessions - uses session-specific encryption.
  Future<dynamic> sessionRPC(
    String sessionId,
    String method,
    Map<String, dynamic> params,
  ) async {
    var sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'fetchMessages: encryption null, '
            'awaiting sessions',
        category: 'sync.messages',
        data: {'sessionId': sessionId},
      ));
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      if (sessionEncryption == null) {
        throw StateError('Session encryption not found for $sessionId');
      }
    }

    final encrypted = await sessionEncryption.encryptRaw(params);
    final result = await socketIoClient.emitWithAck('rpc-call', {
      'method': '$sessionId:$method',
      'params': encrypted,
    });

    if (result is Map && result['ok'] == true) {
      final encryptedResult = result['result'] as String?;
      if (encryptedResult == null) return null;
      final decrypted = await sessionEncryption.decryptRaw(encryptedResult);
      return decrypted;
    }
    // Log the failure reason if available
    final errorMsg = result is Map ? result['error'] : result;
    throw StateError('Session RPC $method failed: $errorMsg');
  }

  /// Typed wrapper around [machineRPC] that deserialises the response.
  Future<Resp> _typedMachineRPC<Resp>(
    String machineId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final override = testMachineRPCOverride;
    final raw = override != null
        ? await override(machineId, method, params)
        : await machineRPC(machineId, method, params, timeout: timeout);
    // Handle null or non-Map responses gracefully
    if (raw == null) {
      throw StateError(
        'Machine RPC $method returned null - encryption may have failed',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Machine RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    return fromJson(raw);
  }

  /// Typed wrapper around [sessionRPC] that deserialises the response.
  Future<Resp> _typedSessionRPC<Resp>(
    String sessionId,
    String method,
    Map<String, dynamic> params,
    Resp Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await sessionRPC(sessionId, method, params);
    // Handle null or non-Map responses gracefully
    if (raw == null) {
      throw StateError(
        'Session RPC $method returned null - encryption may have failed',
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Session RPC $method returned unexpected type: ${raw.runtimeType} '
        '(value: $raw)',
      );
    }
    return fromJson(raw);
  }

  /// Checks whether the session's CLI process is running.
  ///
  /// If the session is already online or starting/running, returns
  /// `false` (no restore needed).  If the session is offline and has
  /// `machineId`/`path` metadata, sends `spawn-happy-session` to
  /// revive it and returns `true` to signal that a **new** process
  /// was spawned (meaning old in-flight state like pending permissions
  /// is gone).
  ///
  /// Returns `false` when no restore was attempted (session was
  /// already ready, or metadata was missing).
  Future<bool> _ensureSessionProcess(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return false;

    final lifecycleState = session.metadata?.lifecycleState;
    // Guard against stale lifecycleState
    // (same logic as _resolveSendTargetSession).
    final lifecycleStateSince = session.metadata?.lifecycleStateSince;
    final lifecycleRecent =
        lifecycleStateSince != null &&
        DateTime.now().millisecondsSinceEpoch - lifecycleStateSince < 120000;
    final agentIsStartingOrRunning =
        lifecycleState == 'starting' || lifecycleState == 'running';
    final isArchived = lifecycleState == 'archived';
    final looksReady =
        !isArchived &&
        (session.isOnline || (agentIsStartingOrRunning && lifecycleRecent));
    if (looksReady) return false;

    final machineId = session.metadata?.machineId;
    final path = session.metadata?.path;
    if (machineId == null ||
        machineId.isEmpty ||
        path == null ||
        path.isEmpty) {
      return false;
    }

    logger.info(
      '[permission] session=$sessionId appears offline '
      '(presence=${session.presence}, '
      'lifecycleState=$lifecycleState); '
      'attempting auto-restore',
    );

    try {
      // Resolve profile env vars for this session before spawning.
      final spawnResult =
          await _getSpawnEnvVarsForSession(sessionId);
      final req = SpawnSessionRequest(
        type: 'spawn-in-directory',
        directory: path,
        sessionId: sessionId,
        agent: session.metadata?.flavor ?? 'claude',
        permissionMode: session.permissionMode,
        model: _getModelOverride(profile: spawnResult.profile),
        environmentVariables: spawnResult.envVars,
      );
      final result = await _typedMachineRPC(
        machineId,
        'spawn-happy-session',
        req.toJson(),
        SpawnSessionResponse.fromJson,
        timeout: const Duration(seconds: 60),
      );
      if (result.type == 'success') {
        logger.info(
          '[permission] auto-restore succeeded '
          'session=$sessionId',
        );
        return true;
      }
      logger.warning(
        '[permission] auto-restore not successful '
        'session=$sessionId type=${result.type ?? 'null'} '
        'error=${result.errorMessage ?? 'unknown'}',
      );
    } catch (error) {
      if (_isTransientConnectionError(error)) {
        logger.info(
          '[permission] auto-restore failed (transient) '
          'session=$sessionId: $error',
        );
      } else {
        logger.warning(
          '[permission] auto-restore failed '
          'session=$sessionId: $error',
        );
      }
    }
    return false;
  }

  /// Fire local notifications for any newly-detected pending
  /// permission requests that the user hasn't seen yet.
  ///
  /// Called after [fetchSessions] merges updated sessions and
  /// after inline socket updates apply new agent state.
  void _checkForNewPermissionRequests(
    Iterable<Session> sessions,
  ) {
    for (final session in sessions) {
      // Don't notify for the session the user is viewing — they
      // can see the permission footer already.
      if (session.id == _visibleSessionId) continue;

      final requests = session.agentState?.requests;
      if (requests == null || requests.isEmpty) continue;

      for (final entry in requests.entries) {
        final permId = entry.key;
        if (_notifiedPermissionIds.contains(permId)) continue;
        // Evict oldest entries when the cap is reached to bound memory.
        if (_notifiedPermissionIds.length >= _maxNotifiedPermissionIds) {
          _notifiedPermissionIds
              .remove(_notifiedPermissionIds.first);
        }
        _notifiedPermissionIds.add(permId);

        final request = entry.value;
        Map<String, dynamic>? toolInput;
        if (request.arguments is Map) {
          toolInput =
              Map<String, dynamic>.from(request.arguments as Map);
        }

        final sessionName =
            session.metadata?.summary?.text ??
            session.metadata?.path?.split('/').last;

        unawaited(
          NotificationService.instance.showPermissionNotification(
            sessionId: session.id,
            permissionId: permId,
            toolName: request.tool,
            toolInput: toolInput,
            sessionName: sessionName,
          ),
        );
      }
    }
  }

  /// Locally clear stale permission requests from a session's
  /// [AgentState] so the UI immediately unlocks the input box
  /// and hides the "permission required" banner.
  void _clearStalePermissionRequests(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    final hadRequests =
        session.agentState?.requests != null &&
        session.agentState!.requests!.isNotEmpty;
    if (hadRequests) {
      // Cancel any pending permission notifications for this session.
      for (final permId in session.agentState!.requests!.keys) {
        _notifiedPermissionIds.remove(permId);
        unawaited(
          NotificationService.instance
              .cancelPermissionNotification(permId),
        );
      }
      _sessions[sessionId] = session.copyWith(
        agentState: AgentState(
          controlledByUser: session.agentState?.controlledByUser,
          completedRequests: session.agentState?.completedRequests,
        ),
      );
    }
    // Also cancel any pending permissions on tool-call messages so
    // the UI stops showing Allow/Deny buttons that will always fail.
    final messages = _sessionMessages[sessionId];
    if (messages != null) {
      var changed = false;
      final updated = List<Map<String, dynamic>>.from(messages);
      for (var i = 0; i < updated.length; i++) {
        final msg = updated[i];
        if (msg['kind'] != 'tool-call') continue;
        final perm = msg['permission'] as Map<String, dynamic>?;
        if (perm == null || perm['status'] != 'pending') continue;
        updated[i] = {
          ...msg,
          'permission': {...perm, 'status': 'canceled'},
        };
        changed = true;
      }
      if (changed) {
        _sessionMessages[sessionId] = updated;
        _sessionMessagesCache = null;
        _sessionMessagesViewCache.remove(sessionId);
        _notifySessionMessagesChanged(sessionId);
      }
    }
    if (hadRequests || messages != null) {
      _notifyDataChanged();
    }
  }

  /// Allow a permission request for a session.
  ///
  /// The server acknowledges with `ok: true` but the response
  /// payload shape varies — the RN app ignores it entirely, so
  /// we just fire-and-forget the RPC without deserialising.
  Future<void> sessionAllow(
    String sessionId,
    String permissionId, {
    String? mode,
    List<String>? allowTools,
    String? decision,
    Map<String, dynamic>? updatedInput,
  }) async {
    final restored = await _ensureSessionProcess(sessionId);
    if (restored) {
      _clearStalePermissionRequests(sessionId);
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
      throw StateError(
        'Session was restarted — this permission has expired. '
        'The agent will re-request it if still needed.',
      );
    }
    try {
      final response = await sessionRPC(
        sessionId,
        'permission',
        PermissionRequest(
          id: permissionId,
          approved: true,
          mode: mode,
          allowTools: allowTools,
          decision: decision,
          updatedInput: updatedInput,
        ).toJson(),
      );
      _throwIfPermissionRpcFailed(response, 'allow');
    } on StateError {
      // Permission was rejected by the server — clear stale local
      // state so the UI unlocks.
      _clearStalePermissionRequests(sessionId);
      rethrow;
    } finally {
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
    }
  }

  /// Deny a permission request for a session.
  ///
  /// See [sessionAllow] — response payload is ignored.
  Future<void> sessionDeny(
    String sessionId,
    String permissionId, {
    String? decision,
  }) async {
    final restored = await _ensureSessionProcess(sessionId);
    if (restored) {
      _clearStalePermissionRequests(sessionId);
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
      throw StateError(
        'Session was restarted — this permission has expired. '
        'The agent will re-request it if still needed.',
      );
    }
    try {
      final response = await sessionRPC(
        sessionId,
        'permission',
        PermissionRequest(
          id: permissionId,
          approved: false,
          decision: decision,
        ).toJson(),
      );
      _throwIfPermissionRpcFailed(response, 'deny');
    } on StateError {
      _clearStalePermissionRequests(sessionId);
      rethrow;
    } finally {
      sessionsSync.invalidate();
      messagesSync[sessionId]?.invalidate();
    }
  }

  void _throwIfPermissionRpcFailed(dynamic response, String action) {
    if (response is! Map) return;
    final success = response['success'];
    final ok = response['ok'];
    final isFailure = success == false || ok == false;
    if (!isFailure) return;
    final error = response['error'];
    throw StateError(
      'Permission $action failed: ${error?.toString() ?? 'unknown error'}',
    );
  }

  /// Kill a session's agent process.
  Future<KillSessionResponse> killSession(String sessionId) async {
    return _typedSessionRPC(
      sessionId,
      'killSession',
      const {},
      KillSessionResponse.fromJson,
    );
  }

  /// Abort the current agent turn without killing the session.
  Future<AbortResponse> abortSession(
    String sessionId, {
    String reason = '',
  }) async {
    return _typedSessionRPC(sessionId, 'abort', {
      'reason': reason,
    }, AbortResponse.fromJson);
  }

  /// Apply settings delta
  Future<void> applySettings(Map<String, dynamic> delta) async {
    _settingsSnapshot = Settings.fromJson({
      ..._settingsSnapshot.toJson(),
      ...delta,
    });
    pendingSettings = {...pendingSettings, ...delta};
    settingsSync.invalidate();
  }

  /// Refresh purchases data
  Future<void> refreshPurchases() async {
    purchasesSync.invalidate();
  }

  /// Refresh profile data
  Future<void> refreshProfile() async {
    await profileSync.invalidateAndAwait();
  }

  /// Get authentication credentials
  AuthCredentials getCredentials() {
    return credentials;
  }

  /// On session visible handler
  void onSessionVisible(String sessionId) {
    _visibleSessionId = sessionId;
    _sessionUnreadCounts.remove(sessionId);
    // Clear any residual failed Future from the inline queue so that
    // new messages can enter the inline fast path immediately.
    _inlineProcessor.clearSession(sessionId);
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'onSessionVisible',
      category: 'sync.messages',
      data: {
        'sessionId': sessionId,
        'hasPending':
            _sessionsWithPendingSocketMessages
                .contains(sessionId),
        'hasMessagesInMemory':
            _sessionMessages[sessionId]
                    ?.isNotEmpty ??
                false,
        'cursorSeq':
            _sessionLastSeq[sessionId] ?? 0,
        'serverLastSeq':
            _sessions[sessionId]?.lastSeq ?? 0,
      },
    ));

    // If this session received socket messages while non-visible, we MUST
    // fetch from the server to get those messages.  Socket messages are NOT
    // stored in _sessionMessages for non-visible sessions (only the seq
    // cursor is advanced), so the cache may be stale even if it has data.
    final hasPendingSocketMessages =
        _sessionsWithPendingSocketMessages.remove(sessionId);

    // Only tail-refresh when we have no messages in memory for this session
    // (first open or after restart).  When messages are already loaded the
    // incremental delta path (afterSeq = _sessionLastSeq) is sufficient and
    // avoids re-downloading the last 200 messages on every navigation.
    var hasMessages =
        _sessionMessages.containsKey(sessionId) &&
        (_sessionMessages[sessionId]?.isNotEmpty ?? false);

    logger.info(
      '[onSessionVisible] sessionId=$sessionId '
      'hasPendingSocketMessages=$hasPendingSocketMessages '
      'hasMessagesInMemory=$hasMessages '
      'cursorSeq=${_sessionLastSeq[sessionId] ?? 0} '
      'serverLastSeq=${_sessions[sessionId]?.lastSeq ?? 0}',
    );

    if (!hasMessages) {
      // Restore from MMKV cache so the UI shows messages immediately
      // while the HTTP fetch is in flight.
      // BUT: when hasPendingSocketMessages is true, the cache is potentially
      // stale (socket messages arrived after the cache was saved) and we MUST
      // skip it to force a server fetch that picks up those messages.
      if (!hasPendingSocketMessages) {
        final cached = MessageCacheService().getMessages(sessionId);
        logger.info(
          '[onSessionVisible] cacheRestore: ${cached.length} cached messages',
        );
        if (cached.isNotEmpty) {
          // Strip orphaned sidechain messages (see _restoreAllCachedMessages).
          final clean = cached.any((m) => m['isSidechain'] == true)
              ? cached.where((m) => m['isSidechain'] != true).toList()
              : cached;
          if (clean.isNotEmpty) {
            _sessionMessages[sessionId] = clean;
            _sessionMessagesCache = null;
            _sessionMessagesViewCache.remove(sessionId);
            hasMessages = true;
            // Notify UI immediately so it can render the cached messages.
            _notifySessionMessagesChanged(sessionId);
            _notifyDataChanged();
          }
        }
      }
      // Only request tail refresh if cache restore failed or was skipped.
      // When messages are restored from cache, the normal delta fetch
      // (afterSeq = _sessionLastSeq) is sufficient — a tail refresh would
      // unnecessarily clear and re-download the same messages.
      if (!hasMessages) {
        _requestTailRefresh(sessionId);
        logger.info('[onSessionVisible] tailRefresh requested');
      }
    } else {
      // Messages are in memory (from cache or previous load). Check if the
      // server has newer messages that we're missing. This handles the case
      // where the app was closed and new messages arrived — delta sync may
      // not update session.lastSeq if only messages changed (no metadata).
      final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
      final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
      final hadPendingUpdates = _sessionsWithPendingUpdates.remove(sessionId);

      logger.info(
        '[onSessionVisible] hasMessages path: cursorSeq=$cursorSeq '
        'serverLastSeq=$serverLastSeq hadPendingUpdates=$hadPendingUpdates',
      );

      // Check for gap: server is ahead of our cursor
      if (cursorSeq > 0 && serverLastSeq > cursorSeq) {
        // Server has messages we haven't seen. Let fetchMessages handle it
        // via the normal incremental delta path (or gapTooLarge tail-load).
        logger.info(
          '[onSessionVisible] gap detected: server($serverLastSeq) > cursor($cursorSeq) '
          '— will fetch delta',
        );
      } else if (hadPendingUpdates) {
        // Socket events arrived while session was non-visible, but cursor
        // appears caught up or ahead.  Only tail-refresh when cursor data
        // is truly invalid (zero/negative).  When cursor >= server, the
        // incremental delta fetch is either a no-op (caught up) or will
        // pick up any remaining messages — a destructive tail-refresh
        // would unnecessarily wipe and re-download messages.
        if (cursorSeq <= 0 || serverLastSeq <= 0) {
          _requestTailRefresh(sessionId);
          logger.info('[onSessionVisible] tailRefresh (pending updates, invalid cursor)');
        }
      }
    }
    if (!messagesSync.containsKey(sessionId)) {
      messagesSync[sessionId] = InvalidateSync(
        () => fetchMessages(sessionId),
        minInterval: _messagesSyncMinInterval,
        name: 'fetchMessages:$sessionId',
      );
    }
    messagesSync[sessionId]?.invalidate();
  }

  void _requestTailRefresh(String sessionId) {
    _sessionsNeedingTailRefresh.add(sessionId);
  }

  int _tailAfterSeqForSession(String sessionId) {
    return _cursorManager.tailAfterSeq(
      sessionId,
      serverLastSeq:
          _sessions[sessionId]?.lastSeq ?? 0,
      initialLoad: initialLoad,
    );
  }

  /// Fetch messages for a session.
  ///
  /// On first open (no entry in [_sessionLastSeq]) this uses the session's
  /// [Session.lastSeq] hint to jump straight to the tail of the history,
  /// fetching only the most recent [initialLoad] messages.  Subsequent calls
  /// (incremental delta syncs) continue from [_sessionLastSeq] as before.
  Future<void> fetchMessages(String sessionId) async {
    logger.info(
      'Fetching messages for session: $sessionId',
    );
    final fetchStopwatch = Stopwatch()..start();

    // Start a Sentry span for this fetch operation
    final fetchSpan = Sentry.getSpan()?.startChild(
      'sync.fetchMessages',
      description: 'Fetch messages for session $sessionId',
    );
    fetchSpan?.setData('sessionId', sessionId);

    var sessionEncryption =
        encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) {
      final encSpan = fetchSpan?.startChild(
        'sync.encryption.init',
        description: 'Wait for session encryption',
      );
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'fetchMessages: encryption null, '
            'awaiting sessions',
        category: 'sync.messages',
        data: {'sessionId': sessionId},
      ));
      // Encryption may not be initialized yet — wait for pending fetch.
      await sessionsSync.invalidateAndAwait();
      sessionEncryption = encryption.getSessionEncryption(sessionId);
      if (sessionEncryption == null) {
        // Force a full fetch in case changedSince race skipped the session.
        _forceFullFetchNext = true;
        await sessionsSync.invalidateAndAwait();
        sessionEncryption = encryption.getSessionEncryption(sessionId);
      }
      encSpan?.finish();
      if (sessionEncryption == null) {
        logger.warning(
          'Session encryption not initialized for '
          '$sessionId after 2 attempts, skipping',
        );
        fetchSpan?.setData('status', 'preconditionFailed');
        fetchSpan?.setData('encryptionInitFailed', true);
        fetchSpan?.setData('elapsedMs', fetchStopwatch.elapsedMilliseconds);
        fetchSpan?.finish();
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'fetchMessages: encryption still '
              'null after 2 attempts',
          category: 'sync.messages',
          level: SentryLevel.warning,
          data: {
            'sessionId': sessionId,
            'sessionExists':
                _sessions.containsKey(sessionId),
            'elapsedMs':
                fetchStopwatch.elapsedMilliseconds,
          },
        ));
        // Notify UI so the loading spinner clears.
        _notifySessionMessagesChanged(sessionId);
        _notifyDataChanged();
        return;
      }
    }

    try {
      final apiClient = ApiClient();
      // "First load" means no messages are in memory yet for this session
      // (new session or app was restarted — _sessionMessages is not
      // persisted to disk).  In this case we do a tail-load using the
      // server's lastSeq hint regardless of the persisted _sessionLastSeq.
      final isFirstLoad =
          !_sessionMessages.containsKey(sessionId) ||
          (_sessionMessages[sessionId]?.isEmpty ?? true);
      final forceTailRefresh = _sessionsNeedingTailRefresh.remove(sessionId);
      int afterSeq;

      // Detect large gaps: when the cursor is far behind the session's
      // current lastSeq, forward-crawling page by page is extremely slow
      // (100 msgs/page × decrypt × O(n) grouping per page).  Fall back
      // to a tail-load so we only fetch the most recent messages.
      final cursorSeq = _sessionLastSeq[sessionId] ?? 0;
      final serverLastSeq = _sessions[sessionId]?.lastSeq ?? 0;
      final gapTooLarge =
          !isFirstLoad &&
          !forceTailRefresh &&
          serverLastSeq > 0 &&
          cursorSeq <= serverLastSeq &&
          (serverLastSeq - cursorSeq) > initialLoad;

      logger.info(
        '[fetchMessages] $sessionId '
        'isFirstLoad=$isFirstLoad '
        'forceTailRefresh=$forceTailRefresh '
        'gapTooLarge=$gapTooLarge '
        'cursorSeq=$cursorSeq '
        'serverLastSeq=$serverLastSeq',
      );

      // Skip the HTTP round-trip when the cursor is at or ahead of the
      // server's known lastSeq — there is nothing to fetch.  Socket
      // events (new-message) update _sessionLastSeq via inline processing
      // for the visible session and can push cursor PAST the server's
      // lastSeq (since session.lastSeq lags behind socket events).
      // We guard with !hasGap so we don't skip when cursor > serverLastSeq —
      // that indicates socket events may have outpaced the server and we
      // should fetch to ensure no messages were missed.
      final hasGap = serverLastSeq > 0 && cursorSeq <= serverLastSeq &&
          (serverLastSeq - cursorSeq) > initialLoad;
      if (!isFirstLoad &&
          cursorSeq > 0 &&
          serverLastSeq > 0 &&
          cursorSeq == serverLastSeq &&
          !hasGap) {
        logger.info(
          '[fetchMessages] $sessionId already caught up '
          '(cursor=$cursorSeq server=$serverLastSeq) '
          '— skipping',
        );
        // Notify UI so any pending loading state clears.
        _notifySessionMessagesChanged(sessionId);
        return;
      }

      // Track that we're doing a tail-load gap recovery. We'll clear
      // stale messages AFTER the first page succeeds to avoid losing
      // messages if the network request fails. Declared early so it's
      // accessible in the while loop below.
      // Note: gapTooLarge is computed with !forceTailRefresh to short-circuit,
      // so we must use || here to ensure stale clearing happens for both
      // explicit tail-refresh requests AND large-gap detections.
      final isGapRecovery = gapTooLarge || forceTailRefresh;
      if (isFirstLoad || forceTailRefresh || gapTooLarge) {
        // Lazy tail-load: start near the end of the session
        // history so we don't download thousands of messages
        // that the UI will never show.
        //
        // For first load and tail refresh, compute the
        // window from the known max seq, ignoring the cursor.
        if (isFirstLoad || forceTailRefresh) {
          final knownMax = max(cursorSeq, serverLastSeq);
          afterSeq = knownMax <= initialLoad
              ? 0
              : knownMax - initialLoad;
          // after_seq=N returns messages with seq > N, so small
          // non-zero values (1-10) would skip the very first
          // message(s) of the conversation.  Round down to 0 when
          // the window barely exceeds initialLoad so the first
          // message is always included in the initial fetch.
          if (afterSeq > 0 && afterSeq <= 10) {
            afterSeq = 0;
          }
        } else {
          afterSeq = _tailAfterSeqForSession(sessionId);
        }
        if (gapTooLarge) {
          logger.info(
            '[fetchMessages] $sessionId gap too large '
            '(cursor=$cursorSeq server=$serverLastSeq) — '
            'switching to tail-load afterSeq=$afterSeq',
          );
        } else if (forceTailRefresh && !isFirstLoad) {
          logger.info(
            '[fetchMessages] $sessionId forcing tail refresh '
            'afterSeq=$afterSeq',
          );
        }
        if (isFirstLoad || gapTooLarge) {
          if (afterSeq > 0) {
            // Record where we started so the UI can offer "load older" later.
            _sessionFirstLoadedSeq[sessionId] = afterSeq + 1;
          } else {
            // Session is short — we will load everything; no older messages.
            _sessionFirstLoadedSeq[sessionId] = 0;
          }
          MMKVStorage().saveSessionFirstLoadedSeq(
            Map.unmodifiable(_sessionFirstLoadedSeq),
          );
        }
      } else if (cursorSeq == 0) {
        // No cursor established yet — use server's hint for tail refresh.
        afterSeq = _tailAfterSeqForSession(sessionId);
      } else {
        afterSeq = cursorSeq;
      }

      var page = 0;
      while (true) {
        // ── Check visibility BEFORE network call ──
        if (page > 0 && _visibleSessionId != sessionId) {
          logger.info(
            '[fetchMessages] $sessionId no longer visible '
            'after page $page — aborting',
          );
          // Notify UI so it stops the loading spinner. The session is
          // non-visible so further pagination is the responsibility of
          // onSessionVisible() when the user navigates back.
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged();
          break;
        }

        final fetchStart = Stopwatch()..start();
        final Response<dynamic> response;
        if (testFetchMessagesOverride != null) {
          final overrideResult = await testFetchMessagesOverride!(
            sessionId,
            afterSeq,
            100,
          );
          // Synthesize a minimal Response to satisfy the rest of the logic.
          response = Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: overrideResult,
          );
        } else {
          response = await apiClient.get(
            '/v3/sessions/$sessionId/messages',
            queryParameters: {'after_seq': afterSeq, 'limit': 100},
          );
        }
        final fetchMs = fetchStart.elapsedMilliseconds;

        if (!apiClient.isSuccess(response)) {
          final statusCode = response.statusCode;
          logger.warning(
            'Failed to fetch messages: $statusCode',
          );
          Sentry.addBreadcrumb(Breadcrumb(
            message: 'fetchMessages: HTTP error',
            category: 'sync.messages',
            level: SentryLevel.warning,
            data: {
              'sessionId': sessionId,
              'statusCode': statusCode,
              'afterSeq': afterSeq,
              'page': page,
              'elapsedMs':
                  fetchStopwatch.elapsedMilliseconds,
            },
          ));
          // 404 means the session doesn't exist on the server. Clean up
          // the local session and stop retries to prevent repeated 404s.
          if (statusCode == 404) {
            logger.warning(
              '[fetchMessages] Session $sessionId not found (404) '
              '— cleaning up local state',
            );
            messagesSync.remove(sessionId)?.dispose();
            _postSendCatchUpTimers.remove(sessionId)?.cancel();
            _loadingOlderMessages.remove(sessionId);
            _sessionMessages.remove(sessionId);
            _sessionMessagesCache = null;
            _sessionMessagesViewCache.remove(sessionId);
            _todoLists.remove(sessionId);
            if (sessionId == _visibleSessionId) {
              _visibleSessionId = null;
            }
            _sessions.remove(sessionId);
            _presenceTimers.remove(sessionId)?.cancel();
            _sessionDataKeys.remove(sessionId);
            _sessionEncryptedDataKeys.remove(sessionId);
            _sessionsNeedingTailRefresh.remove(sessionId);
            _sessionsWithPendingUpdates.remove(sessionId);
            _sessionsWithPendingSocketMessages.remove(sessionId);
            _sessionSpawnedAt.remove(sessionId);
            _autoRestoreInFlight.remove(sessionId);
            _pendingToolResults.remove(sessionId);
            if (isInitialized) {
              _sessionLastSeq.remove(sessionId);
              MMKVStorage().saveSessionLastSeq(
                Map.unmodifiable(_sessionLastSeq),
              );
              _sessionFirstLoadedSeq.remove(sessionId);
              MMKVStorage().saveSessionFirstLoadedSeq(
                Map.unmodifiable(_sessionFirstLoadedSeq),
              );
              _saveMsgsDebounceTimers.remove(sessionId)?.cancel();
              MessageCacheService().clearMessages(sessionId);
              encryption.removeSessionEncryption(sessionId);
            }
            _scheduleSessionsRefresh();
          } else {
            // For other errors, notify UI so it stops the loading spinner
            // and can show an error/empty state instead of spinning forever.
            _notifySessionMessagesChanged(sessionId);
          }
          _notifyDataChanged();
          break;
        }

        final data = response.data as Map<String, dynamic>;
        final messages = (data['messages'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final hasMore = data['hasMore'] as bool? ?? false;

        logger.info(
          '[fetchMessages] $sessionId page=$page '
          'msgs=${messages.length} hasMore=$hasMore '
          'fetchMs=$fetchMs',
        );

        // ── Decrypt + process (isolate for large batches) ──
        final decryptStart = Stopwatch()..start();
        final processed = await sessionEncryption.decryptAndProcessMessages(
          messages,
          sessionId,
        );
        final decryptMs = decryptStart.elapsedMilliseconds;
        final userCount = processed.messages
            .where((message) => message['role'] == MessageRole.user)
            .length;
        final agentCount = processed.messages
            .where((message) => message['role'] == MessageRole.agent)
            .length;
        final eventCount = processed.messages
            .where((message) => message['kind'] == 'agent-event')
            .length;
        logger.info(
          '[fetchMessages] $sessionId page=$page '
          'processedMsgs=${processed.messages.length} '
          'users=$userCount agents=$agentCount events=$eventCount '
          'toolResults=${processed.toolResults.length} '
          'usageUpdates=${processed.usageUpdates.length} '
          'afterSeq=$afterSeq '
          'maxSeq=${processed.maxSeq}',
        );
        if (processed.droppedReasons.isNotEmpty) {
          for (final reason in processed.droppedReasons) {
            logger.warning(
              '[fetchMessages] $sessionId dropped: $reason',
            );
          }
        }

        // ── Yield before main-thread merge/group work ──
        await Future<void>.delayed(Duration.zero);

        // ── Upsert messages ──
        // For gap recovery, clear stale in-memory messages right before
        // the first successful upsert so we don't lose messages if the
        // network request fails. We defer clearing until we know the fetch
        // succeeded.
        if (isGapRecovery && page == 0 && processed.messages.isNotEmpty) {
          _sessionMessages.remove(sessionId);
          _sessionMessagesCache = null;
          _sessionMessagesViewCache.remove(sessionId);
          MessageCacheService().clearMessages(sessionId);
          logger.info(
            '[fetchMessages] $sessionId gap recovery: cleared stale messages '
            'before upserting ${processed.messages.length} new ones',
          );
        }
        final existingCount = _sessionMessages[sessionId]?.length ?? 0;
        final upsertStart = Stopwatch()..start();
        if (processed.messages.isNotEmpty) {
          _upsertSessionMessages(sessionId, processed.messages);
        }
        final upsertMs = upsertStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Apply tool results + usage ──
        final toolStart = Stopwatch()..start();
        if (processed.toolResults.isNotEmpty) {
          _applyToolResults(sessionId, processed.toolResults);
        }
        // Apply any pending tool results that arrived before these messages.
        final pending = _pendingToolResults.remove(sessionId);
        if (pending != null && pending.isNotEmpty) {
          _applyToolResults(sessionId, pending);
        }
        for (final u in processed.usageUpdates) {
          _updateSessionUsage(
            u['sessionId'] as String,
            u['usage'] as Map<String, dynamic>,
            u['timestamp'] as int,
          );
        }
        final toolMs = toolStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Group sidechain messages ──
        final groupStart = Stopwatch()..start();
        _groupSidechainMessages(sessionId);
        final groupMs = groupStart.elapsedMilliseconds;

        // ── Yield ──
        await Future<void>.delayed(Duration.zero);

        // ── Apply permission requests ──
        final permStart = Stopwatch()..start();
        _applyPermissionRequests(sessionId);
        final permMs = permStart.elapsedMilliseconds;

        final mergeMs = upsertMs + toolMs + groupMs + permMs;

        if (processed.maxSeq > afterSeq) {
          afterSeq = processed.maxSeq;
        }
        _advanceSeqCursor(sessionId, afterSeq);

        logger.info(
          '[fetchMessages] $sessionId page=$page '
          'decryptMs=$decryptMs '
          'upsert=$upsertMs tool=$toolMs '
          'group=$groupMs perm=$permMs',
        );

        // Notify the UI after each page so the chat screen can
        // display partial results immediately instead of waiting
        // for all pages to complete. This is critical for sessions
        // with many messages where pagination + decryption exceeds
        // the 5s awaitQueue timeout in ChatScreen._doInitialLoad.
        if (processed.messages.isNotEmpty) {
          _notifySessionMessagesChanged(sessionId);
          _notifyDataChanged();
        }

        if (!hasMore) break;
        page++;

        // Safety valve: stop this cycle to let the UI render, then
        // schedule a follow-up fetch so we keep crawling.  Without the
        // re-trigger, messages beyond the cutoff are lost until the
        // next external invalidation — which may never come if all new
        // messages use the inline socket path.
        const maxPages = 5; // 500 messages max per fetch cycle
        if (page >= maxPages) {
          logger.warning(
            '[fetchMessages] $sessionId hit $maxPages page limit '
            '— stopping forward crawl at afterSeq=$afterSeq',
          );
          // Re-trigger so the next cycle continues from the new cursor.
          messagesSync[sessionId]?.invalidate();
          break;
        }

        // ── Yield between pages ──
        await Future<void>.delayed(Duration.zero);
      }
      // Final notification in case some pages had no messages
      // (notification already fired per-page for non-empty pages).
      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
      // Finish the fetch span successfully
      fetchSpan?.setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      fetchSpan?.finish();
    } on DioException catch (e) {
      fetchSpan?.setData('status', 'networkError');
      fetchSpan?.setData('dioExceptionType', e.type.name);
      fetchSpan?.setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      fetchSpan?.finish();
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'fetchMessages: DioException',
        category: 'sync.messages',
        level: SentryLevel.error,
        data: {
          'sessionId': sessionId,
          'type': e.type.name,
          'statusCode': e.response?.statusCode,
          'elapsedMs':
              fetchStopwatch.elapsedMilliseconds,
        },
      ));
      // Network error (e.g., connection lost). The InvalidateSync retry
      // mechanism will handle retries, but we must notify the UI now so
      // it doesn't spin forever while waiting for awaitQueue(). When
      // retries exhaust, the Completer completes with error and the chat
      // screen's timeout will handle it.
      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
      rethrow;
    } catch (error, stack) {
      fetchSpan?.status = SpanStatus.internalError();
      fetchSpan?.setData('error', error.toString());
      fetchSpan?.setData('totalElapsedMs', fetchStopwatch.elapsedMilliseconds);
      fetchSpan?.finish();
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'fetchMessages: unexpected error',
        category: 'sync.messages',
        level: SentryLevel.error,
        data: {
          'sessionId': sessionId,
          'error': error.toString(),
          'elapsedMs':
              fetchStopwatch.elapsedMilliseconds,
        },
      ));
      logger.error(
        'Error fetching messages',
        error,
        stack,
      );
      // Notify listeners so the UI can handle the error state rather than
      // remaining in a stale loading state.
      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
    }
  }

  /// Fetch the page of messages that precedes what has already been loaded
  /// for [sessionId].  Call [hasOlderMessages] first to guard against
  /// unnecessary requests.
  Future<void> fetchOlderMessages(String sessionId) async {
    if (isLoadingOlderMessages(sessionId)) return;
    final firstLoaded = _sessionFirstLoadedSeq[sessionId] ?? 0;
    if (firstLoaded <= 1) return; // nothing older to fetch

    final sessionEncryption = encryption.getSessionEncryption(sessionId);
    if (sessionEncryption == null) return;

    _loadingOlderMessages.add(sessionId);
    _notifyDataChanged();

    try {
      const pageSize = 100;
      final startSeq = (firstLoaded - 1 - pageSize).clamp(0, firstLoaded - 1);

      final Response<dynamic> response;
      if (testFetchOlderMessagesOverride != null) {
        final overrideResult = await testFetchOlderMessagesOverride!(
          sessionId,
          startSeq,
          pageSize,
        );
        response = Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 200,
          data: overrideResult,
        );
      } else {
        final apiClient = ApiClient();
        response = await apiClient.get(
          '/v3/sessions/$sessionId/messages',
          queryParameters: {'after_seq': startSeq, 'limit': pageSize},
        );

        if (!apiClient.isSuccess(response)) {
          logger.warning(
            'Failed to fetch older messages: ${response.statusCode}',
          );
          return;
        }
      }

      final data = response.data as Map<String, dynamic>;
      final messages = (data['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      logger.info(
        '[fetchOlderMessages] $sessionId '
        'msgs=${messages.length}',
      );

      final processed = await sessionEncryption.decryptAndProcessMessages(
        messages,
        sessionId,
      );

      logger.info(
        '[fetchOlderMessages] $sessionId '
        'processedMsgs=${processed.messages.length} '
        'toolResults=${processed.toolResults.length}',
      );
      if (processed.droppedReasons.isNotEmpty) {
        for (final reason in processed.droppedReasons) {
          logger.warning(
            '[fetchOlderMessages] $sessionId dropped: $reason',
          );
        }
      }

      // Yield before main-thread merge work
      await Future<void>.delayed(Duration.zero);

      if (processed.messages.isNotEmpty) {
        _upsertSessionMessages(sessionId, processed.messages);
      }
      if (processed.toolResults.isNotEmpty) {
        _applyToolResults(sessionId, processed.toolResults);
      }
      // Apply any pending tool results that arrived before these messages.
      final pending = _pendingToolResults.remove(sessionId);
      if (pending != null && pending.isNotEmpty) {
        _applyToolResults(sessionId, pending);
      }
      for (final u in processed.usageUpdates) {
        _updateSessionUsage(
          u['sessionId'] as String,
          u['usage'] as Map<String, dynamic>,
          u['timestamp'] as int,
        );
      }
      _groupSidechainMessages(sessionId);
      _applyPermissionRequests(sessionId);

      // Move the lower boundary back to cover the page we just fetched.
      _sessionFirstLoadedSeq[sessionId] = startSeq == 0 ? 0 : startSeq + 1;
      MMKVStorage().saveSessionFirstLoadedSeq(
        Map.unmodifiable(_sessionFirstLoadedSeq),
      );

      _notifySessionMessagesChanged(sessionId);
      _notifyDataChanged();
    } catch (error, stack) {
      logger.error('Error fetching older messages', error, stack);
    } finally {
      _loadingOlderMessages.remove(sessionId);
      _notifyDataChanged();
    }
  }

  /// Whether a session's agent is connected enough to receive messages.
  /// Checks both ephemeral presence and lifecycle metadata.
  /// Guards against stale lifecycleState by requiring a recent timestamp.
  bool _isSessionReady(Session s) {
    // Cross-check presence with a recent ephemeral event — same logic
    // as _resolveSendTargetSession to avoid trusting stale 'online'
    // presence after a daemon restart.
    final lastEphemeral = _lastEphemeralAt[s.id];
    final recentEphemeral =
        lastEphemeral != null &&
        DateTime.now().millisecondsSinceEpoch - lastEphemeral < 90000;
    if (s.isOnline && recentEphemeral) return true;
    final lc = s.metadata?.lifecycleState;
    if (lc != 'running') return false;
    // Only trust "running" if the timestamp is recent (< 2 minutes).
    final since = s.metadata?.lifecycleStateSince;
    if (since == null) return false;
    return DateTime.now().millisecondsSinceEpoch - since < 120000;
  }

  /// Wait for agent to be ready.
  ///
  /// Returns `true` when the session's presence becomes `'online'`
  /// (set by `handleEphemeralUpdate` when the daemon sends
  /// `session-alive` keep-alives — typically within 2 seconds),
  /// or when `lifecycleState` becomes `'running'` (set by the agent
  /// after connecting to Socket.IO — confirms push delivery).
  ///
  /// Note: `agentStateVersion` is intentionally NOT checked here
  /// because it persists across daemon restarts and would cause
  /// stale sessions to appear ready when the daemon is offline.
  Future<bool> waitForAgentReady(
    String sessionId, [
    int timeoutMs = sessionReadyTimeoutMs,
  ]) async {
    // Fast path: already online or lifecycle running
    final session = _sessions[sessionId];
    if (session != null && _isSessionReady(session)) return true;

    logger.info(
      '[sendMessage] waitForAgentReady waiting '
      'session=$sessionId isOnline=${session?.isOnline} '
      'lifecycleState=${session?.metadata?.lifecycleState}',
    );

    // Event-driven: resolve as soon as onDataChanged fires with session
    // ready, or after timeoutMs, whichever comes first.
    final completer = Completer<bool>();
    StreamSubscription<void>? sub;
    Timer? timer;

    timer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!completer.isCompleted) completer.complete(false);
      sub?.cancel();
    });

    sub = onDataChanged.listen((_) {
      final s = _sessions[sessionId];
      if (s != null && _isSessionReady(s) && !completer.isCompleted) {
        completer.complete(true);
        timer?.cancel();
        sub?.cancel();
      }
    });

    final ready = await completer.future;
    logger.info(
      '[sendMessage] waitForAgentReady done '
      'session=$sessionId ready=$ready',
    );
    return ready;
  }

  /// Process a decrypted message into display messages and tool results.
  /// Test helper for [_processDecryptedMessage].
  @visibleForTesting
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  testProcessDecryptedMessage({
    required String id,
    required int seq,
    required String sessionId,
    required Map<String, dynamic> content,
    String? localId,
    int? createdAtMs,
  }) {
    return _processDecryptedMessage(
      DecryptedMessage(
        id: id,
        seq: seq,
        localId: localId,
        content: content,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ),
      sessionId,
    );
  }

  ///
  /// Returns a tuple of (displayMessages, toolResults).
  /// Display messages are added to the session message list.
  /// Tool results are used to update existing tool-call message states.
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processDecryptedMessage(DecryptedMessage message, String sessionId) {
    final createdAt = message.createdAt.millisecondsSinceEpoch;
    final content = message.content;

    if (content is! Map<String, dynamic>) {
      // Fallback for non-map content
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'kind': 'text',
            'content': content?.toString() ?? '',
            'raw': content,
          },
        ],
        [],
      );
    }

    final role = content['role'] as String?;
    final nestedContent = content['content'];

    // User messages: {role: 'user', content: {type: 'text', text: '...'}}
    if (role == MessageRole.user) {
      if (nestedContent is Map<String, dynamic> &&
          nestedContent['type'] == 'text') {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'user',
              'kind': 'text',
              'content': nestedContent['text']?.toString() ?? '',
              'raw': content,
            },
          ],
          [],
        );
      }
      // Fallback for non-text user messages
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'user',
            'kind': 'text',
            'content': content.toString(),
            'raw': content,
          },
        ],
        [],
      );
    }

    // Agent messages: {role: 'agent', content: {type: ..., data: ...}}
    if (role == MessageRole.agent) {
      if (nestedContent is! Map<String, dynamic>) {
        return (
          [
            {
              'id': 'error-${message.id}_parse',
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'system',
              'kind': 'error',
              'errorType': 'agent_content_not_map',
              'errorMessage':
                  'Agent message content is not '
                  'a valid structure',
              'debugData': {
                'messageId': message.id,
                'seq': message.seq,
                'contentType': '${nestedContent.runtimeType}',
              },
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      final contentType = nestedContent['type'] as String?;

      // Output type: Claude/assistant messages
      if (contentType == 'output') {
        return _processOutputContent(
          message,
          nestedContent,
          createdAt,
          content,
          sessionId,
        );
      }

      // Event type: mode switches, limit reached, etc.
      if (contentType == 'event') {
        // When the agent sends session-cleared (after a /clear restart),
        // immediately drop the session's ephemeral presence to offline so
        // that waitForAgentReady blocks until the new Claude process sends
        // its first keep-alive. Without this, a follow-up message is posted
        // while the old Claude is dead and the new one hasn't connected yet.
        final evData = nestedContent['data'];
        if (evData is Map<String, dynamic>) {
          final evType = (evData['t'] ?? evData['type']) as String?;
          if (evType == 'session-cleared') {
            _presenceTimers[sessionId]?.cancel();
            _presenceTimers.remove(sessionId);
            final current = _sessions[sessionId];
            if (current != null) {
              _sessions[sessionId] = current.copyWith(
                presence: 'offline',
                thinking: false,
              );
              _notifyDataChanged();
            }
          }
        }
        return _processEventContent(message, nestedContent, createdAt, content);
      }

      // Codex type: Codex agent messages
      if (contentType == 'codex') {
        return _processCodexContent(
          message,
          nestedContent,
          createdAt,
          content,
          sessionId,
        );
      }

      // ACP type: unified agent communication protocol
      if (contentType == 'acp') {
        return _processAcpContent(message, nestedContent, createdAt, content);
      }

      // Session protocol envelope embedded directly under content.
      if (_looksLikeSessionEnvelope(nestedContent)) {
        return _processSessionContent(
          message,
          nestedContent,
          createdAt,
          content,
        );
      }

      // Session protocol wrapper (agent role).
      if (contentType == 'session') {
        return _processSessionContent(
          message,
          nestedContent,
          createdAt,
          content,
        );
      }

      final fallback = _extractAgentFallbackText(nestedContent);
      if (fallback != null && fallback.isNotEmpty) {
        return (
          [
            {
              'id': message.id,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': createdAt,
              'role': 'agent',
              'kind': 'text',
              'content': fallback,
              'raw': content,
            },
          ],
          <Map<String, dynamic>>[],
        );
      }

      return (
        [
          {
            'id': 'error-${message.id}_parse',
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'system',
            'kind': 'error',
            'errorType': 'unknown_agent_content_type',
            'errorMessage': 'Unrecognized agent content type: $contentType',
            'debugData': {
              'messageId': message.id,
              'seq': message.seq,
              'contentType': contentType,
            },
          },
        ],
        <Map<String, dynamic>>[],
      );
    }

    // Session protocol envelope role.
    if (role == MessageRole.session) {
      return _processSessionContent(
        message,
        nestedContent ?? content,
        createdAt,
        content,
      );
    }

    return (
      [
        {
          'id': 'error-${message.id}_parse',
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'system',
          'kind': 'error',
          'errorType': 'unknown_role',
          'errorMessage': 'Unrecognized message role: $role',
          'debugData': {
            'messageId': message.id,
            'seq': message.seq,
            'role': role,
          },
        },
      ],
      <Map<String, dynamic>>[],
    );
  }

  bool _looksLikeSessionEnvelope(dynamic value) {
    if (value is! Map<String, dynamic>) return false;
    final hasEvent =
        value['ev'] is Map<String, dynamic> ||
        value['event'] is Map<String, dynamic>;
    final hasIdentity =
        value['id'] != null || value['uuid'] != null || value['time'] != null;
    return hasEvent && hasIdentity;
  }

  String? _extractAgentFallbackText(dynamic nestedContent) {
    if (nestedContent is! Map<String, dynamic>) return null;

    final directText = nestedContent['text'] ?? nestedContent['message'];
    if (directText is String && directText.isNotEmpty) {
      return directText;
    }

    final data = nestedContent['data'];
    if (data is Map<String, dynamic>) {
      final dataMessage = data['message'];
      if (dataMessage is String && dataMessage.isNotEmpty) {
        return dataMessage;
      }
      final dataText = data['text'];
      if (dataText is String && dataText.isNotEmpty) {
        return dataText;
      }
    }

    return null;
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processOutputContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
    String sessionId,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    // Skip meta and compact summary messages
    if (data['isMeta'] == true || data['isCompactSummary'] == true) {
      return ([], []);
    }

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final dataUuid = (data['uuid'] ?? data['id']) as String?;
    final dataParentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    final dataType = data['type'] as String?;

    if (dataType == 'assistant') {
      if (dataUuid == null || dataUuid.isEmpty) return ([], []);

      final agentMsg = data['message'];
      if (agentMsg is! Map<String, dynamic>) return ([], []);

      // Extract usage data for context window tracking
      final usageData = agentMsg['usage'] as Map<String, dynamic>?;
      if (usageData != null) {
        _updateSessionUsage(sessionId, usageData, createdAt);
      }

      final agentContentList = agentMsg['content'];
      if (agentContentList is! List) return ([], []);

      final results = <Map<String, dynamic>>[];
      var i = 0;
      for (final c in agentContentList) {
        if (c is! Map<String, dynamic>) {
          i++;
          continue;
        }
        final type = c['type'] as String?;

        if (type == 'text') {
          results.add({
            'id': '${message.id}_t$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': c['text']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        } else if (type == 'thinking') {
          results.add({
            'id': '${message.id}_k$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n*${c['thinking']}*',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        } else if (type == 'tool_use') {
          results.add({
            'id': '${message.id}_u$i',
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': c['name'],
            'input': c['input'],
            'toolUseId': c['id'],
            'state': 'running',
            'content': c,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': dataUuid,
            'parentUuid': ?dataParentUuid,
          });
        }
        i++;
      }
      return (results, []);
    }

    if (dataType == 'user') {
      // Sidechain root: isSidechain=true, message.content is
      // a string or content-block list (the prompt sent to the
      // sub-agent). We emit a hidden marker so
      // _groupSidechainMessages can match it.
      if (isSidechain) {
        final msgContent = data['message']?['content'];
        // Extract the prompt text — bare string or Claude API
        // content-block format [{type: 'text', text: '...'}].
        final promptText = msgContent is String
            ? msgContent
            : (msgContent is List
                ? _extractTextFromContentBlocks(msgContent)
                : null);
        if (promptText != null && promptText.isNotEmpty) {
          return (
            [
              {
                'id': '${message.id}_sc',
                'seq': message.seq,
                'createdAt': createdAt,
                'kind': 'sidechain-root',
                'isSidechain': true,
                'prompt': promptText,
                'uuid': ?dataUuid,
                'parentUuid': ?dataParentUuid,
              },
            ],
            [],
          );
        }
      }

      // Tool results - collect them to update existing tool-call states
      final toolResults = <Map<String, dynamic>>[];
      final msgContent = data['message']?['content'];

      if (msgContent is List) {
        for (final c in msgContent) {
          if (c is Map<String, dynamic> && c['type'] == 'tool_result') {
            toolResults.add({
              'toolUseId': c['tool_use_id'],
              'result': c['content'],
              'isError': c['is_error'] == true,
              'createdAt': createdAt,
              'permissions': c['permissions'],
              if (isSidechain) 'isSidechain': true,
              'uuid': ?dataUuid,
              'parentUuid': ?dataParentUuid,
            });
          }
        }
      }
      return ([], toolResults);
    }

    // Skip system, result, summary messages
    return ([], []);
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processEventContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    // Skip ready and session-cleared events (session-cleared is handled at the
    // call site to reset ephemeral presence; ready is internal bookkeeping).
    if (data['type'] == 'ready' || data['type'] == 'session-cleared') {
      return ([], []);
    }

    return (
      [
        {
          'id': message.id,
          'localId': message.localId,
          'seq': message.seq,
          'createdAt': createdAt,
          'role': 'agent',
          'kind': 'agent-event',
          'event': data,
          'content': '',
          'raw': outerContent,
        },
      ],
      [],
    );
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processCodexContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
    String sessionId,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final usageData =
        _extractUsageMap(data['usage']) ??
        _extractUsageMap(
          data['message'] is Map ? (data['message'] as Map)['usage'] : null,
        );
    if (usageData != null) {
      _updateSessionUsage(sessionId, usageData, createdAt);
    }

    final dataType = data['type'] as String?;

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final uuid =
        (data['uuid'] ?? data['id']) as String?;
    final parentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    if (dataType == 'message' || dataType == 'reasoning') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': data['message']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': data['name'],
            'input': data['input'],
            'toolUseId': data['callId'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call-result') {
      // Support both 'output' and 'content' fields for tool result
      final result = data['output'] ?? data['content'];
      return (
        [],
        [
          {
            'toolUseId': data['callId'],
            'result': result,
            'isError': data['isError'] == true || data['is_error'] == true,
            'createdAt': createdAt,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
      );
    }

    return ([], []);
  }

  Map<String, dynamic>? _extractUsageMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Extract text from Claude API content blocks format.
  ///
  /// Handles `[{type: 'text', text: '...'}, ...]` by concatenating
  /// all text blocks.
  String? _extractTextFromContentBlocks(List<dynamic> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block is Map<String, dynamic> && block['type'] == 'text') {
        final text = block['text'];
        if (text is String && text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write('\n');
          buffer.write(text);
        }
      }
    }
    return buffer.isEmpty ? null : buffer.toString();
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _processAcpContent(
    DecryptedMessage message,
    Map<String, dynamic> nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    final data = nestedContent['data'];
    if (data is! Map<String, dynamic>) return ([], []);

    final dataType = data['type'] as String?;

    // Sidechain metadata for sub-agent grouping
    final isSidechain =
        data['isSidechain'] == true || data['is_sidechain'] == true;
    final uuid =
        (data['uuid'] ?? data['id']) as String?;
    final parentUuid =
        (data['subagent'] ?? data['parentUuid'] ?? data['parent_uuid'])
            as String?;

    if (dataType == 'message' || dataType == 'reasoning') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'content': data['message']?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'thinking') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'text',
            'isThinking': true,
            'content': '*Thinking...*\n\n*${data['text']}*',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-call') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': data['name'],
            'input': data['input'],
            'toolUseId': data['callId'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (dataType == 'tool-result' || dataType == 'tool-call-result') {
      // Support both 'output' and 'content' fields for tool result
      final result = data['output'] ?? data['content'];
      return (
        [],
        [
          {
            'toolUseId': data['callId'],
            'result': result,
            'isError': data['isError'] == true || data['is_error'] == true,
            'createdAt': createdAt,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
      );
    }

    if (dataType == 'file-edit') {
      return (
        [
          {
            'id': message.id,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': createdAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'file-edit',
            'input': {
              'filePath': data['filePath'],
              'description': data['description'],
              'diff': data['diff'],
              'oldContent': data['oldContent'],
              'newContent': data['newContent'],
            },
            'toolUseId': data['id'],
            'state': 'running',
            'content': data,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            'uuid': ?uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    // Skip task lifecycle events (task_started, task_complete, turn_aborted,
    // token_count, permission-request, etc.)
    return ([], []);
  }

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>)
  _processSessionContent(
    DecryptedMessage message,
    dynamic nestedContent,
    int createdAt,
    Map<String, dynamic> outerContent,
  ) {
    Map<String, dynamic>? envelope;
    if (nestedContent is Map<String, dynamic>) {
      if (nestedContent['type'] == 'session' &&
          nestedContent['data'] is Map<String, dynamic>) {
        envelope = nestedContent['data'] as Map<String, dynamic>;
      } else {
        envelope = nestedContent;
      }
    }
    if (envelope == null) return ([], []);

    final event = envelope['ev'] ?? envelope['event'];
    if (event is! Map<String, dynamic>) return ([], []);

    final eventType = (event['t'] ?? event['type']) as String?;
    if (eventType == null) return ([], []);

    final eventRole = envelope['role'] as String?;
    final envelopeId =
        (envelope['id'] ?? envelope['uuid']) as String? ?? message.id;
    final eventCreatedAt = _parseCreatedAtMs(
      envelope['time'] ?? envelope['createdAt'] ?? createdAt,
    );
    final parentUuid =
        (envelope['subagent'] ??
                envelope['parentUuid'] ??
                envelope['parent_uuid'])
            as String?;
    final isSidechain = parentUuid != null && parentUuid.isNotEmpty;
    final uuid = (envelope['id'] ?? envelope['uuid']) as String? ?? message.id;

    if (eventType == 'turn-start' ||
        eventType == 'start' ||
        eventType == 'stop') {
      return ([], []);
    }

    if (eventType == 'turn-end') {
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'agent-event',
            'event': {'type': 'ready'},
            'content': '',
            'raw': outerContent,
          },
        ],
        [],
      );
    }

    if (eventType == 'service') {
      if (eventRole != 'agent') return ([], []);
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'text',
            'content': (event['text'] ?? event['message'])?.toString() ?? '',
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (uuid.isNotEmpty) 'uuid': uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (eventType == 'text') {
      final text = (event['text'] ?? event['message'])?.toString() ?? '';
      if (eventRole == MessageRole.agent) {
        final thinking = event['thinking'] == true;
        return (
          [
            {
              'id': envelopeId,
              'localId': message.localId,
              'seq': message.seq,
              'createdAt': eventCreatedAt,
              'role': 'agent',
              'kind': 'text',
              if (thinking) 'isThinking': true,
              'content': thinking ? '*Thinking...*\n\n*$text*' : text,
              'raw': outerContent,
              if (isSidechain) 'isSidechain': true,
              if (uuid.isNotEmpty) 'uuid': uuid,
              'parentUuid': ?parentUuid,
            },
          ],
          [],
        );
      }

      if (eventRole == MessageRole.user) {
        if (isSidechain && text.isNotEmpty) {
          return (
            [
              {
                'id': '${envelopeId}_sc',
                'seq': message.seq,
                'createdAt': eventCreatedAt,
                'kind': 'sidechain-root',
                'isSidechain': true,
                'prompt': text,
                if (uuid.isNotEmpty) 'uuid': uuid,
                'parentUuid': parentUuid,
              },
            ],
            [],
          );
        }

        if (text.isNotEmpty) {
          return (
            [
              {
                'id': envelopeId,
                'localId': message.localId,
                'seq': message.seq,
                'createdAt': eventCreatedAt,
                'role': 'user',
                'kind': 'text',
                'content': text,
                'raw': outerContent,
              },
            ],
            [],
          );
        }
      }

      return ([], []);
    }

    if (eventType == 'tool-call-start') {
      if (eventRole != 'agent') return ([], []);
      final args = event['args'] ?? event['input'];
      final input = args is Map<String, dynamic> ? args : <String, dynamic>{};
      final callId =
          (event['call'] ?? event['callId'] ?? event['toolUseId']) as String?;
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': (event['name'] ?? event['tool'])?.toString() ?? 'unknown',
            'input': input,
            'toolUseId': callId ?? envelopeId,
            'state': 'running',
            'content': event,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (uuid.isNotEmpty) 'uuid': uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    if (eventType == 'tool-call-end') {
      final callId =
          (event['call'] ?? event['callId'] ?? event['toolUseId']) as String?;
      if (callId == null || callId.isEmpty) return ([], []);
      return (
        [],
        [
          {
            'toolUseId': callId,
            'result': event['result'] ?? event['output'] ?? event['content'],
            'isError': event['isError'] == true || event['is_error'] == true,
            'createdAt': eventCreatedAt,
            if (isSidechain) 'isSidechain': true,
            if (uuid.isNotEmpty) 'uuid': uuid,
            'parentUuid': ?parentUuid,
          },
        ],
      );
    }

    if (eventType == 'file') {
      if (eventRole != 'agent') return ([], []);
      final image = event['image'];
      final imageMeta = image is Map<String, dynamic>
          ? {
              'width': image['width'],
              'height': image['height'],
              'thumbhash': image['thumbhash'],
            }
          : null;
      return (
        [
          {
            'id': envelopeId,
            'localId': message.localId,
            'seq': message.seq,
            'createdAt': eventCreatedAt,
            'role': 'agent',
            'kind': 'tool-call',
            'name': 'file',
            'input': {
              'ref': event['ref'],
              'name': event['name'],
              'size': event['size'],
              'image': ?imageMeta,
            },
            'toolUseId': envelopeId,
            'state': 'completed',
            'content': event,
            'raw': outerContent,
            if (isSidechain) 'isSidechain': true,
            if (uuid.isNotEmpty) 'uuid': uuid,
            'parentUuid': ?parentUuid,
          },
        ],
        [],
      );
    }

    return ([], []);
  }

  /// Group sidechain messages as children of their parent Task
  /// tool-call messages and remove them from the main message list.
  ///
  /// [changedIds] — when provided (inline streaming path), contains
  /// the IDs of messages that were just upserted.  If none of them
  /// Schedule a debounced full re-grouping sweep for [sessionId].
  ///
  /// Called after each inline sidechain message is processed.
  /// Coalesces rapid arrivals (e.g. 10 sidechain messages in 200 ms)
  /// into a single sweep that runs without [changedIds], forcing
  /// the grouping logic to iterate all messages and catch any that
  /// were orphaned because their parent hadn't been upserted yet.
  void _scheduleSidechainRegroup(String sessionId) {
    _sidechainRegroupTimers[sessionId]?.cancel();
    _sidechainRegroupTimers[sessionId] = Timer(
      const Duration(milliseconds: 300),
      () {
        _sidechainRegroupTimers.remove(sessionId);
        final messages = _sessionMessages[sessionId];
        if (messages == null || messages.isEmpty) return;

        // Only run if there are still ungrouped sidechain messages
        // sitting in the main list (a normal message list has no
        // isSidechain entries after successful grouping).
        final hasOrphans = messages.any(
          (m) => m['isSidechain'] == true,
        );
        if (!hasOrphans) return;

        logger.info(
          '[sidechain] running deferred re-group sweep '
          'for session=$sessionId',
        );
        _groupSidechainMessages(sessionId);
        _notifySessionMessagesChanged(sessionId);
        _notifyDataChanged();
      },
    );
  }

  /// Delegates to [SidechainGrouper] and updates session message
  /// state when grouping modifies the list.
  void _groupSidechainMessages(
    String sessionId, {
    Set<String>? changedIds,
  }) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return;

    final result = _sidechainGrouper.groupMessages(
      messages,
      changedIds: changedIds,
    );

    if (result == null) return;

    if (result.hasOrphans &&
        !identical(result.messages, messages)) {
      _scheduleSidechainRegroup(sessionId);
    } else if (result.hasOrphans) {
      _scheduleSidechainRegroup(sessionId);
      return;
    }

    if (!identical(result.messages, messages)) {
      _sessionMessages[sessionId] = result.messages;
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
    }
  }

  /// Apply tool results to existing tool-call messages in a session.
  void _applyToolResults(
    String sessionId,
    List<Map<String, dynamic>> toolResults,
  ) {
    if (toolResults.isEmpty) return;

    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    if (existing.isEmpty) {
      // Queue tool results that arrived before their tool-call message.
      // They will be applied when the tool-call message arrives.
      _pendingToolResults
          .putIfAbsent(sessionId, () => [])
          .addAll(toolResults);
      return;
    }

    final (updated, changed) =
        _toolResultProcessor.applyToolResults(
      existing,
      toolResults,
    );

    if (changed) {
      _sessionMessages[sessionId] = updated;
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
    }
  }

  /// Enrich tool-call messages with permission data from
  /// [AgentState]. Delegates to [ToolResultProcessor].
  void _applyPermissionRequests(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;

    final agentState = session.agentState;
    if (agentState == null) return;

    final existing = _sessionMessages[sessionId];
    if (existing == null || existing.isEmpty) return;

    final result =
        _toolResultProcessor.applyPermissionRequests(
      existing,
      agentState,
      _notifiedPermissionIds,
    );

    // Cancel notifications for resolved permissions.
    for (final permId in result.resolvedPermIds) {
      _notifiedPermissionIds.remove(permId);
      unawaited(
        NotificationService.instance
            .cancelPermissionNotification(permId),
      );
    }

    if (result.changed) {
      _sessionMessages[sessionId] = result.messages;
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
    }
  }

  void _updateSessionUsage(
    String sessionId,
    Map<String, dynamic> usage,
    int timestamp,
  ) {
    final existing = _sessionUsage[sessionId];
    final existingTs = existing?['timestamp'] as int? ?? 0;
    if (timestamp > existingTs) {
      final inputTokens = usage['input_tokens'] as int? ?? 0;
      final cacheCreation = usage['cache_creation_input_tokens'] as int? ?? 0;
      final cacheRead = usage['cache_read_input_tokens'] as int? ?? 0;
      final outputTokens = usage['output_tokens'] as int? ?? 0;
      _sessionUsage[sessionId] = {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'cacheCreation': cacheCreation,
        'cacheRead': cacheRead,
        'contextSize': cacheCreation + cacheRead + inputTokens,
        'timestamp': timestamp,
      };
    }
  }

  bool _isMessageListOrdered(List<Map<String, dynamic>> messages) {
    for (var i = 1; i < messages.length; i++) {
      final prevCreated = _asInt(messages[i - 1]['createdAt']) ?? 0;
      final currCreated = _asInt(messages[i]['createdAt']) ?? 0;
      if (prevCreated > currCreated) {
        return false;
      }
      if (prevCreated == currCreated) {
        final prevSeq = messages[i - 1]['seq'] as int? ?? 0;
        final currSeq = messages[i]['seq'] as int? ?? 0;
        if (prevSeq > currSeq) {
          return false;
        }
      }
    }
    return true;
  }

  bool _canAppendMessagesFastPath(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    if (existing.isEmpty || incoming.isEmpty) return false;
    if (!_isMessageListOrdered(incoming)) return false;

    final lastMessage = existing.last;
    final lastCreatedAt = _asInt(lastMessage['createdAt']) ?? 0;
    final lastSeq = lastMessage['seq'] as int? ?? 0;

    // Build a small set of IDs from the tail of the existing list
    // (last 20 entries). This catches the common case of an update
    // to a recently-appended message without scanning the full list.
    // For true id collisions deeper in the list, the full merge path
    // handles them correctly (at O(n) cost, but those are rare).
    final tailStart =
        existing.length > 20 ? existing.length - 20 : 0;
    final recentIds = <String>{};
    for (var i = tailStart; i < existing.length; i++) {
      final id = existing[i]['id'] as String?;
      if (id != null && id.isNotEmpty) recentIds.add(id);
    }

    for (final message in incoming) {
      final messageId = message['id'] as String?;
      if (messageId == null || messageId.isEmpty) {
        return false;
      }

      // If this id already exists in the recent tail, it's an update
      // not an append — fall through to merge.
      if (recentIds.contains(messageId)) {
        return false;
      }

      // Messages with localId may collide with optimistic entries —
      // fall through to the full merge path.
      final localId = message['localId'] as String?;
      if (localId != null && localId.isNotEmpty) {
        return false;
      }

      final createdAt = _asInt(message['createdAt']) ?? 0;
      final seq = message['seq'] as int? ?? 0;
      if (createdAt < lastCreatedAt) {
        return false;
      }
      if (createdAt == lastCreatedAt && seq <= lastSeq) {
        return false;
      }
    }

    return true;
  }

  /// @visibleForTesting
  void testUpsertSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    _upsertSessionMessages(sessionId, messages);
  }

  void _upsertSessionMessages(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) {
    final existing = _sessionMessages[sessionId] ?? <Map<String, dynamic>>[];
    const maxMessages = 3000;

    if (_canAppendMessagesFastPath(existing, messages)) {
      final appended = <Map<String, dynamic>>[...existing, ...messages];
      _sessionMessages[sessionId] = appended.length > maxMessages
          ? appended.sublist(appended.length - maxMessages)
          : appended;
      if (sessionId == _visibleSessionId) {
        final afterCount = _sessionMessages[sessionId]?.length ?? 0;
        logger.info(
          '[messages] upsert session=$sessionId '
          'incoming=${messages.length} '
          'before=${existing.length} '
          'after=$afterCount '
          'mode=append',
        );
      }
      _sessionMessagesCache = null;
      _sessionMessagesViewCache.remove(sessionId);
      return;
    }

    final merged = <String, Map<String, dynamic>>{
      for (final message in existing)
        if (message['id'] != null) message['id'] as String: message,
    };
    // Build a reverse index from localId → assigned id, so incoming server
    // messages replace the matching optimistic placeholder.
    // Build a reverse index from localId → assigned id, so incoming server
    // messages replace the matching optimistic placeholder.
    // IMPORTANT: skip empty-string localIds — the Go server sends
    // derefStr(nil) = "" for agent messages, and matching on "" would cause
    // every new agent message to evict a previous one from the list.
    final localIdToId = <String, String>{};
    for (final message in merged.values) {
      final localId = message['localId'] as String?;
      if (localId != null && localId.isNotEmpty && localId != message['id']) {
        localIdToId[localId] = message['id'] as String;
      }
    }
    for (final message in messages) {
      final messageId = message['id'] as String?;
      if (messageId == null || messageId.isEmpty) {
        // Defensive: skip messages without valid ids to prevent crashes.
        // The fast path already filters these at line 7070-7072.
        continue;
      }
      final localId = message['localId'] as String?;
      final hasLocalId = localId != null && localId.isNotEmpty;
      // If this is an incoming server message whose localId matches an
      // optimistic placeholder, remove the placeholder first.
      // Sidechain messages (sub-agent tool calls, sidechain-root
      // prompts) share localId with their parent Task/Agent tool-call
      // but must NOT remove the parent — they are separate messages.
      final isSidechainMsg =
          message['isSidechain'] == true ||
          message['kind'] == 'sidechain-root';
      if (hasLocalId && localId != messageId && !isSidechainMsg) {
        merged.remove(localId);
      }
      // Also remove any existing entry that was the optimistic placeholder
      // for this localId (handles the reverse lookup case).
      // Guard: sidechain messages share localId with their parent
      // assistant message's tool-call cards. Without this guard each
      // arriving sidechain message would evict the last Task tool-call
      // from the list via localIdToId, progressively removing agents
      // until only the first one remains.
      if (hasLocalId && !isSidechainMsg) {
        final existingId = localIdToId[localId];
        if (existingId != null && existingId != messageId) {
          merged.remove(existingId);
        }
      }
      merged[messageId] = message;
    }

    final sorted = merged.values.toList();

    // Optimize: skip sort if already sorted (common case when
    // appending new messages).
    var needsSort = false;
    for (var i = 1; i < sorted.length; i++) {
      final prevCreated = _asInt(sorted[i - 1]['createdAt']) ?? 0;
      final currCreated = _asInt(sorted[i]['createdAt']) ?? 0;
      if (prevCreated > currCreated) {
        needsSort = true;
        break;
      }
      // Also check seq if createdAt is equal.
      if (prevCreated == currCreated) {
        final prevSeq = sorted[i - 1]['seq'] as int? ?? 0;
        final currSeq = sorted[i]['seq'] as int? ?? 0;
        if (prevSeq > currSeq) {
          needsSort = true;
          break;
        }
      }
    }

    if (needsSort) {
      sorted.sort((a, b) {
        final aCreated = _asInt(a['createdAt']) ?? 0;
        final bCreated = _asInt(b['createdAt']) ?? 0;
        if (aCreated != bCreated) {
          return aCreated.compareTo(bCreated);
        }
        return (a['seq'] as int? ?? 0).compareTo(b['seq'] as int? ?? 0);
      });
    }

    _sessionMessages[sessionId] = sorted.length > maxMessages
        ? sorted.sublist(sorted.length - maxMessages)
        : sorted;
    if (sessionId == _visibleSessionId && messages.isNotEmpty) {
      final afterCount = _sessionMessages[sessionId]?.length ?? 0;
      logger.info(
        '[messages] upsert session=$sessionId '
        'incoming=${messages.length} '
        'before=${existing.length} '
        'after=$afterCount '
        'mode=merge',
      );
    }
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.remove(sessionId);
  }

  /// Suspend the sync engine when the app goes to the background.
  ///
  /// Disconnects the socket so the OS does not keep reporting connection
  /// errors while the app is backgrounded (which previously caused a
  /// reconnect loop that saturated the main thread on resume). Pending
  /// debounce writes are flushed to MMKV so no cursor data is lost.
  ///
  /// ALL timers are cancelled to ensure zero network traffic and battery
  /// drain while the app is backgrounded.
  void suspend() {
    if (!isInitialized) return;
    logger.info('[Sync] suspending — disconnecting socket');

    // Cancel deferred resume invalidation — if the app is backgrounding
    // before the 1.5s timer fired, no HTTP requests should be started.
    _deferredResumeInvalidationTimer?.cancel();
    _deferredResumeInvalidationTimer = null;

    // Set backgrounded flag FIRST — this prevents any in-flight
    // InvalidateSync operations from performing network I/O while
    // backgrounded.  Checked in InvalidateSync._run() before the
    // await _action() call.
    InvalidateSync.isBackgrounded = true;

    // Cancel all InvalidateSync retry/cooldown timers.  This stops any
    // exponential-backoff network retries that would otherwise fire while
    // backgrounded (e.g. a settings fetch retry scheduled 1-5s out).
    sessionsSync.dispose();
    settingsSync.dispose();
    profileSync.dispose();
    purchasesSync.dispose();
    machinesSync.dispose();
    pushTokenSync.dispose();
    nativeUpdateSync.dispose();
    artifactsSync.dispose();
    friendsSync.dispose();
    friendRequestsSync.dispose();
    feedSync.dispose();
    todosSync.dispose();
    sessionGitStatusSync.dispose();
    for (final sync in messagesSync.values) {
      sync.dispose();
    }

    _dataChangeDebounceTimer?.cancel();
    for (final timer in _sessionMessageDebounceTimers.values) {
      timer.cancel();
    }
    _sessionMessageDebounceTimers.clear();
    for (final timer in _sidechainRegroupTimers.values) {
      timer.cancel();
    }
    _sidechainRegroupTimers.clear();
    _inlineProcessor.clear();
    _sessionsRefreshDebounceTimer?.cancel();
    _saveSeqDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer?.cancel();
    for (final timer in _postSendCatchUpTimers.values) {
      timer.cancel();
    }
    _postSendCatchUpTimers.clear();
    _sessionsNeedingTailRefresh.clear();
    _sessionsWithPendingUpdates.clear();
    // DON'T clear _sessionsWithPendingSocketMessages — preserve it so resume()
    // can invalidate those sessions and fetch any messages that arrived while
    // backgrounded. Clearing this set causes message loss for non-visible sessions.
    // _sessionsWithPendingSocketMessages.clear();
    _sessionUnreadCounts.clear();

    // Cancel deferred syncs timer (non-critical data syncs)
    _deferredSyncsTimer?.cancel();
    _deferredSyncsTimer = null;

    // Cancel all presence timers (per-session 60s timers)
    for (final timer in _presenceTimers.values) {
      timer.cancel();
    }
    _presenceTimers.clear();

    // Cancel all message save debounce timers
    for (final timer in _saveMsgsDebounceTimers.values) {
      timer.cancel();
    }
    _saveMsgsDebounceTimers.clear();

    // Suspend message outbox to stop retry timers
    messageOutbox.suspend();
    NetworkMonitorService().suspend();

    // Flush pending message saves so the MMKV cache is up-to-date when the
    // OS kills the app while backgrounded.  Without this, an in-flight
    // deferred sidechain regroup can reset the save timer, and the cache
    // retains stale messages with isSidechain == true that become invisible
    // on the next cold start.
    _flushPendingMessageSaves();
    MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
    _persistSessionsCache();
    socketIoClient.disconnect();
  }

  /// Resume the sync engine when the app returns to the foreground.
  ///
  /// Reconnects the socket and invalidates all syncs so any server-side
  /// changes that happened while the app was backgrounded are fetched.
  void resume() {
    if (!isInitialized) return;

    // Debounce: if the app is fluttering between paused/resumed states (e.g.
    // rapid screen lock/unlock), skip redundant resume calls.  Each resume
    // reconnects the socket and kicks off a full sync invalidation — we don't
    // want to do that more than once per _resumeDebounceWindowMs.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastResumeAtMs != null &&
        nowMs - _lastResumeAtMs! < _resumeDebounceWindowMs) {
      logger.debug(
        '[Sync] resume debounced — last resume ${nowMs - _lastResumeAtMs!}ms ago',
      );
      // Still clear the backgrounded flag so any pending operations can run.
      InvalidateSync.isBackgrounded = false;
      return;
    }
    _lastResumeAtMs = nowMs;

    // Clear backgrounded flag BEFORE reconnecting so that any InvalidateSync
    // operations kicked off by the invalidations below are allowed to run.
    // The isBackgrounded check is in InvalidateSync._run() before await _action().
    InvalidateSync.isBackgrounded = false;

    logger.info('[Sync] resuming — reconnecting socket');
    socketIoClient.reconnect();

    // Resume lightweight services immediately.
    messageOutbox.resume();
    NetworkMonitorService().resume();

    // Defer network-heavy invalidations so that rapid foreground/background
    // cycling (e.g. Android 16 aggressive background management) does not
    // fire HTTP requests that get aborted when the app backgrounds again
    // within ~1 second.  suspend() cancels this timer.
    _deferredResumeInvalidationTimer?.cancel();
    _deferredResumeInvalidationTimer = Timer(
      const Duration(milliseconds: 1500),
      () {
        _deferredResumeInvalidationTimer = null;
        if (!isInitialized || InvalidateSync.isBackgrounded) {
          return;
        }

        // Force a full session fetch (not delta) on resume so that
        // session.lastSeq is always up-to-date. Delta fetches may miss
        // sessions where only messages changed (no metadata update),
        // causing fetchMessages() to skip with "already caught up"
        // because both cursorSeq and serverLastSeq are stale.
        _invalidateAllSyncs(
          force: true,
          resetSessionDeltaCursor: true,
        );

        // Invalidate sessions that had pending socket messages
        // before suspend.
        if (_sessionsWithPendingSocketMessages.isNotEmpty) {
          final pendingSessionIds =
              _sessionsWithPendingSocketMessages.toList();
          for (final sessionId in pendingSessionIds) {
            _sessionsNeedingTailRefresh.add(sessionId);
          }
          logger.info(
            '[Sync] resuming — invalidating '
            '${pendingSessionIds.length} sessions with '
            'pending socket messages',
          );
          for (final sessionId in pendingSessionIds) {
            if (!messagesSync.containsKey(sessionId)) {
              messagesSync[sessionId] = InvalidateSync(
                () => fetchMessages(sessionId),
                minInterval: _messagesSyncMinInterval,
                name: 'fetchMessages:$sessionId',
              );
            }
            unawaited(
              sessionsSync.invalidateAndAwait().then((_) {
                messagesSync[sessionId]?.invalidate();
              }),
            );
          }
          _sessionsWithPendingSocketMessages.clear();
        }

        // Always invalidate the visible session.
        if (_visibleSessionId != null) {
          unawaited(
            sessionsSync.invalidateAndAwait().then((_) {
              if (_visibleSessionId != null) {
                messagesSync[_visibleSessionId]
                    ?.invalidate();
              }
            }),
          );
        }
      },
    );
  }

  /// Shutdown sync engine and clear volatile state.
  Future<void> shutdown() async {
    _sessionsRefreshDebounceTimer?.cancel();
    _saveSessionsCacheDebounceTimer?.cancel();
    for (final timer in _postSendCatchUpTimers.values) {
      timer.cancel();
    }
    _postSendCatchUpTimers.clear();
    _sessionsNeedingTailRefresh.clear();
    _sessionsWithPendingUpdates.clear();
    _sessionsWithPendingSocketMessages.clear();
    _notifiedPermissionIds.clear();
    _pendingUpdateSessionIds.clear();
    _pendingToolResults.clear();
    _sessionUnreadCounts.clear();

    socketIoClient
      ..offMessage('update')
      ..offMessage('ephemeral')
      ..disconnect();

    _dataChangeDebounceTimer?.cancel();
    _dataChangeDebounceTimer = null;
    for (final timer in _sessionMessageDebounceTimers.values) {
      timer.cancel();
    }
    _sessionMessageDebounceTimers.clear();
    for (final timer in _sidechainRegroupTimers.values) {
      timer.cancel();
    }
    _sidechainRegroupTimers.clear();
    _inlineProcessor.clear();
    // Flush any pending seq write before shutdown so cursors aren't lost.
    _saveSeqDebounceTimer?.cancel();
    _saveSeqDebounceTimer = null;
    MMKVStorage().saveSessionLastSeq(Map.unmodifiable(_sessionLastSeq));
    _persistSessionsCache();

    // Do NOT close these broadcast controllers — the Sync singleton is reused
    // after logout+login, and closing a final StreamController is permanent.
    // Listeners (screens that subscribe to onDataChanged) would never receive
    // events again, silently breaking all real-time updates.

    for (final sync in messagesSync.values) {
      sync.dispose();
    }
    messagesSync.clear();
    _sessionLastSeq.clear();
    MMKVStorage().clearSessionLastSeq();
    _sessionFirstLoadedSeq.clear();
    MMKVStorage().clearSessionFirstLoadedSeq();
    _loadingOlderMessages.clear();
    _recentInlineMessageKeys.clear();
    _sessionsWithPendingSocketMessages.clear();
    _notifiedPermissionIds.clear();

    sessionsSync.dispose();
    settingsSync.dispose();
    profileSync.dispose();
    purchasesSync.dispose();
    machinesSync.dispose();
    pushTokenSync.dispose();
    nativeUpdateSync.dispose();
    artifactsSync.dispose();
    friendsSync.dispose();
    friendRequestsSync.dispose();
    feedSync.dispose();
    todosSync.dispose();
    sessionGitStatusSync.dispose();

    for (final timer in _presenceTimers.values) {
      timer.cancel();
    }
    _presenceTimers.clear();

    _sessionDataKeys.clear();
    _sessionEncryptedDataKeys.clear();
    _machineDataKeys.clear();
    _artifactDataKeys.clear();
    _todoLists.clear();
    _friends.clear();
    _friendRequests.clear();
    _feedItems.clear();
    _artifacts.clear();
    for (final timer in _saveMsgsDebounceTimers.values) {
      timer.cancel();
    }
    _saveMsgsDebounceTimers.clear();
    _sessionMessages.clear();
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.clear();
    _optimisticallyArchivedSessions.clear();
    _sessions.clear();
    _lastSessionsFetchedAt = null;
    MMKVStorage().clearSessionsCache();
    _machines.clear();
    _sessionGitStatus.clear();
    _sessionSpawnedAt.clear();
    _autoRestoreInFlight.clear();
    _lastEphemeralAt.clear();
    _pendingNewSessionIds.clear();
    _sessionUsage.clear();
    _profile = null;
    _settingsSnapshot = Settings();
    _settingsVersion = 0;
    _purchases = Purchases.defaults;
    pendingSettings.clear();
    _registeredPushToken = null;
    _nativeUpdateUrl = null;
    _isReady = false;
    _connectionStatus = ConnectionStatus.disconnected;
    isInitialized = false;
    // Dispose the outbox so retry timers don't fire after logout.
    messageOutbox.dispose();
  }
}

// Global singleton instance
final sync = Sync();

/// Initialize sync engine
Future<void> syncCreate(AuthCredentials credentials) async {
  if (sync.isInitialized) {
    logger.info('Sync already initialized');
    return;
  }

  final secretKey = Base64Utils.decode(credentials.secret, Encoding.base64url);
  if (secretKey.length != 32) {
    throw StateError(
      'Invalid secret key length: ${secretKey.length}, expected 32',
    );
  }

  final encryption = await Encryption.create(secretKey);
  await sync.create(credentials, encryption);
}

/// Restore sync engine from disk
Future<void> syncRestore(AuthCredentials credentials) async {
  if (sync.isInitialized) {
    logger.info('Sync already initialized');
    return;
  }

  final secretKey = Base64Utils.decode(credentials.secret, Encoding.base64url);
  if (secretKey.length != 32) {
    throw StateError(
      'Invalid secret key length: ${secretKey.length}, expected 32',
    );
  }

  final encryption = await Encryption.create(secretKey);
  await sync.restore(credentials, encryption);
}

/// Shutdown sync engine and clear in-memory state.
Future<void> syncShutdown() async {
  if (!sync.isInitialized) {
    return;
  }
  await sync.shutdown();
}
