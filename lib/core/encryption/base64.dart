import 'dart:convert';
import 'dart:typed_data';

/// Base64 encoding/decoding utilities
class Base64Utils {
  /// Decode base64 string to bytes.
  ///
  /// Accepts both standard base64 (`+`/`/`) and URL-safe base64url (`-`/`_`).
  /// Strips whitespace and adds missing padding automatically.
  static Uint8List decode(
    String base64, [
    Encoding encoding = Encoding.base64,
  ]) {
    // Normalize: convert base64url chars, strip whitespace, fix padding.
    var normalized = base64
        .replaceAll('-', '+')
        .replaceAll('_', '/')
        .replaceAll(RegExp(r'\s'), '');
    final pad = normalized.length % 4;
    if (pad > 0) normalized += '=' * (4 - pad);
    return base64Decode(normalized);
  }

  /// Encode bytes to base64 string
  static String encode(
    Uint8List buffer, [
    Encoding encoding = Encoding.base64,
  ]) {
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
