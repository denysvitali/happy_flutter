import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import 'package:pinenacl/api.dart' as nacl;
import 'package:pinenacl/src/authenticated_encryption/secret.dart' as enc;
import 'text.dart';

/// NaCl-style secret box encryption (symmetric encryption)
class CryptoSecretBox {
  static const int _nonceSize = 24; // Nonce size matching NaCl

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
    final dataBytes = TextUtils.encodeUtf8(jsonData);

    // Use Pinenacl SecretBox for proper encryption
    final box = enc.SecretBox(secretKey);
    final encrypted = box.encrypt(
      dataBytes,
      nonce: nonce,
    );

    // Bundle: nonce + encrypted
    final result = Uint8List(nonce.length + encrypted.length);
    result.setAll(0, nonce);
    result.setAll(nonce.length, encrypted.asTypedList);

    return result;
  }

  /// Decrypt encrypted data
  static dynamic decrypt(Uint8List encryptedData, Uint8List secretKey) {
    try {
      final nonce = encryptedData.sublist(0, _nonceSize);
      final encrypted = encryptedData.sublist(_nonceSize);

      final box = enc.SecretBox(secretKey);
      final decrypted = box.decrypt(
        nacl.ByteList(encrypted),
        nonce: nonce,
      );

      final jsonString = TextUtils.decodeUtf8(decrypted);
      return jsonDecode(jsonString);
    } catch (e) {
      return null;
    }
  }
}
