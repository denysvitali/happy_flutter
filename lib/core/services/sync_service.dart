import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart'
    hide LogLevel, Logger;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../sentry_config.dart';
import '../api/api_client.dart';
import '../api/sessions_api.dart';
import '../api/socket_io_client.dart';
import '../encryption/aes_gcm.dart';
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
import '../models/grok_usage_summary.dart';
import '../models/loop.dart';
import '../models/machine.dart';
import '../models/mcp_server.dart';
import '../models/message.dart';
import '../models/outgoing_image.dart';
import '../models/profile.dart';
import '../models/purchases.dart';
import '../models/sandbox_policy.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../models/todo.dart';
import '../models/workflow_run.dart';
import '../rpc/rpc_types.dart';
import '../rpc/rpc_exception.dart';
import '../rpc/rpc_capabilities.dart';
import '../sync/artifact_manager.dart';
import '../sync/settings_manager.dart';
import '../sync/sync_exceptions.dart';
import '../sync/sync_progress.dart';
import '../services/failure_telemetry.dart';
import '../services/loop_storage.dart';
import '../services/message_cache_service.dart';
import '../services/message_outbox.dart';
import '../services/mmkv_storage.dart';
import '../services/network_monitor_service.dart';
import '../services/opentelemetry_service.dart';
import '../services/performance_context_service.dart';
import '../services/power_diagnostics_service.dart';
import '../services/power_diagnostics_otel_reporter.dart';
import '../services/server_config.dart';
import '../services/sessions_cache_storage.dart';
import '../services/storage_service.dart';
import '../services/workflow_storage.dart';
// Compile-time identity types — see ROADMAP P0 "one canonical localId".
// Imported once at the part-file root so every `_sync_messaging*` part can
// reference [LocalId], [ServerMessageId], [SessionId], and the sealed
// [MessageSendState] hierarchy without an explicit import.
// ignore: unused_import
import '../types/identity_types.dart';
// ignore: unused_import
import '../types/message_retry_result.dart';
// ignore: unused_import
import '../types/message_state.dart';
import '../types/remote_feature_failure.dart';
import '../utils/image_content_blocks.dart';
import '../utils/codex_provider_config.dart';
import '../sync/invalidate_sync.dart';
import '../utils/message_invariant_monitor.dart';
import '../utils/shell_script_parser.dart';
import '../utils/parse_token.dart';
import '../utils/path_utils.dart' show resolveAbsolutePath;
import '../sync/sync_domain.dart';
export '../sync/sync_exceptions.dart' show IncompatibleProviderAndModelError;
export '../sync/sync_progress.dart' show SyncProgress;
export '../sync/sync_domain.dart' show SyncDomain;
export '../rpc/rpc_exception.dart';
export '../rpc/rpc_capabilities.dart';
export '../types/message_retry_result.dart';
import '../wire/wire_parsers.dart';
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
import 'stuck_agent_sentinel.dart';
import 'tool_result_processor.dart';

part '_sync_data.dart';
part '_sync_capabilities.dart';
part '_sync_data_artifacts.dart';
part '_sync_data_machines.dart';
part '_sync_health.dart';
part '_sync_isolate_helpers.dart';
part '_sync_lifecycle.dart';
part '_sync_messaging.dart';
part '_sync_messaging_merge.dart';
part '_sync_messaging_rpc.dart';
part '_sync_messaging_send.dart';
part '_sync_operations.dart';
part '_sync_operations_mcp.dart';
part '_sync_operations_sandbox.dart';
part '_sync_operations_session.dart';
part '_sync_operations_session_profile.dart';
part '_sync_operations_session_model_env.dart';
part '_sync_operations_machine_rpc.dart';
part '_sync_sessions.dart';
part '_sync_socket.dart';
part '_sync_socket_events.dart';
part '_sync_loops.dart';
part '_sync_machine_loops.dart';
part '_sync_workflows.dart';
part 'message_pipeline/message_models.dart';
part 'message_pipeline/message_ingestion_orchestrator.dart';
part '_sync_test_helpers.dart';

// Global singleton instance

/// Typed event emitted on [Sync.onAutoRestoreFailure] when an
/// auto-restore attempt fails in a way that the chat UI needs to
/// surface to the user (the optimistic send cannot proceed because
/// the underlying session could not be restored).
///
/// Subscribers (notably [ChatScreen]) use this to show a snackbar
/// and flip the optimistic message's `sendStatus` to `'failed'` so
/// the user can retry with the same `localId`.
class AutoRestoreFailure {
  const AutoRestoreFailure({
    required this.sessionId,
    required this.error,
    required this.reason,
    this.stack,
  });

  /// The session whose auto-restore failed.
  final String sessionId;

  /// The underlying error object. Kept opaque so we never
  /// accidentally smuggle a non-stringifiable value across the
  /// broadcast boundary.
  final Object error;

  /// Stack trace of the originating failure, when available.
  final StackTrace? stack;

  /// Classification of the failure for downstream handling.
  ///
  /// - `'transient'` — network/RPC blip; retry may succeed.
  /// - `'permanent'` — server says session is gone; retry won't help.
  /// - `'lifecycle_error'` — session was in errored state already.
  /// - `'unknown'` — catch-all branch; failure surfaced silently
  ///   before this stream existed.
  final String reason;
}

class Sync {
  factory Sync() => _instance;
  Sync._();
  static final Sync _instance = Sync._();

  // Constants
  /// Max wait for `waitForAgentReady` before `sendMessage` proceeds anyway.
  ///
  /// Lowered from 3000 ms (p90 2.6s on chat.send_message — Jaeger over 30
  /// spans) to 750 ms: the caller already sends regardless of the wait
  /// result, so the wait is purely user-visible latency.  When the agent
  /// is mid-think the daemon stops emitting ephemeral keep-alives and
  /// `_isSessionReady` falls back to the `lifecycleState == 'running'`
  /// short-circuit; this constant only governs the worst-case stall
  /// when neither signal is fresh.
  static const int sessionReadyTimeoutMs = 750;

  /// Inline window (ms) during which a freshly-spawned session is considered
  /// "recently spawned" for readiness purposes. Outside this window the short
  /// [sessionReadyTimeoutMs] (750 ms) applies.
  static const int recentlySpawnedFlagMs = 30000;

  /// Wait budget for a recently-spawned session to become ready before
  /// sending the message anyway. The 15 s window accommodates cold-start
  /// agent boot (daemon waits 15 s for the agent's startup webhook before
  /// returning an error — see createSession).
  static const int recentlySpawnedWaitMs = 15000;

  // ── Test-only wall-clock overrides ─────────────────────────────────────
  // Production reads go through the private getters below so the shipped
  // defaults stay identical; tests shrink them so real-timer paths
  // (spawn readiness wait, hydration retries, webhook recovery, sessions
  // refresh debounce) stop burning seconds. Reset with
  // [testResetTimingOverrides] in tearDown.

  /// Override for [recentlySpawnedWaitMs] (ms).
  @visibleForTesting
  static int? testRecentlySpawnedWaitMsOverride;

  /// Override for the ordinary foreground send deadline (12 s).
  @visibleForTesting
  static Duration? testSendDeadlineOverride;

  /// Override for the POST slice reserved inside the send deadline (6 s).
  @visibleForTesting
  static Duration? testSendMinPostWindowOverride;

  /// Override for the wait before recovering a session after the daemon's
  /// spawn webhook timed out (5 s).
  @visibleForTesting
  static Duration? testWebhookTimeoutRecoveryDelayOverride;

  /// Override for the `fetchSingleSession` hydration retry cadence
  /// (`[0, 250 ms, 750 ms]`). The attempt count is whatever the list holds.
  @visibleForTesting
  static List<Duration>? testSpawnHydrateRetryDelaysOverride;

  /// Override for [_sessionsRefreshDebounce] (2 s).
  @visibleForTesting
  static Duration? testSessionsRefreshDebounceOverride;

  /// Clears every timing override above. Call from `tearDown`.
  @visibleForTesting
  static void testResetTimingOverrides() {
    testRecentlySpawnedWaitMsOverride = null;
    testSendDeadlineOverride = null;
    testSendMinPostWindowOverride = null;
    testWebhookTimeoutRecoveryDelayOverride = null;
    testSpawnHydrateRetryDelaysOverride = null;
    testSessionsRefreshDebounceOverride = null;
  }

  static int get _recentlySpawnedWaitBudgetMs =>
      testRecentlySpawnedWaitMsOverride ?? recentlySpawnedWaitMs;

