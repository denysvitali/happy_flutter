import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/chat/helpers/chat_dialogs.dart';

Machine _machine(String id, {bool online = true, bool kube = true}) => Machine(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: online,
  activeAt: DateTime.now().millisecondsSinceEpoch,
  metadataVersion: 1,
  daemonStateVersion: 1,
  metadata: MachineMetadata(spawnBackends: kube ? ['kubernetes'] : ['local']),
);

Session _session({Metadata? metadata}) => Session(
  id: 's1',
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: false,
  activeAt: 1,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: 'offline',
  metadata: metadata,
);

void main() {
  group('continueTargetMachine', () {
    test('uses the source session machine when known', () {
      expect(
        continueTargetMachine(
          _session(metadata: const Metadata(machineId: 'own')),
          {'k': _machine('k')},
        ),
        'own',
      );
    });

    test('falls back to the single online Kubernetes machine', () {
      expect(
        continueTargetMachine(_session(), {
          'k': _machine('k'),
          'l': _machine('l', kube: false),
          'off': _machine('off', online: false),
        }),
        'k',
      );
    });

    test('refuses to guess between several Kubernetes machines', () {
      expect(
        continueTargetMachine(null, {'a': _machine('a'), 'b': _machine('b')}),
        isNull,
      );
    });
  });

  test('SpawnSessionRequest sends continueFromSessionId only when set', () {
    const base = SpawnSessionRequest(type: 'spawn-in-directory', directory: '');
    expect(base.toJson().containsKey('continueFromSessionId'), isFalse);
    const req = SpawnSessionRequest(
      type: 'spawn-in-directory',
      directory: '',
      continueFromSessionId: 'src',
      profileId: 'p',
    );
    expect(req.toJson()['continueFromSessionId'], 'src');
    expect(req.withoutProfileId().toJson()['continueFromSessionId'], 'src');
  });
}
