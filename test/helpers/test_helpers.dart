import 'package:dio/dio.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// Creates a mock [Response] with the given [data] and [statusCode].
///
/// Includes a default [RequestOptions] so widget tests that check
/// response objects don't crash on a missing `requestOptions`.
Response<T> mockResponse<T>(T data, {int statusCode = 200}) {
  return Response<T>(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: ''),
  );
}

/// Creates a fully initialized [Sync] instance for testing.
///
/// All [InvalidateSync] fields are pre-configured with no-op callbacks
/// so tests don't need to manually set each one.
Sync createTestSync() {
  final testSync = Sync()
    ..sessionsSync = InvalidateSync(() async {})
    ..settingsSync = InvalidateSync(() async {})
    ..profileSync = InvalidateSync(() async {})
    ..purchasesSync = InvalidateSync(() async {})
    ..machinesSync = InvalidateSync(() async {})
    ..pushTokenSync = InvalidateSync(() async {})
    ..nativeUpdateSync = InvalidateSync(() async {})
    ..artifactsSync = InvalidateSync(() async {})
    ..sessionGitStatusSync = InvalidateSync(() async {})
    ..testCriticalSyncManagersInitialized = true
    ..messagesSync.clear()
    ..testResetRpcCapabilitiesPolicy();
  return testSync;
}

/// Creates a [Sync] for testing with realistic in-memory maps.
///
/// Unlike [createTestSync], the session-related maps are real:
/// - [_sessions] map is real so `sync.sessions[id] = session` works
/// - [_sessionSpawnedAt] map is real so spawn timestamps can be set
/// - [_sessionSpawnedProfile] map is real so profile tracking works
/// - [_sessionSpawnedModel] map is real so model change detection works
///
/// All [InvalidateSync] fields remain no-ops for basic tests.
Sync createPartialMockSync() {
  final testSync = Sync()
    ..sessionsSync = InvalidateSync(() async {})
    ..settingsSync = InvalidateSync(() async {})
    ..profileSync = InvalidateSync(() async {})
    ..purchasesSync = InvalidateSync(() async {})
    ..machinesSync = InvalidateSync(() async {})
    ..pushTokenSync = InvalidateSync(() async {})
    ..nativeUpdateSync = InvalidateSync(() async {})
    ..artifactsSync = InvalidateSync(() async {})
    ..sessionGitStatusSync = InvalidateSync(() async {})
    ..testCriticalSyncManagersInitialized = true
    ..messagesSync.clear()
    ..testResetRpcCapabilitiesPolicy();
  // The test helper getters (testSessions, testSessionSpawnedAt, etc.)
  // expose the real maps, so callers can mutate them directly.
  return testSync;
}

/// Resets a test [Sync] instance back to a clean state.
///
/// Clears all in-memory maps and registered spawn metadata so the instance
/// can be reused across multiple test cases without cross-talk.
void resetTestSync(Sync sync) {
  sync.testSessions.clear();
  sync.testMachines.clear();
  sync.testSessionSpawnedAt.clear();
  sync.testClearSessionSpawnedAt();
  sync.messagesSync.clear();
  sync.testSessionsWithPendingUpdates.clear();
  sync.testClearSessionsWithPendingSocketMessages();
  sync.testSessionEncryptionRecoveryAttempts.clear();
  // testSessionsNeedingTailRefresh() returns a copy, so we can't clear it
  // here — tests should use testAddSessionsNeedingTailRefresh() to manage it.
  // Mirrors shutdown()'s reset of sync-running counters so a stale
  // `_activeSyncCount` / `_runningSyncNames` from a previous test does not
  // make `isSyncing` permanently true.
  sync.testResetSyncState();
  // Per-session shutdown clears — mirrors fields wiped by
  // Sync.shutdown() so per-test residue does not leak across cases.
  sync.testLoopsBySession.clear();
  sync.testClearAllWorkflows();
  sync.testResetWorkflowRefreshPolicy();
  sync.testLastEphemeralAt.clear();
  // Reset the monotonic data-change counters so the next test starts at 0.
  sync.testResetDataChangeCounters();
  // Clear the dedup/inline-processing state so a key from the previous
  // test cannot suppress the same key in the next.
  sync.testClearInlineDedupState();
  // Clear encryption-key caches so a key cached for user A's session
  // does not decrypt user B's data after a logout/login in the same test.
  sync.testClearEncryptionKeyCaches();
  // Clear session-spawn / auto-restore / DEK-fallback guard sets so
  // in-flight restoration tracking from a previous test cannot deadlock
  // the next test's sendMessage.
  sync.testClearSpawnGuardState();
  sync.testResetRpcCapabilitiesPolicy();
  // Without a delta cursor the next catalog read is a full reconciliation.
  sync
    ..testLastSessionsFetchedAt = null
    ..testSessionsCatalogWatermarkMs = null
    ..testLastFullSessionsCatalogAtMs = null;
  // Clear per-session message/regroup/orphan state so residue from a
  // previous test does not survive into the next (matches the
  // per-session fields cleared by Sync.shutdown()).
  sync.testClearAllSessionMessageState();
}

/// Yields the event loop until [condition] holds, or [timeout] elapses.
///
/// Replacement for fixed `await Future.delayed(...)` sleeps in async
/// (non-`testWidgets`) tests that wait for an asynchronous pipeline to
/// settle. The happy path costs one or two poll steps instead of the
/// worst-case wait, while a condition that never becomes true still burns
/// the full budget so the assertion after the call fails exactly as it
/// did with the sleep. Never shortens what the test asserts — only how
/// long it waits for it.
Future<void> settleUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 1),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (!DateTime.now().isBefore(deadline)) return;
    await Future<void>.delayed(step);
  }
}
