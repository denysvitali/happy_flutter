import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_helpers.dart';

/// Per-session projection invariants for [SessionUiStateNotifier]: every
/// row maps to the session with the same id, targeted updates touch only
/// the target entry, and optimistic archive state flows through the
/// ordering projection.
void main() {
  late ProviderContainer container;
  final seeded = <String>{};

  Session buildSession(String id, {String presence = 'online'}) {
    return Session(
      id: id,
      seq: 1,
      createdAt: 1000,
      updatedAt: 1000,
      active: true,
      activeAt: 1000,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      presence: presence,
      metadata: const Metadata(host: 'host', path: '/repo', machineId: 'm1'),
    );
  }

  Map<String, dynamic> message(
    String text, {
    int createdAt = 2000,
    String role = 'agent',
  }) {
    return {
      'id': 'msg-$text',
      'localId': 'local-$text',
      'role': role,
      'content': text,
      'createdAt': createdAt,
    };
  }

  /// Seeds [id] in sync with a session row and one message whose preview
  /// and timestamp encode the id, so cross-wiring between rows is visible.
  void seed(String id, {int createdAt = 2000, int unread = 0}) {
    seeded.add(id);
    sync
      ..testSessions[id] = buildSession(id)
      ..testSetSessionMessages(id, [
        message('preview for $id', createdAt: createdAt),
      ]);
    if (unread > 0) sync.testSeedUnread(id, unread);
  }

  setUp(() {
    container = ProviderContainer();
    createTestSync();
    sync
      ..testSessions.clear()
      ..testClearSpawnGuardState()
      ..testResetDataChangeCounters()
      ..testIsInitialized = true;
  });

  tearDown(() {
    for (final id in seeded) {
      sync.testClearSessionMessageState(id);
    }
    seeded.clear();
    sync
      ..testSessions.clear()
      ..testClearSpawnGuardState()
      ..testIsInitialized = false;
    container.dispose();
  });

  group('id to row mapping', () {
    test('every entry carries the preview and timestamp of its own id', () {
      final random = Random(17);
      final ids = [for (var i = 0; i < 30; i++) 'row-$i'];
      final shuffled = [...ids]..shuffle(random);
      for (final id in shuffled) {
        seed(id, createdAt: 5000 + ids.indexOf(id));
      }
      final state = container.read(sessionUiStateNotifierProvider);
      expect(state.bySessionId.keys.toSet(), ids.toSet());
      for (final id in ids) {
        final entry = state.bySessionId[id]!;
        expect(entry.lastMessagePreview, 'preview for $id');
        expect(entry.lastMessageTimestamp, 5000 + ids.indexOf(id));
        expect(state.ordering.timestamps[id], entry.lastMessageTimestamp);
        expect(
          state.missionControl.bySessionId[id]!.lastMessageTimestamp,
          entry.lastMessageTimestamp,
        );
        expect(
          container.read(sessionUiEntryProvider(id)).lastMessagePreview,
          'preview for $id',
        );
      }
    });

    test('a session without messages maps to a null timestamp entry', () {
      sync.testSessions['bare'] = buildSession('bare');
      seeded.add('bare');
      final state = container.read(sessionUiStateNotifierProvider);
      expect(state.bySessionId['bare']!.lastMessageTimestamp, isNull);
      expect(state.bySessionId['bare']!.lastMessagePreview, isNull);
      expect(state.ordering.timestamps.containsKey('bare'), isTrue);
      expect(state.ordering.timestamps['bare'], isNull);
    });

    test('unknown ids resolve to the shared empty entry', () {
      expect(
        identical(
          container.read(sessionUiEntryProvider('nope')),
          SessionUiEntry.empty,
        ),
        isTrue,
      );
    });
  });

  group('targeted updates', () {
    test('loadSessionFromSync touches only the target entry', () {
      for (var i = 0; i < 5; i++) {
        seed('s$i');
      }
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      final before = container.read(sessionUiStateNotifierProvider);

      sync
        ..testSeedUnread('s2', 4)
        ..testNotifySessionMessagesChanged('s2');
      notifier.loadSessionFromSync('s2');

      final after = container.read(sessionUiStateNotifierProvider);
      expect(after.bySessionId['s2']!.unreadCount, 4);
      expect(
        identical(after.bySessionId['s2'], before.bySessionId['s2']),
        isFalse,
      );
      for (final id in ['s0', 's1', 's3', 's4']) {
        expect(
          identical(after.bySessionId[id], before.bySessionId[id]),
          isTrue,
          reason: '$id must keep identity',
        );
        expect(
          identical(
            after.missionControl.bySessionId[id],
            before.missionControl.bySessionId[id],
          ),
          isTrue,
        );
      }
      // Unread changes the Mission Control lane input but not ordering.
      expect(after.missionControl.bySessionId['s2']!.unreadCount, 4);
      expect(identical(after.ordering, before.ordering), isTrue);
    });

    test('a new message timestamp bumps ordering for the target only', () {
      seed('a', createdAt: 1000);
      seed('b', createdAt: 1000);
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      final before = container.read(sessionUiStateNotifierProvider);

      sync
        ..testSetSessionMessages('a', [message('newer', createdAt: 9000)])
        ..testNotifySessionMessagesChanged('a');
      notifier.loadSessionFromSync('a');

      final after = container.read(sessionUiStateNotifierProvider);
      expect(after.ordering.revision, before.ordering.revision + 1);
      expect(after.ordering.timestamps['a'], 9000);
      expect(after.ordering.timestamps['b'], 1000);
      expect(
        identical(after.bySessionId['b'], before.bySessionId['b']),
        isTrue,
      );
    });

    test('an unchanged target is a no-op for state identity', () {
      seed('a');
      seed('b');
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      final before = container.read(sessionUiStateNotifierProvider);
      notifier.loadSessionFromSync('a');
      expect(
        identical(container.read(sessionUiStateNotifierProvider), before),
        isTrue,
      );
    });

    test(
      'paired session-domain event does not rescan an unchanged catalog',
      () {
        seed('a');
        seed('b');
        final notifier = container.read(
          sessionUiStateNotifierProvider.notifier,
        );
        container.read(sessionUiStateNotifierProvider);
        final fullScansBefore = notifier.debugFullComputeCount;

        sync
          ..testSetSessionMessages('a', [message('changed', createdAt: 7000)])
          ..testNotifySessionMessagesChanged('a')
          ..testNotifyDomains({SyncDomain.messages, SyncDomain.sessions});
        notifier
          ..loadSessionFromSync('a')
          ..loadCatalogFromSync();

        expect(notifier.debugFullComputeCount, fullScansBefore);
        expect(
          container
              .read(sessionUiStateNotifierProvider)
              .bySessionId['a']!
              .lastMessagePreview,
          'changed',
        );
      },
    );

    test('standalone session event still reconciles an unchanged catalog', () {
      seed('a');
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      container.read(sessionUiStateNotifierProvider);
      final fullScansBefore = notifier.debugFullComputeCount;

      sync.testNotifyDomains({SyncDomain.sessions});
      notifier.loadCatalogFromSync();

      expect(notifier.debugFullComputeCount, fullScansBefore + 1);
    });

    test('catalog load still performs a full reconcile for new ids', () {
      seed('a');
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      container.read(sessionUiStateNotifierProvider);
      final fullScansBefore = notifier.debugFullComputeCount;

      seed('b');
      notifier.loadCatalogFromSync();

      expect(notifier.debugFullComputeCount, fullScansBefore + 1);
      expect(
        container.read(sessionUiStateNotifierProvider).bySessionId,
        contains('b'),
      );
    });

    test('a removed target leaves every projection without it', () {
      seed('a');
      seed('b');
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      final before = container.read(sessionUiStateNotifierProvider);

      sync.testSessions.remove('a');
      notifier.loadSessionFromSync('a');

      final after = container.read(sessionUiStateNotifierProvider);
      expect(after.bySessionId.containsKey('a'), isFalse);
      expect(after.ordering.timestamps.containsKey('a'), isFalse);
      expect(after.missionControl.bySessionId.containsKey('a'), isFalse);
      expect(
        identical(after.bySessionId['b'], before.bySessionId['b']),
        isTrue,
      );
      expect(after.ordering.revision, before.ordering.revision + 1);
    });

    test('a full reload with identical data preserves every entry', () {
      for (var i = 0; i < 8; i++) {
        seed('s$i', createdAt: 1000 + i);
      }
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      final before = container.read(sessionUiStateNotifierProvider);

      sync.testNotifyDataChanged();
      notifier.loadFromSync();

      final after = container.read(sessionUiStateNotifierProvider);
      expect(identical(after, before), isTrue);
    });

    test('a full reload after one change keeps the other identities', () {
      for (var i = 0; i < 8; i++) {
        seed('s$i', createdAt: 1000 + i);
      }
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      final before = container.read(sessionUiStateNotifierProvider);

      sync
        ..testSetSessionMessages('s3', [message('changed', createdAt: 7000)])
        ..testNotifySessionMessagesChanged('s3')
        ..testNotifyDataChanged();
      notifier.loadFromSync();

      final after = container.read(sessionUiStateNotifierProvider);
      expect(after.bySessionId['s3']!.lastMessagePreview, 'changed');
      for (var i = 0; i < 8; i++) {
        if (i == 3) continue;
        expect(
          identical(after.bySessionId['s$i'], before.bySessionId['s$i']),
          isTrue,
          reason: 's$i must keep identity',
        );
      }
    });
  });

  group('optimistic archive projection', () {
    test('archived ids reach the ordering and the derived provider', () {
      seed('a');
      seed('b');
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      final before = container.read(sessionUiStateNotifierProvider);
      final fullScansBefore = notifier.debugFullComputeCount;

      sync.markSessionArchived('a');
      notifier.loadCatalogFromSync();

      final after = container.read(sessionUiStateNotifierProvider);
      expect(after.optimisticallyArchivedIds, {'a'});
      expect(after.ordering.optimisticallyArchivedIds, {'a'});
      expect(after.ordering.revision, before.ordering.revision + 1);
      expect(container.read(optimisticallyArchivedIdsProvider), {'a'});
      expect(notifier.debugFullComputeCount, fullScansBefore);
      // Row data is unaffected by archive bookkeeping.
      expect(
        identical(after.bySessionId['a'], before.bySessionId['a']),
        isTrue,
      );

      sync.markSessionUnarchived('a');
      notifier.loadCatalogFromSync();
      final restored = container.read(sessionUiStateNotifierProvider);
      expect(restored.optimisticallyArchivedIds, isEmpty);
      expect(container.read(optimisticallyArchivedIdsProvider), isEmpty);
    });

    test('targeted updates keep the archived set intact', () {
      seed('a');
      seed('b');
      final notifier = container.read(sessionUiStateNotifierProvider.notifier);
      sync.markSessionArchived('a');
      notifier.loadFromSync();

      sync
        ..testSeedUnread('b', 1)
        ..testNotifySessionMessagesChanged('b');
      notifier.loadSessionFromSync('b');

      final state = container.read(sessionUiStateNotifierProvider);
      expect(state.optimisticallyArchivedIds, {'a'});
      expect(state.ordering.optimisticallyArchivedIds, {'a'});
    });
  });

  group('pure projections', () {
    test('SessionUiOrdering.reconcile reuses equal inputs', () {
      final first = SessionUiOrdering.reconcile(
        previous: SessionUiOrdering.empty,
        timestamps: {'a': 1, 'b': null},
        optimisticallyArchivedIds: {'b'},
      );
      final same = SessionUiOrdering.reconcile(
        previous: first,
        timestamps: {'b': null, 'a': 1},
        optimisticallyArchivedIds: {'b'},
      );
      final changed = SessionUiOrdering.reconcile(
        previous: first,
        timestamps: {'a': 2, 'b': null},
        optimisticallyArchivedIds: {'b'},
      );
      expect(identical(same, first), isTrue);
      expect(identical(changed, first), isFalse);
      expect(changed.revision, first.revision + 1);
      expect(first.revision, 1);
    });

    test('an unprepared ordering is always replaced', () {
      final prepared = SessionUiOrdering.reconcile(
        previous: SessionUiOrdering.unprepared,
        timestamps: const {},
        optimisticallyArchivedIds: const {},
      );
      expect(prepared.isPrepared, isTrue);
      expect(identical(prepared, SessionUiOrdering.unprepared), isFalse);
    });

    test('MissionControlUiProjection maps ids one-to-one into UI state', () {
      final projection = MissionControlUiProjection.reconcile(
        previous: MissionControlUiProjection.empty,
        entries: {
          'a': const MissionControlUiEntry(
            lastMessageTimestamp: 5,
            unreadCount: 2,
          ),
          'b': const MissionControlUiEntry(
            lastMessageTimestamp: null,
            unreadCount: 0,
            lastMessageIsError: true,
          ),
        },
      );
      final ui = projection.toUiState();
      expect(ui.bySessionId.keys.toSet(), {'a', 'b'});
      expect(ui.bySessionId['a']!.lastMessageTimestamp, 5);
      expect(ui.bySessionId['a']!.unreadCount, 2);
      expect(ui.bySessionId['b']!.lastMessageIsError, isTrue);
      expect(ui.bySessionId['b']!.lastMessageTimestamp, isNull);

      final same = MissionControlUiProjection.reconcile(
        previous: projection,
        entries: Map.of(projection.bySessionId),
      );
      expect(identical(same, projection), isTrue);
    });
  });
}
