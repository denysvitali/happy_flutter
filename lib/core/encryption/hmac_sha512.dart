import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// HMAC-SHA512 implementation for key derivation
class HmacSha512 {
  static const int _blockSize = 128; // SHA512 block size in bytes
  static const int _opad = 0x5c;
  static const int _ipad = 0x36;

  /// Compute HMAC-SHA512
  static Future<Uint8List> compute(Uint8List key, Uint8List data) async {
    // Prepare key
    Uint8List actualKey = key;
    if (key.length > _blockSize) {
      // If key is longer than block size, hash it
      final keyHash = sha512.convert(key).bytes;
      actualKey = Uint8List.fromList(keyHash);
    }

    // Pad key to block size
    final paddedKey = Uint8List(_blockSize);
    paddedKey.setAll(0, actualKey);

    // Create inner and outer padded keys
    final innerKey = Uint8List(_blockSize);
    final outerKey = Uint8List(_blockSize);

    for (int i = 0; i < _blockSize; i++) {
      innerKey[i] = paddedKey[i] ^ _ipad;
      outerKey[i] = paddedKey[i] ^ _opad;
    }

    // Inner hash: SHA512(innerKey || data)
    final innerData = Uint8List(_blockSize + data.length);
    innerData.setAll(0, innerKey);
    innerData.setAll(_blockSize, data);
    final innerHash = sha512.convert(innerData).bytes;

    // Outer hash: SHA512(outerKey || innerHash)
    final outerData = Uint8List(_blockSize + 64); // 64 bytes for SHA512 hash
    outerData.setAll(0, outerKey);
    outerData.setAll(_blockSize, innerHash);
    final finalHash = sha512.convert(outerData).bytes;

    return Uint8List.fromList(finalHash);
  }
}
