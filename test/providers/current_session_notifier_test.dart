import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('CurrentSessionNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    Session createTestSession({
      required String id,
      String? draft,
      String? permissionMode,
      String? modelMode,
    }) {
      return Session(
        id: id,
        seq: 1,
        createdAt: 1234567890,
        updatedAt: 1234567890,
        active: true,
        activeAt: 1234567890,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'online',
        draft: draft,
        permissionMode: permissionMode,
        modelMode: modelMode,
      );
    }

    test('should initialize with null session', () {
      final session = container.read(currentSessionNotifierProvider);
      expect(session, isNull);
    });

    test('should set session', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(id: 'session-1');
      notifier.setSession(session);

      final state = container.read(currentSessionNotifierProvider);
      expect(state, isNotNull);
      expect(state?.id, 'session-1');
    });

    test('should clear session by setting null', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(id: 'session-1');
      notifier.setSession(session);
      expect(container.read(currentSessionNotifierProvider), isNotNull);

      notifier.setSession(null);

      final state = container.read(currentSessionNotifierProvider);
      expect(state, isNull);
    });

    test('should update draft when session is set', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(id: 'session-1', draft: 'Initial draft');
      notifier.setSession(session);

      notifier.updateDraft('Updated draft message');

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.draft, 'Updated draft message');
    });

    test('should not update draft when session is null', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      // Should not throw when trying to update draft with no session
      notifier.updateDraft('This should not crash');

      final state = container.read(currentSessionNotifierProvider);
      expect(state, isNull);
    });

    test('should update permission mode when session is set', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(
        id: 'session-1',
        permissionMode: 'read',
      );
      notifier.setSession(session);
      expect(container.read(currentSessionNotifierProvider)?.permissionMode, 'read');

      notifier.updatePermissionMode('write');

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.permissionMode, 'write');
    });

    test('should clear permission mode when null is passed', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(
        id: 'session-1',
        permissionMode: 'admin',
      );
      notifier.setSession(session);
      expect(container.read(currentSessionNotifierProvider)?.permissionMode, 'admin');

      notifier.updatePermissionMode(null);

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.permissionMode, isNull);
    });

    test('should not update permission mode when session is null', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      // Should not throw when trying to update with no session
      notifier.updatePermissionMode('write');

      final state = container.read(currentSessionNotifierProvider);
      expect(state, isNull);
    });

    test('should update model mode when session is set', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(
        id: 'session-1',
        modelMode: 'fast',
      );
      notifier.setSession(session);
      expect(container.read(currentSessionNotifierProvider)?.modelMode, 'fast');

      notifier.updateModelMode('quality');

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.modelMode, 'quality');
    });

    test('should clear model mode when null is passed', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(
        id: 'session-1',
        modelMode: 'balanced',
      );
      notifier.setSession(session);
      expect(container.read(currentSessionNotifierProvider)?.modelMode, 'balanced');

      notifier.updateModelMode(null);

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.modelMode, isNull);
    });

    test('should not update model mode when session is null', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      // Should not throw when trying to update with no session
      notifier.updateModelMode('fast');

      final state = container.read(currentSessionNotifierProvider);
      expect(state, isNull);
    });

    test('should preserve other fields when updating draft', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(
        id: 'session-1',
        draft: 'Original',
        permissionMode: 'write',
        modelMode: 'quality',
      );
      notifier.setSession(session);

      notifier.updateDraft('New draft');

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.id, 'session-1');
      expect(state?.draft, 'New draft');
      expect(state?.permissionMode, 'write');
      expect(state?.modelMode, 'quality');
    });

    test('should preserve other fields when updating permission mode', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(
        id: 'session-1',
        draft: 'Test draft',
        permissionMode: 'read',
        modelMode: 'fast',
      );
      notifier.setSession(session);

      notifier.updatePermissionMode('write');

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.id, 'session-1');
      expect(state?.draft, 'Test draft');
      expect(state?.modelMode, 'fast');
    });

    test('should preserve other fields when updating model mode', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(
        id: 'session-1',
        draft: 'Test draft',
        permissionMode: 'admin',
        modelMode: 'fast',
      );
      notifier.setSession(session);

      notifier.updateModelMode('quality');

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.id, 'session-1');
      expect(state?.draft, 'Test draft');
      expect(state?.permissionMode, 'admin');
    });

    test('should handle multiple updates in sequence', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(id: 'session-1');
      notifier.setSession(session);

      notifier.updateDraft('Draft 1');
      notifier.updateDraft('Draft 2');
      notifier.updatePermissionMode('mode1');
      notifier.updateModelMode('model1');
      notifier.updateDraft('Draft 3');
      notifier.updatePermissionMode('mode2');

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.draft, 'Draft 3');
      expect(state?.permissionMode, 'mode2');
      expect(state?.modelMode, 'model1');
    });

    test('should handle session replacement', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session1 = createTestSession(
        id: 'session-1',
        draft: 'Draft from session 1',
        permissionMode: 'mode1',
      );
      notifier.setSession(session1);

      final session2 = createTestSession(
        id: 'session-2',
        draft: 'Draft from session 2',
        modelMode: 'model2',
      );
      notifier.setSession(session2);

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.id, 'session-2');
      expect(state?.draft, 'Draft from session 2');
      expect(state?.permissionMode, isNull);
      expect(state?.modelMode, 'model2');
    });

    test('should handle session with all optional fields null', () {
      final notifier = container.read(currentSessionNotifierProvider.notifier);

      final session = createTestSession(id: 'minimal-session');
      notifier.setSession(session);

      final state = container.read(currentSessionNotifierProvider);
      expect(state?.id, 'minimal-session');
      expect(state?.draft, isNull);
      expect(state?.permissionMode, isNull);
      expect(state?.modelMode, isNull);
    });
  });
}
