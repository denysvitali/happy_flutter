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
import '../services/mmkv_storage.dart';
import '../services/network_monitor_service.dart';
import '../services/server_config.dart';
import '../utils/invalidate_sync.dart';
import '../utils/parse_token.dart';
import '../utils/wire_parsers.dart';
import 'inline_message_processor.dart';
import 'logger_service.dart';
import 'message_cursor_manager.dart';
import 'notification_service.dart';
import 'sidechain_grouper.dart';
import 'tool_result_processor.dart';

part '_sync_socket.dart';
part '_sync_sessions.dart';
part '_sync_data.dart';
part '_sync_operations.dart';
part '_sync_messaging.dart';

// ── Isolate helpers: machine payload decryption ───────────────────────

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

// ── Isolate helpers: artifact payload decryption ──────────────────────

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
  static const int _maxRecentInlineKeys = 2000;

  /// Tracks inline message keys that are currently being processed.
  /// Used to allow retry on processing failure: if a message fails
  /// decryption/processing, its key is left in this set so the next
  /// retry can re-enter the inline path instead of being silently
  /// dropped as "already seen" (which would happen if we moved the
  /// key to _recentInlineMessageKeys before processing).
  ///
  /// On success: key is removed from here and added to
  /// _recentInlineMessageKeys.  On failure: key stays here so a
  /// subsequent retry (via HTTP fallback) can re-process it.
  final Set<String> _pendingInlineMessageKeys = {};

  /// Per-session timestamp of the last no-embed new-message event,
  /// used to collapse rapid-fire duplicate socket broadcasts.
  final Map<String, int> _lastNoEmbedEventMs = {};

  /// Per-session serial queue for inline message processing.
  final InlineMessageProcessor _inlineProcessor =
      InlineMessageProcessor();

  /// Timer for deferred sidechain re-grouping.  After each inline
  /// sidechain message is processed, we schedule a short delayed
  /// sweep to catch any messages that were orphaned due to transient
  /// chain gaps (e.g. a message arrived before its parent was
  /// processed on a previous run).
  final Map<String, Timer> _sidechainRegroupTimers = {};
  /// Epoch-ms when the first regroup was requested for a session during
  /// the current burst. Used to enforce a maximum delay — without this,
  /// rapid streaming keeps cancelling the debounce timer and the sweep
  /// never fires while an agent is active.
  final Map<String, int> _sidechainRegroupFirstRequestMs = {};
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
  int? _suspendedAtMs;
  /// Timestamp of last resume() call for debouncing rapid pause/resume cycles.
  int? _lastResumeAtMs;
  /// Minimum interval between resume() calls — prevents socket reconnect
  /// loops
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

  /// Epoch-ms of last unread count increment per session. Used to
  /// rate-limit increments during rapid agent streaming — without this,
  /// sidechain/meta messages inflate the badge count 10-50x.
  final Map<String, int> _sessionUnreadLastIncrementMs = <String, int>{};

  /// Minimum interval between unread count increments for the same
  /// session (milliseconds). During rapid agent streaming, socket
  /// events fire every ~50ms but only a fraction represent messages
  /// the user would see in the main chat.
  static const int _unreadIncrementMinIntervalMs = 1000;

  /// Maximum unread count per session. Prevents runaway counters for
  /// sessions with heavy agent activity.
  static const int _maxUnreadCount = 99;

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
  /// Maps sessionId → list of pending tool results. Applied when the
  /// tool-call
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
  Map<String, Machine> get testMachines => _machines;

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
  /// When set, [fetchMessages] calls this instead of making a real HTTP
  /// request.
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
      // Skip sidechain messages — they appear inside the agent
      // conversation screen, not in the main chat.
      if (msg['isSidechain'] == true) continue;
      final role = msg['role'] as String?;
      if (role != MessageRole.agent && role != MessageRole.user) continue;
      final kind = msg['kind'] as String?;
      // Skip tool-call and agent-event messages — they don't have
      // meaningful preview text.
      if (kind == 'tool-call' || kind == 'agent-event') continue;
      // Skip thinking blocks — they are collapsed in the UI and
      // don't represent the final assistant response.
      if (msg['isThinking'] == true) continue;
      final text =
          (msg['content'] ?? msg['text']) as String?;
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
      if (msg['isSidechain'] == true) continue;
      final role = msg['role'] as String?;
      if (role != MessageRole.agent && role != MessageRole.user) continue;
      final kind = msg['kind'] as String?;
      if (kind == 'tool-call' || kind == 'agent-event') continue;
      if (msg['isThinking'] == true) continue;
      final text =
          (msg['content'] ?? msg['text']) as String?;
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

  /// Invalidate all sync managers
  static const int _invalidateAllSyncsCooldownMs = 5000;

  /// Phases for selective sync invalidation to prevent thundering herd
  static const _criticalSyncPhase = 0;
  static const _deferredSyncPhase = 1;
  Timer? _deferredSyncsTimer;

  bool _dataChangePendingTrailing = false;

  /// Cached per-session JSON + object reference from the last persist.
  /// On each persist, only sessions whose object reference differs from
  /// the cached one are re-serialized via `toJson()`.
  final Map<String, (Session, Map<String, dynamic>)>
      _sessionJsonCache = {};

  static const Duration _sessionsRefreshDebounce = Duration(milliseconds: 250);

  /// Minimum interval between consecutive message fetches for a session.
  /// Prevents rapid-fire HTTP refetches when many socket events arrive
  /// in quick succession (e.g. during streaming).
  static const Duration _messagesSyncMinInterval = Duration(milliseconds: 500);

  static const Duration _machinesRefreshDebounce =
      Duration(milliseconds: 250);

  Timer? _machinesRefreshDebounceTimer;
  final Set<String> _pendingUpdateMachineIds = {};

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
    _suspendedAtMs = DateTime.now().millisecondsSinceEpoch;

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
    _sidechainRegroupFirstRequestMs.clear();
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
    // DON'T clear _sessionsWithPendingSocketMessages — preserve it so
    // resume()
    // can invalidate those sessions and fetch any messages that arrived while
    // backgrounded. Clearing this set causes message loss for non-visible
    // sessions.
    // _sessionsWithPendingSocketMessages.clear();
    _sessionUnreadCounts.clear();
    _sessionUnreadLastIncrementMs.clear();

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
        '[Sync] resume debounced — '
        'last resume ${nowMs - _lastResumeAtMs!}ms ago',
      );
      // Still clear the backgrounded flag so any pending operations can run.
      InvalidateSync.isBackgrounded = false;
      return;
    }
    _lastResumeAtMs = nowMs;

    // Clear backgrounded flag BEFORE reconnecting so that any InvalidateSync
    // operations kicked off by the invalidations below are allowed to run.
    // The isBackgrounded check is in InvalidateSync._run() before
    // await _action().
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

        // Only force a full session fetch when the app was suspended
        // long enough for delta results to be unreliable (>5 min).
        // Short suspends (screen-off, quick app-switch) keep the delta
        // cursor so we avoid re-fetching all sessions.
        final suspendDuration = _suspendedAtMs != null
            ? DateTime.now().millisecondsSinceEpoch - _suspendedAtMs!
            : 0;
        final needsFullFetch = suspendDuration > 5 * 60 * 1000;
        _invalidateAllSyncs(
          force: true,
          resetSessionDeltaCursor: needsFullFetch,
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
    _sessionUnreadLastIncrementMs.clear();

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
    _sidechainRegroupFirstRequestMs.clear();
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
    _recentInlineMessageKeyOrder.clear();
    _pendingInlineMessageKeys.clear();
    _lastNoEmbedEventMs.clear();
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
