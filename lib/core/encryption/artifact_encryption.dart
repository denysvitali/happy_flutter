import 'dart:typed_data';
import 'dart:math';
import 'encryptor.dart';
import 'base64.dart';

/// Artifact-specific encryption management
class ArtifactEncryption {
  final AES256Encryption _encryptor;

  ArtifactEncryption(Uint8List dataEncryptionKey)
      : _encryptor = AES256Encryption(dataEncryptionKey);

  /// Generate a new data encryption key for an artifact
  static Uint8List generateDataEncryptionKey() {
    final random = Random.secure();
    final key = Uint8List(32); // 256 bits for AES-256
    for (int i = 0; i < 32; i++) {
      key[i] = random.nextInt(256);
    }
    return key;
  }

  /// Encrypt artifact header
  Future<String> encryptHeader(Map<String, dynamic> header) async {
    final encrypted = await _encryptor.encrypt([header]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt artifact header
  Future<Map<String, dynamic>?> decryptHeader(String encryptedHeader) async {
    try {
      final encryptedData = Base64Utils.decode(encryptedHeader, Encoding.base64);
      final decrypted = await _encryptor.decrypt([encryptedData]);
      if (decrypted[0] == null) {
        return null;
      }

      final header = decrypted[0] as Map<String, dynamic>?;
      if (header == null) {
        return null;
      }

      return {
        'title': header['title'] as String?,
      };
    } catch (e) {
      return null;
    }
  }

  /// Encrypt artifact body
  Future<String> encryptBody(Map<String, dynamic> body) async {
    final encrypted = await _encryptor.encrypt([body]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt artifact body
  Future<Map<String, dynamic>?> decryptBody(String encryptedBody) async {
    try {
      final encryptedData = Base64Utils.decode(encryptedBody, Encoding.base64);
      final decrypted = await _encryptor.decrypt([encryptedData]);
      if (decrypted[0] == null) {
        return null;
      }

      final body = decrypted[0] as Map<String, dynamic>?;
      if (body == null) {
        return null;
      }

      return {
        'body': body['body'] as String?,
      };
    } catch (e) {
      return null;
    }
  }
}