  static const int _visibleMessageFetchPageLimit = kIsWeb ? 4 : 12;
  static const int _backgroundMessageFetchPageLimit = 1;
  static const int _maxVisibleSessionMessages = kIsWeb ? 600 : 1000;
  static const int _maxBackgroundSessionMessages = 200;

  // ── Idle background window shrink ─────────────────────────────────────
  // Per-session windows are bounded (200/1000 rows) but were never evicted
  // across sessions: every session that ever received traffic kept its full
  // window — with decrypted tool outputs and sidechain children — for the
  // process lifetime. At 251+ sessions that is the progressive "laggier the
  // longer it runs" heap shape. Sessions untouched for
  // [idleSessionShrinkAfterMs] are shrunk to [idleSessionShrinkKeepRows]
  // newest rows (enough for the session-card preview); scroll-back state is
  // re-armed so reopening pages history back in, and MessageCacheService
  // still holds 200 rows for cold-start repaint.

  /// Rows kept when an idle background session's window is shrunk.
  static const int idleSessionShrinkKeepRows = 25;

  /// Background inactivity before a session's window is eligible to shrink.
  static const int idleSessionShrinkAfterMs = 30 * 60 * 1000;

  /// Minimum interval between shrink sweeps. The sweep piggybacks on
  /// [_notifyDataChanged] so it needs no lifecycle-managed timer: a fully
  /// quiet app runs no sweeps, but a quiet app also accumulates nothing.
  static const int idleSessionShrinkSweepIntervalMs = 5 * 60 * 1000;

  /// Maximum number of (non-visible) sessions that keep their *full* resident
  /// transcript at once. The time-based shrink above only fires after
  /// [idleSessionShrinkAfterMs], so a user who fans across a large catalog can
  /// retain one full ~200-row decrypted transcript per session for the whole
  /// grace window — the heap footprint that made the app "laggier the longer
  /// it runs" and scaled RSS with session count (RSS p95 hit the 2 GB bucket
  /// at 101-250 sessions; progressive-lag audit 2026-08-24, fifth pass).
  ///
  /// Beyond this budget, the least-recently-touched sessions are shrunk to
  /// [idleSessionShrinkKeepRows] immediately, so full residency is bounded to
  /// the handful of sessions the user is actually cycling between. The visible
  /// session and any session with an unsettled send are always exempt, and a
  /// shrunk session pages its history back in on reopen (same re-armed
  /// scroll-back boundary as the time-based shrink).
  static const int maxFullResidentSessions = 8;

  /// Silence (no message-window mutation) after which a session still
  /// flagged `thinking` is treated as wedged: thinking is demoted locally
  /// and stuck running tool rows walk back to canceled. Generous enough
  /// that a legitimately quiet long-running command inside an active turn
  /// is never interrupted.
  static const int stuckThinkingReconcileAfterMs = 15 * 60 * 1000;

  /// sessionId → epoch-ms of the last message-window mutation or visibility
  /// change. Written by [_invalidateMessageCaches] (the mutation choke
  /// point) and [prepareSessionVisibility].
  final Map<String, int> _sessionMessagesTouchedAtMs = {};

  int _lastIdleShrinkSweepMs = 0;

  /// Overrides the clock used by the idle-window shrink sweep.
  @visibleForTesting
  int? testIdleShrinkNowMsOverride;

  /// Bounds only the TCP+TLS handshake, not the transfer. A healthy mobile
  /// connection establishes in well under a second, so 8 s still fails fast
  /// on a black-holed route.
  static const Duration _messageFetchConnectTimeout = Duration(seconds: 8);

  /// Budget for receiving a message page body.
  ///
  /// Was 8 s, copied from the connect timeout above. That number bounds a
  /// handshake, not a body: production traces show the server producing a
  /// page in 94.8 ms and the client aborting at 8.14 s — the whole 8 s was
  /// transfer of a ~1.5 MB payload, which needs ~1.5 Mbit/s sustained to
  /// fit. 30 s covers the same page at ~400 kbit/s.
  ///
  /// Raising this only trades an error for a stall if the page has no
  /// recovery path; it does now ([_messagesSyncMaxRetries]). Worst case for
  /// one page is 30 s + 1 s backoff + 30 s, and the chat screen never blocks
  /// on it — it awaits the sync queue with its own short UI cap.
  static const Duration _messageFetchReceiveTimeout = Duration(seconds: 30);

  /// Budget for a message send round-trip. Also inherited from the 8 s
  /// connect timeout. A send carries the user's whole prompt (attachments
  /// included) and its response is small, so the risk profile is the
  /// opposite of a page fetch: giving up early strands a message the server
  /// may well have accepted. 20 s.
  static const Duration _messageSendTimeout = Duration(seconds: 20);

  /// Default throttle between consecutive orphan-recovery fetchOlder
  /// attempts. Reduced from 60s to 15s so users see recovery within
  /// their perception window when new activity arrives.
  static const int _orphanSuppressionWindowMs = 15000;

  /// Extended suppression applied when history is genuinely exhausted
  /// (no more older messages exist). The heavy-grouper path must not
  /// keep running for stuck sessions.
  static const int _orphanSuppressionExtendedWindowMs = 60000;

  /// Maximum cumulative page-count budget for orphan-recovery
  /// walk-back. Replaces the prior 12-attempt cap; the cap is now
  /// page-counted so a session with deeply nested sub-agent trees
  /// (parent Tasks 10k-50k seqs behind the loaded window) can
  /// recover. Once the budget is exhausted and orphans persist, the
  /// sidechain messages render inline.
  static const int _orphanFetchOlderMaxPageSequences = 25000;

  /// Seq range the aggressive (lightly-throttled) walk-back phase may
  /// cover before falling back to the standard throttle.
  ///
  /// Expressed in sequences rather than pages so it is independent of
  /// [_orphanFetchOlderPageSize]: shrinking the page must not shrink how
  /// far back the aggressive phase can reach.
  static const int _orphanAggressiveWalkbackSequences = 2500;

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
  static const int _olderMessagePageSize = 100;

  /// Per-page fetch size for the automatic orphan-recovery walk-back.
  ///
  /// Kept at 500 deliberately. Production traces showed this request
  /// timing out client-side at 8.1 s on ~1.5 MB bodies the server had
  /// produced in 94.8 ms — but the cause was the 8 s receive budget, now
  /// [_messageFetchReceiveTimeout] at 30 s, plus the absence of any retry
  /// layer. Both are fixed. Shrinking the page instead cuts how far one
  /// aggressive sweep reaches, which is a pinned contract: a cold start
  /// whose cache window is entirely sidechain orphans must page back to
  /// seq < 500 fast enough to surface the early Agents
  /// (test/integration/orphan_cold_start_15_agents_e2e_test.dart).
  static const int _orphanFetchOlderPageSize = 500;

  /// [_orphanFetchOlderPageSize], exposed so walk-back contract tests size
  /// their seq windows from the real constant instead of a stale literal.
  @visibleForTesting
  static const int orphanFetchOlderPageSizeForTesting =
      _orphanFetchOlderPageSize;

  /// [_maxVisibleSessionMessages], exposed so walk-back contract tests can
  /// build a session that is exactly at the trim cap.
  @visibleForTesting
  static const int maxVisibleSessionMessagesForTesting =
      _maxVisibleSessionMessages;

  /// [_maxBackgroundSessionMessages], exposed so merge tests can drive the
  /// trim without hard-coding the cap.
  @visibleForTesting
  static const int maxBackgroundSessionMessagesForTesting =
      _maxBackgroundSessionMessages;

  /// Soft budget for a single [fetchMessages] cycle.  When the elapsed
  /// time exceeds this, we stop crawling forward pages and let the
  /// next invalidate-cycle resume from the advanced cursor.  Any
  /// already-merged messages stay in memory, so the user sees the
  /// freshest tail load even if a slow server tries to bury us.
  ///
  /// Must leave room for more than one page, otherwise the crawl is
  /// guaranteed to defer after every single page and a session with a real
  /// backlog only advances one page per invalidate-cycle. At 15 s it was
  /// already below [_messageFetchReceiveTimeout], so a single slow page
  /// blew the whole budget; 40 s fits a handful of healthy pages while
  /// still capping how long one session can pin the fetcher.
  static const Duration _messageFetchBudget = Duration(seconds: 40);
  static const Duration _visiblePostSendProbeDelay = Duration(seconds: 2);

  /// How long post-send catch-up polling keeps probing for the agent's
  /// reply before giving up.
  ///
  /// Was 30 s, which 34% of polls (37/108 in 24h) hit before any reply
  /// arrived — an agent that takes longer than half a minute to answer is
  /// completely ordinary. The budget now covers the realistic thinking
  /// window; [_postSendCatchUpInterval] widens the cadence so the longer
  /// budget does not multiply the fetch load.
  static const Duration _postSendCatchUpBudget = Duration(seconds: 90);

