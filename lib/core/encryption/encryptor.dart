import 'dart:typed_data';
import 'dart:convert';
import 'crypto_secret_box.dart';
import 'crypto_box.dart';
import 'text.dart';
import 'base64.dart';

/// Encryptor interface
abstract class Encryptor {
  Future<List<Uint8List>> encrypt(List<dynamic> data);
}

/// Decryptor interface
abstract class Decryptor {
  Future<List<dynamic?>> decrypt(List<Uint8List> data);
}

/// NaCl Secret Box encryption (symmetric)
class SecretBoxEncryption implements Encryptor, Decryptor {
  final Uint8List _secretKey;

  SecretBoxEncryption(this._secretKey);

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      results.add(CryptoSecretBox.encrypt(item, _secretKey));
    }
    return results;
  }

  @override
  Future<List<dynamic?>> decrypt(List<Uint8List> data) async {
    final results = <dynamic?>[];
    for (final item in data) {
      results.add(CryptoSecretBox.decrypt(item, _secretKey));
    }
    return results;
  }
}

/// NaCl Box encryption (public key)
class BoxEncryption implements Encryptor, Decryptor {
  late final Uint8List _privateKey;
  late final Uint8List _publicKey;

  BoxEncryption(Uint8List seed) {
    final keypair = CryptoBox.keypairFromSeed(seed);
    _privateKey = keypair.secretKey;
    _publicKey = keypair.publicKey;
  }

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      final jsonBytes = TextUtils.encodeUtf8(jsonEncode(item));
      final encrypted = CryptoBox.encrypt(jsonBytes, _publicKey, _privateKey);
      results.add(encrypted);
    }
    return results;
  }

  @override
  Future<List<dynamic?>> decrypt(List<Uint8List> data) async {
    final results = <dynamic?>[];
    for (final item in data) {
      final decrypted = CryptoBox.decrypt(item, _privateKey);
      if (decrypted == null) {
        results.add(null);
        continue;
      }
      try {
        final jsonString = TextUtils.decodeUtf8(decrypted);
        results.add(jsonDecode(jsonString));
      } catch (e) {
        results.add(null);
      }
    }
    return results;
  }
}

/// AES-256-GCM encryption
class AES256Encryption implements Encryptor, Decryptor {
  final Uint8List _secretKey;
  late final String _secretKeyB64;

  AES256Encryption(this._secretKey) {
    _secretKeyB64 = Base64Utils.encode(_secretKey);
  }

  @override
  Future<List<Uint8List>> encrypt(List<dynamic> data) async {
    final results = <Uint8List>[];
    for (final item in data) {
      // Use secret box as implementation (production should use proper AES-GCM)
      final encrypted = CryptoSecretBox.encrypt(item, _secretKey);
      // Add version byte prefix
      final output = Uint8List(encrypted.length + 1);
      output[0] = 0;
      output.setAll(1, encrypted);
      results.add(output);
    }
    return results;
  }

  @override
  Future<List<dynamic?>> decrypt(List<Uint8List> data) async {
    final results = <dynamic?>[];
    for (final item in data) {
      try {
        if (item[0] != 0) {
          results.add(null);
          continue;
        }
        final decrypted = CryptoSecretBox.decrypt(item.sublist(1), _secretKey);
        results.add(decrypted);
      } catch (e) {
        results.add(null);
      }
    }
    return results;
  }
}
