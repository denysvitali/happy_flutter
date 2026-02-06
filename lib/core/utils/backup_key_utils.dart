import 'dart:typed_data';

/// Utility for backing up and restoring secret keys using base32 with dashes
/// format.
///
/// This matches the React Native implementation in
/// happy/packages/happy-app/sources/auth/secretKeyBackup.ts
///
/// The format is: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-
/// XXXXX (11 groups of 5 characters = 55 with dashes, 52 without)
///
/// Uses RFC 4648 Base32 alphabet: ABCDEFGHIJKLMNOPQRSTUVWXYZ234567
/// - Easy to read and transcribe
/// - Case-insensitive
/// - 32 bytes = 256 bits = 52 base32 chars
class BackupKeyUtils {
  /// Base32 alphabet (RFC 4648) - excludes confusing characters
  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Encode a 32-byte secret key to base32 with dashes format
  ///
  /// Format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
  static String encodeKey(Uint8List secretKey) {
    if (secretKey.length != 32) {
      throw ArgumentError('Secret key must be exactly 32 bytes');
    }

    final base32 = _toBase32(secretKey);
    return _formatWithDashes(base32);
  }

  /// Decode a base32 with dashes format back to 32-byte secret key
  ///
  /// Accepts formats like:
  /// - AAAAA-BBBBB-CCCCC-DDDDD-EEEEE-FFFFF-GGGGG-HHHHH-IIIII-JJJJJ-KKKKK
  /// - AAAAABBBBBCCCCCDDDDDEEEEEFFFFFGGGGGHHHHHIIIIJJJJJKKKK
  static Uint8List decodeKey(String formattedKey) {
    final cleaned = _removeDashesAndNormalize(formattedKey);

    final bytes = _fromBase32(cleaned);
    if (bytes.length != 32) {
      throw FormatException(
        'Invalid key length: expected 32 bytes, got ${bytes.length}',
      );
    }

    return bytes;
  }

  /// Validate a formatted key
  static bool isValidKey(String formattedKey) {
    try {
      decodeKey(formattedKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Convert bytes to RFC 4648 base32
  static String _toBase32(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    final result = StringBuffer();
    var buffer = 0;
    var bitsLeft = 0;

    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;

      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        final index = (buffer >> bitsLeft) & 0x1F;
        result.write(_base32Alphabet[index]);
      }
    }

    // Handle remaining bits
    if (bitsLeft > 0) {
      final index = (buffer << (5 - bitsLeft)) & 0x1F;
      result.write(_base32Alphabet[index]);
    }

    // 32 bytes = 256 bits = 52 base32 characters (rounded up from 51.2)
    final resultStr = result.toString();
    // Pad with 'A' (which represents 0) to reach 52 characters
    final padded = resultStr.padRight(52, 'A');
    return padded.substring(0, 52);
  }

  /// Convert RFC 4648 base32 back to bytes
  static Uint8List _fromBase32(String base32) {
    final cleaned = base32.toUpperCase();

    final bytes = <int>[];
    var buffer = 0;
    var bitsLeft = 0;

    for (final char in cleaned.runes) {
      final charStr = String.fromCharCode(char);

      final value = _base32Alphabet.indexOf(charStr);
      if (value == -1) {
        throw FormatException('Invalid base32 character: $charStr');
      }

      buffer = (buffer << 5) | value;
      bitsLeft += 5;

      while (bitsLeft >= 8) {
        bitsLeft -= 8;
        bytes.add((buffer >> bitsLeft) & 0xFF);
      }
    }

    return Uint8List.fromList(bytes);
  }

  /// Format base32 string with dashes every 5 characters
  static String _formatWithDashes(String base32) {
    final groups = <String>[];
    for (var i = 0; i < base32.length; i += 5) {
      groups.add(base32.substring(i, (i + 5).clamp(0, base32.length)));
    }
    return groups.join('-');
  }

  /// Remove dashes and normalize the input
  /// Matches React Native behavior:
  /// - 0 -> O
  /// - 1 -> I
  /// - 8 -> B
  /// - 9 -> G
  static String _removeDashesAndNormalize(String formatted) {
    var result = formatted.toUpperCase();

    // Normalize common mistakes (matching React Native)
    result = result.replaceAll('0', 'O');
    result = result.replaceAll('1', 'I');
    result = result.replaceAll('8', 'B');
    result = result.replaceAll('9', 'G');

    // Remove all non-base32 characters (spaces, dashes, etc)
    result = result.replaceAll(RegExp(r'[^A-Z2-7]'), '');

    if (result.isEmpty) {
      throw FormatException('No valid characters found');
    }

    return result;
  }

  /// Generate a random 32-byte key (for testing)
  static Uint8List generateRandomKey() {
    final random = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      random[i] = (DateTime.now().millisecondsSinceEpoch + i) % 256;
    }
    return random;
  }
}
