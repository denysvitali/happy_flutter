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
    var actualKey = key;
    if (key.length > _blockSize) {
      // If key is longer than block size, hash it
      final keyHash = sha512.convert(key).bytes;
      actualKey = Uint8List.fromList(keyHash);
    }

    // Pad key to block size
    final paddedKey = Uint8List(_blockSize)..setAll(0, actualKey);

    // Create inner and outer padded keys
    final innerKey = Uint8List(_blockSize);
    final outerKey = Uint8List(_blockSize);

    for (var i = 0; i < _blockSize; i++) {
      innerKey[i] = paddedKey[i] ^ _ipad;
      outerKey[i] = paddedKey[i] ^ _opad;
    }

    // Inner hash: SHA512(innerKey || data)
    final innerData = Uint8List(_blockSize + data.length)
      ..setAll(0, innerKey)
      ..setAll(_blockSize, data);
    final innerHash = sha512.convert(innerData).bytes;

    // Outer hash: SHA512(outerKey || innerHash)
    // 64 bytes for SHA512 hash
    final outerData = Uint8List(_blockSize + 64)
      ..setAll(0, outerKey)
      ..setAll(_blockSize, innerHash);
    final finalHash = sha512.convert(outerData).bytes;

    return Uint8List.fromList(finalHash);
  }
}
