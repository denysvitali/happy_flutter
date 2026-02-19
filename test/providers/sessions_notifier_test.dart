import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

/// Creates a minimal [Session] for use in tests.
Session makeSession({
  required String id,
  int seq = 1,
  bool active = true,
  bool thinking = false,
}) {
  return Session(
    id: id,
    seq: seq,
    createdAt: 1700000000,
    updatedAt: 1700000000,
    active: active,
    activeAt: 1700000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: 'online',
  );
}

void main() {
  group('SessionsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty map', () {
      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, isEmpty);
      expect(sessions, isA<Map<String, Session>>());
    });

    test('addSession adds session to the map keyed by id', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      final session = makeSession(id: 'sess-1');

      notifier.addSession(session);

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, hasLength(1));
      expect(sessions.containsKey('sess-1'), isTrue);
      expect(sessions['sess-1']!.id, 'sess-1');
    });

    test('addSession with multiple sessions adds all to the map', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier
        ..addSession(makeSession(id: 'sess-a'))
        ..addSession(makeSession(id: 'sess-b'))
        ..addSession(makeSession(id: 'sess-c'));

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, hasLength(3));
      expect(sessions.containsKey('sess-a'), isTrue);
      expect(sessions.containsKey('sess-b'), isTrue);
      expect(sessions.containsKey('sess-c'), isTrue);
    });

    test('addSession overwrites existing session with same id', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier
        ..addSession(makeSession(id: 'sess-dup', seq: 1))
        ..addSession(makeSession(id: 'sess-dup', seq: 2));

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, hasLength(1));
      expect(sessions['sess-dup']!.seq, 2);
    });

    test('removeSession removes the session from the map', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier
        ..addSession(makeSession(id: 'sess-del'))
        ..addSession(makeSession(id: 'sess-keep'))
        ..removeSession('sess-del');

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, hasLength(1));
      expect(sessions.containsKey('sess-del'), isFalse);
      expect(sessions.containsKey('sess-keep'), isTrue);
    });

    test('removeSession with non-existent id does not error', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier.addSession(makeSession(id: 'sess-existing'));

      // Should not throw.
      notifier.removeSession('non-existent-id');

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, hasLength(1));
    });

    test('setSessions replaces all sessions at once', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier
        ..addSession(makeSession(id: 'old-1'))
        ..addSession(makeSession(id: 'old-2'));

      final newSessions = [
        makeSession(id: 'new-1'),
        makeSession(id: 'new-2'),
        makeSession(id: 'new-3'),
      ];
      notifier.setSessions(newSessions);

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, hasLength(3));
      expect(sessions.containsKey('old-1'), isFalse);
      expect(sessions.containsKey('new-1'), isTrue);
      expect(sessions.containsKey('new-2'), isTrue);
      expect(sessions.containsKey('new-3'), isTrue);
    });

    test('clear removes all sessions', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier
        ..addSession(makeSession(id: 'sess-1'))
        ..addSession(makeSession(id: 'sess-2'));

      expect(container.read(sessionsNotifierProvider), hasLength(2));

      notifier.clear();

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, isEmpty);
    });

    test('getSession returns session by id', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      final session = makeSession(id: 'sess-get');

      notifier.addSession(session);

      final found = notifier.getSession('sess-get');
      expect(found, isNotNull);
      expect(found!.id, 'sess-get');
    });

    test('getSession returns null for non-existent id', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final result = notifier.getSession('does-not-exist');
      expect(result, isNull);
    });

    test('sessions are accessible by their id', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier
        ..addSession(makeSession(id: 'alpha', seq: 10))
        ..addSession(makeSession(id: 'beta', seq: 20));

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions['alpha']!.seq, 10);
      expect(sessions['beta']!.seq, 20);
    });

    test('updateSession modifies existing session', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier.addSession(makeSession(id: 'sess-upd', thinking: false));

      notifier.updateSession(
        'sess-upd',
        (s) => Session(
          id: s.id,
          seq: s.seq,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
          active: s.active,
          activeAt: s.activeAt,
          metadataVersion: s.metadataVersion,
          agentStateVersion: s.agentStateVersion,
          thinking: true,
          presence: s.presence,
        ),
      );

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions['sess-upd']!.thinking, isTrue);
    });

    test('updateSession does nothing for non-existent id', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier.addSession(makeSession(id: 'sess-real'));

      // Should not throw.
      notifier.updateSession('non-existent', (s) => s);

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, hasLength(1));
    });

    test('setSessions with empty list clears all sessions', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      notifier
        ..addSession(makeSession(id: 'sess-1'))
        ..addSession(makeSession(id: 'sess-2'));

      notifier.setSessions([]);

      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, isEmpty);
    });

    test('loadFromSync does nothing when sync is not initialized', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      // sync is not initialized in tests, so loadFromSync is a no-op
      notifier.loadFromSync();

      // State should remain unchanged (empty)
      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, isEmpty);
    });
  });
}
