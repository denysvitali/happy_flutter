import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  late Sync sync;
  const id = 'har-model-switch';
  const luna = 'codex/gpt-6-luna';
  const sol = 'codex/gpt-6.1-sol';
  const grok = 'grok/grok-4.7';

  setUp(() {
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
      metadata: const Metadata(host: '', model: luna, flavor: 'har'),
    );
    sync.testSetSessionSpawnedModel(id, luna);
  });

  tearDown(() {
    sync.testSessionRPCOverride = null;
    sync.testSessions.remove(id);
    sync.testSessionSpawnedModel.remove(id);
  });

  test(
    'confirmed switch updates running and launch baselines before socket',
    () async {
      sync.testSessionRPCOverride = (sessionId, method, params) async {
        expect(sessionId, id);
        expect(method, 'set_model');
        expect(params, {'model': sol});
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
        expect(method, 'set_model');
        expect(params, {'model': grok});
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
}
