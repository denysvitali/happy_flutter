import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../api/api_client.dart';
import '../api/push_api.dart';
import '../api/sessions_api.dart';
import '../api/socket_io_client.dart';
import '../encryption/aes_gcm.dart';
import '../encryption/artifact_encryption.dart';
import '../encryption/base64.dart';
import '../encryption/crypto_secret_box.dart';
import '../encryption/encryption_cache.dart';
import '../encryption/encryption_manager.dart';
import '../encryption/encryptor.dart';
import '../encryption/session_encryption.dart';
import '../models/api_update.dart';
import '../models/artifact.dart';
import '../models/auth.dart';
import '../models/built_in_profiles.dart';
import '../models/codex_usage_summary.dart';
import '../models/machine.dart';
import '../models/message.dart';
import '../models/profile.dart';
import '../models/purchases.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../rpc/rpc_types.dart';
import '../services/message_cache_service.dart';
import '../services/message_outbox.dart';
import '../services/mmkv_storage.dart';
import '../services/network_monitor_service.dart';
import '../services/performance_context_service.dart';
import '../services/power_diagnostics_service.dart';
import '../services/server_config.dart';
import '../services/sessions_cache_storage.dart';
import '../services/storage_service.dart';
// Compile-time identity types — see ROADMAP P0 "one canonical localId".
// Imported once at the part-file root so every `_sync_messaging*` part can
// reference [LocalId], [ServerMessageId], [SessionId], and the sealed
// [MessageSendState] hierarchy without an explicit import.
// ignore: unused_import
import '../types/identity_types.dart';
// ignore: unused_import
import '../types/message_state.dart';
import '../utils/invalidate_sync.dart';
import '../utils/parse_token.dart';
import '../utils/path_utils.dart' show resolveAbsolutePath;
import '../utils/wire_parsers.dart';
// Canary mode — runtime invariant assertions.  No-ops when kCanary
// is false, so the part files can call CanaryAssert.* freely without
// production overhead.
// ignore: unused_import
import 'canary_mode.dart';
import 'inline_message_processor.dart';
import 'logger_service.dart';
import 'message_cursor_manager.dart';
import 'notification_service.dart';
import '_sync_session_restore_split.dart';
import 'session_activity_coordinator.dart';
import 'sidechain_grouper.dart';
import 'tool_result_processor.dart';

part '_sync_data.dart';
part '_sync_data_artifacts.dart';
part '_sync_data_machines.dart';
part '_sync_health.dart';
part '_sync_isolate_helpers.dart';
part '_sync_lifecycle.dart';
part '_sync_messaging.dart';
part '_sync_messaging_merge.dart';
part '_sync_messaging_parse.dart';
part '_sync_messaging_parse_output.dart';
part '_sync_messaging_rpc.dart';
part '_sync_messaging_send.dart';
part '_sync_operations.dart';
part '_sync_operations_session.dart';
part '_sync_sessions.dart';
part '_sync_socket.dart';
part '_sync_socket_events.dart';
part '_sync_test_helpers.dart';

enum SyncDomain {
  sessions,
  messages,
  machines,
  settings,
  profile,
  artifacts,
  gitStatus,
  friendRequests,
}

class SyncProgress {
  const SyncProgress({required this.label, this.completed, this.total});

  final String label;
  final int? completed;
  final int? total;

  double? get fraction {
    final totalValue = total;
    final completedValue = completed;
    if (totalValue == null || totalValue <= 0 || completedValue == null) {
      return null;
    }
    return (completedValue / totalValue).clamp(0.0, 1.0);
  }

  String get displayText {
    final totalValue = total;
    final completedValue = completed;
    if (totalValue == null || completedValue == null || totalValue <= 0) {
      return label;
    }
    return '$label $completedValue/$totalValue';
  }
}

// Global singleton instance
class Sync {
  factory Sync() => _instance;
  Sync._();
  static final Sync _instance = Sync._();

  // Constants
  static const int sessionReadyTimeoutMs = 3000;
  static const int _visibleMessageFetchPageLimit = kIsWeb ? 4 : 12;
  static const int _backgroundMessageFetchPageLimit = 1;
  static const int _maxVisibleSessionMessages = kIsWeb ? 600 : 1000;
  static const int _maxBackgroundSessionMessages = 200;
  static const Duration _messageFetchConnectTimeout = Duration(seconds: 8);
  static const Duration _messageFetchReceiveTimeout = Duration(seconds: 8);

