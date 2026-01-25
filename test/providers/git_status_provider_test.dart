import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('SessionGitStatusProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with empty map', () {
      final statusMap = container.read(sessionGitStatusProvider);
      expect(statusMap, isEmpty);
    });

    test('should update git status for a session', () {
      final notifier = container.read(sessionGitStatusProvider.notifier);

      final gitStatus = GitStatus(
        branch: 'main',
        isDirty: true,
        modifiedCount: 3,
        untrackedCount: 2,
        stagedCount: 1,
        lastUpdatedAt: 1234567890,
        stagedLinesAdded: 10,
        stagedLinesRemoved: 5,
        unstagedLinesAdded: 15,
        unstagedLinesRemoved: 8,
        linesAdded: 25,
        linesRemoved: 13,
        linesChanged: 38,
        upstreamBranch: 'origin/main',
        aheadCount: 2,
        behindCount: 1,
        stashCount: 0,
      );

      notifier.updateGitStatus('session-123', gitStatus);

      final statusMap = container.read(sessionGitStatusProvider);
      expect(statusMap, hasLength(1));
      expect(statusMap['session-123'], isNotNull);
      expect(statusMap['session-123']?.branch, 'main');
      expect(statusMap['session-123']?.isDirty, isTrue);
      expect(statusMap['session-123']?.modifiedCount, 3);
      expect(statusMap['session-123']?.linesAdded, 25);
      expect(statusMap['session-123']?.linesRemoved, 13);
    });

    test('should retrieve git status for a specific session', () {
      final notifier = container.read(sessionGitStatusProvider.notifier);

      final gitStatus1 = GitStatus(
        branch: 'main',
        isDirty: false,
        modifiedCount: 0,
        untrackedCount: 0,
        stagedCount: 0,
        lastUpdatedAt: 1234567890,
      );

      final gitStatus2 = GitStatus(
        branch: 'feature-branch',
        isDirty: true,
        modifiedCount: 5,
        untrackedCount: 1,
        stagedCount: 2,
        lastUpdatedAt: 1234567891,
      );

      notifier.updateGitStatus('session-1', gitStatus1);
      notifier.updateGitStatus('session-2', gitStatus2);

      expect(notifier.getGitStatus('session-1')?.branch, 'main');
      expect(notifier.getGitStatus('session-2')?.branch, 'feature-branch');
      expect(notifier.getGitStatus('nonexistent'), isNull);
    });

    test('should clear git status for a specific session', () {
      final notifier = container.read(sessionGitStatusProvider.notifier);

      final gitStatus = GitStatus(
        branch: 'main',
        isDirty: true,
        modifiedCount: 3,
        untrackedCount: 2,
        stagedCount: 1,
        lastUpdatedAt: 1234567890,
      );

      notifier.updateGitStatus('session-123', gitStatus);
      expect(container.read(sessionGitStatusProvider), hasLength(1));

      notifier.clearGitStatus('session-123');
      expect(container.read(sessionGitStatusProvider), isEmpty);
    });

    test('should clear all git statuses', () {
      final notifier = container.read(sessionGitStatusProvider.notifier);

      final gitStatus = GitStatus(
        branch: 'main',
        isDirty: true,
        modifiedCount: 3,
        untrackedCount: 2,
        stagedCount: 1,
        lastUpdatedAt: 1234567890,
      );

      notifier.updateGitStatus('session-1', gitStatus);
      notifier.updateGitStatus('session-2', gitStatus);
      notifier.updateGitStatus('session-3', gitStatus);

      expect(container.read(sessionGitStatusProvider), hasLength(3));

      notifier.clearAll();
      expect(container.read(sessionGitStatusProvider), isEmpty);
    });

    test('should update git status with branch tracking info', () {
      final notifier = container.read(sessionGitStatusProvider.notifier);

      final gitStatus = GitStatus(
        branch: 'feature-branch',
        isDirty: false,
        modifiedCount: 0,
        untrackedCount: 0,
        stagedCount: 0,
        lastUpdatedAt: 1234567890,
        upstreamBranch: 'origin/feature-branch',
        aheadCount: 5,
        behindCount: 2,
        stashCount: 1,
      );

      notifier.updateGitStatus('session-123', gitStatus);

      final status = container.read(sessionGitStatusProvider)['session-123'];
      expect(status?.upstreamBranch, 'origin/feature-branch');
      expect(status?.aheadCount, 5);
      expect(status?.behindCount, 2);
      expect(status?.stashCount, 1);
    });

    test('should handle multiple sessions independently', () {
      final notifier = container.read(sessionGitStatusProvider.notifier);

      final status1 = GitStatus(
        branch: 'main',
        isDirty: false,
        modifiedCount: 0,
        untrackedCount: 0,
        stagedCount: 0,
        lastUpdatedAt: 1234567890,
      );

      final status2 = GitStatus(
        branch: 'develop',
        isDirty: true,
        modifiedCount: 10,
        untrackedCount: 5,
        stagedCount: 3,
        lastUpdatedAt: 1234567891,
        linesAdded: 50,
        linesRemoved: 20,
        linesChanged: 70,
      );

      notifier.updateGitStatus('session-1', status1);
      notifier.updateGitStatus('session-2', status2);

      final statusMap = container.read(sessionGitStatusProvider);
      expect(statusMap['session-1']?.isDirty, isFalse);
      expect(statusMap['session-2']?.isDirty, isTrue);
      expect(statusMap['session-2']?.linesChanged, 70);
    });
  });
}
