import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

/// Derived session views: recency ordering, machine/path recency
/// derivation, and identity-stable list projections.
void main() {
  late ProviderContainer container;

  Session buildSession(
    String id, {
    required int updatedAt,
    String? machineId = 'm1',
    String? path = '/repo',
  }) {
    return Session(
      id: id,
      seq: 1,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      active: true,
      activeAt: updatedAt,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      presence: 'online',
      metadata: Metadata(host: 'host', path: path ?? '', machineId: machineId),
    );
  }

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('recentSessionIdsProvider', () {
    test('orders by updatedAt descending regardless of insertion order', () {
      final random = Random(8);
      final pool = [
        for (var i = 0; i < 20; i++) buildSession('s$i', updatedAt: 1000 + i),
      ];
      final expected = pool.reversed.map((s) => s.id).toList();
      final notifier = container.read(sessionsNotifierProvider.notifier);
      for (var round = 0; round < 20; round++) {
        notifier.setSessions([...pool]..shuffle(random));
        expect(container.read(recentSessionIdsProvider), expected);
      }
    });

    test('the id list maps back to the session with that id', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([
        buildSession('a', updatedAt: 3, path: '/a'),
        buildSession('b', updatedAt: 2, path: '/b'),
        buildSession('c', updatedAt: 1, path: '/c'),
      ]);
      for (final id in container.read(recentSessionIdsProvider)) {
        final session = container.read(sessionByIdProvider(id));
        expect(session?.id, id);
        expect(session?.metadata?.path, '/$id');
      }
      expect(container.read(sessionByIdProvider('nope')), isNull);
    });
  });

  group('recentMachineIdsProvider', () {
    test('machines are ordered by their most recent session, deduped', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([
        buildSession('old-m2', updatedAt: 1, machineId: 'm2'),
        buildSession('new-m2', updatedAt: 9, machineId: 'm2'),
        buildSession('mid-m1', updatedAt: 5, machineId: 'm1'),
        buildSession('no-machine', updatedAt: 10, machineId: null),
      ]);
      expect(container.read(recentMachineIdsProvider), ['m2', 'm1']);
    });
  });

  group('recentPathsForMachineProvider', () {
    test('paths are scoped per machine, deduped, most recent first', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([
        buildSession('a', updatedAt: 1, machineId: 'm1', path: '/x'),
        buildSession('b', updatedAt: 5, machineId: 'm1', path: '/y'),
        buildSession('c', updatedAt: 3, machineId: 'm1', path: '/x'),
        buildSession('d', updatedAt: 9, machineId: 'm2', path: '/x'),
        buildSession('e', updatedAt: 8, machineId: 'm1', path: ''),
      ]);
      expect(container.read(recentPathsForMachineProvider('m1')), ['/y', '/x']);
      expect(container.read(recentPathsForMachineProvider('m2')), ['/x']);
      expect(container.read(recentPathsForMachineProvider('ghost')), isEmpty);
    });

    test('same path on two machines stays separate per machine', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([
        buildSession('a', updatedAt: 1, machineId: 'm1', path: '/shared'),
        buildSession('b', updatedAt: 2, machineId: 'm2', path: '/shared'),
      ]);
      expect(container.read(recentPathsForMachineProvider('m1')), ['/shared']);
      expect(container.read(recentPathsForMachineProvider('m2')), ['/shared']);
      expect(container.read(recentMachineIdsProvider), ['m2', 'm1']);
    });
  });

  group('sessionsListProvider', () {
    test('contains every session exactly once', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      final sessions = [
        for (var i = 0; i < 15; i++) buildSession('s$i', updatedAt: i),
      ];
      notifier.setSessions(sessions);
      final list = container.read(sessionsListProvider);
      expect(list.map((s) => s.id).toSet(), sessions.map((s) => s.id).toSet());
      expect(list.length, sessions.length);
    });

    test('rebuilds only when the sessions map changes', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([buildSession('a', updatedAt: 1)]);
      final first = container.read(sessionsListProvider);
      expect(identical(container.read(sessionsListProvider), first), isTrue);

      notifier.setSessions([buildSession('a', updatedAt: 2)]);
      final second = container.read(sessionsListProvider);
      expect(identical(second, first), isFalse);
      expect(second.single.updatedAt, 2);
    });
  });
}