  /// Per-page fetch size for [/v3/sessions/:id/messages].
  ///
  /// Previously 1000 — which on outlier sessions with large encrypted
  /// payloads regularly hit the server-side filter slow path and pushed
  /// `sync.invalidate.fetchMessages` p95 to ~54s (multiple pages × slow
  /// server responses serialized back-to-back, sometimes timing out
  /// against the Dio receive timeout).  Smaller pages let the server
  /// stream a useful response within the 8s timeout and let the UI
  /// paint partial results sooner via the per-page
  /// [_notifySessionMessagesChanged] hook.  The page-limit was bumped
  /// in step (8 → 12) so the worst-case crawl still covers
  /// 12 × 200 = 2400 messages on native — well above the visible cap of
  /// 1000. Web uses smaller pages/limits to avoid browser main-thread and
  /// CanvasKit memory spikes while decrypting and rendering large sessions.
  static const int _messageFetchPageSize = kIsWeb ? 100 : 200;

  /// Soft budget for a single [fetchMessages] cycle.  When the elapsed
  /// time exceeds this, we stop crawling forward pages and let the
  /// next invalidate-cycle resume from the advanced cursor.  Any
  /// already-merged messages stay in memory, so the user sees the
  /// freshest tail load even if a slow server tries to bury us.
  static const Duration _messageFetchBudget = Duration(seconds: 15);
  static const Duration _visiblePostSendProbeDelay = Duration(seconds: 2);
  static const Duration _sessionListMachineRefreshDelay =
      Duration(milliseconds: 800);

  /// Number of recent messages to load on first open of a session.
  static const int initialLoad = kIsWeb ? 100 : 200;
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
  bool _encryptionInitialized = false;
  late String serverID;
  late String anonID;
  late AuthCredentials credentials;
  final EncryptionCache encryptionCache = EncryptionCache();
  final SidechainGrouper _sidechainGrouper = SidechainGrouper();
  final ToolResultProcessor _toolResultProcessor = ToolResultProcessor();
  final MessageCursorManager _cursorManager = MessageCursorManager();

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
  Map<String, int> get _sessionLastSeq => _cursorManager.lastSeq;
  Map<String, int> get _sessionFirstLoadedSeq => _cursorManager.firstLoadedSeq;

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
  static const int _maxRecentInlineKeys = 10000;

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

  /// Sessions that have an explicit reason to probe the messages API even when
  /// the local cursor appears caught up to session.lastSeq.
  ///
  /// This is used for cases where the app knows a new message may exist but
  /// the sessions snapshot can legitimately lag behind message storage:
  /// visible `new-message` events without an embedded payload and post-send
  /// catch-up polling after a successful user send.
  final Set<String> _sessionsNeedingFetchProbe = <String>{};

  /// Per-session serial queue for inline message processing.
  final InlineMessageProcessor _inlineProcessor = InlineMessageProcessor();

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

  /// How many consecutive regroup sweeps have failed to make progress
  /// for each session. Used to delay orphan absorption until we are
  /// confident the parent Task is genuinely absent (not just delayed
  /// by an in-flight socket message or REST batch).
  final Map<String, int> _sidechainRegroupSweepCount = {};
  late InvalidateSync settingsSync;
  late InvalidateSync profileSync;
  late InvalidateSync purchasesSync;
  late InvalidateSync machinesSync;
  late InvalidateSync pushTokenSync;
  late InvalidateSync nativeUpdateSync;
  late InvalidateSync artifactsSync;
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
  final List<DecryptedArtifact> _artifacts = <DecryptedArtifact>[];
  final Map<String, List<Map<String, dynamic>>> _sessionMessages = {};
  final Map<String, Map<String, String?>> _sessionContentSignatures = {};
  Map<String, List<Map<String, dynamic>>>? _sessionMessagesCache;

  /// Cached preview metadata per session — avoids rescanning
  /// the full message list on every session-card build.
  /// Invalidated when messages change via [_invalidatePreviewCache].
  final Map<String, ({int? timestamp, String? preview, String? role})>
  _previewCache = {};

