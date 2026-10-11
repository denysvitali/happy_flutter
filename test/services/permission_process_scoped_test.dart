import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

void main() {
  late Sync sync;

  setUp(() {
    sync = createTestSync();
    resetTestSync(sync);
    sync.testIsInitialized = true;
  });

  tearDown(() {
    sync.testMachineRPCOverride = null;
    sync.testGetSpawnEnvVarsOverride = null;
    sync.testSessionRPCOverride = null;
    sync.testResetRpcCapabilitiesPolicy();
    sync.testIsInitialized = false;
    resetTestSync(sync);
  });

  for (final flavor in ['prime-agent', 'har']) {
    for (final lifecycle in ['stopped', 'archived']) {
      for (final allow in [true, false]) {
        test(
          '$flavor $lifecycle recent permission $allow never restores',
          () async {
            const sessionId = 'stopped-process';
            var spawnCalls = 0;
            var permissionCalls = 0;
            sync.testSessions[sessionId] = Session(
              id: sessionId,
              seq: 1,
              createdAt: 0,
              updatedAt: 0,
              active: true,
              presence: 'online',
              activeAt: 0,
              metadataVersion: 1,
              agentStateVersion: 1,
              thinking: false,
              metadata: Metadata(
                host: '',
                machineId: 'machine-1',
                path: '/project',
                flavor: flavor,
                lifecycleState: lifecycle,
              ),
            );
            sync.testRegisterSpawn(sessionId, agent: flavor);
            sync.testMachineRPCOverride = (_, _, _) async {
              spawnCalls++;
              return {'type': 'success', 'sessionId': sessionId};
            };
            sync.testSessionRPCOverride = (_, _, _) async {
              permissionCalls++;
              return {'ok': true};
            };
            await expectLater(
              allow
                  ? sync.sessionAllow(sessionId, 'old-permission')
                  : sync.sessionDeny(sessionId, 'old-permission'),
              throwsA(isA<StateError>()),
            );
            expect(spawnCalls, 0);
            expect(permissionCalls, 0);
          },
        );
      }
    }
  }

  for (final allow in [true, false]) {
    for (final stage in ['capability', 'response', 'error', 'restore']) {
      test(
        'permission $allow stale $stage preserves replacement state',
        () async {
          const id = 'permission-reset';
          final started = Completer<void>();
          final release = Completer<dynamic>();
          var permissionCalls = 0;
          var refreshes = 0;
          sync.testSessionRPCOverride = (_, _, _) {
            permissionCalls++;
            if (stage != 'capability' && stage != 'restore') {
              started.complete();
              return release.future;
            }
            return Future<dynamic>.value({'ok': true});
          };
          if (stage == 'capability') {
            sync.testRpcCapabilitiesOverride = (_, _, _) {
              started.complete();
              return release.future;
            };
          }
          if (stage == 'restore') {
            sync.testGetSpawnEnvVarsOverride = (_) async =>
                (envVars: <String, String>{}, profile: null);
            sync.testSessions[id] = Session(
              id: id,
              seq: 1,
              createdAt: 0,
              updatedAt: 0,
              active: false,
              activeAt: 0,
              metadataVersion: 1,
              agentStateVersion: 1,
              thinking: false,
              metadata: const Metadata(
                host: '',
                machineId: 'machine-1',
                path: '/project',
                flavor: 'claude',
                lifecycleState: 'archived',
              ),
            );
            sync.testMachineRPCOverride = (_, _, _) {
              started.complete();
              return release.future.then(
                (value) => Map<String, dynamic>.from(value as Map),
              );
            };
          }
          final result = expectLater(
            allow
                ? sync.sessionAllow(id, 'old-permission')
                : sync.sessionDeny(id, 'old-permission'),
            throwsStateError,
          );
          await started.future;
          sync.testAdvanceRuntimeGeneration();
          sync.testSessions.clear();
          sync.testSetSessionMessages(id, [
            {
              'id': 'replacement',
              'seq': 1,
              'kind': 'tool-call',
              'permission': {'status': 'pending'},
            },
          ]);
          sync.sessionsSync = InvalidateSync(() async {
            refreshes++;
          });
          sync.messagesSync[id] = InvalidateSync(() async {
            refreshes++;
          });
          if (stage == 'error') {
            release.completeError(StateError('old ACK error'));
          } else if (stage == 'capability') {
            release.complete({
              'scope': 'session',
              'protocolVersion': 2,
              'methods': ['permission'],
            });
          } else if (stage == 'restore') {
            release.complete({'type': 'success', 'sessionId': id});
          } else {
            release.complete({'ok': true});
          }
          await result;
          await Future<void>.delayed(Duration.zero);
          expect(refreshes, 0);
          expect(
            permissionCalls,
            stage == 'response' || stage == 'error' ? 1 : 0,
          );
          expect(sync.testSessionMessages(id)!.single['permission'], {
            'status': 'pending',
          });
          expect(sync.testSessionSpawnedAt.containsKey(id), isFalse);
          sync.sessionsSync.dispose();
          sync.messagesSync[id]?.dispose();
        },
      );
    }
  }
}
