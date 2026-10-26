import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/message_outbox.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

class _OutboxStorage extends MMKVStorage {
  _OutboxStorage() : super.testConstructor();
  String? data;

  @override
  Future<String?> getOutboxEntries() async => data;

  @override
  Future<void> saveOutboxEntries(String value) async {
    data = value;
  }
}

void main() {
  late Sync sync;
  const id = 'har-model-switch';
  const luna = 'codex/gpt-6-luna';
  const sol = 'codex/gpt-6.1-sol';
  const grok = 'grok/grok-4.7';

  setUp(() {
    messageOutbox.dispose();
    messageOutbox.testStorage = _OutboxStorage();
    sync = createTestSync();
    sync.testSessions[id] = Session(
      id: id,
      seq: 1,
      createdAt: 1,
      updatedAt: 1,
      active: true,
      activeAt: 1,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      modelMode: luna,
      metadata: const Metadata(
        host: '',
        model: luna,
        flavor: 'har',
        harRuntimeId: 'runtime-1',
        harModelSwitchBarrier: {'version': 1, 'runtimeId': 'runtime-1'},
      ),
    );
    sync.testSetSessionSpawnedModel(id, luna);
  });

  tearDown(() {
    messageOutbox.dispose();
    sync.testSessionRPCOverride = null;
    sync.testSessions.remove(id);
    sync.testSessionSpawnedModel.remove(id);
  });

  test(
    'switch reserves delivery lane and fences new sends and retries',
    () async {
      sync.testIsInitialized = true;
      final releaseDelivery = Completer<void>();
      final deliveryStarted = Completer<void>();
      final delivery = messageOutbox.serialize(id, () async {
        deliveryStarted.complete();
        await releaseDelivery.future;
      });
      await deliveryStarted.future;
      var rpcCalls = 0;
      final reply = Completer<Map<String, dynamic>>();
      sync.testSessionRPCOverride = (_, _, _) {
        rpcCalls++;
        return reply.future;
      };
      final switching = sync.setSessionModel(id, sol);
      await Future<void>.delayed(Duration.zero);
      expect(rpcCalls, 0);
      await expectLater(
        sync.sendMessage(id, 'blocked', clientLocalId: 'blocked-model-message'),
        throwsStateError,
      );
      expect(
        sync.testSessionMessages(id)!.single['localId'],
        'blocked-model-message',
      );
      expect(sync.testSessionMessages(id)!.single['sendStatus'], 'failed');
      await expectLater(
        sync.retryFailedMessage(id, 'blocked-model-message'),
        throwsStateError,
      );
      releaseDelivery.complete();
      await delivery;
      await Future<void>.delayed(Duration.zero);
      expect(rpcCalls, 1);
      expect(sync.testSessions[id]!.metadata!.model, luna);
      reply.complete({'model': sol});
      await switching;
      await sync.lastCompleteSendFuture;
      sync.testClearSessionMessageState(id);
      sync.testIsInitialized = false;
    },
  );

  for (final dead in [false, true]) {
    test(
      'switch refuses ${dead ? 'rearmable dead' : 'pending'} retries',
      () async {
        final entry = OutboxEntry(
          localId: 'older-model-message',
          sessionId: id,
          text: 'continue',
          encryptedContent: 'encrypted',
          rawRecord: const {
            'meta': {'model': luna},
          },
          queuedAt: 1,
          failureClass: OutboxFailureClass.transient,
        );
        if (dead) {
          messageOutbox.testInsertDead(entry);
        } else {
          messageOutbox.testInsertPending(entry);
        }
        var rpcCalls = 0;
        sync.testSessionRPCOverride = (_, _, _) async {
          rpcCalls++;
          return {'model': sol};
        };
        await expectLater(sync.setSessionModel(id, sol), throwsStateError);
        expect(rpcCalls, 0);
        expect(sync.testSessionSpawnedModel[id], luna);
        expect(sync.testSessions[id]!.metadata!.model, luna);
      },
    );
  }

  test('automatic outbox delivery finishes before model RPC', () async {
    final started = Completer<void>();
    final releaseRetry = Completer<void>();
    final events = <String>[];
    messageOutbox.configure(
      deliver: (_) async {
        events.add('retry-start');
        started.complete();
        await releaseRetry.future;
        events.add('retry-end');
        return null;
      },
    );
    messageOutbox.testInsertPending(
      const OutboxEntry(
        localId: 'automatic-retry',
        sessionId: id,
        text: 'continue',
        encryptedContent: 'encrypted',
        rawRecord: {
          'meta': {'model': luna},
        },
        queuedAt: 1,
      ),
    );
    final retry = messageOutbox.testAttemptNow('automatic-retry');
    await started.future;
    sync.testSessionRPCOverride = (_, _, _) async {
      events.add('model-rpc');
      return {'model': sol};
    };
    final switching = sync.setSessionModel(id, sol);
    await Future<void>.delayed(Duration.zero);
    expect(events, ['retry-start']);
    releaseRetry.complete();
    await retry;
    await switching;
    expect(events, ['retry-start', 'retry-end', 'model-rpc']);
    expect(messageOutbox.entries, isEmpty);
  });

  test('revived Har payload cannot deliver under a different model', () async {
    sync.testIsInitialized = true;
    sync.testSessions[id] = sync.testSessions[id]!.copyWith(
      metadata: sync.testSessions[id]!.metadata!.copyWith(model: sol),
    );
    final result = await sync.testDeliverOutboxEntryClassified(
      const OutboxEntry(
        localId: 'old-model-retry',
        sessionId: id,
        text: 'continue',
        encryptedContent: 'encrypted',
        rawRecord: {
          'meta': {'model': luna},
        },
        queuedAt: 1,
      ),
    );
    expect(result?.failureClass, OutboxFailureClass.permanent);
    expect(result?.reason, 'model_changed');
    sync.testIsInitialized = false;
  });

  test(
    'confirmed switch updates running and launch baselines before socket',
    () async {
      sync.testSessionRPCOverride = (sessionId, method, params) async {
        expect(sessionId, id);
        expect(method, 'set_model_sequenced_v1');
        expect(params, {
          'model': sol,
          'afterSeq': 1,
          'runtimeId': 'runtime-1',
          'barrierVersion': 1,
        });
        return {'model': sol};
      };
      final response = await sync.setSessionModel(id, sol);
      expect(response.model, sol);
      expect(sync.testSessions[id]!.metadata!.model, sol);
      expect(sync.testSessions[id]!.modelMode, sol);
      expect(sync.testSessionSpawnedModel[id], sol);
    },
  );

  test(
    'Grok switch preserves the exact qualified model after confirmation',
    () async {
      sync.testSessionRPCOverride = (sessionId, method, params) async {
        expect(sessionId, id);
        expect(method, 'set_model_sequenced_v1');
        expect(params, {
          'model': grok,
          'afterSeq': 1,
          'runtimeId': 'runtime-1',
          'barrierVersion': 1,
        });
        return {'model': grok};
      };
      final response = await sync.setSessionModel(id, grok);
      expect(response.model, grok);
      expect(sync.testSessions[id]!.metadata!.model, grok);
      expect(sync.testSessions[id]!.modelMode, grok);
      expect(sync.testSessionSpawnedModel[id], grok);
    },
  );

  test(
    'busy and invalid acknowledgements leave all baselines unchanged',
    () async {
      for (final reject in [true, false]) {
        sync.testSessionRPCOverride = (_, _, _) async {
          if (reject) throw StateError('busy');
          return {'model': luna};
        };
        await expectLater(sync.setSessionModel(id, sol), throwsStateError);
        expect(sync.testSessions[id]!.metadata!.model, luna);
        expect(sync.testSessions[id]!.modelMode, luna);
        expect(sync.testSessionSpawnedModel[id], luna);
      }
    },
  );

  test('runtime reset during RPC cannot mutate the next runtime', () async {
    final reply = Completer<Map<String, dynamic>>();
    sync.testSessionRPCOverride = (_, _, _) => reply.future;
    final result = sync.setSessionModel(id, sol);
    final expectation = expectLater(result, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    sync.testAdvanceRuntimeGeneration();
    reply.complete({'model': sol});
    await expectation;
    expect(sync.testSessions[id]!.metadata!.model, luna);
    expect(sync.testSessionSpawnedModel[id], luna);
  });

  for (final useCursor in [false, true]) {
    test(
      'switch supplies acknowledged ${useCursor ? 'ACK' : 'catalog'} boundary',
      () async {
        sync.testSessions[id] = sync.testSessions[id]!.copyWith(seq: 5);
        sync.testSetSessionLastSeq(id, useCursor ? 9 : 3);
        sync.testSessionRPCOverride = (_, _, params) async {
          expect(params, {
            'model': sol,
            'afterSeq': useCursor ? 9 : 5,
            'runtimeId': 'runtime-1',
            'barrierVersion': 1,
          });
          return {'model': sol};
        };
        await sync.setSessionModel(id, sol);
        sync.testSetSessionLastSeq(id, 0);
      },
    );
  }

  test('runtime reset while waiting for delivery cancels before RPC', () async {
    final release = Completer<void>();
    final delivery = messageOutbox.serialize(id, () => release.future);
    var rpcCalls = 0;
    sync.testSessionRPCOverride = (_, _, _) async {
      rpcCalls++;
      return {'model': sol};
    };
    final switching = sync.setSessionModel(id, sol);
    final rejected = expectLater(switching, throwsStateError);
    sync.testAdvanceRuntimeGeneration();
    release.complete();
    await delivery;
    await rejected;
    expect(rpcCalls, 0);
    expect(sync.testSessionSpawnedModel[id], luna);
  });

  for (final beforeRpc in [false, true]) {
    test(
      'replacement ${beforeRpc ? 'before' : 'during'} RPC fences model',
      () async {
        final release = Completer<void>();
        final delivery = beforeRpc
            ? messageOutbox.serialize(id, () => release.future)
            : Future<void>.value();
        final rpcStarted = Completer<void>();
        final response = Completer<Map<String, dynamic>>();
        var rpcCalls = 0;
        sync.testSessionRPCOverride = (_, _, _) {
          rpcCalls++;
          rpcStarted.complete();
          return response.future;
        };
        final switching = sync.setSessionModel(id, sol);
        final rejected = expectLater(switching, throwsStateError);
        if (!beforeRpc) await rpcStarted.future;
        sync.testSessions[id] = sync.testSessions[id]!.copyWith(
          metadata: sync.testSessions[id]!.metadata!.copyWith(
            harRuntimeId: 'replacement-runtime',
          ),
        );
        if (beforeRpc) {
          release.complete();
        } else {
          response.complete({'model': sol});
        }
        await delivery;
        await rejected;
        expect(rpcCalls, beforeRpc ? 0 : 1);
        expect(sync.testSessions[id]!.metadata!.model, luna);
        expect(sync.testSessionSpawnedModel[id], luna);
      },
    );
  }

  for (final barrier in <Map<String, dynamic>?>[
    null,
    {'version': 1, 'runtimeId': 'old-runtime'},
    {'version': 2, 'runtimeId': 'runtime-1'},
    {'version': 1.0, 'runtimeId': 'runtime-1'},
  ]) {
    test('unsupported barrier $barrier rejects before RPC', () async {
      sync.testSessions[id] = sync.testSessions[id]!.copyWith(
        metadata: sync.testSessions[id]!.metadata!.copyWith(
          harModelSwitchBarrier: barrier,
        ),
      );
      var rpcCalls = 0;
      sync.testSessionRPCOverride = (_, _, _) async {
        rpcCalls++;
        return {'model': sol};
      };
      await expectLater(sync.setSessionModel(id, sol), throwsStateError);
      expect(rpcCalls, 0);
      expect(sync.testSessions[id]!.metadata!.model, luna);
    });
  }
}
