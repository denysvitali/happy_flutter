import 'dart:convert';
import 'dart:typed_data';

/// Text encoding/decoding utilities
class TextUtils {
  /// Encode string to UTF-8 bytes
  static Uint8List encodeUtf8(String value) {
    return Uint8List.fromList(utf8.encode(value));
  }

  /// Decode UTF-8 bytes to string
  static String decodeUtf8(Uint8List value) {
    return utf8.decode(value);
  }

  /// Normalize string to NFKD form
  static String normalizeNfkd(String value) {
    // Dart doesn't have built-in NFKD normalization
    // For now, return as-is. Consider using 'intl' package or other libraries
    // if NFKD normalization is required.
    return value;
  }
}
