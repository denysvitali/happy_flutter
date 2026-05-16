import 'package:dio/dio.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';

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
    ..messagesSync.clear();
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
    ..messagesSync.clear();
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
  // testSessionsNeedingTailRefresh() returns a copy, so we can't clear it
  // here — tests should use testAddSessionsNeedingTailRefresh() to manage it.
}
