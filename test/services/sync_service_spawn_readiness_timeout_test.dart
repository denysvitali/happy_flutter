// Regression coverage for the sendMessage spawn-readiness timeout warn.
//
// Production once observed this single Loki WARN over 24h:
//
//   [sendMessage] recently spawned session did not become ready within
//   timeout, queueing until ready session=<id>
//
// The fix promotes the warn to a structured Sentry capture (with
// sessionId / spawnedAt / waitMs / recentlySpawned fields), bumps an
// OTel counter (`app.session.spawn_timeout`), replaces two inline magic
// numbers (15 000 / 30 000) with named constants on `Sync`
// (`recentlySpawnedWaitMs`, `recentlySpawnedFlagMs`), and funnels all
// four `_sessionSpawned*` map writes through a single `_registerSpawn`
// helper so `wasRecentlySpawned` anchors on a consistent time across
// the recovered-after-webhook-timeout path and the auto-restore path.
//
// These tests pin each of those guarantees so the single production
// occurrence does not silently regress.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';
import '../helpers/test_helpers.dart';

class _CapturingSessionEncryption implements SessionEncryption {
  @override
  bool get canDecryptAes => false;

  @override
  Future<String> encryptRawRecord(Map<String, dynamic> record) async {
    return 'encrypted-content';
  }

