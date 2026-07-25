import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// A mock server for E2E testing of the sync service.
///
/// Provides:
/// - HTTP mocking via Dio interceptors
/// - Socket event capture and injection
/// - Deterministic message sequence control
///
/// Usage:
/// ```dart
/// final mock = MockSyncServer();
/// await mock.setUp();
///
/// // Configure mock responses
/// mock.stubSessions([session1, session2]);
/// mock.stubMessages('sess-1', [msg1, msg2, msg3]);
///
/// // Simulate socket events
/// mock.emitSocketEvent('new-message', { ... });
///
/// // Run the sync
/// await sync.onSessionVisible('sess-1');
///
/// // Assert results
/// expect(sync.messagesForSession('sess-1'), hasLength(3));
///
/// await mock.tearDown();
/// ```
class MockSyncServer {
  MockSyncServer();

  Interceptor? _interceptor;
  String? _capturedSocketEvent;
  dynamic _capturedSocketData;
  final List<Map<String, dynamic>> _capturedSocketEvents = [];

  // Stubbed responses
  final Map<String, List<Map<String, dynamic>>> _stubbedMessages = {};
  final Map<String, Session> _stubbedSessions = {};
  List<Session> _stubbedSessionList = [];
  Map<String, dynamic>? _stubbedSessionsResponse;

  /// Server-side cap on the message page size, mirroring production
  /// servers that return fewer messages than the client's `limit`.
  /// When set, pages are clamped to this size (forcing hasMore=true
  /// pagination even when the client asks for more).
  int? maxMessagePageSize;

  /// `after_seq` values of every /v3 message-page GET, in arrival order.
  /// Lets tests assert exactly which pages were requested (e.g. that
  /// prefetch pipelining neither duplicates nor skips pages).
  final List<int> messageRequestLog = [];

  // Deferred response controllers
  final Map<String, Completer<Response<dynamic>>> _pendingRequests = {};

  /// Set up the mock server. Must be called before using.
  Future<void> setUp() async {
    await ApiClient().initialize(serverUrl: 'http://localhost');
    _interceptor = InterceptorsWrapper(
      onRequest: _handleRequest,
    );
    ApiClient().testDio!.interceptors.add(_interceptor!);
  }

  /// Tear down the mock server and clean up.
  Future<void> tearDown() async {
    if (_interceptor != null) {
      ApiClient().testDio!.interceptors.remove(_interceptor);
    }
    _stubbedMessages.clear();
    _stubbedSessions.clear();
    _stubbedSessionList = [];
    _capturedSocketEvents.clear();
    _capturedSocketEvent = null;
    _capturedSocketData = null;
    messageRequestLog.clear();
    maxMessagePageSize = null;
    ApiClient().dispose();
  }

  /// Configure which socket event to emit when the sync sends one.
  /// Set to null to ignore socket sends.
  void setNextSocketResponse({String? event, dynamic data}) {
    _capturedSocketEvent = event;
    _capturedSocketData = data;
  }

  /// Get all socket events that were captured.
  List<Map<String, dynamic>> get capturedSocketEvents =>
      List.unmodifiable(_capturedSocketEvents);

  /// Configure stubbed session list response for /v2/sessions.
  void stubSessions(List<Session> sessions) {
    _stubbedSessionList = sessions;
    _stubbedSessionsResponse = null;
    _stubbedSessions
      ..clear()
      ..addEntries(sessions.map((s) => MapEntry(s.id, s)));
  }

  /// Configure a stubbed sessions response with custom shape.
  void stubSessionsResponse(Map<String, dynamic> response) {
    _stubbedSessionsResponse = response;
  }

  /// Configure stubbed messages for a session.
  void stubMessages(String sessionId, List<Map<String, dynamic>> messages) {
    _stubbedMessages[sessionId] = List.from(messages);
  }

  /// Add a single message to an existing stubbed message list.
  void appendStubbedMessage(String sessionId, Map<String, dynamic> message) {
    _stubbedMessages.putIfAbsent(sessionId, () => []);
    _stubbedMessages[sessionId]!.add(message);
  }

  /// Clear all stubbed data.
  void clearStubbedData() {
    _stubbedMessages.clear();
    _stubbedSessions.clear();
    _stubbedSessionList = [];
    _stubbedSessionsResponse = null;
    _pendingRequests.clear();
  }

  void _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final path = options.uri.path;

