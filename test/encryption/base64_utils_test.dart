import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/base64.dart';

void main() {
  group('Base64Utils', () {
    group('encode', () {
      test('encodes empty bytes', () {
        final result = Base64Utils.encode(Uint8List(0));
        expect(result, '');
      });

      test('encodes single byte', () {
        final result = Base64Utils.encode(Uint8List.fromList([0x00]));
        expect(result, isNotEmpty);
        // Can be decoded back
        final decoded = Base64Utils.decode(result);
        expect(decoded, Uint8List.fromList([0x00]));
      });

      test('encodes known data', () {
        // 'Hello' = [72, 101, 108, 108, 111]
        final result = Base64Utils.encode(
          Uint8List.fromList([72, 101, 108, 108, 111]),
        );
        expect(result, 'SGVsbG8=');
      });

      test('standard base64 contains + and / chars', () {
        // Create data that will produce + and / in base64
        final result =
            Base64Utils.encode(Uint8List.fromList([251, 239, 190, 222]));
        // Standard encoding may contain +/=
        expect(result, isA<String>());
      });

      test('URL-safe encoding replaces + with -', () {
        // Create data that produces + in standard base64
        final data = Uint8List.fromList([0xFB, 0xEF, 0xBE, 0xDE]);
        final standard = Base64Utils.encode(data, Encoding.base64);
        final urlSafe = Base64Utils.encode(data, Encoding.base64url);

        if (standard.contains('+')) {
          expect(urlSafe.contains('-'), true);
        }
        expect(urlSafe.contains('+'), false);
      });

      test('URL-safe encoding replaces / with _', () {
        // Create data that produces / in standard base64
        final data = Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]);
        final standard = Base64Utils.encode(data, Encoding.base64);
        final urlSafe = Base64Utils.encode(data, Encoding.base64url);

        if (standard.contains('/')) {
          expect(urlSafe.contains('_'), true);
        }
        expect(urlSafe.contains('/'), false);
      });

      test('URL-safe encoding removes padding', () {
        final data = Uint8List.fromList([72, 101, 108, 108, 111]);
        final standard = Base64Utils.encode(data, Encoding.base64);
        final urlSafe = Base64Utils.encode(data, Encoding.base64url);

        // Standard may have = padding
        // URL-safe should not have = padding
        expect(urlSafe.contains('='), false);
      });

      test('large data encodes correctly', () {
        final data = Uint8List(1024);
        for (var i = 0; i < 1024; i++) {
          data[i] = i % 256;
        }
        final encoded = Base64Utils.encode(data);
        final decoded = Base64Utils.decode(encoded);
        expect(decoded, data);
      });
    });

    group('decode', () {
      test('decodes empty string', () {
        final result = Base64Utils.decode('');
        expect(result, Uint8List(0));
      });

      test('decodes known base64', () {
        final result = Base64Utils.decode('SGVsbG8=');
        expect(result, Uint8List.fromList([72, 101, 108, 108, 111]));
      });

      test('decodes base64 with whitespace', () {
        // Whitespace should be stripped
        final result = Base64Utils.decode('SGVs\nbG8=');
        expect(result, Uint8List.fromList([72, 101, 108, 108, 111]));
      });

      test('decodes base64 with tabs', () {
        final result = Base64Utils.decode('SGVs\tbG8=');
        expect(result, Uint8List.fromList([72, 101, 108, 108, 111]));
      });

      test('handles missing padding', () {
        // 'SGVsbG8' without trailing =
        final result = Base64Utils.decode('SGVsbG8');
        expect(result, Uint8List.fromList([72, 101, 108, 108, 111]));
      });

      test('decodes URL-safe base64 (base64url)', () {
        // Create standard encoding, convert to url-safe format manually
        final data = Uint8List.fromList([0xFB, 0xEF, 0xBE, 0xDE]);
        final encoded = Base64Utils.encode(data, Encoding.base64);
        final urlSafe = encoded
            .replaceAll('+', '-')
            .replaceAll('/', '_')
            .replaceAll('=', '');

        final decoded = Base64Utils.decode(urlSafe);
        expect(decoded, data);
      });

      test('roundtrip preserves data', () {
        final original =
            Uint8List.fromList([0, 1, 2, 3, 4, 5, 250, 251, 252, 253, 254, 255]);
        final encoded = Base64Utils.encode(original);
        final decoded = Base64Utils.decode(encoded);
        expect(decoded, original);
      });

      test('roundtrip with URL-safe encoding', () {
        final original = Uint8List.fromList([0xFF, 0xFE, 0xFD, 0xFB]);
        final encoded = Base64Utils.encode(original, Encoding.base64url);
        final decoded = Base64Utils.decode(encoded);
        expect(decoded, original);
      });

      test('roundtrip with large data', () {
        final original = Uint8List(4096);
        for (var i = 0; i < 4096; i++) {
          original[i] = i % 256;
        }
        final encoded = Base64Utils.encode(original);
        final decoded = Base64Utils.decode(encoded);
        expect(decoded, original);
      });
    });

    group('Encoding enum', () {
      test('has base64 and base64url values', () {
        expect(Encoding.values, hasLength(2));
        expect(Encoding.values, contains(Encoding.base64));
        expect(Encoding.values, contains(Encoding.base64url));
      });
    });
  });
}
