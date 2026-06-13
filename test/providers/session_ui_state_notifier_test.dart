import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/utils/invalidate_sync.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('SessionUiStateNotifier', () {
    late ProviderContainer container;

    Session makeSession({
      required String id,
      String presence = 'online',
    }) {
      final now = DateTime.now().millisecondsSinceEpoch;
      return Session(
        id: id,
        seq: 1,
        createdAt: now - 10000,
        updatedAt: now - 5000,
        active: true,
        activeAt: now - 5000,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: presence,
        metadata: const Metadata(
          host: 'host',
          path: '/repo',
          machineId: 'machine-1',
        ),
      );
    }

    setUp(() {
      container = ProviderContainer();
      sync
        ..testIsInitialized = true
        ..sessionsSync = InvalidateSync(() async {})
        ..settingsSync = InvalidateSync(() async {})
        ..profileSync = InvalidateSync(() async {})
        ..purchasesSync = InvalidateSync(() async {})
        ..machinesSync = InvalidateSync(() async {})
        ..pushTokenSync = InvalidateSync(() async {})
        ..nativeUpdateSync = InvalidateSync(() async {})
        ..artifactsSync = InvalidateSync(() async {})
        ..sessionGitStatusSync = InvalidateSync(() async {});
    });

    tearDown(() {
      sync
        ..testSessions.clear()
        ..testClearSessionMessageState('session-1')
        ..testClearSessionMessageState('session-2')
        ..testIsInitialized = false;
      container.dispose();
    });

    test('build computes initial state from sync when initialized', () {
      sync
        ..testSessions['session-1'] = makeSession(id: 'session-1')
        ..testSetSessionMessages('session-1', [
          {
            'id': 'msg-1',
            'localId': 'local-1',
            'role': 'user',
            'content': 'Hello',
            'createdAt': 1000,
          },
        ])
        ..testSetLastEphemeralAt(
          'session-1',
          DateTime.now().millisecondsSinceEpoch,
        )
        ..testSetSessionUsage('session-1', {'contextSize': 42});

      final state = container.read(sessionUiStateNotifierProvider);
      final entry = state.bySessionId['session-1']!;

      expect(entry.lastMessageTimestamp, 1000);
      expect(entry.lastMessagePreview, 'Hello');
      expect(entry.lastMessageRole, 'user');
      expect(entry.isSessionReadyForMessages, isTrue);
      expect(entry.sessionUsage['contextSize'], 42);
    });

    test('build returns empty state when sync is not initialized', () {
      sync.testIsInitialized = false;

      final state = container.read(sessionUiStateNotifierProvider);

      expect(state.bySessionId, isEmpty);
      expect(state.optimisticallyArchivedIds, isEmpty);
    });

    test('loadFromSync updates derived state when sessions change', () {
      sync
        ..testSessions['session-1'] = makeSession(id: 'session-1')
        ..testSetSessionMessages('session-1', const []);

      final notifier = container.read(
        sessionUiStateNotifierProvider.notifier,
      );
      notifier.loadFromSync();

      expect(
        container.read(sessionUiStateNotifierProvider).bySessionId,
        contains('session-1'),
      );

      sync
        ..testSessions['session-2'] = makeSession(id: 'session-2')
        ..testNotifyDataChanged();
      notifier.loadFromSync();

      final state = container.read(sessionUiStateNotifierProvider);
      expect(state.bySessionId, contains('session-1'));
      expect(state.bySessionId, contains('session-2'));
    });

    test('loadFromSync is idempotent when sync counters are unchanged', () {
      sync
        ..testSessions['session-1'] = makeSession(id: 'session-1')
        ..testSetSessionMessages('session-1', const []);

      final notifier = container.read(
        sessionUiStateNotifierProvider.notifier,
      );
      notifier.loadFromSync();
      final first = container.read(sessionUiStateNotifierProvider);

      notifier.loadFromSync();
      final second = container.read(sessionUiStateNotifierProvider);

      expect(identical(first, second), isTrue);
    });

    test('clear resets state and counters', () {
      sync
        ..testSessions['session-1'] = makeSession(id: 'session-1')
        ..testSetSessionMessages('session-1', const []);

      final notifier = container.read(
        sessionUiStateNotifierProvider.notifier,
      );
      notifier.loadFromSync();
      expect(
        container.read(sessionUiStateNotifierProvider).bySessionId,
        isNotEmpty,
      );

      notifier.clear();

      final state = container.read(sessionUiStateNotifierProvider);
      expect(state.bySessionId, isEmpty);
      expect(state.optimisticallyArchivedIds, isEmpty);
    });

    test(
      'sessionUiEntryProvider returns empty entry for unknown session',
      () {
        final entry = container.read(
          sessionUiEntryProvider('unknown-session'),
        );
        expect(entry, same(SessionUiEntry.empty));
      },
    );

    test('optimisticallyArchivedIdsProvider exposes archived set', () {
      sync
        ..testSessions['session-1'] = makeSession(id: 'session-1')
        ..testSetSessionMessages('session-1', const [])
        ..markSessionArchived('session-1');

      container.read(sessionUiStateNotifierProvider.notifier).loadFromSync();

      final archived = container.read(optimisticallyArchivedIdsProvider);
      expect(archived, contains('session-1'));
    });
  });
}