  /// Delay before the catch-up probe numbered [probesSoFar] (1-based after
  /// the first probe has run): tight while a reply is most likely, then
  /// widening. Total probes across [_postSendCatchUpBudget]: ~6.
  static Duration _postSendCatchUpInterval(int probesSoFar) {
    if (probesSoFar <= 2) return const Duration(seconds: 10);
    if (probesSoFar == 3) return const Duration(seconds: 15);
    return const Duration(seconds: 20);
  }

  static const Duration _sessionListMachineRefreshDelay = Duration(
    milliseconds: 800,
  );

  /// Number of recent messages to load on first open of a session.
  static const int initialLoad = kIsWeb ? 100 : 200;

  /// Bump when an older persisted message window needs another bounded
  /// authoritative verification after an upgrade.
  static const int _socketGapRepairVersion = 1;
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
  ArtifactManager? artifactManager;
  SettingsManager? settingsManager;
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

  /// Per-session rate-limiter for encryption-key recovery attempts. When a
  /// session's decryptor is the legacy NaCl implementation but the server
  /// still advertises an encrypted data key, we try to re-fetch the session
  /// once so a rotated/wrapped key can be decrypted with the current keypair.
  final Map<String, int> _sessionEncryptionRecoveryAttempts = {};
  static const int _sessionEncryptionRecoveryThrottleMs = 30000;

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

  /// Sessions whose history has been paginated all the way back to seq 0.
  ///
  /// [_sessionFirstLoadedSeq] has two writers that disagree about what it
  /// means: `fetchOlderMessages` treats it as "oldest seq ever fetched" and
  /// writes 0 when it reaches the beginning, while `_ensureFirstLoadedSeq`
  /// treats it as "oldest seq currently in memory" and re-arms it from the
  /// in-memory minimum whenever it is 0 or null.
  ///
  /// Without this marker the two writers form a loop driven purely by tail
  /// traffic: walk back to 0 -> a new tail message arrives -> the newest-N
  /// trim in `_upsertSessionMessages` drops the oldest rows -> the in-memory
  /// minimum rises -> `_ensureFirstLoadedSeq` writes a fresh non-zero
  /// boundary -> `hasOlderMessages` flips back to true -> the orphan sweep
  /// re-downloads history the client already had and discarded. Unbounded.
  ///
  /// Deliberately in-memory only: a restart restores full scroll-back for a
  /// user who wants to page through the beginning again. Cleared when the
  /// session is deleted.
  final Set<String> _sessionsHistoryFullyLoaded = {};

  /// Sessions whose in-memory message window has ever dropped rows to the
  /// newest-N trim in `_upsertSessionMessages`.
  ///
  /// Once any fetched row has been discarded, "the whole history is
  /// resident" can no longer be claimed honestly, so a walk-back that later
  /// reaches seq 0 must not pin [_sessionsHistoryFullyLoaded] or write
  /// `_sessionFirstLoadedSeq[sessionId] = 0` — that flips [hasOlderMessages]
  /// false over a tail-only window and the chat renders "Beginning of
  /// conversation" with the rest of the transcript hidden behind a dead
  /// scroll-back. Observed in production 2026-08-03: a 13k-seq session
  /// showed only its newest ~200 rows after a 2.5h orphan walk-back whose
  /// pages were trimmed as fast as they arrived.
  ///
  /// In-memory only, mirroring [_sessionsHistoryFullyLoaded]: a restart
  /// re-derives it from the first trim that actually happens. Cleared when
  /// the session is deleted.
  final Set<String> _sessionsHistoryTrimmed = {};

  /// Sessions that received socket messages while non-visible.
  /// Used to force a server fetch (instead of stale cache restore) when
  /// the user opens a session that had pending socket messages.
  final Set<String> _sessionsWithPendingSocketMessages = {};

  /// Lowest cursor observed before a socket burst that needs authoritative
  /// HTTP verification.
  ///
  /// Inline socket processing advances [_sessionLastSeq] to a high-water
  /// mark. If the chat is hidden, or seq N+2 arrives before N+1, reopening
  /// from that high-water mark permanently skips the missing lower seq. Keep
  /// the pre-burst cursor so [fetchMessages] overlaps the socket window and
  /// recovers any dropped or out-of-order events without duplicating rows.
  final Map<String, int> _sessionSocketCatchUpAfterSeq = {};

  /// Sessions whose rows came from the persisted message cache this process.
  final Set<String> _sessionsRestoredFromMessageCache = {};

  /// Cached sessions currently running the one-time upgrade repair overlap.
  final Set<String> _sessionsNeedingLegacySocketGapRepair = {};

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

  /// `localId`s the client stopped waiting on (its own send deadline), not
  /// ones the server rejected. When the outbox retry then confirms the
  /// message was already persisted, the send is reported as slow rather
  /// than degraded. Bounded FIFO: a send that never comes back is simply
  /// forgotten.
  final Set<String> _sendDeadlineLocalIds = {};
  final Queue<String> _sendDeadlineLocalIdOrder = Queue<String>();
  static const int _maxSendDeadlineLocalIds = 64;

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

  /// Cursor sequence associated with the last visible no-embed probe per
  /// session.
  final Map<String, int> _lastNoEmbedEventCursorSeq = {};

  /// Epoch-ms of the last machineRPC SLOW/FAILED Sentry capture, keyed by
  /// `<machineId>:<method>:<kind>`. A single wedged daemon previously
  /// minted a fresh Sentry issue on every retry (elapsedMs interpolated
  /// into the message defeated grouping). This throttles captures to at
  /// most one per key per [_machineRpcWarnCooldownMs]; the local
  /// logger.warning still fires every time so the signal is not lost.
  final Map<String, int> _lastMachineRpcWarnMs = {};

  /// Sessions that have an explicit reason to probe the messages API even when
  /// the local cursor appears caught up to session.lastSeq.
  ///
  /// This is used for cases where the app knows a new message may exist but
  /// the sessions snapshot can legitimately lag behind message storage:
  /// visible `new-message` events without an embedded payload and post-send
  /// catch-up polling after a successful user send.
  final Set<String> _sessionsNeedingFetchProbe = <String>{};

  /// Ordered recovery intents waiting for an authoritative message fetch.
  ///
  /// The order token avoids millisecond-clock ambiguity: a fetch can satisfy
  /// an intent only when its HTTP request started strictly after that intent.
  /// [requiredAfterSeq] pins the oldest cursor floor the fetch must cover, so
  /// a newer tail request cannot accidentally suppress reconnect gap repair.
  final Map<String, ({int order, int requiredAfterSeq})>
  _messageFetchProbeIntents = <String, ({int order, int requiredAfterSeq})>{};

  /// Coverage of the most recent successfully processed HTTP page per
  /// session. The stored floor is the first page's `after_seq` for the cycle,
  /// not its final cursor, so multi-page recovery retains its full overlap.
  final Map<String, ({int requestOrder, int verifiedAfterSeq})>
  _messageFetchCoverage =
      <String, ({int requestOrder, int verifiedAfterSeq})>{};
  int _messageFetchWorkOrder = 0;

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
  bool _criticalSyncManagersInitialized = false;

  // State tracking
  bool revenueCatInitialized = false;
  bool isInitialized = false;
  bool _isReady = false;
  // Account/runtime epoch. Every asynchronous state commit captures this
  // value and must abandon work after logout or a subsequent restore.
  int _runtimeGeneration = 0;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  // Pending settings
  final Map<String, List<Map<String, dynamic>>> _sessionMessages = {};
  final Map<String, Map<String, String?>> _sessionContentSignatures = {};

  /// Read-only view of the decrypt pre-filter's per-session signature map.
  @visibleForTesting
  Map<String, String?> testContentSignatures(String sessionId) =>
      Map.unmodifiable(
        _sessionContentSignatures[sessionId] ?? const <String, String?>{},
      );
  Map<String, List<Map<String, dynamic>>>? _sessionMessagesCache;

  /// Cached preview metadata per session — avoids rescanning
  /// the full message list on every session-card build.
  /// Invalidated when messages change via [_invalidatePreviewCache].
  final Map<
    String,
    ({int? timestamp, String? preview, String? role, bool isError})
  >
  _previewCache = {};

  /// Identity of the message list when the preview was computed.
  final Map<String, int> _previewCacheVersion = {};
  final Map<String, List<Map<String, dynamic>>> _sessionMessagesViewCache = {};

