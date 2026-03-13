import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/text.dart';

void main() {
  group('TextUtils', () {
    group('encodeUtf8', () {
      test('encodes empty string', () {
        final result = TextUtils.encodeUtf8('');
        expect(result, Uint8List(0));
      });

      test('encodes ASCII string', () {
        final result = TextUtils.encodeUtf8('Hello');
        expect(result.length, 5);
        expect(result, Uint8List.fromList([72, 101, 108, 108, 111]));
      });

      test('encodes unicode characters', () {
        final result = TextUtils.encodeUtf8('\u00e9'); // e-acute
        expect(result.length, 2); // UTF-8 encodes as 2 bytes
      });

      test('encodes emoji', () {
        final result = TextUtils.encodeUtf8('\u{1F600}'); // grinning face
        expect(result.length, 4); // UTF-8 encodes as 4 bytes
      });

      test('encodes CJK characters', () {
        final result = TextUtils.encodeUtf8('\u4f60\u597d'); // ni hao
        expect(result.length, 6); // 3 bytes each
      });

      test('encodes special characters', () {
        final result = TextUtils.encodeUtf8('\n\r\t');
        expect(result.length, 3);
        expect(result[0], 0x0A); // newline
        expect(result[1], 0x0D); // carriage return
        expect(result[2], 0x09); // tab
      });

      test('encodes null character', () {
        final result = TextUtils.encodeUtf8('\u0000');
        expect(result.length, 1);
        expect(result[0], 0);
      });
    });

    group('decodeUtf8', () {
      test('decodes empty bytes', () {
        final result = TextUtils.decodeUtf8(Uint8List(0));
        expect(result, '');
      });

      test('decodes ASCII bytes', () {
        final result = TextUtils.decodeUtf8(
          Uint8List.fromList([72, 101, 108, 108, 111]),
        );
        expect(result, 'Hello');
      });

      test('decodes unicode bytes', () {
        final encoded = Uint8List.fromList([0xC3, 0xA9]); // e-acute
        final result = TextUtils.decodeUtf8(encoded);
        expect(result, '\u00e9');
      });

      test('decodes emoji bytes', () {
        // grinning face U+1F600 = F0 9F 98 80
        final encoded = Uint8List.fromList([0xF0, 0x9F, 0x98, 0x80]);
        final result = TextUtils.decodeUtf8(encoded);
        expect(result, '\u{1F600}');
      });

      test('roundtrip encode then decode preserves string', () {
        final original = 'Hello, World! \u00e9\u00e8\u00ea \u{1F600}';
        final encoded = TextUtils.encodeUtf8(original);
        final decoded = TextUtils.decodeUtf8(encoded);
        expect(decoded, original);
      });
    });

    group('normalizeNfkd', () {
      test('returns string as-is (no normalization)', () {
        const input = 'Hello, World!';
        final result = TextUtils.normalizeNfkd(input);
        expect(result, input);
      });

      test('preserves unicode characters', () {
        const input = '\u00e9\u00e8\u00ea';
        final result = TextUtils.normalizeNfkd(input);
        expect(result, input);
      });

      test('preserves empty string', () {
        const input = '';
        final result = TextUtils.normalizeNfkd(input);
        expect(result, '');
      });
    });
  });
}
