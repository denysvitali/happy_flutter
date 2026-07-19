import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

void main() {
  group('isRemoteAbsolutePath', () {
    test('accepts posix absolute paths', () {
      expect(isRemoteAbsolutePath('/home/user/a.dart'), isTrue);
    });

    test('accepts windows drive paths with either separator', () {
      expect(isRemoteAbsolutePath(r'C:\Users\a.dart'), isTrue);
      expect(isRemoteAbsolutePath('C:/Users/a.dart'), isTrue);
    });

    test('accepts UNC paths', () {
      expect(isRemoteAbsolutePath(r'\\server\share\a.dart'), isTrue);
    });

    test('rejects relative and tilde paths', () {
      expect(isRemoteAbsolutePath('test/a.dart'), isFalse);
      expect(isRemoteAbsolutePath('~/a.dart'), isFalse);
      expect(isRemoteAbsolutePath(''), isFalse);
    });
  });

  group('resolveRemoteFetchPath', () {
    test('returns absolute paths unchanged', () {
      expect(
        resolveRemoteFetchPath(
          '/home/user/project/a.dart',
          sessionPath: '/home/user/project',
        ),
        '/home/user/project/a.dart',
      );
      expect(
        resolveRemoteFetchPath(
          r'C:\repo\a.dart',
          sessionPath: r'C:\repo',
        ),
        r'C:\repo\a.dart',
      );
    });

    test('anchors relative paths to the session root', () {
      expect(
        resolveRemoteFetchPath(
          'test/features/chat/a_test.dart',
          sessionPath: '/home/user/project',
        ),
        '/home/user/project/test/features/chat/a_test.dart',
      );
    });

    test('strips a trailing separator from the session root', () {
      expect(
        resolveRemoteFetchPath(
          'a.dart',
          sessionPath: '/home/user/project/',
        ),
        '/home/user/project/a.dart',
      );
    });

    test('joins windows session roots with backslashes', () {
      expect(
        resolveRemoteFetchPath(
          r'test\a_test.dart',
          sessionPath: r'C:\repo',
        ),
        r'C:\repo\test\a_test.dart',
      );
    });

    test('expands ~ with the machine home dir', () {
      expect(
        resolveRemoteFetchPath(
          '~/notes.md',
          sessionPath: '/home/user/project',
          homeDir: '/home/user',
        ),
        '/home/user/notes.md',
      );
    });

    test('leaves ~ unchanged when home dir is unknown', () {
      expect(
        resolveRemoteFetchPath('~/notes.md', sessionPath: '/home/user'),
        '~/notes.md',
      );
    });

    test('returns relative paths unchanged without a session root', () {
      expect(resolveRemoteFetchPath('a.dart'), 'a.dart');
      expect(resolveRemoteFetchPath('a.dart', sessionPath: ''), 'a.dart');
    });

    test('returns empty paths unchanged', () {
      expect(
        resolveRemoteFetchPath('', sessionPath: '/home/user/project'),
        '',
      );
    });
  });
}