  /// Monotonic per-session message revision, bumped on every real
  /// message-list change (see [_notifySessionMessagesChanged]). Lets the
  /// chat UI detect in-place edits that an identical()/tail-fingerprint
  /// comparison would otherwise miss.
  final Map<String, int> _sessionMessagesRevision = {};
  final Map<String, Map<String, dynamic>> _sessionUsage = {};
  Map<String, Session> _sessions = <String, Session>{};
  int? _lastSessionsFetchedAt;
  bool _forceFullFetchNext = false;
  int? _lastInvalidateAllSyncsAtMs;

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

  /// Timestamp of the last successful settings POST.  Delegated to
  /// [SettingsManager].
  int? get lastSettingsPostAtMs => settingsManager?.lastSettingsPostAtMs;

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

  /// Delay before the socket is actually disconnected on suspend. Short
  /// Android lifecycle bounces commonly produce hidden/inactive/resumed
  /// transitions within tens of milliseconds; disconnecting immediately turns
  /// those into reconnect storms.
  static const int _suspendSocketDisconnectDelayMs = 2000;

  /// Delay before the reconnection watchdog fires on resume. If the
  /// socket hasn't connected by this point, force a fresh reconnect
  /// cycle to recover from exhausted Socket.IO attempts. The watchdog
  /// re-arms itself after each fire while the socket stays disconnected
  /// (cancelled on connect, suspend, or shutdown), so recovery time is
  /// bounded by this interval instead of waiting out full Socket.IO
  /// 10-attempt backoff cycles.
  static const int _reconnectWatchdogDelayMs = 15000;

  /// How long a backgrounded socket may sit idle before resume() treats a
  /// "connected" status as a zombie and forces a fresh connection. The
  /// server-side Socket.IO session dies ~45s after the client stops
  /// heartbeating (ping interval + ping timeout), and the client cannot
  /// notice while the isolate is suspended. When the OS suspends the app
  /// faster than [_suspendSocketDisconnectDelayMs] (common on iOS), the
  /// deferred disconnect never fires and resume() would otherwise trust
  /// the stale status, skipping both the reconnect and the watchdog.
  ///
  /// Aligned with the ~45s server-side death (was 60s): the previous 60s
  /// left a 45-60s dead zone where the server session was already gone
  /// but the client still trusted "connected", so the app showed live
  /// status yet received no updates until the next ping timeout. A
  /// false-positive here only costs one cheap forced reconnect, so we
  /// bias the threshold down to the server-death boundary.
  static const int _zombieSocketMaxIdleMs = 45 * 1000;

  /// Minimum interval between broad sessions/catalog refreshes caused by
  /// socket reconnect recovery. Visible chat messages are refreshed on every
  /// reconnect; the expensive `/v2/sessions` recovery path is capped so a
  /// flaky transport cannot keep the radio awake with repeated catalog fetches.
  static const int _reconnectGlobalInvalidationCooldownMs = 60 * 1000;

  /// Socket outages shorter than this recover on reconnect with only the
  /// critical catalogs (sessions + machines); outages at least this long,
  /// or with an untracked start, also refresh the deferred/background
  /// domains (settings, profile, purchases, native update, git status).
  /// A flapping connection must not re-fetch settings and purchases every
  /// 60 seconds; a five-minute outage plausibly missed server-side
  /// changes in them.
  static const int _reconnectLongOutageThresholdMs = 5 * 60 * 1000;

  /// Timestamp of the last connected → not-connected transition observed
  /// by the status listener. Null while connected or when no transition
  /// has been seen this process; drives [_reconnectLongOutageThresholdMs].
  int? _socketDisconnectedAtMs;

  /// Base delay before phase-1 (deferred) syncs fire after phase-0
  /// (sessions). Was `Duration.zero` — fired on the very next event-loop
  /// tick, which meant every global invalidation queued sessions, machines,
  /// settings, and profile fetches (plus their socket RPCs) into the same
  /// microtask burst. A small stagger spreads the radio-busy window without
  /// adding visible latency. Combined with [_deferredSyncPhaseJitterMs] for
  /// some randomness so concurrent devices/sessions don't line up either.
  static const int _deferredSyncPhaseBaseDelayMs = 150;
  static const int _deferredSyncPhaseJitterMs = 150;
  static final Random _syncPhaseJitterRng = Random();

  /// Delay before firing network invalidations on resume. Cancelled by
  /// suspend() so that rapid foreground/background cycling does not produce
  /// wasted HTTP requests that the OS aborts mid-flight.
  Timer? _deferredSocketDisconnectTimer;
  Timer? _deferredResumeInvalidationTimer;
  Timer? _reconnectWatchdogTimer;

  /// Consecutive watchdog fires since the last deliberate reconnect entry
  /// point (resume / manual) or the last observed connection. Drives the
  /// watchdog's exponential backoff; reset whenever the socket connects so
  /// an unrelated later outage starts from the fast 15s probe again.
  int _reconnectWatchdogAttempt = 0;
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

  /// How long resume waits for the sessions/messages sync queues to settle
  /// before continuing anyway.
  ///
  /// Was 6 s, another descendant of the 8 s page-fetch number: it awaits a
  /// whole sync *queue* (sessions refresh plus a batch of per-session
  /// message fetches), not one HTTP page, so it was almost always tripping
  /// and logging a false "resume refresh did not settle". 15 s covers a
  /// normal resume batch on mobile without letting a wedged queue hold the
  /// resume path open indefinitely.
  static const Duration _resumeSessionsAwaitTimeout = Duration(seconds: 15);

  /// [_resumeSessionsAwaitTimeout], exposed so resume-progress tests advance
  /// fake time by the real budget instead of a stale literal.
  @visibleForTesting
  static const Duration resumeSessionsAwaitTimeoutForTesting =
      _resumeSessionsAwaitTimeout;
  Timer? _sessionsRefreshDebounceTimer;
  Timer? _artifactsSyncDebounceTimer;
  final Set<String> _pendingNewSessionIds = <String>{};
  final Map<String, Machine> _machines = <String, Machine>{};
  // Timers that drop presence back to 'offline' if no activity arrives.
  final Map<String, Timer> _presenceTimers = {};
  final Map<String, GitStatus> _sessionGitStatus = <String, GitStatus>{};

  // Change notification streams
  final _dataChangeController = StreamController<void>.broadcast();
  final _domainChangeController = StreamController<SyncDomain>.broadcast();
  final _sessionMessageChangeController = StreamController<String>.broadcast();
  final _paginationErrorController = StreamController<String>.broadcast();
  final _syncStateController = StreamController<void>.broadcast();
  final _autoRestoreFailureController =
      StreamController<AutoRestoreFailure>.broadcast();
  int _activeSyncCount = 0;
  SyncProgress? _syncProgress;
  final Map<String, int> _runningSyncNames = {};
  Timer? _dataChangeDebounceTimer;
  final Map<SyncDomain, Timer> _domainChangeDebounceTimers = {};
  final Map<String, Timer> _sessionMessageDebounceTimers = {};
  final Set<String> _sessionMessagePendingTrailing = {};
  final Set<SyncDomain> _domainChangePendingTrailing = {};

  /// Monotonic counter incremented on every data change. Providers compare
  /// this against their last-seen value to skip expensive equality checks
  /// when nothing has changed.
  int _dataChangeCounter = 0;

  /// Monotonic counter incremented on every message-list mutation across all
  /// sessions. See [messagesChangeCounter].
  int _messagesChangeCounter = 0;
  final Map<SyncDomain, int> _domainChangeCounters = {
    for (final domain in SyncDomain.values) domain: 0,
  };
  Timer? _saveSeqDebounceTimer;
  bool _saveFirstLoadedSeqQueued = false;
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

  /// Per-session count of consecutive orphan-recovery fetchOlder attempts
  /// that did not reduce the orphan set. Resets when a fetchOlder page
  /// actually attaches orphans or when the persisting orphan set changes
  /// (tracked via [_orphanWalkbackOrphanIds]). Used to cap the aggressive
  /// walk-back so a session whose parent Task is genuinely missing cannot
  /// poll the server indefinitely.
  final Map<String, int> _orphanFetchOlderNoProgressCount = {};