  /// Identity of the message list when the preview was computed.
  final Map<String, int> _previewCacheVersion = {};
  final Map<String, List<Map<String, dynamic>>> _sessionMessagesViewCache = {};
  final Map<String, Map<String, dynamic>> _sessionUsage = {};
  Settings _settingsSnapshot = Settings();
  int _settingsVersion = 0;
  Purchases _purchases = Purchases.defaults;
  Map<String, Session> _sessions = <String, Session>{};
  int? _lastSessionsFetchedAt;
  bool _forceFullFetchNext = false;
  int? _lastInvalidateAllSyncsAtMs;

  /// Wall-clock timestamp of the last successful `/v1/version` poll.
  /// Used to skip redundant native-update checks on cold start /
  /// resume / reconnect — the upstream URL changes at most once a
  /// day, but the deferred-sync fan-out fires this on every
  /// invalidation cycle.
  int? _lastNativeUpdateFetchedAt;
  static const _nativeUpdateFreshnessMs = 6 * 60 * 60 * 1000;

  /// Timestamp of the last reconnect session enumeration.  Used to debounce
  /// the per-session pending-message queue during rapid reconnect cycling.
  int? _lastReconnectSessionEnumerationMs;
  void Function()? _unsubscribeSocketUpdate;
  void Function()? _unsubscribeSocketEphemeral;
  void Function()? _unsubscribeSocketError;
  void Function()? _unsubscribeSocketReconnected;
  void Function()? _unsubscribeSocketReconnectExhausted;
  void Function()? _unsubscribeSocketStatus;

  /// Timestamp of last resume() call for debouncing rapid pause/resume cycles.
  int? _lastResumeAtMs;
  int? _lastSuspendedAtMs;

  /// Timestamp of the last successful settings POST.  Used to suppress
  /// the socket echo that follows immediately after a local write —
  /// without this, every local settings change triggers a redundant
  /// server round-trip (the echo fires settingsSync.invalidate() which
  /// does a GET, doubling the HTTP load for every profile/model switch).
  int? _lastSettingsPostAtMs;

  /// Snapshot of _sessionLastSeq for the visible session captured at the
  /// moment of socket reconnection.  Used by fetchMessages to start the
  /// reconnection fetch from the pre-reconnect cursor position, avoiding
  /// a race where inline socket events advance the cursor past the
  /// disconnect gap and cause messages to be permanently skipped.
  int? _reconnectCursorSnapshot;

  /// Minimum interval between resume() calls — prevents socket reconnect
  /// loops
  /// when the app cycles between paused and resumed states repeatedly.
  static const int _resumeDebounceWindowMs = 2000;

  /// Delay before the reconnection watchdog fires on resume. If the
  /// socket hasn't connected by this point, force a fresh reconnect
  /// cycle to recover from exhausted Socket.IO attempts.
  static const int _reconnectWatchdogDelayMs = 15000;

  /// Delay before firing network invalidations on resume. Cancelled by
  /// suspend() so that rapid foreground/background cycling does not produce
  /// wasted HTTP requests that the OS aborts mid-flight.
  Timer? _deferredResumeInvalidationTimer;
  Timer? _reconnectWatchdogTimer;
  Timer? _resumeBatchTimer;
  int? _lastResumeHttpFallbackAtMs;
  int _resumeConversationRefreshTotal = 0;
  int _resumeConversationRefreshCompleted = 0;

  /// Safety timer that clears the "Fetching conversations" progress
  /// indicator if the resume conversation refresh hasn't completed within
  /// [_resumeConversationProgressTimeoutMs]. This guarantees the UI never
  /// hangs on a stale "0 of N complete" state when an upstream
  /// `sessionsSync` cycle or batched `messagesSync.invalidate()` fails or
  /// is silently dropped (e.g. fatal exceptions inside
  /// `awaitQueue().then(...)`).
  Timer? _resumeConversationProgressSafetyTimer;
  static const int _resumeConversationProgressTimeoutMs = 30 * 1000;
  static const Duration _resumeSessionsAwaitTimeout = Duration(seconds: 6);
  Timer? _sessionsRefreshDebounceTimer;
  Timer? _artifactsSyncDebounceTimer;
  final Set<String> _pendingNewSessionIds = <String>{};
  final Map<String, Machine> _machines = <String, Machine>{};
  // Timers that drop presence back to 'offline' if no activity arrives.
  final Map<String, Timer> _presenceTimers = {};
  Profile? _profile;
  final Map<String, GitStatus> _sessionGitStatus = <String, GitStatus>{};

