import 'dart:typed_data';
import 'dart:math';
import 'dart:convert';
import '../encryption/encryption_manager.dart';

/// Encryption service wrapper for backward compatibility
class EncryptionService {
  Encryption? _encryption;

  Future<void> initialize(Uint8List masterSecret) async {
    _encryption = await Encryption.create(masterSecret);
  }

  /// Get the underlying Encryption instance
  Encryption get encryption {
    if (_encryption == null) {
      throw StateError('EncryptionService not initialized. Call initialize() first.');
    }
    return _encryption!;
  }

  String get anonId => _encryption?.anonId ?? '';

  Future<String> encryptRaw(dynamic data) async {
    return _encryption?.encryptRaw(data) ?? '';
  }

  Future<dynamic> decryptRaw(String encrypted) async {
    return _encryption?.decryptRaw(encrypted);
  }

  /// Legacy method for backward compatibility
  Future<Uint8List?> decryptSecretBox(Uint8List encryptedData) async {
    final result = _encryption?.decryptRaw(
      base64Encode(encryptedData),
    );
    if (result == null) return null;
    return base64Decode(result as String);
  }

  Uint8List randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