  /// Per-session orphan-id set seen by the last deferred regroup sweep.
  /// Paired with [_orphanWalkbackParentKeys] to decide whether a fresh
  /// walk-back budget (no-progress reset + suppression lifted) is
  /// granted: only when some previously-unresolved orphan id disappeared
  /// (resolved/attached), or a newly-arrived orphan belongs to a parent
  /// Task group not already tracked (a genuinely new, unrelated burst).
  /// Pure growth of an ALREADY-TRACKED parent group — more children of
  /// the same un-found Task arriving, every previously-seen id still
  /// present — must NOT grant a fresh budget: that was a real production
  /// bug where a single stuck subagent kept emitting child sidechain
  /// messages (new ids every sweep, same parentToolUseId) and the old
  /// id-set-changed check reset the no-progress counter to 0 every time,
  /// so the hard cap below was never reached and the walk-back hammered
  /// fetchOlderMessages indefinitely. This must also NOT be reset by
  /// message upserts — the walk-back's own fetchOlder upserts every page
  /// it fetches, and a blanket reset pinned the no-progress counter below
  /// both caps, looping fetchOlder forever.
  final Map<String, Set<String>> _orphanWalkbackOrphanIds = {};

  /// Per-session set of parent Task group keys (see
  /// [WireParsers.sidechainParentToolUseId]) seen across the orphans
  /// tracked by [_orphanWalkbackOrphanIds] as of the last sweep. A newly
  /// arrived orphan whose parent key is not in this set is a genuinely
  /// new burst and grants a fresh walk-back budget even while an older,
  /// stuck parent group's orphans are still pending — see
  /// [_orphanWalkbackOrphanIds] for why pure growth of an already-tracked
  /// group must NOT do the same.
  final Map<String, Set<String>> _orphanWalkbackParentKeys = {};

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
  // detect profile changes and respawn the session automatically.
  final Map<String, String?> _sessionSpawnedProfile = {};
  // sessionId → modelMode used when spawning. Lets _resolveSendTargetSession
  // detect model changes and respawn the session automatically.
  final Map<String, String?> _sessionSpawnedModel = {};
  // sessionId → agent used when spawning. Used as fallback when
  // session.metadata?.flavor is null (e.g., metadata decryption failed)
  // so auto-restore uses the correct agent instead of defaulting to 'claude'.
  final Map<String, String> _sessionSpawnedAgent = {};

  /// Captured `Hint.withMap({...})` payloads from the spawn-readiness
  /// timeout `Sentry.captureMessage` branch. Production writes via the
  /// helper in `_sync_messaging_send.dart`; tests read through
  /// `testSpawnReadinessTimeoutCaptures`.
  final List<Map<String, Object?>> _spawnReadinessTimeoutCaptures = [];

  /// Funnel all spawn-metadata writes through a single helper so the four
  /// `_sessionSpawned*` maps stay in lock-step and `wasRecentlySpawned` /
  /// `_resolveSendTargetSession` agree on the same anchor time.
  ///
  /// Pass [at] when the caller already has the canonical spawn epoch
  /// (e.g. a session recovered via `found.createdAt` after a webhook
  /// timeout); otherwise the helper stamps `DateTime.now()`. [agent] is
  /// stored verbatim; [profileId] / [modelMode] accept null when the
  /// caller cannot resolve them yet (caller is responsible for updating
  /// those entries later if needed — see `_sync_operations_session.dart`
  /// auto-restore path).
  void _registerSpawn(
    String sessionId, {
    String? profileId,
    String? modelMode,
    String? agent,
    DateTime? at,
  }) {
    final atMs = (at ?? DateTime.now()).millisecondsSinceEpoch;
    _sessionSpawnedAt[sessionId] = atMs;
    if (profileId != null) {
      _sessionSpawnedProfile[sessionId] = profileId;
    }
    if (modelMode != null) {
      _sessionSpawnedModel[sessionId] = modelMode;
    }
    if (agent != null) {
      _sessionSpawnedAgent[sessionId] = agent;
    }
  }

  // machineId → epoch-ms of last offline warning. Deduplicates the
  // "Machine appears offline" warning that fires on every createSession().
  final Map<String, int> _machineOfflineWarnedAtMs = {};
  // Sessions whose DEK failed to decrypt and fell back to legacy NaCl —
  // captured to Sentry once per session per app run so DEK-fallback
  // sessions can be correlated with later CryptoSecretBox.decrypt
  // failures (scope=session:<id>:messages). DEK decryption re-runs on
  // every fetchSessions, so without this set the capture would repeat.
  final Set<String> _dekFallbackCaptured = {};
  // Live runtime guard for the chat-send contract. Observes the merge / ack
  // / retry path and forwards typed, per-session-rate-limited violations to
  // Sentry. Pure observation — never changes send behavior. See
  // `message_invariant_monitor.dart`.
  final MessageInvariantMonitor messageInvariantMonitor =
      MessageInvariantMonitor();
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
  ///
  /// Bounded: entries are FIFO-capped at [maxPendingToolResultsPerSession]
  /// and expire after [pendingToolResultTtlMs]. A result whose tool-call was
  /// trimmed out of the resident window is permanently unmatchable — without
  /// these bounds the queue grew for the process lifetime and was re-scanned
  /// against every resident row on every socket batch and fetch page.
  final Map<String, List<Map<String, dynamic>>> _pendingToolResults = {};

  /// FIFO cap for [_pendingToolResults] per session.
  static const int maxPendingToolResultsPerSession = 200;

  /// Max age of a queued tool result before it is dropped as unmatchable.
  static const int pendingToolResultTtlMs = 10 * 60 * 1000;

  /// Local-clock stamp key added to queued copies in [_pendingToolResults].
  /// Ignored by the matcher; never leaves the process.
  static const String pendingToolResultQueuedAtKey = 'pendingQueuedAtMs';

  /// Overrides the clock used for [_pendingToolResults] TTL pruning.
  @visibleForTesting
  int? testPendingToolResultNowMsOverride;
  @visibleForTesting
  bool? testSocketConnectedOverride;
  @visibleForTesting
  Duration? testRefreshAllLoopsDeadline;
  @visibleForTesting
  void Function(String event, dynamic data)? testSocketSendOverride;
  @visibleForTesting
  Future<void>? lastCompleteSendFuture;

  List<DecryptedArtifact> get artifacts =>
      List.unmodifiable(artifactManager?.artifacts ?? []);

  /// Get usage data for a session (contextSize, inputTokens, outputTokens).
  Map<String, Map<String, dynamic>> get sessionUsage =>
      Map.unmodifiable(_sessionUsage);
  // Test-only fallback for settings snapshot. Allows tests that set
  // [testSettingsSnapshot] before [settingsManager] is instantiated to
  // still read the snapshot through the public getter.
  Settings? _testSettingsSnapshot;

  // Test-only fallback for pending settings, mirroring _testSettingsSnapshot.
  Map<String, dynamic>? _testPendingSettings;

  /// Current settings snapshot.
  Settings get settingsSnapshot =>
      settingsManager?.settingsSnapshot ?? _testSettingsSnapshot ?? Settings();
  int get settingsVersion => settingsManager?.settingsVersion ?? 0;
  Purchases get purchases => settingsManager?.purchases ?? Purchases.defaults;
  Map<String, Session> get sessions => Map.unmodifiable(_sessions);

  /// Zero-copy read-only view of the sessions catalog.
  ///
  /// [sessions] copies every entry per access — at 251+ sessions that is
  /// real garbage on paths that run per message tick or timer tick. This
  /// view is live: read it synchronously and do not hold it across awaits.
  Map<String, Session> get sessionsView => UnmodifiableMapView(_sessions);

  /// Single-session lookup without copying the whole catalog.
  Session? sessionById(String sessionId) => _sessions[sessionId];

  /// Zero-copy read-only view of per-session usage. Live — same rules as
  /// [sessionsView]. Inner maps are replaced wholesale on update, so a held
  /// inner map is safely immutable.
  Map<String, Map<String, dynamic>> get sessionUsageView =>
      UnmodifiableMapView(_sessionUsage);

  /// Number of sessions held in memory without allocating a map view.
  ///
  /// Performance telemetry reads this on every frame-metrics flush, so it
  /// should not call [sessions] merely to ask for its length.
  int get sessionCount => _sessions.length;

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

  /// Test hook fired whenever [_requestTailRefresh] is called.
  /// Tests can use this to observe tail-refresh requests without racing
  /// [fetchMessages], which removes the session from
  /// [_sessionsNeedingTailRefresh] before the assertion can run.
  @visibleForTesting
  void Function(String sessionId)? onTailRefreshRequested;

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

  /// Whether [sessionId] has been paginated back to seq 0, which pins
  /// [_sessionFirstLoadedSeq] against re-arming. See
  /// [_sessionsHistoryFullyLoaded].
  @visibleForTesting
  bool testHistoryFullyLoaded(String sessionId) =>
      _sessionsHistoryFullyLoaded.contains(sessionId);

