import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';

/// Hex encoding/decoding utilities
class HexUtils {
  /// Decode hex string to bytes
  static Uint8List decode(String hexString, [HexFormat format = HexFormat.normal]) {
    String encoded = hexString;

    if (format == HexFormat.mac) {
      encoded = hexString.replaceAll(':', '');
    }

    return Uint8List.fromList(hex.decode(encoded));
  }

  /// Encode bytes to hex string
  static String encode(Uint8List buffer, [HexFormat format = HexFormat.normal]) {
    final encoded = hex.encode(buffer);

    if (format == HexFormat.mac) {
      final matches = RegExp(r'.{2}').allMatches(encoded);
      return matches.map((m) => m.group(0)!).join(':');
    }

    return encoded;
  }
}

enum HexFormat {
  normal,
  mac,
}
