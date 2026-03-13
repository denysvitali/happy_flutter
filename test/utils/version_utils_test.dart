import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/version_utils.dart';

void main() {
  group('compareVersions', () {
    test('equal versions return 0', () {
      expect(compareVersions('1.0.0', '1.0.0'), 0);
      expect(compareVersions('2.5.3', '2.5.3'), 0);
    });

    test('first version greater returns 1', () {
      expect(compareVersions('2.0.0', '1.0.0'), 1);
      expect(compareVersions('1.1.0', '1.0.0'), 1);
      expect(compareVersions('1.0.1', '1.0.0'), 1);
    });

    test('first version less returns -1', () {
      expect(compareVersions('1.0.0', '2.0.0'), -1);
      expect(compareVersions('1.0.0', '1.1.0'), -1);
      expect(compareVersions('1.0.0', '1.0.1'), -1);
    });

    test('handles pre-release versions', () {
      expect(compareVersions('1.0.0-beta', '1.0.0'), 0);
      expect(compareVersions('1.0.0-alpha', '1.0.0-beta'), 0);
    });

    test('pads shorter versions with zeros', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
    });

    test('handles different segment counts', () {
      expect(compareVersions('1.0.0.1', '1.0.0'), 1);
      expect(compareVersions('1.0.0', '1.0.0.1'), -1);
    });
  });

  group('isVersionSupported', () {
    test('returns false for null version', () {
      expect(isVersionSupported(null), isFalse);
    });

    test('returns true when version meets minimum', () {
      expect(isVersionSupported('0.10.0'), isTrue);
      expect(isVersionSupported('1.0.0'), isTrue);
      expect(isVersionSupported('0.11.0'), isTrue);
    });

    test('returns false when below minimum', () {
      expect(isVersionSupported('0.9.0'), isFalse);
      expect(isVersionSupported('0.0.1'), isFalse);
    });

    test('accepts custom minimum version', () {
      expect(isVersionSupported('1.5.0', '2.0.0'), isFalse);
      expect(isVersionSupported('2.0.0', '2.0.0'), isTrue);
      expect(isVersionSupported('3.0.0', '2.0.0'), isTrue);
    });

    test('returns false for invalid version strings', () {
      expect(isVersionSupported('not-a-version'), isFalse);
      expect(isVersionSupported(''), isFalse);
    });
  });

  group('parseVersion', () {
    test('parses valid version string', () {
      final result = parseVersion('1.2.3');
      expect(result, isNotNull);
      expect(result!.major, 1);
      expect(result.minor, 2);
      expect(result.patch, 3);
    });

    test('strips pre-release suffix', () {
      final result = parseVersion('1.2.3-beta.1');
      expect(result, isNotNull);
      expect(result!.major, 1);
      expect(result.minor, 2);
      expect(result.patch, 3);
    });

    test('returns null for less than 3 segments', () {
      expect(parseVersion('1.2'), isNull);
      expect(parseVersion('1'), isNull);
    });

    test('returns null for non-numeric segments', () {
      expect(parseVersion('a.b.c'), isNull);
      expect(parseVersion('1.2.c'), isNull);
    });

    test('returns null for empty string', () {
      expect(parseVersion(''), isNull);
    });

    test('ParsedVersion toString', () {
      final v = ParsedVersion(major: 1, minor: 2, patch: 3);
      expect(v.toString(), '1.2.3');
    });

    test('ParsedVersion equality', () {
      final v1 = ParsedVersion(major: 1, minor: 2, patch: 3);
      final v2 = ParsedVersion(major: 1, minor: 2, patch: 3);
      final v3 = ParsedVersion(major: 1, minor: 2, patch: 4);
      expect(v1, equals(v2));
      expect(v1.hashCode, equals(v2.hashCode));
      expect(v1, isNot(equals(v3)));
    });
  });

  group('isPreRelease', () {
    test('returns true for versions with dash', () {
      expect(isPreRelease('1.0.0-beta'), isTrue);
      expect(isPreRelease('1.0.0-rc.1'), isTrue);
    });

    test('returns false for release versions', () {
      expect(isPreRelease('1.0.0'), isFalse);
    });
  });

  group('getPreReleaseSuffix', () {
    test('extracts suffix', () {
      expect(getPreReleaseSuffix('1.0.0-beta'), 'beta');
      expect(getPreReleaseSuffix('1.0.0-rc.1'), 'rc.1');
    });

    test('returns null for release version', () {
      expect(getPreReleaseSuffix('1.0.0'), isNull);
    });

    test('handles multiple dashes', () {
      expect(getPreReleaseSuffix('1.0.0-beta-1'), 'beta-1');
    });
  });

  group('formatVersion', () {
    test('formats without suffix', () {
      expect(formatVersion(1, 2, 3), '1.2.3');
    });

    test('formats with suffix', () {
      expect(formatVersion(1, 0, 0, 'beta'), '1.0.0-beta');
    });

    test('ignores empty suffix', () {
      expect(formatVersion(1, 0, 0, ''), '1.0.0');
    });

    test('ignores null suffix', () {
      expect(formatVersion(1, 0, 0, null), '1.0.0');
    });
  });

  group('minimumCliVersion', () {
    test('is a valid version string', () {
      final parsed = parseVersion(minimumCliVersion);
      expect(parsed, isNotNull);
    });
  });
}
