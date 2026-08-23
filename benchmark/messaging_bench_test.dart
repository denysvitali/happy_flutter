@Timeout(Duration(minutes: 10))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../test/integration/mock_sync_server.dart';
import 'bench_runner.dart';
import 'fixtures.dart';

/// End-to-end messaging-path benchmarks against a mocked backend.
///
/// Exercises the two production ingress routes over realistic encrypted
/// wire envelopes. Crypto is the integration suite's plaintext-passthrough
/// encryptor, so numbers isolate pipeline (parse/normalize/group/upsert)
/// cost; raw crypto cost is measured separately in crypto_bench_test.dart.
void main() {
  late Sync sync;
  late MockSyncServer server;
  final reporter = BenchReporter(group: 'messaging');

  setUp(() async {
    sync = Sync();
    server = MockSyncServer();
    _resetSyncState(sync);
    sync.testSocketConnectedOverride = true;
    sync.testSocketSendOverride = (_, __) {};
    sync.encryption = _BenchEncryption();
    sync.testIsInitialized = true;
    sync.testFetchMessagesOverride = null;
    await server.setUp();
  });

  tearDown(() async {
    sync.testSocketConnectedOverride = null;
    sync.testSocketSendOverride = null;
    sync.testVisibleSessionId = null;
    sync.testFetchMessagesOverride = null;
    await server.tearDown();
  });

  tearDownAll(() => reporter.finish());

  test('socket inline ingest: batches of 100 encrypted new-message events',
      () async {
    const sessionId = 'bench-ingest';
    const batch = 100;
    // Keep any inline-path HTTP fallback from leaving the mock backend
    // (mirrors the integration suite's guard).
    sync.testFetchMessagesOverride =
        (_, __, ___) async => <String, dynamic>{
              'messages': <Map<String, dynamic>>[],
              'hasMore': false,
            };

    // Seed once; every round appends contiguously onto the growing
    // transcript so the inline path sees a gap-free chain (a per-round
    // reset would make the cursor logic schedule endless catch-up
    // fetches against the always-empty override).
    _seedSession(sync, sessionId, lastSeq: 0, visible: true);
    var injected = 0;

    Future<double> injectRound() async {
      final base = injected;
      final messages = makeTranscript(batch);
      for (var i = 0; i < messages.length; i++) {
        messages[i]['seq'] = base + i + 1;
        messages[i]['id'] = 'bench-ingest-$base-$i';
      }
      final watch = Stopwatch()..start();
      for (final m in messages) {
        unawaited(sync.handleUpdate(<String, dynamic>{
          't': 'new-message',
          'sid': sessionId,
          'message': m,
        }));
      }
      injected += batch;
      await _waitForMessageCount(sync, sessionId, injected);
      watch.stop();
      return watch.elapsedMicroseconds / 1000.0;
    }

    await reporter.measureTimed(
      'socket_inline_ingest_100',
      injectRound,
      iterations: 6,
      warmup: 2,
      opsPerIteration: batch,
    );

    final resident = sync.testSessionMessages(sessionId);
    expect(resident, isNotNull, reason: 'ingest must leave rows resident');
    expect(resident!.length, greaterThanOrEqualTo(batch),
        reason: 'ingest bench must have merged its batch');
  });

  test(
      'socket inline ingest: 500-message burst into a fresh visible session',
      () async {
    const sessionId = 'bench-ingest-500';
    const burst = 500;
    sync.testFetchMessagesOverride =
        (_, __, ___) async => <String, dynamic>{
              'messages': <Map<String, dynamic>>[],
              'hasMore': false,
            };

    _seedSession(sync, sessionId, lastSeq: 0, visible: true);

    final messages = makeTranscript(burst);
    for (var i = 0; i < messages.length; i++) {
      messages[i]['seq'] = i + 1;
      messages[i]['id'] = 'bench-ingest-500-$i';
    }
    final watch = Stopwatch()..start();
    for (final m in messages) {
      unawaited(sync.handleUpdate(<String, dynamic>{
        't': 'new-message',
        'sid': sessionId,
        'message': m,
      }));
    }
    await _waitForMessageCount(sync, sessionId, burst);
    watch.stop();
    final elapsedMs = watch.elapsedMicroseconds / 1000.0;

    final resident = sync.testSessionMessages(sessionId);
    expect(resident!.length, greaterThanOrEqualTo(burst),
        reason: 'burst bench must have merged its whole burst');
    // Report through the same timed-scenario shape so the job summary
    // pipeline picks the number up.
    await reporter.measureTimed(
      'socket_inline_ingest_500_burst',
      () async => elapsedMs,
      iterations: 1,
      warmup: 0,
      opsPerIteration: burst,
    );
  });

  test('REST fetch: first-load tail page of 200 encrypted messages',
      () async {
    const sessionId = 'bench-fetch';
    // Production chat-open shape: a session's first load tail-loads only
    // the newest Sync.initialLoad (200 on mobile) rows — window starts at
    // lastSeq - initialLoad regardless of history size. Stub a longer
    // history behind that window and measure exactly the 200-row page.
    const tailRows = 200; // Sync.initialLoad on mobile
    const historyRows = 600;
    // Register the session in the catalog with a lastSeq above the cursor:
    // with no catalog entry the cursor reads 0 == serverLastSeq(0) and
    // fetchMessages exits as up-to-date without ever hitting the wire.
    final catalogSession = _wireSession(sessionId, lastSeq: historyRows);
    server.stubSessions(<Session>[catalogSession]);
    _seedSession(
      sync,
      sessionId,
      lastSeq: 0,
      visible: true,
      sessionLastSeq: historyRows,
    );

    final history = makeTranscript(historyRows);
    var fetchedAtLeastOnce = false;

    Future<double> fetchRound() async {
      // Full per-round reset (rows, cursor, content signatures, probe
      // state) so every iteration is a genuine first-load tail through
      // decrypt + upsert.
      sync.testClearSessionMessageState(sessionId);
      sync.messagesSync[sessionId] = InvalidateSync(
        () => sync.fetchMessages(sessionId),
      );
      server.clearStubbedData();
      server.stubMessages(sessionId, history);
      final watch = Stopwatch()..start();
      await sync.fetchMessages(sessionId);
      // fetchMessages is Future<void>; completion is proven by the rows
      // being resident (poll granularity adds ~2ms of measured noise).
      await _waitForMessageCount(sync, sessionId, tailRows);
      watch.stop();
      fetchedAtLeastOnce = true;
      return watch.elapsedMicroseconds / 1000.0;
    }

    await reporter.measureTimed(
      'rest_fetch_tail_200',
      fetchRound,
      iterations: 12,
      warmup: 2,
      opsPerIteration: tailRows,
    );

    expect(fetchedAtLeastOnce, isTrue);
    expect(server.messageRequestLog, isNotEmpty,
        reason: 'bench must have hit the mocked /v3 endpoint');
  });
}

