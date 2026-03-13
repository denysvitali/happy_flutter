import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('SessionGitStatusNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    GitStatus createTestGitStatus({
      String? branch = 'main',
      bool isDirty = false,
      int modifiedCount = 0,
      int untrackedCount = 0,
      int stagedCount = 0,
      int lastUpdatedAt = 1234567890,
    }) {
      return GitStatus(
        branch: branch,
        isDirty: isDirty,
        modifiedCount: modifiedCount,
        untrackedCount: untrackedCount,
        stagedCount: stagedCount,
        lastUpdatedAt: lastUpdatedAt,
      );
    }

    test('should initialize with empty map', () {
      final state = container.read(sessionGitStatusNotifierProvider);
      expect(state, isEmpty);
    });

    test('should set git status for a session', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );
      final status = createTestGitStatus();

      notifier.setGitStatus('session-1', status);

      final state = container.read(sessionGitStatusNotifierProvider);
      expect(state, hasLength(1));
      expect(state['session-1'], status);
    });

    test('should set git status for multiple sessions', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      notifier.setGitStatus(
        'session-1',
        createTestGitStatus(branch: 'main'),
      );
      notifier.setGitStatus(
        'session-2',
        createTestGitStatus(branch: 'develop', isDirty: true),
      );

      final state = container.read(sessionGitStatusNotifierProvider);
      expect(state, hasLength(2));
      expect(state['session-1']?.branch, 'main');
      expect(state['session-2']?.branch, 'develop');
      expect(state['session-2']?.isDirty, true);
    });

    test('should update existing git status', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      notifier.setGitStatus(
        'session-1',
        createTestGitStatus(isDirty: false),
      );
      notifier.setGitStatus(
        'session-1',
        createTestGitStatus(isDirty: true, modifiedCount: 3),
      );

      final state = container.read(sessionGitStatusNotifierProvider);
      expect(state, hasLength(1));
      expect(state['session-1']?.isDirty, true);
      expect(state['session-1']?.modifiedCount, 3);
    });

    test('should get git status for a session', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );
      final status = createTestGitStatus(branch: 'feature/test');

      notifier.setGitStatus('session-1', status);

      final result = notifier.getGitStatus('session-1');
      expect(result, isNotNull);
      expect(result?.branch, 'feature/test');
    });

    test('should return null for non-existent session', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      final result = notifier.getGitStatus('non-existent');
      expect(result, isNull);
    });

    test('should clear git status for a specific session', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      notifier.setGitStatus('session-1', createTestGitStatus());
      notifier.setGitStatus('session-2', createTestGitStatus());

      expect(
        container.read(sessionGitStatusNotifierProvider),
        hasLength(2),
      );

      notifier.clearGitStatus('session-1');

      final state = container.read(sessionGitStatusNotifierProvider);
      expect(state, hasLength(1));
      expect(state.containsKey('session-1'), isFalse);
      expect(state.containsKey('session-2'), isTrue);
    });

    test('should set all git statuses at once', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      final statuses = {
        'session-1': createTestGitStatus(branch: 'main'),
        'session-2': createTestGitStatus(branch: 'develop'),
        'session-3': createTestGitStatus(branch: 'hotfix'),
      };

      notifier.setAllGitStatuses(statuses);

      final state = container.read(sessionGitStatusNotifierProvider);
      expect(state, hasLength(3));
      expect(state['session-1']?.branch, 'main');
      expect(state['session-2']?.branch, 'develop');
      expect(state['session-3']?.branch, 'hotfix');
    });

    test('should replace all statuses when setAllGitStatuses', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      notifier.setGitStatus('old-session', createTestGitStatus());

      notifier.setAllGitStatuses({
        'new-session': createTestGitStatus(branch: 'new-branch'),
      });

      final state = container.read(sessionGitStatusNotifierProvider);
      expect(state, hasLength(1));
      expect(state.containsKey('old-session'), isFalse);
      expect(state['new-session']?.branch, 'new-branch');
    });

    test('should clear all git statuses', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      notifier.setGitStatus('session-1', createTestGitStatus());
      notifier.setGitStatus('session-2', createTestGitStatus());
      expect(
        container.read(sessionGitStatusNotifierProvider),
        hasLength(2),
      );

      notifier.clear();

      final state = container.read(sessionGitStatusNotifierProvider);
      expect(state, isEmpty);
    });

    test('should store complete git status with all fields', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      final fullStatus = GitStatus(
        branch: 'feature/full',
        isDirty: true,
        modifiedCount: 5,
        untrackedCount: 2,
        stagedCount: 3,
        lastUpdatedAt: 9999999999,
        stagedLinesAdded: 10,
        stagedLinesRemoved: 5,
        unstagedLinesAdded: 15,
        unstagedLinesRemoved: 8,
        linesAdded: 25,
        linesRemoved: 13,
        linesChanged: 38,
        upstreamBranch: 'origin/feature/full',
        aheadCount: 2,
        behindCount: 1,
        stashCount: 3,
      );

      notifier.setGitStatus('session-1', fullStatus);

      final result = notifier.getGitStatus('session-1');
      expect(result?.branch, 'feature/full');
      expect(result?.isDirty, true);
      expect(result?.modifiedCount, 5);
      expect(result?.untrackedCount, 2);
      expect(result?.stagedCount, 3);
      expect(result?.lastUpdatedAt, 9999999999);
      expect(result?.stagedLinesAdded, 10);
      expect(result?.stagedLinesRemoved, 5);
      expect(result?.unstagedLinesAdded, 15);
      expect(result?.unstagedLinesRemoved, 8);
      expect(result?.linesAdded, 25);
      expect(result?.linesRemoved, 13);
      expect(result?.linesChanged, 38);
      expect(result?.upstreamBranch, 'origin/feature/full');
      expect(result?.aheadCount, 2);
      expect(result?.behindCount, 1);
      expect(result?.stashCount, 3);
    });

    test('should handle git status with null optional fields', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      final minimalStatus = GitStatus(
        branch: null,
        isDirty: false,
        modifiedCount: 0,
        untrackedCount: 0,
        stagedCount: 0,
        lastUpdatedAt: 0,
      );

      notifier.setGitStatus('session-1', minimalStatus);

      final result = notifier.getGitStatus('session-1');
      expect(result?.branch, isNull);
      expect(result?.upstreamBranch, isNull);
      expect(result?.aheadCount, isNull);
      expect(result?.behindCount, isNull);
      expect(result?.stashCount, isNull);
    });

    test('should maintain state independence across sessions', () {
      final notifier = container.read(
        sessionGitStatusNotifierProvider.notifier,
      );

      notifier.setGitStatus(
        'session-1',
        createTestGitStatus(isDirty: true, modifiedCount: 10),
      );
      notifier.setGitStatus(
        'session-2',
        createTestGitStatus(isDirty: false, modifiedCount: 0),
      );

      expect(notifier.getGitStatus('session-1')?.isDirty, true);
      expect(notifier.getGitStatus('session-1')?.modifiedCount, 10);
      expect(notifier.getGitStatus('session-2')?.isDirty, false);
      expect(notifier.getGitStatus('session-2')?.modifiedCount, 0);
    });
  });
}