    // /v2/sessions — session list
    if (path == '/v2/sessions' && options.method == 'GET') {
      if (_stubbedSessionsResponse != null) {
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: _stubbedSessionsResponse,
        ));
        return;
      }
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'sessions': _stubbedSessionList
              .map((s) => _sessionToJson(s))
              .toList(),
          'hasNext': false,
        },
      ));
      return;
    }

    // /v1/sessions/{id} — single session
    final singleSessionMatch = RegExp(r'^/v1/sessions/([^/]+)$').firstMatch(path);
    if (singleSessionMatch != null && options.method == 'GET') {
      final sessionId = singleSessionMatch.group(1)!;
      final session = _stubbedSessions[sessionId];
      if (session != null) {
        handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {'session': _sessionToJson(session)},
        ));
        return;
      }
      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 404,
        data: {},
      ));
      return;
    }

    // /v3/sessions/{id}/messages — message list
    final messagesMatch =
        RegExp(r'^/v3/sessions/([^/]+)/messages$').firstMatch(path);
    if (messagesMatch != null && options.method == 'GET') {
      final sessionId = messagesMatch.group(1)!;
      final messages = _stubbedMessages[sessionId] ?? [];
      final afterSeq = options.queryParameters['after_seq'] as int? ?? 0;
      var limit = options.queryParameters['limit'] as int? ?? 100;
      final cap = maxMessagePageSize;
      if (cap != null && limit > cap) {
        limit = cap;
      }
      messageRequestLog.add(afterSeq);

      // Filter messages by seq > afterSeq
      final filtered = messages.where((m) {
        final seq = m['seq'] as int? ?? 0;
        return seq > afterSeq;
      }).toList();

      final page = filtered.take(limit).toList();
      final hasMore = filtered.length > limit;

      handler.resolve(Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: {
          'messages': page,
          'hasMore': hasMore,
        },
      ));
      return;
    }

    // Default: 404 for unhandled requests
    handler.resolve(Response<dynamic>(
      requestOptions: options,
      statusCode: 404,
      data: {'error': 'Not mocked: ${options.method} $path'},
    ));
  }

  Map<String, dynamic> _sessionToJson(Session s) {
    return {
      'id': s.id,
      'seq': s.seq,
      'createdAt': s.createdAt,
      'updatedAt': s.updatedAt,
      'active': s.active,
      'activeAt': s.activeAt,
      'metadataVersion': s.metadataVersion,
      'agentStateVersion': s.agentStateVersion,
      'thinking': s.thinking,
      'presence': s.presence,
      if (s.lastSeq != null) 'lastSeq': s.lastSeq,
      if (s.archived != null) 'archived': s.archived,
    };
  }
}

/// Test helpers for setting up sync with mocks.
class SyncTestHarness {
  SyncTestHarness();

  late Sync sync;
  late MockSyncServer mockServer;

  /// Initialize harness with a fresh sync and mock server.
  Future<void> setUp() async {
    sync = Sync();
    mockServer = MockSyncServer();

    // Stub all sync fields
    sync.sessionsSync = InvalidateSync(() async {});
    sync.settingsSync = InvalidateSync(() async {});
    sync.profileSync = InvalidateSync(() async {});
    sync.purchasesSync = InvalidateSync(() async {});
    sync.machinesSync = InvalidateSync(() async {});
    sync.pushTokenSync = InvalidateSync(() async {});
    sync.nativeUpdateSync = InvalidateSync(() async {});
    sync.artifactsSync = InvalidateSync(() async {});
    sync.sessionGitStatusSync = InvalidateSync(() async {});
    sync.messagesSync.clear();

    // Socket is "connected" for these tests
    sync.testSocketConnectedOverride = true;
    sync.testSocketSendOverride = (event, data) {};

    await mockServer.setUp();
  }

  /// Clean up harness.
  Future<void> tearDown() async {
    sync.testSocketConnectedOverride = null;
    sync.testSocketSendOverride = null;
    await mockServer.tearDown();
  }

  /// Inject a socket event as if it arrived from the server.
  void injectSocketEvent(String type, Map<String, dynamic> data) {
    sync.handleUpdate({'t': type, ...data});
  }

  /// Inject a socket ephemeral event.
  void injectEphemeralEvent(Map<String, dynamic> data) {
    sync.handleEphemeralUpdate(data);
  }

  /// Helper to make a test session.
  Session makeSession(
    String id, {
    int seq = 1,
    int lastSeq = 10,
    bool thinking = false,
    String presence = 'offline',
    DateTime? createdAt,
  }) {
    return Session(
      id: id,
      seq: seq,
      createdAt: createdAt?.millisecondsSinceEpoch ?? 1700000000000,
      updatedAt: 1700000000000,
      active: true,
      activeAt: 1700000000000,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: thinking,
      presence: presence,
      lastSeq: lastSeq,
    );
  }

  /// Helper to make a test message.
  Map<String, dynamic> makeMessage(
    String id, {
    int seq = 1,
    String role = 'user',
    String kind = 'text',
    String? content,
    String? localId,
    int? createdAt,
  }) {
    return {
      'id': id,
      'seq': seq,
      'role': role,
      'kind': kind,
      if (content != null) 'content': content,
      if (localId != null) 'localId': localId,
      'createdAt': createdAt ?? 1700000000000,
    };
  }
}