// ---------------------------------------------------------------------------
// Harness helpers (mirror the integration-suite fakes so the pipeline runs
// unmodified while crypto passes plaintext through).
// ---------------------------------------------------------------------------

void _resetSyncState(Sync sync) {
  for (final id in sync.sessionMessages.keys.toList()) {
    sync.testSetSessionMessages(id, <Map<String, dynamic>>[]);
  }
  for (final id in sync.testSessions.keys.toList()) {
    sync.testSetSessionLastSeq(id, 0);
  }
  sync.testSessions.clear();
  sync.messagesSync.clear();
}

void _seedSession(
  Sync sync,
  String sessionId, {
  required int lastSeq,
  required bool visible,
  int sessionLastSeq = 10,
}) {
  sync.testSessions[sessionId] = _wireSession(sessionId, lastSeq: sessionLastSeq);
  sync.testSetSessionMessages(sessionId, <Map<String, dynamic>>[]);
  sync.testSetSessionLastSeq(sessionId, lastSeq);
  if (visible) {
    sync.testVisibleSessionId = sessionId;
  }
  sync.messagesSync[sessionId] = InvalidateSync(
    () => sync.fetchMessages(sessionId),
  );
}

Session _wireSession(String id, {int lastSeq = 10}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
    lastSeq: lastSeq,
  );
}

Future<void> _waitForMessageCount(
  Sync sync,
  String sessionId,
  int expected, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final msgs = sync.testSessionMessages(sessionId);
    if (msgs != null && msgs.length >= expected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  throw StateError(
    'ingest settle timeout: session $sessionId never reached '
    '$expected resident messages',
  );
}

class _BenchEncryption implements Encryption {
  final Map<String, SessionEncryption> _sessions =
      <String, SessionEncryption>{};

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessions.putIfAbsent(
      sessionId,
      () => SessionEncryption(
        sessionId: sessionId,
        encryptor: _PassthroughEncryptor(),
        decryptor: _PassthroughEncryptor(),
        cache: EncryptionCache(),
      ),
    );
  }

  @override
  String generateId() =>
      'bench-local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PassthroughEncryptor implements Encryptor {
  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    throw UnimplementedError('bench ingest path never encrypts');
  }

  @override
  Future<List<dynamic>> decrypt(List<Uint8List> data) async {
    final results = <dynamic>[];
    for (final item in data) {
      if (item.isEmpty) {
        results.add(null);
        continue;
      }
      try {
        if (item[0] == 0x01) {
          results.add(jsonDecode(utf8.decode(item.sublist(1))));
        } else {
          results.add(utf8.decode(item));
        }
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }
}