  @override
  Future<ProcessedMessages> decryptAndProcessMessages(
    List<Map<String, dynamic>> messages,
    String sessionId,
  ) async {
    return const ProcessedMessages(
      messages: [],
      toolResults: [],
      usageUpdates: [],
      maxSeq: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption({required this.sessionEncryption});

  final SessionEncryption sessionEncryption;

  @override
  SessionEncryption? getSessionEncryption(String sessionId) =>
      sessionEncryption;

  @override
  String generateId() => 'local-spawn-timeout';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void _stubAllSyncs(Sync instance) {
  instance.sessionsSync = InvalidateSync(() async {});
  instance.settingsSync = InvalidateSync(() async {});
  instance.profileSync = InvalidateSync(() async {});
  instance.purchasesSync = InvalidateSync(() async {});
  instance.machinesSync = InvalidateSync(() async {});
  instance.pushTokenSync = InvalidateSync(() async {});
  instance.nativeUpdateSync = InvalidateSync(() async {});
  instance.artifactsSync = InvalidateSync(() async {});
  instance.messagesSync.clear();
}

/// A session that is freshly spawned but has NOT yet become ready:
/// offline presence, no ephemeral keep-alive, no lifecycle metadata.
/// `waitForAgentReady` will therefore run out its budget and return
/// `false`.
Session _coldRecentlySpawnedSession(String id) => Session(
  id: id,
  seq: 0,
  createdAt: 0,
  updatedAt: 0,
  active: true,
  activeAt: 0,
  metadataVersion: 0,
  agentStateVersion: 0,
  thinking: false,
  presence: 'offline',
  lifecycleStateCleartext: 'starting',
  metadata: const Metadata(lifecycleState: 'starting'),
);

void main() {
  group('Sync.recentlySpawned constants', () {
    test('recentlySpawnedFlagMs is 30 000 (was inline literal)', () {
      expect(Sync.recentlySpawnedFlagMs, 30000);
    });

    test('recentlySpawnedWaitMs is 15 000 (was inline literal)', () {
      expect(Sync.recentlySpawnedWaitMs, 15000);
    });
  });

  group('Sync._registerSpawn funnel', () {
    test('defaults at to DateTime.now() when not provided', () {
      final sync = Sync();
      _stubAllSyncs(sync);
      sync.testClearSessionSpawnedAt();

      final before = DateTime.now().millisecondsSinceEpoch;
      sync.testRegisterSpawn('sess-now');
      final after = DateTime.now().millisecondsSinceEpoch;

      final stored = sync.testSessionSpawnedAt['sess-now']!;
      expect(stored, greaterThanOrEqualTo(before));
      expect(stored, lessThanOrEqualTo(after));
      resetTestSync(sync);
    });

    test('honours caller-supplied at (recovered found.createdAt path)', () {
      final sync = Sync();
      _stubAllSyncs(sync);
      sync.testClearSessionSpawnedAt();

      final anchor = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      sync.testRegisterSpawn('sess-anchor', at: anchor);

      expect(
        sync.testSessionSpawnedAt['sess-anchor'],
        anchor.millisecondsSinceEpoch,
      );
      resetTestSync(sync);
    });

    test('writes all four spawn maps when fields are supplied', () {
      final sync = Sync();
      _stubAllSyncs(sync);
      sync.testClearSessionSpawnedAt();

      sync.testRegisterSpawn(
        'sess-full',
        profileId: 'profile-1',
        modelMode: 'opus',
        agent: 'claude',
      );

      expect(sync.testSessionSpawnedAt['sess-full'], isNotNull);
      expect(sync.testSessionSpawnedProfile['sess-full'], 'profile-1');
      expect(sync.testSessionSpawnedModel['sess-full'], 'opus');
      expect(sync.testSessionSpawnedAgent['sess-full'], 'claude');
      resetTestSync(sync);
    });
  });

  group('Sync.sendMessage spawn-readiness timeout', () {
    late Sync instance;
    late _CapturingSessionEncryption sessionEncryption;
    dynamic capturedRequestData;

    setUp(() async {
      instance = Sync();
      _stubAllSyncs(instance);
      instance.testIsInitialized = true;
      instance.testClearSessionMessageState('sess-spawn');
      instance.testSessions.clear();
      instance.testSessions['sess-spawn'] = _coldRecentlySpawnedSession(
        'sess-spawn',
      );
      // Register the session as freshly spawned (5 s ago) so
      // `recentlySpawned` evaluates true and the larger 15 s budget
      // applies — matching the production log shape.
      instance.testSetSessionSpawnedAt(
        'sess-spawn',
        DateTime.now().millisecondsSinceEpoch - 5000,
      );
      instance.testClearSpawnReadinessTimeoutCaptures();

      sessionEncryption = _CapturingSessionEncryption();
      instance.encryption = _FakeEncryption(
        sessionEncryption: sessionEncryption,
      );
      instance.testSocketConnectedOverride = null;
      instance.testSocketSendOverride = null;

      capturedRequestData = null;
      await ApiClient().initialize(serverUrl: 'http://localhost');
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST' &&
                options.path == '/v3/sessions/sess-spawn/messages') {
              capturedRequestData = options.data;
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'messages': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': 'srv-msg-spawn',
                        'seq': 1,
                        'localId': 'local-spawn-timeout',
                        'createdAt': 1700000010000,
                      },
                    ],
                  },
                ),
              );
              return;
            }
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 404,
                data: <String, dynamic>{},
              ),
            );
          },
        ),
      );

      messageOutbox.dispose();
      messageOutbox.testStorage = _FakeMMKVStorage();
      messageOutbox.configure(
        deliver: (_) async => OutboxDeliveryFailure.permanent,
      );
    });

    tearDown(() async {
      ApiClient().dispose();
      messageOutbox.dispose();
      messageOutbox.testStorage = MMKVStorage.testConstructor();
      instance.testSessions.clear();
      instance.testSetSessionSpawnedAt('sess-spawn', 0);
      instance.testClearSpawnReadinessTimeoutCaptures();
      instance.testIsInitialized = false;
      InvalidateSync.isBackgrounded = false;
      instance.testSocketConnectedOverride = null;
      instance.testSocketSendOverride = null;
    });

    test('records exactly one Sentry-style spawn-timeout capture '
        'when waitForAgentReady runs out', () async {
      await instance.sendMessage('sess-spawn', 'capture me');
      await instance.lastCompleteSendFuture;

      final captures = instance.testSpawnReadinessTimeoutCaptures;
      expect(captures, hasLength(1));
      final capture = captures.single;
      expect(capture['sessionId'], 'sess-spawn');
      expect(capture['waitMs'], Sync.recentlySpawnedWaitMs);
      expect(capture['recentlySpawned'], isTrue);
      expect(capture['spawnedAt'], isA<int>());
    });

    test(
      'queues with the same localId instead of POSTing before readiness',
      () async {
        await instance.sendMessage('sess-spawn', 'queue until ready');
        await instance.lastCompleteSendFuture;

        expect(capturedRequestData, isNull);
        expect(messageOutbox.contains('local-spawn-timeout'), isTrue);
        final queued = messageOutbox.entries.single;
        expect(queued.localId, 'local-spawn-timeout');
        expect(queued.sessionId, 'sess-spawn');
        expect(queued.encryptedContent, 'encrypted-content');
      },
    );

    test('gives a recently-spawned session its full recentlySpawnedWaitMs '
        'instead of clamping it into the ordinary send deadline', () async {
      final stopwatch = Stopwatch()..start();
      await instance.sendMessage('sess-spawn', 'wait for me');
      await instance.lastCompleteSendFuture;
      stopwatch.stop();

      // The ordinary 12 s send deadline reserves 6 s for the POST, so
      // clamping the readiness wait into it caps the wait at 6 s — a
      // pod that needs >10 s to come up could never be waited for, and
      // every spawn-then-send raised a bogus spawn-timeout alarm.
      expect(
        stopwatch.elapsedMilliseconds,
        greaterThanOrEqualTo(Sync.recentlySpawnedWaitMs - 1500),
        reason:
            'the readiness wait must not be clamped below '
            'Sync.recentlySpawnedWaitMs for a freshly-spawned session',
      );

      // And the telemetry must report what was actually waited.
      final capture = instance.testSpawnReadinessTimeoutCaptures.single;
      expect(capture['waitMs'], Sync.recentlySpawnedWaitMs);
      expect(capture['requestedWaitMs'], Sync.recentlySpawnedWaitMs);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('does NOT emit a spawn-timeout capture when the session becomes '
        'ready during the wait', () async {
      // Flip the session to online mid-wait so _isSessionReady
      // returns true. Use a small budget so the test stays fast.
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        final s = instance.testSessions['sess-spawn']!;
        instance.testSessions['sess-spawn'] = s.copyWith(presence: 'online');
        instance.testSetLastEphemeralAt(
          'sess-spawn',
          DateTime.now().millisecondsSinceEpoch,
        );
        instance.testNotifyDataChanged();
      });

      await instance.sendMessage('sess-spawn', 'comes online');
      await instance.lastCompleteSendFuture;

      expect(instance.testSpawnReadinessTimeoutCaptures, isEmpty);
    });
  });
}

class _FakeMMKVStorage extends MMKVStorage {
  _FakeMMKVStorage() : super.testConstructor();
}
