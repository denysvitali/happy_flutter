import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/chat/helpers/chat_dialogs.dart';

Machine _machine(
  String id, {
  bool online = true,
  bool kube = true,
  String? host,
  int ageMs = 0,
}) => Machine(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: online,
  activeAt: DateTime.now().millisecondsSinceEpoch - ageMs,
  metadataVersion: 1,
  daemonStateVersion: 1,
  metadata: MachineMetadata(
    host: host ?? id,
    spawnBackends: kube ? ['kubernetes'] : ['local'],
  ),
);

List<String> _ids(List<Machine> ms) => ms.map((m) => m.id).toList();

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
  group('continueTargetMachines', () {
    test('uses the source session machine when known', () {
      expect(
        _ids(
          continueTargetMachines(
            _session(metadata: const Metadata(machineId: 'own')),
            {'own': _machine('own'), 'k': _machine('k')},
          ),
        ),
        ['own'],
      );
    });

    test('collapses a daemon serving a previous machine ID', () {
      expect(
        _ids(
          continueTargetMachines(_session(), {
            'current': _machine('current', host: 'pod-1'),
            'alias': _machine('alias', host: 'pod-1', ageMs: 5000),
            'local': _machine('local', kube: false),
            'off': _machine('off', online: false),
          }),
        ),
        ['current'],
      );
    });

    test('offers every distinct Kubernetes daemon', () {
      expect(
        _ids(
          continueTargetMachines(null, {
            'a': _machine('a'),
            'b': _machine('b'),
          }),
        )..sort(),
        ['a', 'b'],
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

  test('SpawnSessionRequest sends codexCyberAccessProgram only when set', () {
    const base = SpawnSessionRequest(type: 'spawn-in-directory', directory: '');
    expect(base.toJson().containsKey('codexCyberAccessProgram'), isFalse);
    const req = SpawnSessionRequest(
      type: 'spawn-in-directory',
      directory: '',
      profileId: 'p',
      codexCyberAccessProgram: 'daybreak_blue',
    );
    expect(req.toJson()['codexCyberAccessProgram'], 'daybreak_blue');
    expect(
      req.withoutProfileId().toJson()['codexCyberAccessProgram'],
      'daybreak_blue',
    );
    final legacy = req.withoutCodexCyberAccessProgram().toJson();
    expect(legacy.containsKey('codexCyberAccessProgram'), isFalse);
    expect(legacy['profileId'], 'p');
  });
}
