import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';

void main() {
  group('WireParsers.parseInt', () {
    test('parses numbers and numeric strings', () {
      expect(WireParsers.parseInt(42), 42);
      expect(WireParsers.parseInt(42.9), 42);
      expect(WireParsers.parseInt('42'), 42);
      expect(WireParsers.parseInt('42.9'), 42);
      expect(WireParsers.parseInt('  123  '), 123);
    });

    test('returns null for invalid values', () {
      expect(WireParsers.parseInt(null), isNull);
      expect(WireParsers.parseInt('abc'), isNull);
      expect(WireParsers.parseInt(<String, dynamic>{}), isNull);
    });

    test('handles boundary integers', () {
      expect(WireParsers.parseInt(0), 0);
      expect(WireParsers.parseInt(-1), -1);
      expect(WireParsers.parseInt(-999999), -999999);
    });

    test('handles large integers', () {
      expect(WireParsers.parseInt(2147483647), 2147483647);
      expect(WireParsers.parseInt(-2147483648), -2147483648);
    });

    test('handles double truncation toward zero', () {
      expect(WireParsers.parseInt(0.9), 0);
      expect(WireParsers.parseInt(-0.9), 0);
      expect(WireParsers.parseInt(1.1), 1);
      expect(WireParsers.parseInt(-1.1), -1);
      expect(WireParsers.parseInt(99.99), 99);
    });

    test('handles negative string numbers', () {
      expect(WireParsers.parseInt('-42'), -42);
      expect(WireParsers.parseInt(' -7 '), -7);
      expect(WireParsers.parseInt('-3.14'), -3);
    });

    test('handles empty and whitespace strings', () {
      expect(WireParsers.parseInt(''), isNull);
      expect(WireParsers.parseInt('   '), isNull);
      expect(WireParsers.parseInt('\t'), isNull);
      expect(WireParsers.parseInt('\n'), isNull);
    });

    test('handles malformed numeric strings', () {
      expect(WireParsers.parseInt('42abc'), isNull);
      expect(WireParsers.parseInt('abc42'), isNull);
      expect(WireParsers.parseInt('4.2.3'), isNull);
      // '0x10' is valid for int.tryParse in Dart (hex).
      expect(WireParsers.parseInt('0x10'), 16);
      // '1e5' is valid for double.tryParse (scientific notation).
      expect(WireParsers.parseInt('1e5'), 100000);
    });

    test('handles infinity and NaN doubles', () {
      // The source does double.toInt() without guarding infinity/NaN,
      // so these throw UnsupportedError.
      expect(
        () => WireParsers.parseInt(double.infinity),
        throwsUnsupportedError,
      );
      expect(
        () => WireParsers.parseInt(double.negativeInfinity),
        throwsUnsupportedError,
      );
      expect(
        () => WireParsers.parseInt(double.nan),
        throwsUnsupportedError,
      );
    });

    test('handles string representations of special doubles', () {
      // 'Infinity' and 'NaN' are parsed by double.tryParse, then
      // .toInt() throws UnsupportedError.
      expect(
        () => WireParsers.parseInt('Infinity'),
        throwsUnsupportedError,
      );
      expect(
        () => WireParsers.parseInt('NaN'),
        throwsUnsupportedError,
      );
      // 'inf' is not parsed by double.tryParse, returns null.
      expect(WireParsers.parseInt('inf'), isNull);
    });

    test('handles non-primitive types', () {
      expect(WireParsers.parseInt([1, 2, 3]), isNull);
      expect(WireParsers.parseInt(true), isNull);
      expect(WireParsers.parseInt(false), isNull);
    });

    test('handles zero doubles', () {
      expect(WireParsers.parseInt(0.0), 0);
      expect(WireParsers.parseInt(-0.0), 0);
    });

    test('handles num type explicitly', () {
      final num n = 42;
      expect(WireParsers.parseInt(n), 42);
      final num d = 3.7;
      expect(WireParsers.parseInt(d), 3);
    });

    test('handles scientific notation in strings', () {
      expect(WireParsers.parseInt('1e3'), 1000);
      expect(WireParsers.parseInt('1.5e2'), 150);
    });

    test('handles hex prefix strings', () {
      // Dart's int.tryParse supports hex format natively.
      expect(WireParsers.parseInt('0x10'), 16);
    });
  });

  group('WireParsers.parseBool', () {
    test('parses booleans from multiple wire formats', () {
      expect(WireParsers.parseBool(true), true);
      expect(WireParsers.parseBool(false), false);
      expect(WireParsers.parseBool(1), true);
      expect(WireParsers.parseBool(0), false);
      expect(WireParsers.parseBool('true'), true);
      expect(WireParsers.parseBool('false'), false);
      expect(WireParsers.parseBool('1'), true);
      expect(WireParsers.parseBool('0'), false);
    });

    test('returns null for invalid values', () {
      expect(WireParsers.parseBool(null), isNull);
      expect(WireParsers.parseBool('yes'), isNull);
      expect(WireParsers.parseBool(<String, dynamic>{}), isNull);
    });

    test('handles case insensitivity for strings', () {
      expect(WireParsers.parseBool('TRUE'), true);
      expect(WireParsers.parseBool('FALSE'), false);
      expect(WireParsers.parseBool('True'), true);
      expect(WireParsers.parseBool('False'), false);
      expect(WireParsers.parseBool('TrUe'), true);
    });

    test('handles whitespace in string values', () {
      expect(WireParsers.parseBool(' true '), true);
      expect(WireParsers.parseBool(' false '), false);
      expect(WireParsers.parseBool(' 1 '), true);
      expect(WireParsers.parseBool(' 0 '), false);
    });

    test('handles non-zero numbers as true', () {
      expect(WireParsers.parseBool(2), true);
      expect(WireParsers.parseBool(-1), true);
      expect(WireParsers.parseBool(0.5), true);
      expect(WireParsers.parseBool(-0.5), true);
    });

    test('handles empty string as null', () {
      expect(WireParsers.parseBool(''), isNull);
      expect(WireParsers.parseBool('  '), isNull);
    });

    test('handles non-primitive types', () {
      expect(WireParsers.parseBool([true]), isNull);
      expect(WireParsers.parseBool({'value': true}), isNull);
    });

    test('handles invalid string values', () {
      expect(WireParsers.parseBool('Truee'), isNull);
      expect(WireParsers.parseBool('2'), isNull);
      expect(WireParsers.parseBool('-1'), isNull);
      expect(WireParsers.parseBool('on'), isNull);
      expect(WireParsers.parseBool('off'), isNull);
    });

    test('handles num type', () {
      final num one = 1;
      final num zero = 0;
      final num negative = -5;
      expect(WireParsers.parseBool(one), true);
      expect(WireParsers.parseBool(zero), false);
      expect(WireParsers.parseBool(negative), true);
    });
  });

  group('WireParsers.parseString', () {
    test('returns string as-is', () {
      expect(WireParsers.parseString('hello'), 'hello');
      expect(WireParsers.parseString(''), '');
    });

    test('returns null for null input', () {
      expect(WireParsers.parseString(null), isNull);
    });

    test('converts non-string types to string', () {
      expect(WireParsers.parseString(42), '42');
      expect(WireParsers.parseString(true), 'true');
      expect(WireParsers.parseString(false), 'false');
      expect(WireParsers.parseString(3.14), '3.14');
    });

    test('converts complex types', () {
      final result = WireParsers.parseString([1, 2, 3]);
      expect(result, isNotNull);
      expect(result, contains('1'));
    });
  });

  group('WireParsers integration', () {
    test('parseInt and parseBool handle same wire value types', () {
      // Server may send 0/1 as either int or string
      expect(WireParsers.parseInt(1), 1);
      expect(WireParsers.parseBool(1), true);
      expect(WireParsers.parseInt('1'), 1);
      expect(WireParsers.parseBool('1'), true);
    });

    test('all parsers handle null gracefully', () {
      expect(WireParsers.parseInt(null), isNull);
      expect(WireParsers.parseBool(null), isNull);
      expect(WireParsers.parseString(null), isNull);
    });
  });
}
