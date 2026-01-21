import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:pointycastle/pointycastle.dart';

/// Simplified secret box encryption using AES-CBC
class CryptoSecretBox {
  static const int _nonceSize = 16; // IV size for CBC

  /// Generate random nonce
  static Uint8List randomNonce() {
    final random = Random.secure();
    final nonce = Uint8List(_nonceSize);
    for (int i = 0; i < _nonceSize; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  /// Encrypt data using secret key
  static Uint8List encrypt(dynamic data, Uint8List secretKey) {
    final nonce = randomNonce();
    final jsonData = jsonEncode(data);
    final dataBytes = utf8.encode(jsonData);

    // Use AES-CBC for encryption with PKCS7 padding
    final keyParam = KeyParameter(Uint8List.fromList(secretKey.sublist(0, 32)));
    final ivParam = ParametersWithIV(keyParam, nonce);
    final params = PaddedBlockCipherParameters(ivParam, null);

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    cipher.init(true, params);
    final encrypted = cipher.process(dataBytes);

    // Bundle: nonce + encrypted
    final result = Uint8List(nonce.length + encrypted.length);
    result.setAll(0, nonce);
    result.setAll(nonce.length, encrypted);

    return result;
  }

  /// Decrypt encrypted data
  static dynamic decrypt(Uint8List encryptedData, Uint8List secretKey) {
    try {
      final nonce = encryptedData.sublist(0, _nonceSize);
      final encrypted = encryptedData.sublist(_nonceSize);

      final keyParam = KeyParameter(Uint8List.fromList(secretKey.sublist(0, 32)));
      final ivParam = ParametersWithIV(keyParam, nonce);
      final params = PaddedBlockCipherParameters(ivParam, null);

      final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
      cipher.init(false, params);
      final decrypted = cipher.process(encrypted);

      final jsonString = utf8.decode(decrypted);
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }
}