  // Change notification streams
  final _dataChangeController = StreamController<void>.broadcast();
  final _domainChangeController = StreamController<SyncDomain>.broadcast();
  final _sessionMessageChangeController = StreamController<String>.broadcast();
  final _paginationErrorController = StreamController<String>.broadcast();
  final _syncStateController = StreamController<void>.broadcast();
  int _activeSyncCount = 0;
  SyncProgress? _syncProgress;
  Timer? _dataChangeDebounceTimer;
  final Map<SyncDomain, Timer> _domainChangeDebounceTimers = {};
  final Map<String, Timer> _sessionMessageDebounceTimers = {};
  final Set<String> _sessionMessagePendingTrailing = {};
  final Set<SyncDomain> _domainChangePendingTrailing = {};

  /// Monotonic counter incremented on every data change. Providers compare
  /// this against their last-seen value to skip expensive equality checks
  /// when nothing has changed.
  int _dataChangeCounter = 0;
  final Map<SyncDomain, int> _domainChangeCounters = {
    for (final domain in SyncDomain.values) domain: 0,
  };
  Timer? _saveSeqDebounceTimer;
  Timer? _saveSessionsCacheDebounceTimer;
  final Map<String, Timer> _saveMsgsDebounceTimers = {};

  /// Epoch-ms of the first call to [_scheduleSaveMessages] in the
  /// current debounce window for each session. Used to enforce a
  /// max-delay ceiling so the MMKV save cannot be perpetually deferred
  /// by sustained streaming traffic.
  final Map<String, int> _saveMsgsFirstScheduledAtMs = {};
  final Map<String, Timer> _postSendCatchUpTimers = {};
  final Set<String> _sessionsNeedingTailRefresh = <String>{};
  final Set<String> _sessionsNeedingVisibleRegroup = <String>{};
  final Set<String> _sessionsNeedingSidechainRegroup = <String>{};

  /// Per-session epoch-ms of the last attempt to recover orphans by
  /// fetching older message pages. The parent Task is often just below
  /// the loaded window; one extra page usually pulls it in so the next
  /// grouper pass can re-attach the children. Throttled so a session
  /// with genuinely missing parents can't hammer the API.
  final Map<String, int> _orphanFetchOlderAttemptedMs = {};

  /// Per-session epoch-ms until which orphan regroup work is suppressed.
  /// Used after history is exhausted so caught-up fetches don't repeatedly
  /// run the O(n) grouper for sidechain children that must render inline.
  final Map<String, int> _orphanSuppressedUntilMs = {};

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
  // sessionId → profileId used when spawning. Lets _resolveSendTargetSession
  // detect profile changes and kill+respawn the session automatically.
  final Map<String, String?> _sessionSpawnedProfile = {};
  // sessionId → modelMode used when spawning. Lets _resolveSendTargetSession
  // detect model changes and kill+respawn the session automatically.
  final Map<String, String?> _sessionSpawnedModel = {};
  // sessionId → agent used when spawning. Used as fallback when
  // session.metadata?.flavor is null (e.g., metadata decryption failed)
  // so auto-restore uses the correct agent instead of defaulting to 'claude'.
  final Map<String, String> _sessionSpawnedAgent = {};
  // machineId → epoch-ms of last offline warning. Deduplicates the
  // "Machine appears offline" warning that fires on every createSession().
  final Map<String, int> _machineOfflineWarnedAtMs = {};
  // Sessions whose DEK failed to decrypt and fell back to legacy NaCl —
  // captured to Sentry once per session per app run so DEK-fallback
  // sessions can be correlated with later CryptoSecretBox.decrypt
  // failures (scope=session:<id>:messages). DEK decryption re-runs on
  // every fetchSessions, so without this set the capture would repeat.
  final Set<String> _dekFallbackCaptured = {};
  // Track sessions where a profile/model-change kill is in flight. Prevents
  // a concurrent or outbox-retry sendMessage call from firing a second kill
  // for the same session before the first auto-restore has completed and
  // re-registered _sessionSpawnedProfile. Cleared in the auto-restore finally.
  final Set<String> _profileModelKillInFlight = {};
  // Track sessions currently undergoing auto-restore. Concurrent sendMessage
  // calls await the in-flight Completer instead of silently returning the
  // stale offline session.
  final Set<String> _autoRestoreInFlight = {};
  final Map<
    String,
    Completer<
      ({String sessionId, Session session, SessionEncryption sessionEncryption})
    >
  >
  _autoRestoreCompleters = {};
  // Tracks the profileIdOverride used by each in-flight auto-restore.
  // Used to detect when concurrent sendMessage calls with different
  // profileIds should NOT share the same in-flight auto-restore.
  final Map<String, String?> _autoRestoreProfileIds = {};

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

