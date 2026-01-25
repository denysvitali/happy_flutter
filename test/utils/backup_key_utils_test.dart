import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/backup_key_utils.dart';

void main() {
  group('BackupKeyUtils', () {
    group('Encoding', () {
      test('encodeKey produces correct format with dashes', () {
        final key = Uint8List(32);

        final encoded = BackupKeyUtils.encodeKey(key);

        // Format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
        expect(encoded.contains('-'), isTrue);
        final parts = encoded.split('-');
        expect(parts.length, 5);
        for (final part in parts) {
          expect(part.length, 5);
        }
      });

      test('encodeKey produces 29 character string', () {
        final key = Uint8List(32);

        final encoded = BackupKeyUtils.encodeKey(key);

        // 25 characters + 4 dashes = 29
        expect(encoded.length, 29);
      });

      test('encodeKey is deterministic', () {
        final key = Uint8List.fromList(List.generate(32, (i) => i % 256));

        final encoded1 = BackupKeyUtils.encodeKey(key);
        final encoded2 = BackupKeyUtils.encodeKey(key);

        expect(encoded1, equals(encoded2));
      });

      test('encodeKey produces different output for different keys', () {
        final key1 = Uint8List(32);
        final key2 = Uint8List(32);
        key2[0] = 1;

        final encoded1 = BackupKeyUtils.encodeKey(key1);
        final encoded2 = BackupKeyUtils.encodeKey(key2);

        expect(encoded1, isNot(equals(encoded2)));
      });

      test('encodeKey throws on wrong key length', () {
        final key = Uint8List(16);

        expect(
          () => BackupKeyUtils.encodeKey(key),
          throwsArgumentError,
        );
      });

      test('encodeKey uses Crockford base32 charset', () {
        final key = Uint8List(32);
        key[0] = 0xFF;

        final encoded = BackupKeyUtils.encodeKey(key);

        // Crockford's base32 charset (excluding confusing characters)
        const validChars = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
        final withoutDashes = encoded.replaceAll('-', '');
        for (final char in withoutDashes.runes) {
          final charStr = String.fromCharCode(char);
          expect(
            validChars.contains(charStr),
            isTrue,
            reason: '$charStr should be in base32 charset',
          );
        }
      });
    });

    group('Decoding', () {
      test('decodeKey restores original key', () {
        final originalKey = Uint8List.fromList(
          List.generate(32, (i) => (i * 7) % 256),
        );

        final encoded = BackupKeyUtils.encodeKey(originalKey);
        final decoded = BackupKeyUtils.decodeKey(encoded);

        expect(decoded, equals(originalKey));
      });

      test('decodeKey accepts format with dashes', () {
        final originalKey = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(originalKey);

        final decoded = BackupKeyUtils.decodeKey(encoded);

        expect(decoded, equals(originalKey));
      });

      test('decodeKey accepts format without dashes', () {
        final originalKey = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(originalKey);
        final withoutDashes = encoded.replaceAll('-', '');

        final decoded = BackupKeyUtils.decodeKey(withoutDashes);

        expect(decoded, equals(originalKey));
      });

      test('decodeKey normalizes confusing characters', () {
        final originalKey = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(originalKey);

        // Replace some characters with confusing alternatives
        final normalized = encoded
            .replaceAll('0', 'O')
            .replaceAll('1', 'I')
            .replaceAll('1', 'L');

        final decoded = BackupKeyUtils.decodeKey(normalized);

        expect(decoded, equals(originalKey));
      });

      test('decodeKey handles lowercase input', () {
        final originalKey = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(originalKey);
        final lowercase = encoded.toLowerCase();

        final decoded = BackupKeyUtils.decodeKey(lowercase);

        expect(decoded, equals(originalKey));
      });

      test('decodeKey throws on invalid length', () {
        final invalidKey = 'AAAAA-BBBBB';

        expect(
          () => BackupKeyUtils.decodeKey(invalidKey),
          throwsFormatException,
        );
      });

      test('decodeKey throws on invalid characters', () {
        final invalidKey = 'UUUUU-UUUUU-UUUUU-UUUUU-UUUUU'; // U is invalid

        expect(
          () => BackupKeyUtils.decodeKey(invalidKey),
          throwsFormatException,
        );
      });

      test('decodeKey throws on too short input', () {
        final invalidKey = 'AAAAA-BBBBB-CCCCC-DDDDD';

        expect(
          () => BackupKeyUtils.decodeKey(invalidKey),
          throwsFormatException,
        );
      });

      test('decodeKey throws on too long input', () {
        final invalidKey = 'AAAAA-BBBBB-CCCCC-DDDDD-EEEEE-FFFFF';

        expect(
          () => BackupKeyUtils.decodeKey(invalidKey),
          throwsFormatException,
        );
      });
    });

    group('Validation', () {
      test('isValidKey returns true for valid key with dashes', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key);

        expect(BackupKeyUtils.isValidKey(encoded), isTrue);
      });

      test('isValidKey returns true for valid key without dashes', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key).replaceAll('-', '');

        expect(BackupKeyUtils.isValidKey(encoded), isTrue);
      });

      test('isValidKey returns false for invalid length', () {
        expect(BackupKeyUtils.isValidKey('AAAAA-BBBBB'), isFalse);
      });

      test('isValidKey returns false for invalid characters', () {
        expect(
          BackupKeyUtils.isValidKey('UUUUU-UUUUU-UUUUU-UUUUU-UUUUU'),
          isFalse,
        );
      });

      test('isValidKey returns false for empty string', () {
        expect(BackupKeyUtils.isValidKey(''), isFalse);
      });

      test('isValidKey handles mixed case and confusing characters', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key);

        // Test with various character substitutions
        final variants = [
          encoded.toLowerCase(),
          encoded.toUpperCase(),
          encoded.replaceAll('0', 'O'),
          encoded.replaceAll('1', 'I'),
        ];

        for (final variant in variants) {
          expect(
            BackupKeyUtils.isValidKey(variant),
            isTrue,
            reason: 'Should accept variant: $variant',
          );
        }
      });
    });

    group('Roundtrip Tests', () {
      test('encode-decode roundtrip works for all-zero key', () {
        final key = Uint8List(32);

        final encoded = BackupKeyUtils.encodeKey(key);
        final decoded = BackupKeyUtils.decodeKey(encoded);

        expect(decoded, equals(key));
      });

      test('encode-decode roundtrip works for all-ones key', () {
        final key = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          key[i] = 0xFF;
        }

        final encoded = BackupKeyUtils.encodeKey(key);
        final decoded = BackupKeyUtils.decodeKey(encoded);

        expect(decoded, equals(key));
      });

      test('encode-decode roundtrip works for sequential keys', () {
        for (int seed = 0; seed < 10; seed++) {
          final key = Uint8List.fromList(
            List.generate(32, (i) => (seed + i) % 256),
          );

          final encoded = BackupKeyUtils.encodeKey(key);
          final decoded = BackupKeyUtils.decodeKey(encoded);

          expect(decoded, equals(key), reason: 'Failed for seed $seed');
        }
      });

      test('encode-decode roundtrip handles boundary values', () {
        final boundaryKeys = [
          Uint8List.fromList([0x00, 0x01, 0x7F, 0x80, 0xFF] +
              List.generate(27, (i) => 0)),
          Uint8List.fromList(List.generate(32, (i) => 0x80)),
        ];

        for (final key in boundaryKeys) {
          final encoded = BackupKeyUtils.encodeKey(key);
          final decoded = BackupKeyUtils.decodeKey(encoded);

          expect(decoded, equals(key));
        }
      });
    });

    group('Character Normalization', () {
      test('normalizes O/o to 0', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key);

        // Replace all 0s with O
        final withO = encoded.replaceAll('0', 'O');

        expect(BackupKeyUtils.isValidKey(withO), isTrue);

        final decoded = BackupKeyUtils.decodeKey(withO);
        expect(decoded, equals(key));
      });

      test('normalizes I/i/L/l to 1', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key);

        // Replace all 1s with I, L, and lowercase variants
        final withI = encoded.replaceAll('1', 'I');
        final withL = encoded.replaceAll('1', 'L');
        final withLowerL = encoded.replaceAll('1', 'l');
        final withLowerI = encoded.replaceAll('1', 'i');

        expect(BackupKeyUtils.isValidKey(withI), isTrue);
        expect(BackupKeyUtils.isValidKey(withL), isTrue);
        expect(BackupKeyUtils.isValidKey(withLowerL), isTrue);
        expect(BackupKeyUtils.isValidKey(withLowerI), isTrue);
      });
    });

    group('Base32 Encoding Details', () {
      test('produces 52 base32 characters before formatting', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key);
        final withoutDashes = encoded.replaceAll('-', '');

        expect(withoutDashes.length, 52);
      });

      test('uses only valid base32 characters', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key);

        const validChars = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
        for (final char in encoded.runes) {
          final charStr = String.fromCharCode(char);
          if (charStr == '-') continue;
          expect(
            validChars.contains(charStr),
            isTrue,
            reason: '$charStr should be a valid base32 character',
          );
        }
      });

      test('excludes confusing characters from output', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key);

        // These characters should not appear in the output
        // (though they may be accepted as input for normalization)
        expect(encoded.contains('I'), isFalse);
        expect(encoded.contains('L'), isFalse);
        expect(encoded.contains('O'), isFalse);
        expect(encoded.contains('U'), isFalse);
      });
    });

    group('Edge Cases', () {
      test('handles very large values', () {
        final key = Uint8List.fromList(List.generate(32, (i) => 0xFF));

        final encoded = BackupKeyUtils.encodeKey(key);
        final decoded = BackupKeyUtils.decodeKey(encoded);

        expect(decoded, equals(key));
      });

      test('handles alternating pattern', () {
        final key = Uint8List.fromList(
          List.generate(32, (i) => i % 2 == 0 ? 0xAA : 0x55),
        );

        final encoded = BackupKeyUtils.encodeKey(key);
        final decoded = BackupKeyUtils.decodeKey(encoded);

        expect(decoded, equals(key));
      });

      test('formatWithDashes produces consistent groups', () {
        final key = Uint8List(32);
        final encoded = BackupKeyUtils.encodeKey(key);
        final parts = encoded.split('-');

        expect(parts.length, 5);
        for (final part in parts) {
          expect(part.length, 5);
        }
      });
    });
  });
}
