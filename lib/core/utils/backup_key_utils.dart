import 'dart:typed_data';

/// Utility for backing up and restoring secret keys using base32 with dashes format.
///
/// The format is: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX (5 characters per group, 5 groups)
/// This format is:
/// - Easy to read and transcribe
/// - Case-insensitive
/// - No confusing characters (0 vs O, 1 vs l vs I)
/// - 25 characters total + 4 dashes = 29 characters
class BackupKeyUtils {
  static const int _groupLength = 5;
  static const int _numGroups = 5;
  static const int _totalChars = _groupLength * _numGroups;

  /// Characters used in base32 encoding ( Crockford's base32 )
  /// Excludes confusing characters: 0, 1, I, L, O, U
  static const String _base32Chars = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static final Map<String, String> _normalizedChars = {
    '0': '0', 'O': '0', 'o': '0',
    '1': '1', 'I': '1', 'i': '1', 'L': '1', 'l': '1',
  };

  /// Encode a 32-byte secret key to base32 with dashes format
  ///
  /// Format: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
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
  /// - AAAAA-BBBBB-CCCCC-DDDDD-EEEEE
  /// - AAAAABBBBBCCCCCDDDDDEEEEE
  static Uint8List decodeKey(String formattedKey) {
    final cleaned = _removeDashesAndNormalize(formattedKey);

    if (cleaned.length != _totalChars) {
      throw FormatException(
        'Invalid key format. Expected $_totalChars characters, got ${cleaned.length}',
      );
    }

    return _fromBase32(cleaned);
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

  /// Convert bytes to Crockford's base32
  static String _toBase32(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    final result = StringBuffer();
    int buffer = 0;
    int bitsLeft = 0;

    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;

      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        final index = (buffer >> bitsLeft) & 0x1F;
        result.write(_base32Chars[index]);
      }
    }

    // Handle remaining bits
    if (bitsLeft > 0) {
      final index = (buffer << (5 - bitsLeft)) & 0x1F;
      result.write(_base32Chars[index]);
    }

    var resultStr = result.toString();
    // Pad to 52 characters (40 bits / 5 = 8 chars per 5 bytes, 32 bytes = 52 chars)
    while (resultStr.length < 52) {
      resultStr += '0';
    }
    // Take only first 52 characters
    return resultStr.substring(0, 52);
  }

  /// Convert Crockford's base32 back to bytes
  static Uint8List _fromBase32(String base32) {
    if (base32.isEmpty) return Uint8List(0);

    final cleaned = base32.toUpperCase();
    final bytes = <int>[];
    int buffer = 0;
    int bitsLeft = 0;

    for (final char in cleaned.runes) {
      final charStr = String.fromCharCode(char);
      final normalized = _normalizedChars[charStr] ?? charStr;

      if (!_base32Chars.contains(normalized)) {
        throw FormatException('Invalid base32 character: $charStr');
      }

      final value = _base32Chars.indexOf(normalized);
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
    for (int i = 0; i < _numGroups; i++) {
      final start = i * _groupLength;
      groups.add(base32.substring(start, start + _groupLength));
    }
    return groups.join('-');
  }

  /// Remove dashes and normalize confusing characters
  static String _removeDashesAndNormalize(String formatted) {
    final result = StringBuffer();

    for (final char in formatted.runes) {
      final charStr = String.fromCharCode(char);
      if (charStr == '-') continue;

      final normalized = _normalizedChars[charStr] ?? charStr.toUpperCase();
      result.write(normalized);
    }

    return result.toString();
  }

  /// Generate a random 32-byte key (for testing)
  static Uint8List generateRandomKey() {
    final random = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      random[i] = (DateTime.now().millisecondsSinceEpoch + i) % 256;
    }
    return random;
  }
}