  // ── @visibleForTesting fields ─────────────────────────────────────────
  // These must live on the class (not in an extension) because extensions
  // cannot declare instance fields.

  /// Overrides the HTTP fetch path in [fetchMessages] for integration
  /// tests. When set, [fetchMessages] calls this instead of making a
  /// real HTTP request.
  /// The callback receives (sessionId, afterSeq, limit) and returns
  /// the parsed response map.
  @visibleForTesting
  Future<Map<String, dynamic>>? Function(
    String sessionId,
    int afterSeq,
    int limit,
  )?
  testFetchMessagesOverride;

  /// Overrides the HTTP fetch path in [fetchOlderMessages] for
  /// integration tests.
  @visibleForTesting
  Future<Map<String, dynamic>>? Function(
    String sessionId,
    int afterSeq,
    int limit,
  )?
  testFetchOlderMessagesOverride;

  /// Overrides [_messageFetchBudget] for tests so the hard-budget
  /// pagination guard can be exercised deterministically without
  /// running for the full 15 s production budget.
  @visibleForTesting
  Duration? testMessageFetchBudgetOverride;

  /// Returns the active per-cycle budget, honoring any test override.
  Duration get _activeMessageFetchBudget =>
      testMessageFetchBudgetOverride ?? _messageFetchBudget;

  /// Override _typedMachineRPC for testing createSession and
  /// auto-restore without a real socket connection.
  @visibleForTesting
  Future<dynamic> Function(
    String machineId,
    String method,
    Map<String, dynamic> params,
  )?
  testMachineRPCOverride;

  /// Override [SyncMessagingRpc.ensureMachineReachable] for testing the
  /// pre-flight liveness probe without a real socket connection.
  @visibleForTesting
  Future<void> Function(String machineId)? testEnsureMachineReachableOverride;

  /// Override fetchSingleSession for testing sendMessage encryption
  /// recovery without a real API call.
  @visibleForTesting
  Future<Session?> Function(String sessionId)? testFetchSingleSessionOverride;

  /// Override _getSpawnEnvVarsForSession to avoid MMKV dependency in
  /// tests that exercise auto-restore / createSession.
  @visibleForTesting
  Future<({Map<String, String> envVars, AIBackendProfile? profile})> Function(
    String sessionId,
  )?
  testGetSpawnEnvVarsOverride;

  // ── @visibleForTesting mutable maps for test helpers ─────────────────

  /// Mutable sessions map — use in tests that need to seed session state.
  @visibleForTesting
  Map<String, Session> get testSessions => _sessions;

  /// Mutable machines map — use in tests that need to seed machine state.
  @visibleForTesting
  Map<String, Machine> get testMachines => _machines;

  /// Mutable spawn timestamp map — use in model/profile change tests.
  @visibleForTesting
  Map<String, int> get testSessionSpawnedAt => _sessionSpawnedAt;

  /// Mutable spawn profile map — use in profile change tests.
  @visibleForTesting
  Map<String, String?> get testSessionSpawnedProfile => _sessionSpawnedProfile;

  /// Mutable spawn model map — use in model change tests.
  @visibleForTesting
  Map<String, String?> get testSessionSpawnedModel => _sessionSpawnedModel;

  /// Mutable pending-updates set.
  @visibleForTesting
  Set<String> get testSessionsWithPendingUpdates => _sessionsWithPendingUpdates;

  /// Mutable ephemeral timestamps map.
  @visibleForTesting
  Map<String, int> get testLastEphemeralAt => _lastEphemeralAt;

