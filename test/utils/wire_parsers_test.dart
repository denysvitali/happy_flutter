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
  });
}
