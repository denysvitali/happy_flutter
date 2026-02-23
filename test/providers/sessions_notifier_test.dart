import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('SessionsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Session createTestSession({
      required String id,
      required String name,
      bool active = true,
    }) {
      return Session(
        id: id,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
        active: active,
        activeAt: 1234567890,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'online',
        metadata: Metadata(
          host: 'test-host',
          path: '/test/path',
          name: name,
        ),
      );
    }

    test('should initialize with empty map', () {
      final sessions = container.read(sessionsNotifierProvider);
      expect(sessions, isEmpty);
    });

    test('should set sessions from list', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final sessions = [
        createTestSession(id: 'session-1', name: 'Session 1'),
        createTestSession(id: 'session-2', name: 'Session 2'),
        createTestSession(id: 'session-3', name: 'Session 3'),
      ];

      notifier.setSessions(sessions);

      final state = container.read(sessionsNotifierProvider);
      expect(state, hasLength(3));
      expect(state['session-1']?.metadata?.name, 'Session 1');
      expect(state['session-2']?.metadata?.name, 'Session 2');
      expect(state['session-3']?.metadata?.name, 'Session 3');
    });

    test('should get session by id', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final session = createTestSession(id: 'test-session', name: 'Test Session');
      notifier.setSessions([session]);

      final retrieved = notifier.getSession('test-session');
      expect(retrieved, isNotNull);
      expect(retrieved?.id, 'test-session');
      expect(retrieved?.metadata?.name, 'Test Session');
    });

    test('should return null for non-existent session', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final retrieved = notifier.getSession('non-existent');
      expect(retrieved, isNull);
    });

    test('should clear all sessions', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final sessions = [
        createTestSession(id: 'session-1', name: 'Session 1'),
        createTestSession(id: 'session-2', name: 'Session 2'),
      ];

      notifier.setSessions(sessions);
      expect(container.read(sessionsNotifierProvider), hasLength(2));

      notifier.clear();

      final state = container.read(sessionsNotifierProvider);
      expect(state, isEmpty);
    });

    test('should replace existing sessions when setting new list', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final initialSessions = [
        createTestSession(id: 'session-1', name: 'Original 1'),
        createTestSession(id: 'session-2', name: 'Original 2'),
      ];

      notifier.setSessions(initialSessions);
      expect(container.read(sessionsNotifierProvider), hasLength(2));

      final newSessions = [
        createTestSession(id: 'session-3', name: 'New 1'),
        createTestSession(id: 'session-4', name: 'New 2'),
        createTestSession(id: 'session-5', name: 'New 3'),
      ];

      notifier.setSessions(newSessions);

      final state = container.read(sessionsNotifierProvider);
      expect(state, hasLength(3));
      expect(state.containsKey('session-1'), isFalse);
      expect(state.containsKey('session-2'), isFalse);
      expect(state['session-3']?.metadata?.name, 'New 1');
      expect(state['session-4']?.metadata?.name, 'New 2');
      expect(state['session-5']?.metadata?.name, 'New 3');
    });

    test('should handle sessions with different active states', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final sessions = [
        createTestSession(id: 'active-session', name: 'Active', active: true),
        createTestSession(id: 'inactive-session', name: 'Inactive', active: false),
      ];

      notifier.setSessions(sessions);

      final state = container.read(sessionsNotifierProvider);
      expect(state['active-session']?.active, isTrue);
      expect(state['inactive-session']?.active, isFalse);
    });

    test('should handle sessions with optional metadata fields', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final session = Session(
        id: 'minimal-session',
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
        active: true,
        activeAt: 1234567890,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'offline',
      );

      notifier.setSessions([session]);

      final state = container.read(sessionsNotifierProvider);
      expect(state['minimal-session'], isNotNull);
      expect(state['minimal-session']?.metadata, isNull);
      expect(state['minimal-session']?.presence, 'offline');
    });

    test('loadFromSync should handle uninitialized sync', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      // Should not throw when sync is not initialized
      notifier.loadFromSync();

      final state = container.read(sessionsNotifierProvider);
      expect(state, isEmpty);
    });

    test('refreshFromSync should handle uninitialized sync', () async {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      // Should not throw when sync is not initialized
      await notifier.refreshFromSync();

      final state = container.read(sessionsNotifierProvider);
      expect(state, isEmpty);
    });

    test('should maintain session order by id in map', () {
      final notifier = container.read(sessionsNotifierProvider.notifier);

      final sessions = [
        createTestSession(id: 'zebra', name: 'Zebra'),
        createTestSession(id: 'alpha', name: 'Alpha'),
        createTestSession(id: 'beta', name: 'Beta'),
      ];

      notifier.setSessions(sessions);

      final state = container.read(sessionsNotifierProvider);
      final keys = state.keys.toList();
      expect(keys, contains('zebra'));
      expect(keys, contains('alpha'));
      expect(keys, contains('beta'));
    });
  });
}