  /// Convenience setter for spawn timestamp.
  @visibleForTesting
  void testSetSessionSpawnedAt(String sessionId, int timestamp) {
    _sessionSpawnedAt[sessionId] = timestamp;
  }

  /// Convenience setter for spawn profile.
  @visibleForTesting
  void testSetSessionSpawnedProfile(String sessionId, String? profileId) {
    _sessionSpawnedProfile[sessionId] = profileId;
  }

  /// Convenience setter for spawn model.
  @visibleForTesting
  void testSetSessionSpawnedModel(String sessionId, String? modelMode) {
    _sessionSpawnedModel[sessionId] = modelMode;
  }

  /// Convenience setter for last ephemeral timestamp.
  @visibleForTesting
  void testSetLastEphemeralAt(String sessionId, int timestamp) {
    _lastEphemeralAt[sessionId] = timestamp;
  }

  /// Clears all spawn-tracking maps.
  @visibleForTesting
  void testClearSessionSpawnedAt() {
    _sessionSpawnedAt.clear();
    _sessionSpawnedProfile.clear();
    _sessionSpawnedModel.clear();
    _sessionSpawnedAgent.clear();
  }

  /// Clears pending socket-message session set.
  @visibleForTesting
  void testClearSessionsWithPendingSocketMessages() {
    _sessionsWithPendingSocketMessages.clear();
  }

  Map<String, Machine> get machines => Map.unmodifiable(_machines);
  Profile? get profile => _profile;
  bool get isReady => _isReady;
  bool get isEncryptionInitialized => _encryptionInitialized;
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
  int? getLastMessageTimestamp(String sessionId) =>
      _ensurePreviewCache(sessionId).timestamp;

  /// Returns a brief preview of the last message in a session.
  ///
  /// Scans from the end to find the last assistant or human message
  /// with non-empty text content. Strips markdown, collapses
  /// whitespace, and truncates to [_kPreviewMaxLen] characters.
  /// Returns null when no suitable preview is available.
  String? getLastMessagePreview(String sessionId) =>
      _ensurePreviewCache(sessionId).preview;

  /// Returns the role ([MessageRole.user] or [MessageRole.agent]) of
  /// the message used by [getLastMessagePreview], or null.
  String? getLastMessageRole(String sessionId) =>
      _ensurePreviewCache(sessionId).role;

  /// Invalidates the preview cache for a session so the next call
  /// to [getLastMessagePreview] etc. will rescan.
  void _invalidatePreviewCache(String sessionId) {
    _previewCache.remove(sessionId);
    _previewCacheVersion.remove(sessionId);
  }