  /// Drops the "history fully loaded" pin for [sessionId] so tests sharing
  /// the [Sync] singleton stay isolated.
  @visibleForTesting
  void testClearHistoryFullyLoaded(String sessionId) {
    _sessionsHistoryFullyLoaded.remove(sessionId);
  }

  /// Whether the newest-N trim has ever discarded rows for [sessionId].
  /// See [_sessionsHistoryTrimmed].
  @visibleForTesting
  bool testHistoryTrimmed(String sessionId) =>
      _sessionsHistoryTrimmed.contains(sessionId);

  /// Drops the "history was trimmed" ledger entry for [sessionId] so tests
  /// sharing the [Sync] singleton stay isolated.
  @visibleForTesting
  void testClearHistoryTrimmed(String sessionId) {
    _sessionsHistoryTrimmed.remove(sessionId);
  }

  /// Override _typedMachineRPC for testing createSession and
  /// auto-restore without a real socket connection.
  @visibleForTesting
  Future<dynamic> Function(
    String machineId,
    String method,
    Map<String, dynamic> params,
  )?
  testMachineRPCOverride;

  /// Override [sessionRPC] for tests that need to observe or stub
  /// session-scoped agent RPC calls such as abort/kill.
  @visibleForTesting
  Future<dynamic> Function(
    String sessionId,
    String method,
    Map<String, dynamic> params,
  )?
  testSessionRPCOverride;

  /// Override [SyncMessagingRpc.ensureMachineReachable] for testing the
  /// pre-flight liveness probe without a real socket connection.
  @visibleForTesting
  Future<void> Function(String machineId)? testEnsureMachineReachableOverride;

  /// Override the raw RPC call inside [SyncMessagingRpc.ensureMachineReachable]
  /// so the retry loop can be exercised without a real socket connection.
  /// Generic [testMachineRPCOverride] stubs continue to short-circuit the
  /// probe to avoid breaking createSession tests that do not care about pings.
  @visibleForTesting
  Future<dynamic> Function(
    String machineId,
    String method,
    Map<String, dynamic> params,
  )?
  testEnsureMachineReachableMachineRPCOverride;

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

  /// Mutable spawn agent map — use in agent change tests.
  @visibleForTesting
  Map<String, String> get testSessionSpawnedAgent => _sessionSpawnedAgent;

  /// Mutable pending-updates set.
  @visibleForTesting
  Set<String> get testSessionsWithPendingUpdates => _sessionsWithPendingUpdates;

  /// Mutable ephemeral timestamps map.
  @visibleForTesting
  Map<String, int> get testLastEphemeralAt => _lastEphemeralAt;

  /// Mutable loops-by-session map — use in tests that need to seed loop state.
  @visibleForTesting
  Map<String, List<Loop>> get testLoopsBySession => _loopsBySession;

  /// In-memory mirror of `Map<sessionId, List<Loop>>`. Populated by socket
  /// events; persisted to MMKV via [LoopStorage].
  final Map<String, List<Loop>> _loopsBySession = <String, List<Loop>>{};

  /// Broadcast stream that fires when the loops for a session change.
  /// Subscribers receive the sessionId so they can refresh only the
  /// affected view.
  final StreamController<String> _loopsChangeController =
      StreamController<String>.broadcast();

  /// Mutable workflows-by-session map — use in tests that need to seed
  /// workflow state.
  @visibleForTesting
  Map<String, List<WorkflowRun>> get testWorkflowsBySession =>
      _workflowsBySession;

  /// In-memory mirror of `Map<sessionId, List<WorkflowRun>>`. Populated by
  /// RPC fetches; persisted to MMKV via [WorkflowStorage].
  final Map<String, List<WorkflowRun>> _workflowsBySession =
      <String, List<WorkflowRun>>{};

  /// Broadcast stream that fires when the workflow runs for a session change.
  /// Subscribers receive the sessionId so they can refresh only the affected
  /// view.
  final StreamController<String> _workflowsChangeController =
      StreamController<String>.broadcast();

  /// One in-flight list request per session. Workflow surfaces can mount at
  /// the same time (for example the sessions shell and a detail screen), so
  /// sharing the request prevents duplicate session RPCs.
  final Map<String, Future<void>> _workflowRefreshesInFlight =
      <String, Future<void>>{};

  /// One in-flight snapshot request per run. The same run can be visible in
  /// the chat inline surface and the workflow detail route simultaneously;
  /// sharing the RPC prevents duplicate polling work on both client and
  /// daemon.
  final Map<(String, String), Future<WorkflowRun?>>
  _workflowSnapshotFetchesInFlight = <(String, String), Future<WorkflowRun?>>{};

  /// Capability keys for daemons that do not implement `workflow-list`.
  /// Keys prefer machine id so one unsupported response suppresses retries
  /// for every session owned by the same daemon. Values are epoch-ms
  /// expiration timestamps so a machine that upgrades to a capable daemon
  /// is re-probed after the capability TTL or a socket reconnect.
  final Map<String, int> _workflowListUnsupportedCapabilities = <String, int>{};

  /// Capability keys for daemons that do not implement `loop-list`.
  /// Keys prefer machine id so one unsupported response suppresses retries
  /// for every session owned by the same daemon.
  final Set<String> _loopListUnsupportedCapabilities = <String>{};

  /// Short per-session retry suppression after transient failures.
  final Map<String, int> _workflowRefreshBackoffUntil = <String, int>{};
  final Map<String, int> _workflowRefreshFailureCount = <String, int>{};

  /// Capability manifests are valid only for a single socket generation.
  final Map<String, RpcCapabilities> _rpcCapabilitiesCache =
      <String, RpcCapabilities>{};

  /// Capability discovery is a feature-gating hint, not the feature RPC
  /// itself. Share one probe per scoped handler/version identity so several
  /// mounting surfaces cannot each spend a socket ACK timeout discovering the
  /// same daemon manifest.
  final Map<String, Future<RpcCapabilities?>> _rpcCapabilityProbesInFlight =
      <String, Future<RpcCapabilities?>>{};

  /// Cross-generation cooldown for legacy/temporarily unreachable handlers.
  /// The key includes the advertised daemon version, so an upgrade bypasses
  /// the old negative entry immediately; expiry still re-probes daemons that
  /// cannot advertise a version.
  final Map<String, int> _rpcCapabilityNegativeUntil = <String, int>{};
  final Map<String, int> _rpcCapabilityFailureCount = <String, int>{};
  int _rpcCapabilityPolicyEpoch = 0;

  /// Machine model catalogs are read-only and change only when the daemon or
  /// installed Codex CLI changes. Chat rebuilds can request the catalog many
  /// times, so share the transport and retain a bounded result instead of
  /// putting every rebuild through capability discovery + a socket ACK.
  final Map<String, CodexModelsResponse> _codexModelsCache =
      <String, CodexModelsResponse>{};
  final Map<String, int> _codexModelsCacheAtMs = <String, int>{};
  final Map<String, Future<CodexModelsResponse>> _codexModelsInFlight =
      <String, Future<CodexModelsResponse>>{};

  /// Test seam around the encrypted capability transport. Production uses
  /// [machineRPC]/[sessionRPC]; tests can assert policy without constructing
  /// encryption or a live Socket.IO connection.
  @visibleForTesting
  Future<dynamic> Function(String scope, String id, Duration timeout)?
  testRpcCapabilitiesOverride;

  @visibleForTesting
  Duration? testRpcCapabilityProbeTimeout;

  @visibleForTesting
  Duration? testRpcCapabilityLegacyTtl;

  @visibleForTesting
  Duration? testRpcCapabilityTransientBackoffBase;

  @visibleForTesting
  int Function()? testRpcCapabilityNowMs;

  /// Test override for the [SyncWorkflows.refreshAllWorkflows] deadline.
  @visibleForTesting
  Duration? testRefreshAllWorkflowsDeadline;

