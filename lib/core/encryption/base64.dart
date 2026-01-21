import 'dart:convert';
import 'dart:typed_data';

/// Base64 encoding/decoding utilities
class Base64Utils {
  /// Decode base64 string to bytes
  static Uint8List decode(String base64, [Encoding encoding = Encoding.base64]) {
    String normalizedBase64 = base64;

    if (encoding == Encoding.base64url) {
      normalizedBase64 = base64.replaceAll('-', '+').replaceAll('_', '/');

      final padding = normalizedBase64.length % 4;
      if (padding > 0) {
        normalizedBase64 += '=' * (4 - padding);
      }
    }

    return base64Decode(normalizedBase64);
  }

  /// Encode bytes to base64 string
  static String encode(Uint8List buffer, [Encoding encoding = Encoding.base64]) {
    final base64 = base64Encode(buffer);

    if (encoding == Encoding.base64url) {
      return base64.replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
    }

    return base64;
  }
}

enum Encoding {
  base64,
  base64url,
}