  ({int? timestamp, String? preview, String? role}) _ensurePreviewCache(
    String sessionId,
  ) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) {
      return (timestamp: null, preview: null, role: null);
    }
    // Use list identity + length as a cheap version check.
    final version = identityHashCode(messages) ^ messages.length;
    if (_previewCacheVersion[sessionId] == version) {
      return _previewCache[sessionId]!;
    }

    // Compute all three in a single backward scan.
    final timestamp = messages.last['createdAt'] as int?;
    String? preview;
    String? role;
    String? toolFallback;
    String? toolFallbackRole;
    var sawToolCall = false;
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg['isSidechain'] == true) continue;
      final msgRole = msg['role'] as String?;
      if (msgRole != MessageRole.agent && msgRole != MessageRole.user) {
        continue;
      }
      final kind = msg['kind'] as String?;
      if (kind == 'tool-call') {
        sawToolCall = true;
        if (toolFallback == null) {
          toolFallback = _toolPreview(msg);
          toolFallbackRole = msgRole;
        }
        continue;
      }
      if (kind == 'agent-event') continue;
      if (msg['isThinking'] == true) continue;
      final text = (msg['content'] ?? msg['text']) as String?;
      if (text != null && text.trim().isNotEmpty) {
        preview = _cleanPreviewText(text.trim());
        role = msgRole;
        break;
      }
    }
    preview ??= toolFallback;
    role ??= toolFallbackRole ?? (sawToolCall ? MessageRole.agent : null);

    final result = (timestamp: timestamp, preview: preview, role: role);
    _previewCache[sessionId] = result;
    _previewCacheVersion[sessionId] = version;
    return result;
  }

  static const _kPreviewMaxLen = 120;

  String? _toolPreview(Map<String, dynamic> message) {
    final name = message['name'] as String?;
    if (name == null || name.isEmpty) return null;
    return _cleanPreviewText('Used $name');
  }

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
  int getUnreadCount(String sessionId) => _sessionUnreadCounts[sessionId] ?? 0;

  /// Stream that emits when session/machine/general data changes.
  Stream<void> get onDataChanged => _dataChangeController.stream;

  /// Stream that emits the specific domain that changed.
  Stream<SyncDomain> get onDomainChanged => _domainChangeController.stream;

  /// Monotonic counter incremented on every data change notification.
  /// Providers compare this to skip expensive equality checks.
  int get dataChangeCounter => _dataChangeCounter;

  /// Monotonic counter for a specific domain.
  int domainChangeCounter(SyncDomain domain) =>
      _domainChangeCounters[domain] ?? 0;

  /// Stream that emits the sessionId when messages for that session change.
  Stream<String> get onSessionMessagesChanged =>
      _sessionMessageChangeController.stream;

  /// Stream that emits the sessionId when older-message pagination fails.
  /// ChatScreen listens to this to show an inline error or snackbar.
  Stream<String> get onPaginationError => _paginationErrorController.stream;

  /// Stream that emits whenever sync state changes (any sync starts or stops).
  Stream<void> get onSyncStateChanged => _syncStateController.stream;

  /// Whether any sync operation is currently running.
  bool get isSyncing => _activeSyncCount > 0;

  /// Human-readable sync progress for status UI.
  SyncProgress? get syncProgress => _syncProgress;

  void _setSyncProgress(SyncProgress? progress) {
    final current = _syncProgress;
    if (current?.label == progress?.label &&
        current?.completed == progress?.completed &&
        current?.total == progress?.total) {
      return;
    }
    _syncProgress = progress;
    _syncStateController.add(null);
  }

  void _onSyncRunningChanged(bool isRunning) {
    if (isRunning) {
      _activeSyncCount++;
    } else {
      _activeSyncCount--;
      if (_activeSyncCount < 0) _activeSyncCount = 0;
      if (_activeSyncCount == 0) {
        _syncProgress = null;
      }
    }
    _syncStateController.add(null);
  }

  /// Returns true for transient network errors that are not actionable
  /// (e.g. DNS failure, timeout, Cronet aborting a connection because the
  /// app was backgrounded, or Socket.IO connection issues).
  static bool _isTransientConnectionError(Object error) {
    // Check for typed socket exceptions first
    if (error is SocketNotConnectedException ||
        error is SocketAckTimeoutException) {
      return true;
    }
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
        msg.contains('Software caused connection abort') ||
        msg.contains('Machine encryption not found') ||
        msg.contains('operation has timed out');
  }

  /// Whether [error] indicates a machine/session RPC method that
  /// the daemon does not support (e.g. older daemon version).
  /// These are expected and should not be reported to Sentry.
  static bool _isRpcMethodNotAvailable(Object error) {
    if (error is! StateError) return false;
    final msg = error.message;
    return msg.contains('not available') ||
        msg.contains('RPC method') ||
        msg.contains('RPC handler') ||
        // Session agent disconnected or died mid-request
        msg.contains('handler disconnected') ||
        msg.contains('no handler') ||
        // Handler registration failures
        msg.contains('handler not found') ||
        msg.contains('not registered');
  }

  /// Whether [error] is an infra-side RPC forwarding failure during spawn or
  /// auto-restore. The client cannot recover this locally, so it should not be
  /// treated as an app bug.
  static bool _isRpcReplicaTimeout(Object error) {
    if (error is! StateError) return false;
    final msg = error.message;
    return msg.contains('forwarded via Redis') &&
        msg.contains('no replica responded');
  }

  /// Combined transient classification used at machine-RPC call sites:
  /// either the local socket is wobbly ([_isTransientConnectionError]) or
  /// the infra side never reached a replica ([_isRpcReplicaTimeout]). Both
  /// are non-actionable from the client and should be downgraded to info.
  static bool _isTransientRpcError(Object error) =>
      _isTransientConnectionError(error) || _isRpcReplicaTimeout(error);

  bool _isSocketConnected() {
    return testSocketConnectedOverride ??
        socketIoClient.connectionStatus == ConnectionStatus.connected;
  }

  /// Invalidate all sync managers
  static const int _invalidateAllSyncsCooldownMs = 10000;

  /// Maximum number of non-visible sessions to refresh messages for on
  /// resume.  Each failed fetch retries 3× with a 15 s HTTP timeout,
  /// so capping this avoids launching dozens of parallel 54 s timeout
  /// cascades that block the UI and saturate the network.
  static const int _maxResumeMessageSyncs = 5;

  /// Phases for selective sync invalidation to prevent thundering herd.
  ///
  ///   * 0: Critical — needed for the default sessions tab. Fires
  ///        immediately.
  ///   * 1: Tab-needed — machines/settings/profile. Fires ~1s in so
  ///        cold-start fetchSessions finishes uncontested first.
  ///   * 2: Background — purchases / push token / native update /
  ///        git status. Fires ~3s in. None of these
  ///        block any user-visible screen.
  static const _criticalSyncPhase = 0;
  static const _deferredSyncPhase = 1;
  static const _backgroundSyncPhase = 2;
  Timer? _deferredSyncsTimer;
  Timer? _backgroundSyncsTimer;

  bool _dataChangePendingTrailing = false;

  /// Cached per-session JSON + object reference from the last persist.
  /// On each persist, only sessions whose object reference differs from
  /// the cached one are re-serialized via `toJson()`.
  final Map<String, (Session, Map<String, dynamic>)> _sessionJsonCache = {};

  /// Debounce for the safety-net HTTP fetch after update-session events.
  /// Since _handleUpdateSession patches unencrypted fields (presence,
  /// active, title, thinking) inline, this fetch is only needed for
  /// encrypted metadata/agentState changes which are infrequent.
  /// Previously 250ms — caused N+1 fetches during startup bursts.
  static const Duration _sessionsRefreshDebounce = Duration(seconds: 2);

  /// Minimum interval between the end of one sessions fetch and the start
  /// of the next.  Without this, socket event bursts (dozens of
  /// update-session events per second during streaming) cause hundreds of
  /// back-to-back /v2/sessions HTTP requests — the debounce timer only
  /// throttles the *scheduling*, not the InvalidateSync itself.
  static const Duration _sessionsSyncMinInterval = Duration(seconds: 2);

  /// Minimum interval between consecutive settings syncs.  Without this,
  /// profile switching and socket-echo cascades can cause rapid-fire POST
  /// and GET cycles that amplify into settings sync storms.
  static const Duration _settingsSyncMinInterval = Duration(seconds: 2);

  /// Window after a successful settings POST during which the socket
  /// echo is suppressed.  The server broadcasts an update-account event
  /// immediately after committing the POST — without this filter, the
  /// client receives its own write as an update and does a redundant GET.
  static const int _settingsEchoFilterWindowMs = 5000;

  /// Minimum interval between consecutive message fetches for a session.
  /// Prevents rapid-fire HTTP refetches when many socket events arrive
  /// in quick succession (e.g. during streaming).
  static const Duration _messagesSyncMinInterval = Duration(milliseconds: 500);

  static const Duration _machinesRefreshDebounce = Duration(milliseconds: 250);

  /// Minimum interval between machine fetches via InvalidateSync.
  static const Duration _machinesSyncMinInterval = Duration(seconds: 1);

  Future<void>? _sessionListRefreshInFlight;

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

  // Message processing methods (_processDecryptedMessage,
  // _processOutputContent, _processEventContent, _processCodexContent,
  // _processAcpContent, _processSessionContent, _extractUsageMap,
  // _extractAgentFallbackText, _looksLikeSessionEnvelope,
  // _extractTextFromContentBlocks) are in _sync_messaging.dart.
  // Lifecycle methods (suspend, resume, shutdown) are in
  // _sync_lifecycle.dart.
  // @visibleForTesting helpers are in _sync_test_helpers.dart.
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
  sessionActivityCoordinator.attach(sync);
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
  sessionActivityCoordinator.attach(sync);
}

/// Shutdown sync engine and clear in-memory state.
Future<void> syncShutdown() async {
  if (!sync.isInitialized) {
    return;
  }
  await sessionActivityCoordinator.detach();
  await sync.shutdown();
}
