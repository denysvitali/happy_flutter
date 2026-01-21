import 'dart:typed_data';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'derive_key.dart';
import 'encryptor.dart';
import 'encryption_cache.dart';
import 'session_encryption.dart';
import 'machine_encryption.dart';
import 'base64.dart';
import 'hex.dart';
import 'crypto_box.dart';

/// Main encryption manager
class Encryption {
  static final Uuid _uuid = const Uuid();

  /// Create encryption instance from master secret
  static Future<Encryption> create(Uint8List masterSecret) async {
    // Derive content data key
    final contentDataKey = await DeriveKey.derive(
      masterSecret,
      'Happy EnCoder',
      ['content'],
    );

    // Derive content data key keypair
    final contentKeyPair = CryptoBox.keypairFromSeed(contentDataKey);

    // Derive anonymous ID
    final anonIdBytes = await DeriveKey.derive(
      masterSecret,
      'Happy Coder',
      ['analytics', 'id'],
    );
    final anonId = HexUtils.encode(anonIdBytes.sublist(0, 16)).toLowerCase();

    return Encryption._(
      anonId: anonId,
      masterSecret: masterSecret,
      contentKeyPair: contentKeyPair,
    );
  }

  final SecretBoxEncryption _legacyEncryption;
  final KeyPair _contentKeyPair;
  final EncryptionCache _cache = EncryptionCache();

  final String anonId;
  final Uint8List contentDataKey;

  // Session and machine encryption management
  final Map<String, SessionEncryption> _sessionEncryptions = {};
  final Map<String, MachineEncryption> _machineEncryptions = {};

  Encryption._({
    required this.anonId,
    required Uint8List masterSecret,
    required KeyPair contentKeyPair,
  })  : _contentKeyPair = contentKeyPair,
        _legacyEncryption = SecretBoxEncryption(masterSecret),
        contentDataKey = contentKeyPair.publicKey;

  /// Core encryption opening
  Future<dynamic> openEncryption(Uint8List? dataEncryptionKey) async {
    if (dataEncryptionKey == null) {
      return _legacyEncryption;
    }
    return AES256Encryption(dataEncryptionKey);
  }

  /// Initialize sessions with their encryption keys
  Future<void> initializeSessions(
    Map<String, Uint8List?> sessions,
  ) async {
    for (final entry in sessions.entries) {
      final sessionId = entry.key;
      final dataKey = entry.value;

      // Skip if already initialized
      if (_sessionEncryptions.containsKey(sessionId)) {
        continue;
      }

      // Create appropriate encryptor
      final encryptorDecryptor = await openEncryption(dataKey);

      // Create and cache session encryption
      if (encryptorDecryptor is Encryptor && encryptorDecryptor is Decryptor) {
        final enc = encryptorDecryptor as Encryptor;
        final dec = encryptorDecryptor as Decryptor;
        final sessionEnc = SessionEncryption(
          sessionId: sessionId,
          encryptor: enc,
          decryptor: dec,
          cache: _cache,
        );
        _sessionEncryptions[sessionId] = sessionEnc;
      }
    }
  }

  /// Get session encryption if initialized
  SessionEncryption? getSessionEncryption(String sessionId) {
    return _sessionEncryptions[sessionId];
  }

  /// Remove session encryption when session is deleted
  void removeSessionEncryption(String sessionId) {
    _sessionEncryptions.remove(sessionId);
    _cache.clearSessionCache(sessionId);
  }

  /// Initialize machines with their encryption keys
  Future<void> initializeMachines(
    Map<String, Uint8List?> machines,
  ) async {
    for (final entry in machines.entries) {
      final machineId = entry.key;
      final dataKey = entry.value;

      // Skip if already initialized
      if (_machineEncryptions.containsKey(machineId)) {
        continue;
      }

      // Create appropriate encryptor
      final encryptorDecryptor = await openEncryption(dataKey);

      // Create and cache machine encryption
      if (encryptorDecryptor is Encryptor && encryptorDecryptor is Decryptor) {
        final enc = encryptorDecryptor as Encryptor;
        final dec = encryptorDecryptor as Decryptor;
        final machineEnc = MachineEncryption(
          machineId: machineId,
          encryptor: enc,
          decryptor: dec,
          cache: _cache,
        );
        _machineEncryptions[machineId] = machineEnc;
      }
    }
  }

  /// Get machine encryption if initialized
  MachineEncryption? getMachineEncryption(String machineId) {
    return _machineEncryptions[machineId];
  }

  /// Legacy methods for machine metadata (temporary)
  Future<String> encryptRaw(dynamic data) async {
    final encrypted = await _legacyEncryption.encrypt([data]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  Future<dynamic> decryptRaw(String encrypted) async {
    try {
      final encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
      final decrypted = await _legacyEncryption.decrypt([encryptedData]);
      return decrypted[0] ?? null;
    } catch (e) {
      return null;
    }
  }

  /// Decrypt encrypted data encryption key
  Future<Uint8List?> decryptEncryptionKey(String encrypted) async {
    final encryptedKey = Base64Utils.decode(encrypted, Encoding.base64);
    if (encryptedKey[0] != 0) {
      return null;
    }

    final decrypted = CryptoBox.decrypt(
      encryptedKey.sublist(1),
      _contentKeyPair.secretKey,
    );

    return decrypted;
  }

  /// Encrypt data encryption key
  Future<Uint8List> encryptEncryptionKey(Uint8List key) async {
    // Use public key for encryption (encrypt TO ourselves)
    final encrypted = CryptoBox.encrypt(key, _contentKeyPair.publicKey, _contentKeyPair.secretKey);
    final result = Uint8List(encrypted.length + 1);
    result[0] = 0; // Version byte
    result.setAll(1, encrypted);
    return result;
  }

  /// Generate unique ID
  String generateId() {
    return _uuid.v4();
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return _cache.getStats();
  }

  /// Clear all caches
  void clearAllCaches() {
    _cache.clearAll();
  }
}
