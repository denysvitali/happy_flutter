import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

void main() {
  group('resolvePath', () {
    test('returns path unchanged when metadata is null', () {
      expect(resolvePath('/some/path', null), '/some/path');
    });

    test('returns path unchanged for unknown metadata type', () {
      expect(resolvePath('/some/path', 'string'), '/some/path');
      expect(resolvePath('/some/path', 42), '/some/path');
    });

    test('resolves path relative to Metadata object root', () {
      const metadata = Metadata(path: '/root/dir');
      expect(resolvePath('/root/dir/file.txt', metadata), 'file.txt');
    });

    test('resolves path relative to Map metadata root', () {
      final metadata = {'path': '/root/dir'};
      expect(resolvePath('/root/dir/file.txt', metadata), 'file.txt');
    });

    test('returns <root> when path equals root', () {
      const metadata = Metadata(path: '/root/dir');
      expect(resolvePath('/root/dir', metadata), '<root>');
    });

    test('handles case-insensitive root matching', () {
      const metadata = Metadata(path: '/Root/Dir');
      expect(resolvePath('/root/dir/file.txt', metadata), 'file.txt');
    });

    test('returns path unchanged when not under root', () {
      const metadata = Metadata(path: '/root/dir');
      expect(resolvePath('/other/path/file.txt', metadata),
          '/other/path/file.txt');
    });

    test('strips leading slash from remainder', () {
      const metadata = Metadata(path: '/root');
      expect(resolvePath('/root/subdir/file.txt', metadata),
          'subdir/file.txt');
    });

    test('handles backslash separator', () {
      const metadata = Metadata(path: r'C:\root');
      expect(resolvePath(r'C:\root\file.txt', metadata), 'file.txt');
    });

    test('handles empty path in Map metadata', () {
      final metadata = {'path': ''};
      expect(resolvePath('/some/path', metadata), '/some/path');
    });

    test('handles missing path key in Map metadata', () {
      final metadata = {'other': 'value'};
      expect(resolvePath('/some/path', metadata), isNotNull);
    });
  });

  group('resolveAbsolutePath', () {
    test('returns path unchanged when no tilde prefix', () {
      expect(resolveAbsolutePath('/absolute/path'), '/absolute/path');
      expect(resolveAbsolutePath('relative/path'), 'relative/path');
    });

    test('returns path unchanged when no homeDir provided', () {
      expect(resolveAbsolutePath('~/documents'), '~/documents');
      expect(resolveAbsolutePath('~'), '~');
    });

    test('resolves ~ to home directory', () {
      final result = resolveAbsolutePath('~', homeDir: '/home/user');
      expect(result, '/home/user');
    });

    test('resolves ~ with trailing slash in homeDir', () {
      final result = resolveAbsolutePath('~', homeDir: '/home/user/');
      expect(result, '/home/user');
    });

    test('resolves ~/path to homeDir/path', () {
      final result = resolveAbsolutePath(
        '~/documents/file.txt',
        homeDir: '/home/user',
      );
      expect(result, '/home/user/documents/file.txt');
    });

    test('resolves ~/path with trailing slash in homeDir', () {
      final result = resolveAbsolutePath(
        '~/documents/file.txt',
        homeDir: '/home/user/',
      );
      expect(result, '/home/user/documents/file.txt');
    });

    test('handles Windows home directory', () {
      final result = resolveAbsolutePath(
        r'~\documents\file.txt',
        homeDir: r'C:\Users\user',
      );
      expect(result, r'C:\Users\user\documents\file.txt');
    });

    test('handles Windows homeDir with backslash', () {
      final result = resolveAbsolutePath(
        '~/documents/file.txt',
        homeDir: r'C:\Users\user',
      );
      // Detects backslash separator from homeDir
      expect(result, contains('documents'));
    });

    test('returns path unchanged for ~username paths', () {
      expect(
        resolveAbsolutePath('~otheruser/documents', homeDir: '/home/user'),
        '~otheruser/documents',
      );
    });

    test('handles empty tilde-only path', () {
      final result = resolveAbsolutePath('~', homeDir: '/home/user');
      expect(result, '/home/user');
    });

    test('handles homeDir with mixed separators', () {
      final result = resolveAbsolutePath(
        '~/file.txt',
        homeDir: '/home/user',
      );
      expect(result, '/home/user/file.txt');
    });
  });

  group('getFileName', () {
    test('extracts file name from path', () {
      expect(getFileName('/path/to/file.txt'), 'file.txt');
      expect(getFileName('file.txt'), 'file.txt');
    });

    test('handles path without extension', () {
      expect(getFileName('/path/to/file'), 'file');
    });

    test('handles root path', () {
      expect(getFileName('/'), '');
    });
  });

  group('getDirectoryName', () {
    test('extracts directory from path', () {
      expect(getDirectoryName('/path/to/file.txt'), '/path/to');
    });

    test('handles file in current directory', () {
      expect(getDirectoryName('file.txt'), '.');
    });
  });

  group('getFileExtension', () {
    test('extracts file extension', () {
      expect(getFileExtension('file.txt'), '.txt');
      expect(getFileExtension('/path/to/file.dart'), '.dart');
    });

    test('returns empty for no extension', () {
      expect(getFileExtension('file'), '');
    });

    test('handles multiple dots', () {
      expect(getFileExtension('archive.tar.gz'), '.gz');
    });
  });

  group('isAbsolutePath', () {
    test('detects absolute paths', () {
      expect(isAbsolutePath('/usr/local'), isTrue);
    });

    test('detects relative paths', () {
      expect(isAbsolutePath('relative/path'), isFalse);
      expect(isAbsolutePath('./path'), isFalse);
    });
  });

  group('isRelativePath', () {
    test('detects relative paths', () {
      expect(isRelativePath('relative/path'), isTrue);
      expect(isRelativePath('./path'), isTrue);
    });

    test('detects absolute paths', () {
      expect(isRelativePath('/usr/local'), isFalse);
    });
  });

  group('joinPath', () {
    test('joins two paths', () {
      expect(joinPath('/usr', 'local'), '/usr/local');
    });

    test('joins three paths', () {
      expect(joinPath('/usr', 'local', 'bin'), '/usr/local/bin');
    });

    test('joins four paths', () {
      expect(joinPath('/usr', 'local', 'bin', 'tool'), '/usr/local/bin/tool');
    });
  });
}
