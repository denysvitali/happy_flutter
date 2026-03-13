import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/hex.dart';

void main() {
  group('HexUtils', () {
    group('encode', () {
      test('encodes empty bytes to empty string', () {
        final result = HexUtils.encode(Uint8List(0));
        expect(result, '');
      });

      test('encodes single byte', () {
        final result = HexUtils.encode(Uint8List.fromList([0]));
        expect(result, '00');
      });

      test('encodes 0xFF to ff', () {
        final result = HexUtils.encode(Uint8List.fromList([0xFF]));
        expect(result, 'ff');
      });

      test('encodes multiple bytes', () {
        final result = HexUtils.encode(Uint8List.fromList([0x01, 0xAB, 0xCD]));
        expect(result, '01abcd');
      });

      test('encodes zero-prefixed bytes correctly', () {
        final result =
            HexUtils.encode(Uint8List.fromList([0x00, 0x01, 0x0A]));
        expect(result, '00010a');
      });

      test('encodes all byte values', () {
        final bytes = Uint8List(256);
        for (var i = 0; i < 256; i++) {
          bytes[i] = i;
        }
        final result = HexUtils.encode(bytes);
        expect(result.length, 512);
        expect(result.startsWith('000102'), true);
        expect(result.endsWith('fdfeff'), true);
      });

      test('MAC format adds colons every two hex digits', () {
        final result =
            HexUtils.encode(Uint8List.fromList([0xAB, 0xCD, 0xEF]),
                HexFormat.mac,);
        expect(result, 'ab:cd:ef');
      });

      test('MAC format with single byte', () {
        final result =
            HexUtils.encode(Uint8List.fromList([0x12]), HexFormat.mac);
        expect(result, '12');
      });

      test('MAC format with many bytes', () {
        final bytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]);
        final result = HexUtils.encode(bytes, HexFormat.mac);
        expect(result, '01:02:03:04:05');
      });
    });

    group('decode', () {
      test('decodes empty string to empty bytes', () {
        final result = HexUtils.decode('');
        expect(result, Uint8List(0));
      });

      test('decodes single byte', () {
        final result = HexUtils.decode('ff');
        expect(result, Uint8List.fromList([0xFF]));
      });

      test('decodes multiple bytes', () {
        final result = HexUtils.decode('01abcd');
        expect(result, Uint8List.fromList([0x01, 0xAB, 0xCD]));
      });

      test('decodes uppercase hex', () {
        final result = HexUtils.decode('DEAD');
        expect(result, Uint8List.fromList([0xDE, 0xAD]));
      });

      test('decodes mixed case hex', () {
        final result = HexUtils.decode('DeAdBeEf');
        expect(result, Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]));
      });

      test('MAC format strips colons before decoding', () {
        final result =
            HexUtils.decode('ab:cd:ef', HexFormat.mac);
        expect(result, Uint8List.fromList([0xAB, 0xCD, 0xEF]));
      });

      test('roundtrip encode then decode preserves data', () {
        final original = Uint8List.fromList([0x00, 0x01, 0xAB, 0xFF, 0x42]);
        final encoded = HexUtils.encode(original);
        final decoded = HexUtils.decode(encoded);
        expect(decoded, original);
      });

      test('MAC format roundtrip preserves data', () {
        final original = Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]);
        final encoded = HexUtils.encode(original, HexFormat.mac);
        final decoded = HexUtils.decode(encoded, HexFormat.mac);
        expect(decoded, original);
      });
    });

    group('HexFormat enum', () {
      test('has normal and mac values', () {
        expect(HexFormat.values, hasLength(2));
        expect(HexFormat.values, contains(HexFormat.normal));
        expect(HexFormat.values, contains(HexFormat.mac));
      });
    });
  });
}