  /// Test override for the workflow-list unsupported capability TTL.
  @visibleForTesting
  Duration? testWorkflowUnsupportedCapabilityTtl;

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
    _sessionSocketCatchUpAfterSeq.clear();
    _sessionsRestoredFromMessageCache.clear();
    _sessionsNeedingLegacySocketGapRepair.clear();
  }

  Map<String, Machine> get machines => Map.unmodifiable(_machines);
  Profile? get profile => settingsManager?.profile;
  bool get isReady => _isReady;
  bool get isEncryptionInitialized => _encryptionInitialized;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String? get nativeUpdateUrl => settingsManager?.nativeUpdateUrl;
  bool get hasNativeUpdate => settingsManager?.nativeUpdateUrl != null;
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

  /// Monotonic revision for a session's message list, bumped on every real
  /// mutation. Subscribers compare it to detect in-place content changes
  /// that an identical()/tail-fingerprint check cannot see.
  int messagesRevision(String sessionId) =>
      _sessionMessagesRevision[sessionId] ?? 0;

  void _bumpMessagesRevision(String sessionId) {
    _sessionMessagesRevision[sessionId] =
        (_sessionMessagesRevision[sessionId] ?? 0) + 1;
    _messagesChangeCounter++;
  }

  /// Invalidate the cached all-sessions snapshot and the per-session
  /// message view so the next read rebuilds from [_sessionMessages].
  /// Call after any in-place mutation of a session's message list.
  void _invalidateMessageCaches(String sessionId) {
    _sessionMessagesCache = null;
    _sessionMessagesViewCache.remove(sessionId);
    // Every message-window mutation flows through here — the touch stamp
    // is what keeps the idle-window shrink sweep away from live sessions.
    _sessionMessagesTouchedAtMs[sessionId] =
        testIdleShrinkNowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
  }

  /// Returns the messages for a single session without copying all sessions.
  List<Map<String, dynamic>> messagesForSession(String sessionId) =>
      _sessionMessagesViewCache.putIfAbsent(
        sessionId,
        () => List<Map<String, dynamic>>.unmodifiable(
          _sessionMessages[sessionId] ?? const <Map<String, dynamic>>[],
        ),
      );

  /// Returns the number of currently-loaded orphan sidechain messages for a
  /// session — messages whose `isSidechain` flag is set and whose parent
  /// Task is NOT in the loaded window. These render inline as their own
  /// top-level subagent tiles until the parent Task arrives and grouping
  /// can attach them.
  ///
  /// O(n) over the loaded message list; results are NOT cached because
  /// the underlying list mutates frequently (upserts, regroup sweeps,
  /// history fetches). The scan is bounded by [_maxCachedMessages] = 200.
  int orphanCountForSession(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) return 0;
    var count = 0;
    for (final m in messages) {
      if (isVisibleSidechainOrphan(m)) count++;
    }
    return count;
  }

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

  /// Returns whether the last previewable message in [sessionId] was an
  /// error (wire `isError` flag, or the CLI's conventional `API Error:`
  /// text prefix when the daemon does not flag it).
  bool getLastMessageIsError(String sessionId) =>
      _ensurePreviewCache(sessionId).isError;

  /// Invalidates the preview cache for a session so the next call
  /// to [getLastMessagePreview] etc. will rescan.
  void _invalidatePreviewCache(String sessionId) {
    _previewCache.remove(sessionId);
    _previewCacheVersion.remove(sessionId);
  }

  ({int? timestamp, String? preview, String? role, bool isError})
  _ensurePreviewCache(String sessionId) {
    final messages = _sessionMessages[sessionId];
    if (messages == null || messages.isEmpty) {
      return (timestamp: null, preview: null, role: null, isError: false);
    }
    // Use list identity + length as a cheap version check.
    final version = identityHashCode(messages) ^ messages.length;
    if (_previewCacheVersion[sessionId] == version) {
      return _previewCache[sessionId]!;
    }

    // Compute all fields in a single backward scan.
    final timestamp = messages.last['createdAt'] as int?;
    String? preview;
    String? role;
    String? toolFallback;
    String? toolFallbackRole;
    var isError = false;
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
      // Synthetic agent API errors render as error cards carrying the
      // human-readable failure in errorMessage — feed the error lane
      // from them instead of skipping to an older message.
      if (kind == 'error') {
        final errorText = msg['errorMessage'] as String?;
        if (msgRole == MessageRole.agent &&
            errorText != null &&
            errorText.trim().isNotEmpty) {
          preview = _cleanPreviewText(errorText.trim());
          role = msgRole;
          isError = true;
          break;
        }
        continue;
      }
      final text = (msg['content'] ?? msg['text']) as String?;
      if (text != null && text.trim().isNotEmpty) {
        preview = _cleanPreviewText(text.trim());
        role = msgRole;
        // Only text messages mark the error lane — a failed tool result
        // is routine agent self-correction, not a stalled session.
        isError = msg['isError'] == true || text.trim().startsWith('API Error');
        break;
      }
    }
    preview ??= toolFallback;
    role ??= toolFallbackRole ?? (sawToolCall ? MessageRole.agent : null);

    final result = (
      timestamp: timestamp,
      preview: preview,
      role: role,
      isError: isError,
    );
    _previewCache[sessionId] = result;
    _previewCacheVersion[sessionId] = version;
    return result;
  }

  static const _kPreviewMaxLen = 120;

  String? _toolPreview(Map<String, dynamic> message) {
    final name = message['name'] as String?;
    if (name == null || name.isEmpty) return null;
    final target = _toolTargetHint(message['input']);
    return _cleanPreviewText(
      target == null ? 'Used $name' : 'Used $name · $target',
    );
  }

  /// Best-effort one-line hint of what a tool call operated on, so
  /// session rows read "Used Bash · rg mission" instead of "Used Bash".
  static String? _toolTargetHint(Object? input) {
    if (input is! Map) return null;
    for (final key in const [
      'command',
      'file_path',
      'path',
      'pattern',
      'url',
      'description',
    ]) {
      final value = input[key];
      if (value is String && value.trim().isNotEmpty) {
        final hint = value.trim();
        return hint.length > 60 ? '${hint.substring(0, 60)}…' : hint;
      }
    }
    return null;
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

  /// Emits a `sync.on_data_changed` OTel span that wraps the firehose
  /// tick. Use this from the call sites that mutate sync state
  /// instead of `_dataChangeController.add(null)` directly so the
  /// span timing matches the actual broadcast.
  void _emitDataChangeSpan() {
    final active = OpenTelemetryService().currentSpan;
    final span = active != null
        ? OpenTelemetryService().startChildSpan(
            'sync.on_data_changed',
            parent: active,
            kind: SpanKind.internal,
            attributes: {'data_change_counter': _dataChangeCounter},
          )
        : OpenTelemetryService().startTrace(
            'sync.on_data_changed',
            kind: SpanKind.internal,
            attributes: {'data_change_counter': _dataChangeCounter},
          );
    // Spans are short — the data tick itself is synchronous and
    // the span is consumed by listeners. End immediately; downstream
    // spans (e.g. subagent.spawn from the banner's reconciler) will
    // be parented to whatever active span is set *next*.
    span?.end(ok: true);
  }

  /// Stream that emits the specific domain that changed.
  Stream<SyncDomain> get onDomainChanged => _domainChangeController.stream;

  /// Monotonic counter incremented on every data change notification.
  /// Providers compare this to skip expensive equality checks.
  int get dataChangeCounter => _dataChangeCounter;

  /// Monotonic counter incremented on every real message-list mutation, in
  /// any session. Unlike [messagesRevision] this is collection-wide, which
  /// is what a global "did anything change in this window?" check needs —
  /// see `FrameMetricsService` idle-render detection.
  int get messagesChangeCounter => _messagesChangeCounter;

  /// Monotonic counter for a specific domain.
  int domainChangeCounter(SyncDomain domain) =>
      _domainChangeCounters[domain] ?? 0;

  /// Stream that emits the sessionId when messages for that session change.
  Stream<String> get onSessionMessagesChanged =>
      _sessionMessageChangeController.stream;

  /// Stream that emits the sessionId when older-message pagination fails.
  /// ChatScreen listens to this to show an inline error or snackbar.
  Stream<String> get onPaginationError => _paginationErrorController.stream;

  /// Stream that emits an [AutoRestoreFailure] whenever an auto-restore
  /// attempt in `_resolveSendTargetSession` falls into the catch-all
  /// branch (neither transient, nor permanent, nor lifecycle-error).
  ///
  /// Previously the catch-all branch only logged at error level — the
  /// user-visible signal was lost and `_completeSend` POSTed to a
  /// broken session.  ChatScreen now subscribes to this stream to
  /// surface a snackbar and flip the optimistic message's
  /// `sendStatus` to `'failed'`.
  Stream<AutoRestoreFailure> get onAutoRestoreFailure =>
      _autoRestoreFailureController.stream;

  // ── Safe helpers for auto-restore failure observability ─────────────
  //
  // These are split out of the catch-all branch in
  // `_resolveSendTargetSession` so the call site stays readable, and
  // so unit tests can override each hook independently
  // (`testAutoRestoreFailureSink`).
  //
  // They are best-effort and must never throw — the catch-all branch
  // is already in an error path, and re-throwing here would mask the
  // real failure from the user.

  @visibleForTesting
  void Function(AutoRestoreFailure failure)? testAutoRestoreFailureSink;

  @visibleForTesting
  void Function(String name)? testRecordAppErrorSink;

  void _safeRecordAppError(String name) {
    final sink = testRecordAppErrorSink;
    if (sink != null) {
      try {
        sink(name);
      } catch (_) {
        // Test sinks must never propagate.
      }
      return;
    }
    try {
      PowerDiagnosticsOtelReporter.instance.recordAppError(name);
    } catch (_) {
      // OTel initialization failures must not break the host flow.
    }
  }

  void _safeEmitAutoRestoreFailure(AutoRestoreFailure failure) {
    final sink = testAutoRestoreFailureSink;
    if (sink != null) {
      try {
        sink(failure);
      } catch (_) {
        // Test sinks must never propagate.
      }
      return;
    }
    if (_autoRestoreFailureController.isClosed) return;
    _autoRestoreFailureController.add(failure);
  }

  /// Stream that emits whenever sync state changes (any sync starts or stops).
  Stream<void> get onSyncStateChanged => _syncStateController.stream;

  /// Whether any sync operation is currently running.
  bool get isSyncing => _activeSyncCount > 0;

  /// Whether essential catalog data failed after exhausting its retries.
  ///
  /// Sessions and machines drive the app's primary navigation and creation
  /// flows. Treating their cold-start failures as authoritative empty data
  /// makes a REST outage look like a healthy account with no machines.
  bool get hasUnrecoveredCriticalSyncFailure {
    if (!isInitialized || !_criticalSyncManagersInitialized) return false;
    return hasUnrecoveredSyncFailure(sessionsSync) ||
        hasUnrecoveredSyncFailure(machinesSync);
  }

  /// Human-readable sync progress for status UI.
  SyncProgress? get syncProgress {
    final explicit = _syncProgress;
    if (explicit != null) return explicit;
    if (_activeSyncCount <= 0 || _runningSyncNames.isEmpty) return null;
    return SyncProgress(label: _fallbackSyncLabel(_runningSyncNames.keys));
  }

  static String _fallbackSyncLabel(Iterable<String> names) {
    final sorted = names.toList()..sort();
    if (sorted.length == 1) {
      return 'Syncing ${_displayName(sorted.first)}';
    }
    final first = _displayName(sorted.first);
    return 'Syncing $first and ${sorted.length - 1} more';
  }

  static String _displayName(String name) {
    // Strip common prefixes so the label reads naturally.
    var base = name;
    if (base.startsWith('fetch')) {
      base = base.substring(5);
    } else if (base.startsWith('sync')) {
      base = base.substring(4);
    }
    if (base.isEmpty) return name;
    // Lower-case with leading capital, e.g. 'settings' -> 'Settings'.
    return '${base[0].toUpperCase()}${base.substring(1)}';
  }

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

  void _onSyncRunningChanged(String? name, bool isRunning) {
    if (isRunning) {
      _activeSyncCount++;
      if (name != null && name.isNotEmpty) {
        _runningSyncNames[name] = (_runningSyncNames[name] ?? 0) + 1;
      }
    } else {
      _activeSyncCount--;
      if (name != null && name.isNotEmpty) {
        final count = (_runningSyncNames[name] ?? 0) - 1;
        if (count <= 0) {
          _runningSyncNames.remove(name);
        } else {
          _runningSyncNames[name] = count;
        }
      }
      if (_activeSyncCount < 0) _activeSyncCount = 0;
      if (_activeSyncCount == 0) {
        _syncProgress = null;
        _runningSyncNames.clear();
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
        msg.contains('ApiClient not initialized') ||
        msg.contains('ApiClient was reconfigured during request startup') ||
        msg.contains('Machine encryption not found') ||
        msg.contains('operation has timed out');
  }

  /// Whether [error] indicates a machine/session RPC method that
  /// the daemon does not support (e.g. older daemon version).
  /// These are expected and should not be reported to Sentry.
  static bool _isRpcMethodNotAvailable(Object error) {
    if (error is RpcException) {
      return error.code == RpcErrorCode.methodUnsupported ||
          error.code == RpcErrorCode.protocolUnsupported ||
          error.code == RpcErrorCode.handlerOffline;
    }
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

  /// Whether [error] is an infra-side RPC forwarding failure that the
  /// client cannot recover from locally:
  ///   - spawn-time Redis replica timeouts (`forwarded via Redis` +
  ///     `no replica responded`)
  ///   - session RPCs whose daemon-side response channel was closed
  ///     mid-flight (`RPC forwarding failed: response channel closed`).
  /// Both are non-actionable from the client and should be downgraded
  /// to info at every call site that uses [_isTransientRpcError].
  static bool _isRpcReplicaTimeout(Object error) {
    if (error is RpcException) {
      return error.retryable &&
          (error.code == RpcErrorCode.handlerOffline ||
              error.code == RpcErrorCode.forwardingFailed);
    }
    if (error is! StateError) return false;
    final msg = error.message;
    return (msg.contains('forwarded via Redis') &&
            msg.contains('no replica responded')) ||
        msg.contains('RPC forwarding failed');
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
  static Duration get _sessionsRefreshDebounce =>
      testSessionsRefreshDebounceOverride ?? const Duration(seconds: 2);

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

  /// Retry budget for the per-session `messagesSync` [InvalidateSync].
  ///
  /// Message pages are fetched with `disableRetry: true` so the Dio
  /// [RetryInterceptor] never sees them — a stuck page must not be retried
  /// inside its own receive-timeout budget. That left message fetches with
  /// zero retries at BOTH layers: a single transport stall permanently
  /// discarded a page and the chat silently kept stale data until an
  /// unrelated event re-invalidated the session.
  ///
  /// One InvalidateSync retry (1s + jitter, see [InvalidateSync.baseDelayMs])
  /// restores a real recovery layer without reintroducing a retry storm:
  /// the failure path now also stamps `_lastRunEnd`, so
  /// [_messagesSyncMinInterval] throttles anything that follows.
  ///
  /// Every `messagesSync` instance must use this constant — build them with
  /// [_createMessagesSync] and never call `InvalidateSync(...)` for
  /// `fetchMessages` directly.
  static const int _messagesSyncMaxRetries = 1;

  /// The single construction point for a per-session `fetchMessages`
  /// [InvalidateSync].
  ///
  /// Four call sites create these (session visible, socket reconnect
  /// refresh, session restore, lazy recreate on a socket event) and they
  /// previously drifted apart, leaving three of them with `maxRetries: 0`
  /// — i.e. no recovery layer at all, since the page requests also opt out
  /// of the HTTP retry interceptor. See [_messagesSyncMaxRetries].
  InvalidateSync _createMessagesSync(String sessionId) => InvalidateSync(
    () => fetchMessages(sessionId),
    minInterval: _messagesSyncMinInterval,
    name: 'fetchMessages',
    onRunningChanged: _onSyncRunningChanged,
    maxRetries: _messagesSyncMaxRetries,
  );

  /// Extra cooldown for visible no-embed probes when the cursor has not
  /// advanced since the previous probe.
  static const int _noEmbedProbeCooldownMs = 2000;

  /// Cooldown between machineRPC SLOW/FAILED Sentry captures for the same
  /// `<machineId>:<method>:<kind>`. 5 minutes collapses a wedged daemon's
  /// retry storm into at most one capture per window per machine.
  static const int _machineRpcWarnCooldownMs = 5 * 60 * 1000;

  /// Whether a machineRPC SLOW/FAILED Sentry capture is allowed for this
  /// key right now, recording the timestamp when it is. Local warning
  /// logs are unaffected — only the Sentry side is throttled.
  bool _shouldCaptureMachineRpcWarn(String key) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final lastMs = _lastMachineRpcWarnMs[key] ?? 0;
    if (nowMs - lastMs < _machineRpcWarnCooldownMs) return false;
    _lastMachineRpcWarnMs[key] = nowMs;
    return true;
  }

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

  // Message decryption + parsing live in the standalone pipeline:
  // lib/core/encryption/message_processor.dart (processDecryptedMessages),
  // driven by message_pipeline/message_ingestion_orchestrator.dart.
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
  stuckAgentSentinel.attach(sync);
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
  stuckAgentSentinel.attach(sync);
}

/// Shutdown sync engine and clear in-memory state.
Future<void> syncShutdown() async {
  if (!sync.isInitialized) {
    return;
  }
  await sessionActivityCoordinator.detach();
  await stuckAgentSentinel.detach();
  await sync.shutdown();
}
