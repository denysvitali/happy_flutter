import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sftp/models/sftp_directory.dart';

void main() {
  group('SftpAuthMethod', () {
    test('has correct values', () {
      expect(SftpAuthMethod.values, hasLength(3));
      expect(SftpAuthMethod.password.name, 'password');
      expect(SftpAuthMethod.publicKey.name, 'publicKey');
      expect(SftpAuthMethod.anonymous.name, 'anonymous');
    });
  });

  group('SftpClipboardMode', () {
    test('has correct values', () {
      expect(SftpClipboardMode.values, hasLength(4));
      expect(SftpClipboardMode.off.name, 'off');
      expect(SftpClipboardMode.bidirectional.name, 'bidirectional');
      expect(SftpClipboardMode.pushOnly.name, 'pushOnly');
      expect(SftpClipboardMode.pullOnly.name, 'pullOnly');
    });
  });

  group('SftpDirectory', () {
    group('constructor', () {
      test('creates with required fields', () {
        const dir = SftpDirectory(
          id: 'dir-1',
          name: 'My Share',
          path: '/home/user/shared',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        expect(dir.id, 'dir-1');
        expect(dir.name, 'My Share');
        expect(dir.path, '/home/user/shared');
        expect(dir.port, 22);
        expect(dir.authMethod, SftpAuthMethod.password);
        expect(dir.clipboardMode, SftpClipboardMode.off);
        expect(dir.remotePath, isNull);
        expect(dir.isActive, isTrue);
      });

      test('creates with all fields', () {
        const dir = SftpDirectory(
          id: 'dir-2',
          name: 'Full Share',
          path: '/var/data',
          port: 2022,
          authMethod: SftpAuthMethod.publicKey,
          clipboardMode: SftpClipboardMode.bidirectional,
          remotePath: '/remote/data',
          isActive: false,
        );

        expect(dir.id, 'dir-2');
        expect(dir.name, 'Full Share');
        expect(dir.path, '/var/data');
        expect(dir.port, 2022);
        expect(dir.authMethod, SftpAuthMethod.publicKey);
        expect(dir.clipboardMode, SftpClipboardMode.bidirectional);
        expect(dir.remotePath, '/remote/data');
        expect(dir.isActive, isFalse);
      });
    });

    group('fromJson', () {
      test('parses required fields with defaults', () {
        final json = {
          'id': 'dir-1',
          'name': 'Test Share',
          'path': '/tmp/share',
        };

        final dir = SftpDirectory.fromJson(json);

        expect(dir.id, 'dir-1');
        expect(dir.name, 'Test Share');
        expect(dir.path, '/tmp/share');
        expect(dir.port, 22);
        expect(dir.authMethod, SftpAuthMethod.password);
        expect(dir.clipboardMode, SftpClipboardMode.off);
        expect(dir.remotePath, isNull);
        expect(dir.isActive, isTrue);
      });

      test('parses all fields', () {
        final json = {
          'id': 'dir-2',
          'name': 'Full Share',
          'path': '/var/data',
          'port': 2022,
          'authMethod': 'publicKey',
          'clipboardMode': 'pushOnly',
          'remotePath': '/remote/data',
          'isActive': false,
        };

        final dir = SftpDirectory.fromJson(json);

        expect(dir.id, 'dir-2');
        expect(dir.name, 'Full Share');
        expect(dir.path, '/var/data');
        expect(dir.port, 2022);
        expect(dir.authMethod, SftpAuthMethod.publicKey);
        expect(dir.clipboardMode, SftpClipboardMode.pushOnly);
        expect(dir.remotePath, '/remote/data');
        expect(dir.isActive, isFalse);
      });

      test('falls back for unknown auth method', () {
        final json = {
          'id': 'dir-3',
          'name': 'Test',
          'path': '/tmp',
          'authMethod': 'unknown_method',
        };

        final dir = SftpDirectory.fromJson(json);
        expect(dir.authMethod, SftpAuthMethod.password);
      });

      test('falls back for unknown clipboard mode', () {
        final json = {
          'id': 'dir-4',
          'name': 'Test',
          'path': '/tmp',
          'clipboardMode': 'unknown_mode',
        };

        final dir = SftpDirectory.fromJson(json);
        expect(dir.clipboardMode, SftpClipboardMode.off);
      });

      test('parses anonymous auth method', () {
        final json = {
          'id': 'dir-5',
          'name': 'Anon',
          'path': '/public',
          'authMethod': 'anonymous',
        };

        final dir = SftpDirectory.fromJson(json);
        expect(dir.authMethod, SftpAuthMethod.anonymous);
      });

      test('parses pullOnly clipboard mode', () {
        final json = {
          'id': 'dir-6',
          'name': 'Pull',
          'path': '/data',
          'clipboardMode': 'pullOnly',
        };

        final dir = SftpDirectory.fromJson(json);
        expect(dir.clipboardMode, SftpClipboardMode.pullOnly);
      });
    });

    group('toJson', () {
      test('serializes required fields', () {
        const dir = SftpDirectory(
          id: 'dir-1',
          name: 'My Share',
          path: '/home/user/shared',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final json = dir.toJson();

        expect(json['id'], 'dir-1');
        expect(json['name'], 'My Share');
        expect(json['path'], '/home/user/shared');
        expect(json['port'], 22);
        expect(json['authMethod'], 'password');
        expect(json['clipboardMode'], 'off');
        expect(json['isActive'], isTrue);
        expect(json.containsKey('remotePath'), isFalse);
      });

      test('serializes remotePath when present', () {
        const dir = SftpDirectory(
          id: 'dir-2',
          name: 'Full',
          path: '/data',
          port: 2022,
          authMethod: SftpAuthMethod.publicKey,
          clipboardMode: SftpClipboardMode.bidirectional,
          remotePath: '/remote/data',
          isActive: false,
        );

        final json = dir.toJson();

        expect(json['remotePath'], '/remote/data');
        expect(json['isActive'], isFalse);
        expect(json['authMethod'], 'publicKey');
        expect(json['clipboardMode'], 'bidirectional');
      });

      test('omits remotePath when null', () {
        const dir = SftpDirectory(
          id: 'dir-3',
          name: 'No Remote',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.anonymous,
          clipboardMode: SftpClipboardMode.pullOnly,
        );

        final json = dir.toJson();
        expect(json.containsKey('remotePath'), isFalse);
      });
    });

    group('toJson/fromJson round-trip', () {
      test('preserves all fields', () {
        const original = SftpDirectory(
          id: 'dir-rt',
          name: 'Round Trip',
          path: '/data/share',
          port: 2022,
          authMethod: SftpAuthMethod.publicKey,
          clipboardMode: SftpClipboardMode.pushOnly,
          remotePath: '/remote/share',
          isActive: false,
        );

        final json = original.toJson();
        final restored = SftpDirectory.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.path, original.path);
        expect(restored.port, original.port);
        expect(restored.authMethod, original.authMethod);
        expect(restored.clipboardMode, original.clipboardMode);
        expect(restored.remotePath, original.remotePath);
        expect(restored.isActive, original.isActive);
      });

      test('round-trip without optional fields', () {
        const original = SftpDirectory(
          id: 'dir-rt2',
          name: 'Minimal',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final json = original.toJson();
        final restored = SftpDirectory.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.remotePath, isNull);
        expect(restored.isActive, isTrue);
      });
    });

    group('copyWith', () {
      test('copies with updated name', () {
        const original = SftpDirectory(
          id: 'dir-1',
          name: 'Original',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final updated = original.copyWith(name: 'Updated');

        expect(updated.id, 'dir-1');
        expect(updated.name, 'Updated');
        expect(updated.path, '/tmp');
        expect(updated.port, 22);
      });

      test('copies with updated port', () {
        const original = SftpDirectory(
          id: 'dir-2',
          name: 'Test',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final updated = original.copyWith(port: 2022);

        expect(updated.port, 2022);
        expect(updated.name, 'Test');
      });

      test('copies with updated auth method', () {
        const original = SftpDirectory(
          id: 'dir-3',
          name: 'Test',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final updated = original.copyWith(
          authMethod: SftpAuthMethod.publicKey,
        );

        expect(updated.authMethod, SftpAuthMethod.publicKey);
      });

      test('copies with updated clipboard mode', () {
        const original = SftpDirectory(
          id: 'dir-4',
          name: 'Test',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final updated = original.copyWith(
          clipboardMode: SftpClipboardMode.bidirectional,
        );

        expect(updated.clipboardMode, SftpClipboardMode.bidirectional);
      });

      test('copies with updated remotePath', () {
        const original = SftpDirectory(
          id: 'dir-5',
          name: 'Test',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final updated = original.copyWith(remotePath: '/remote');

        expect(updated.remotePath, '/remote');
      });

      test('copies with updated isActive', () {
        const original = SftpDirectory(
          id: 'dir-6',
          name: 'Test',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final updated = original.copyWith(isActive: false);

        expect(updated.isActive, isFalse);
      });

      test('copies with multiple updates', () {
        const original = SftpDirectory(
          id: 'dir-7',
          name: 'Original',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final updated = original.copyWith(
          name: 'New Name',
          path: '/new/path',
          port: 2022,
          authMethod: SftpAuthMethod.anonymous,
          clipboardMode: SftpClipboardMode.pullOnly,
          remotePath: '/remote',
          isActive: false,
        );

        expect(updated.id, 'dir-7');
        expect(updated.name, 'New Name');
        expect(updated.path, '/new/path');
        expect(updated.port, 2022);
        expect(updated.authMethod, SftpAuthMethod.anonymous);
        expect(updated.clipboardMode, SftpClipboardMode.pullOnly);
        expect(updated.remotePath, '/remote');
        expect(updated.isActive, isFalse);
      });

      test('preserves original when no changes', () {
        const original = SftpDirectory(
          id: 'dir-8',
          name: 'Same',
          path: '/tmp',
          port: 22,
          authMethod: SftpAuthMethod.password,
          clipboardMode: SftpClipboardMode.off,
        );

        final copied = original.copyWith();

        expect(copied.id, original.id);
        expect(copied.name, original.name);
        expect(copied.path, original.path);
        expect(copied.port, original.port);
        expect(copied.authMethod, original.authMethod);
        expect(copied.clipboardMode, original.clipboardMode);
        expect(copied.remotePath, original.remotePath);
        expect(copied.isActive, original.isActive);
      });
    });
  });
}
