import 'dart:typed_data';
import 'dart:math';
import 'package:pinenacl/api.dart' as nacl;
import 'package:pinenacl/src/authenticated_encryption/public.dart' as enc;

/// Constants for NaCl box encryption
class CryptoBoxConstants {
  static const int publicKeyBytes = 32;
  static const int secretKeyBytes = 32;
  static const int nonceBytes = 24;
  static const int macBytes = 16;
  static const int seedBytes = 32;
}

/// NaCl-style box encryption (public key encryption)
class CryptoBox {
  /// Generate a random nonce
  static Uint8List randomNonce() {
    final random = Random.secure();
    final nonce = Uint8List(CryptoBoxConstants.nonceBytes);
    for (int i = 0; i < CryptoBoxConstants.nonceBytes; i++) {
      nonce[i] = random.nextInt(256);
    }
    return nonce;
  }

  /// Generate keypair from seed
  static KeyPair keypairFromSeed(Uint8List seed) {
    final privateKey = nacl.PrivateKey.fromSeed(seed);
    final publicKey = privateKey.publicKey;
    return KeyPair(
      publicKey.asTypedList,
      privateKey.asTypedList,
    );
  }

  /// Generate new random keypair
  static KeyPair generateKeypair() {
    final privateKey = nacl.PrivateKey.generate();
    final publicKey = privateKey.publicKey;
    return KeyPair(
      publicKey.asTypedList,
      privateKey.asTypedList,
    );
  }

  /// Encrypt data using public key
  static Uint8List encrypt(
    Uint8List data,
    Uint8List recipientPublicKey,
    Uint8List senderSecretKey,
  ) {
    final ephemeralKeyPair = generateKeypair();
    final nonce = randomNonce();

    final recipientKey = nacl.PublicKey(recipientPublicKey);
    final senderKey = nacl.PrivateKey(senderSecretKey);

    // Create box for encryption
    final box = enc.Box(
      myPrivateKey: senderKey,
      theirPublicKey: recipientKey,
    );

    final encrypted = box.encrypt(data, nonce: nonce);

    // Bundle format: ephemeral public key + nonce + encrypted data
    final encryptedList = encrypted.asTypedList;
    final result = Uint8List(
      CryptoBoxConstants.publicKeyBytes +
      CryptoBoxConstants.nonceBytes +
      encryptedList.length,
    );
    result.setAll(0, ephemeralKeyPair.publicKey);
    result.setAll(CryptoBoxConstants.publicKeyBytes, nonce);
    result.setAll(
      CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes,
      encryptedList,
    );

    return result;
  }

  /// Decrypt encrypted bundle
  static Uint8List? decrypt(
    Uint8List encryptedBundle,
    Uint8List recipientSecretKey,
  ) {
    try {
      // Extract components: ephemeral public key + nonce + encrypted data
      final ephemeralPublicKey = encryptedBundle.sublist(
        0,
        CryptoBoxConstants.publicKeyBytes,
      );
      final nonce = encryptedBundle.sublist(
        CryptoBoxConstants.publicKeyBytes,
        CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes,
      );
      final encrypted = encryptedBundle.sublist(
        CryptoBoxConstants.publicKeyBytes + CryptoBoxConstants.nonceBytes,
      );

      final ephemeralKey = nacl.PublicKey(ephemeralPublicKey);
      final recipientKey = nacl.PrivateKey(recipientSecretKey);

      // Create box for decryption
      final box = enc.Box(
        myPrivateKey: recipientKey,
        theirPublicKey: ephemeralKey,
      );

      return box.decrypt(nacl.ByteList(encrypted), nonce: nonce);
    } catch (e) {
      return null;
    }
  }
}

/// KeyPair for box encryption
class KeyPair {
  final Uint8List publicKey;
  final Uint8List secretKey;

  KeyPair(this.publicKey, this.secretKey);
}
