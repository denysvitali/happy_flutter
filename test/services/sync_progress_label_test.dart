import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

/// Tests that [Sync.syncProgress] falls back to descriptive labels based on
/// which named [InvalidateSync] instances are running, so the UI never shows
/// the generic "Refreshing app data" text when a specific sync is active.
void main() {
  late Sync instance;

  setUp(() {
    instance = Sync();
    instance.testResetSyncState();
    instance.sessionsSync = InvalidateSync(() async {});
    instance.settingsSync = InvalidateSync(() async {});
    instance.profileSync = InvalidateSync(() async {});
    instance.purchasesSync = InvalidateSync(() async {});
    instance.machinesSync = InvalidateSync(() async {});
    instance.pushTokenSync = InvalidateSync(() async {});
    instance.nativeUpdateSync = InvalidateSync(() async {});
    instance.artifactsSync = InvalidateSync(() async {});
    instance.sessionGitStatusSync = InvalidateSync(() async {});
    instance.messagesSync.clear();
  });

  group('syncProgress fallback labels', () {
    test('returns null when no sync is running', () {
      expect(instance.isSyncing, isFalse);
      expect(instance.syncProgress, isNull);
    });

    test('single running sync uses its name', () async {
      final completer = Completer<void>();
      instance.settingsSync = InvalidateSync(
        () => completer.future,
        name: 'syncSettings',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );

      instance.settingsSync.invalidate();
      await Future<void>.delayed(Duration.zero);

      expect(instance.isSyncing, isTrue);
      expect(instance.syncProgress, isNotNull);
      expect(instance.syncProgress!.label, equals('Syncing Settings'));
      expect(instance.syncProgress!.completed, isNull);
      expect(instance.syncProgress!.total, isNull);

      completer.complete();
      await instance.settingsSync.awaitQueue();

      expect(instance.isSyncing, isFalse);
      expect(instance.syncProgress, isNull);
    });

    test('fetch prefix is stripped for readable labels', () async {
      final completer = Completer<void>();
      instance.sessionsSync = InvalidateSync(
        () => completer.future,
        name: 'fetchSessions',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );

      instance.sessionsSync.invalidate();
      await Future<void>.delayed(Duration.zero);

      expect(instance.syncProgress!.label, equals('Syncing Sessions'));

      completer.complete();
      await instance.sessionsSync.awaitQueue();
    });

    test('multiple concurrent syncs summarize by first + count', () async {
      final sessionsCompleter = Completer<void>();
      final machinesCompleter = Completer<void>();
      instance.sessionsSync = InvalidateSync(
        () => sessionsCompleter.future,
        name: 'fetchSessions',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );
      instance.machinesSync = InvalidateSync(
        () => machinesCompleter.future,
        name: 'fetchMachines',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );

      instance.sessionsSync.invalidate();
      instance.machinesSync.invalidate();
      await Future<void>.delayed(Duration.zero);

      expect(
        instance.syncProgress!.label,
        equals('Syncing Machines and 1 more'),
      );

      machinesCompleter.complete();
      await instance.machinesSync.awaitQueue();

      expect(instance.syncProgress!.label, equals('Syncing Sessions'));

      sessionsCompleter.complete();
      await instance.sessionsSync.awaitQueue();

      expect(instance.syncProgress, isNull);
    });

    test('multiple instances with the same name are reference counted', () async {
      final completerA = Completer<void>();
      final completerB = Completer<void>();
      final syncA = InvalidateSync(
        () => completerA.future,
        name: 'fetchMessages',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );
      final syncB = InvalidateSync(
        () => completerB.future,
        name: 'fetchMessages',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );

      syncA.invalidate();
      syncB.invalidate();
      await Future<void>.delayed(Duration.zero);

      expect(instance.syncProgress!.label, equals('Syncing Messages'));

      completerA.complete();
      await syncA.awaitQueue();

      expect(instance.syncProgress!.label, equals('Syncing Messages'));

      completerB.complete();
      await syncB.awaitQueue();

      expect(instance.syncProgress, isNull);
    });

    test('explicit progress takes precedence over fallback label', () async {
      final completer = Completer<void>();
      instance.sessionsSync = InvalidateSync(
        () => completer.future,
        name: 'fetchSessions',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );

      instance.sessionsSync.invalidate();
      await Future<void>.delayed(Duration.zero);
      expect(instance.syncProgress!.label, equals('Syncing Sessions'));

      instance.testSyncProgress = const SyncProgress(
        label: 'Fetching conversations',
        completed: 1,
        total: 5,
      );
      expect(instance.syncProgress!.label, equals('Fetching conversations'));

      completer.complete();
      await instance.sessionsSync.awaitQueue();

      expect(instance.syncProgress, isNull);
    });

    test('fallback label ignores empty or null names', () async {
      final completer = Completer<void>();
      final unnamed = InvalidateSync(
        () => completer.future,
        onRunningChanged: instance.testOnSyncRunningChanged,
      );
      instance.sessionsSync = InvalidateSync(
        () => completer.future,
        name: 'fetchSessions',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );

      unnamed.invalidate();
      instance.sessionsSync.invalidate();
      await Future<void>.delayed(Duration.zero);

      expect(instance.syncProgress!.label, equals('Syncing Sessions'));

      completer.complete();
      await instance.sessionsSync.awaitQueue();
    });

    test('disposing a running sync clears fallback progress', () async {
      final completer = Completer<void>();
      instance.settingsSync = InvalidateSync(
        () => completer.future,
        name: 'syncSettings',
        onRunningChanged: instance.testOnSyncRunningChanged,
      );

      instance.settingsSync.invalidate();
      await Future<void>.delayed(Duration.zero);

      expect(instance.isSyncing, isTrue);
      expect(instance.syncProgress!.label, equals('Syncing Settings'));

      instance.settingsSync.dispose();

      expect(instance.isSyncing, isFalse);
      expect(instance.syncProgress, isNull);
    });
  });
}
