import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sftp/models/sftp_directory.dart';
import 'package:happy_flutter/features/sftp/providers/sftp_provider.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('SftpState', () {
    test('creates with default values', () {
      const state = SftpState();
      expect(state.directories, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('creates with provided values', () {
      const dirs = [
        SftpDirectory(
          id: 'dir-1',
          name: 'Test',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        ),
      ];
      final state = SftpState(directories: dirs, isLoading: true);

      expect(state.directories, hasLength(1));
      expect(state.isLoading, isTrue);
    });

    group('copyWith', () {
      test('copies with updated directories', () {
        const original = SftpState();
        const newDirs = [
          SftpDirectory(
            id: 'dir-1',
            name: 'New',
            path: '/tmp',
            port: 22,
            authMethod: SftpAuthMethod.password,
            clipboardMode: SftpClipboardMode.off,
          ),
        ];

        final updated = original.copyWith(directories: newDirs);

        expect(updated.directories, hasLength(1));
        expect(updated.isLoading, isFalse);
      });

      test('copies with updated isLoading', () {
        const original = SftpState();
        final updated = original.copyWith(isLoading: true);

        expect(updated.isLoading, isTrue);
        expect(updated.directories, isEmpty);
      });

      test('preserves values when no changes', () {
        const dirs = [
          SftpDirectory(
            id: 'dir-1',
            name: 'Test',
            path: '/tmp',
            port: 22,
            authMethod: SftpAuthMethod.password,
            clipboardMode: SftpClipboardMode.off,
          ),
        ];
        final original = SftpState(directories: dirs, isLoading: true);
        final copied = original.copyWith();

        expect(copied.directories, hasLength(1));
        expect(copied.isLoading, isTrue);
      });

      test('updates both fields', () {
        const original = SftpState();
        const newDirs = [
          SftpDirectory(
            id: 'dir-1',
            name: 'Test',
            path: '/tmp',
            port: 22,
            authMethod: SftpAuthMethod.password,
            clipboardMode: SftpClipboardMode.off,
          ),
        ];

        final updated = original.copyWith(
          directories: newDirs,
          isLoading: true,
        );

        expect(updated.directories, hasLength(1));
        expect(updated.isLoading, isTrue);
      });
    });
  });

  group('SftpNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      container = ProviderContainer();
      // Trigger build() and wait for async _loadDirectories to complete.
      // Without this, _loadDirectories finishes after test operations and
      // overwrites state with empty directories.
      container.read(sftpNotifierProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() {
      container.dispose();
    });

    test('initializes with empty state after failed load', () {
      final state = container.read(sftpNotifierProvider);
      expect(state.directories, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('addDirectory adds a directory to state', () async {
      final notifier = container.read(sftpNotifierProvider.notifier);

      const dir = SftpDirectory(
        id: 'dir-1',
        name: 'My Share',
        path: '/home/user/shared',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      await notifier.addDirectory(dir);

      final state = container.read(sftpNotifierProvider);
      expect(state.directories, hasLength(1));
      expect(state.directories.first.id, 'dir-1');
      expect(state.directories.first.name, 'My Share');
    });

    test('addDirectory appends to existing directories', () async {
      final notifier = container.read(sftpNotifierProvider.notifier);

      const dir1 = SftpDirectory(
        id: 'dir-1',
        name: 'First',
        path: '/tmp/first',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      const dir2 = SftpDirectory(
        id: 'dir-2',
        name: 'Second',
        path: '/tmp/second',
        port: 2022,
        authMethod: SftpAuthMethod.publicKey,
        clipboardMode: SftpClipboardMode.bidirectional,
      );

      await notifier.addDirectory(dir1);
      await notifier.addDirectory(dir2);

      final state = container.read(sftpNotifierProvider);
      expect(state.directories, hasLength(2));
      expect(state.directories[0].id, 'dir-1');
      expect(state.directories[1].id, 'dir-2');
    });

    test('updateDirectory updates matching directory', () async {
      final notifier = container.read(sftpNotifierProvider.notifier);

      const original = SftpDirectory(
        id: 'dir-1',
        name: 'Original',
        path: '/tmp',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      await notifier.addDirectory(original);

      const updated = SftpDirectory(
        id: 'dir-1',
        name: 'Updated Name',
        path: '/new/path',
        port: 2022,
        authMethod: SftpAuthMethod.publicKey,
        clipboardMode: SftpClipboardMode.pushOnly,
      );

      await notifier.updateDirectory(updated);

      final state = container.read(sftpNotifierProvider);
      expect(state.directories, hasLength(1));
      expect(state.directories.first.name, 'Updated Name');
      expect(state.directories.first.path, '/new/path');
      expect(state.directories.first.port, 2022);
      expect(
        state.directories.first.authMethod,
        SftpAuthMethod.publicKey,
      );
      expect(
        state.directories.first.clipboardMode,
        SftpClipboardMode.pushOnly,
      );
    });

    test('updateDirectory does not affect other directories', () async {
      final notifier = container.read(sftpNotifierProvider.notifier);

      const dir1 = SftpDirectory(
        id: 'dir-1',
        name: 'First',
        path: '/tmp/first',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      const dir2 = SftpDirectory(
        id: 'dir-2',
        name: 'Second',
        path: '/tmp/second',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      await notifier.addDirectory(dir1);
      await notifier.addDirectory(dir2);

      const updated = SftpDirectory(
        id: 'dir-1',
        name: 'Modified',
        path: '/modified',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      await notifier.updateDirectory(updated);

      final state = container.read(sftpNotifierProvider);
      expect(state.directories, hasLength(2));
      expect(
        state.directories.firstWhere((d) => d.id == 'dir-1').name,
        'Modified',
      );
      expect(
        state.directories.firstWhere((d) => d.id == 'dir-2').name,
        'Second',
      );
    });

    test('removeDirectory removes matching directory', () async {
      final notifier = container.read(sftpNotifierProvider.notifier);

      const dir = SftpDirectory(
        id: 'dir-1',
        name: 'To Remove',
        path: '/tmp',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      await notifier.addDirectory(dir);
      expect(
        container.read(sftpNotifierProvider).directories,
        hasLength(1),
      );

      await notifier.removeDirectory('dir-1');

      final state = container.read(sftpNotifierProvider);
      expect(state.directories, isEmpty);
    });

    test('removeDirectory only removes matching id', () async {
      final notifier = container.read(sftpNotifierProvider.notifier);

      const dir1 = SftpDirectory(
        id: 'dir-1',
        name: 'Keep',
        path: '/tmp/keep',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      const dir2 = SftpDirectory(
        id: 'dir-2',
        name: 'Remove',
        path: '/tmp/remove',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      await notifier.addDirectory(dir1);
      await notifier.addDirectory(dir2);

      await notifier.removeDirectory('dir-2');

      final state = container.read(sftpNotifierProvider);
      expect(state.directories, hasLength(1));
      expect(state.directories.first.id, 'dir-1');
    });

    test('removeDirectory is no-op for unknown id', () async {
      final notifier = container.read(sftpNotifierProvider.notifier);

      const dir = SftpDirectory(
        id: 'dir-1',
        name: 'Test',
        path: '/tmp',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      await notifier.addDirectory(dir);
      await notifier.removeDirectory('unknown-id');

      final state = container.read(sftpNotifierProvider);
      expect(state.directories, hasLength(1));
    });

    test('add, update, and remove work together', () async {
      final notifier = container.read(sftpNotifierProvider.notifier);

      const dir1 = SftpDirectory(
        id: 'dir-1',
        name: 'First',
        path: '/tmp/first',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      const dir2 = SftpDirectory(
        id: 'dir-2',
        name: 'Second',
        path: '/tmp/second',
        port: 22,
        authMethod: SftpAuthMethod.password,
        clipboardMode: SftpClipboardMode.off,
      );

      // Add two directories
      await notifier.addDirectory(dir1);
      await notifier.addDirectory(dir2);
      expect(
        container.read(sftpNotifierProvider).directories,
        hasLength(2),
      );

      // Update first directory
      const updated = SftpDirectory(
        id: 'dir-1',
        name: 'Updated First',
        path: '/updated',
        port: 2022,
        authMethod: SftpAuthMethod.anonymous,
        clipboardMode: SftpClipboardMode.pullOnly,
      );
      await notifier.updateDirectory(updated);
      expect(
        container.read(sftpNotifierProvider).directories.first.name,
        'Updated First',
      );

      // Remove second directory
      await notifier.removeDirectory('dir-2');
      final state = container.read(sftpNotifierProvider);
      expect(state.directories, hasLength(1));
      expect(state.directories.first.id, 'dir-1');
      expect(state.directories.first.name, 'Updated First');
    });
  });
}
