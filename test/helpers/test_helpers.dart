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
    ..friendsSync = InvalidateSync(() async {})
    ..friendRequestsSync = InvalidateSync(() async {})
    ..feedSync = InvalidateSync(() async {})
    ..todosSync = InvalidateSync(() async {})
    ..sessionGitStatusSync = InvalidateSync(() async {})
    ..messagesSync.clear();
  return testSync;
}
