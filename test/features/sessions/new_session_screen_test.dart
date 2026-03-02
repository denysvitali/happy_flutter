import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/features/sessions/new_session_screen.dart';

Machine _machine({
  required String id,
  required bool active,
  required int activeAt,
}) {
  return Machine(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: active,
    activeAt: activeAt,
    metadataVersion: 1,
    daemonStateVersion: 1,
  );
}

void main() {
  group('sortMachinesForSessionCreation', () {
    test('includes inactive machines', () {
      final machines = [_machine(id: 'm1', active: false, activeAt: 10)];

      final sorted = sortMachinesForSessionCreation(machines);

      expect(sorted, hasLength(1));
      expect(sorted.first.id, 'm1');
    });

    test('sorts active machines before inactive machines', () {
      final machines = [
        _machine(id: 'inactive', active: false, activeAt: 50),
        _machine(id: 'active', active: true, activeAt: 10),
      ];

      final sorted = sortMachinesForSessionCreation(machines);

      expect(sorted.map((m) => m.id).toList(), ['active', 'inactive']);
    });

    test('sorts by activeAt descending within same active state', () {
      final machines = [
        _machine(id: 'old', active: true, activeAt: 10),
        _machine(id: 'new', active: true, activeAt: 20),
      ];

      final sorted = sortMachinesForSessionCreation(machines);

      expect(sorted.map((m) => m.id).toList(), ['new', 'old']);
    });
  });
}
