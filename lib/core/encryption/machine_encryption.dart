import '../services/logger_service.dart' show logger;

import 'base64.dart';
import 'encryption_cache.dart';
import 'encryptor.dart';

/// Machine-specific encryption management
class MachineEncryption {

  MachineEncryption({
    required String machineId,
    required Encryptor encryptor,
    required Decryptor decryptor,
    required EncryptionCache cache,
  })  : _machineId = machineId,
        _encryptor = encryptor,
        _decryptor = decryptor,
        _cache = cache;
  final String _machineId;
  final Encryptor _encryptor;
  final Decryptor _decryptor;
  final EncryptionCache _cache;

  /// Encrypt machine metadata
  Future<String> encryptMetadata(Map<String, dynamic> metadata) async {
    final encrypted = await _encryptor.encrypt([metadata]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt machine metadata with caching
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async {
    // Check cache first
    final cached = _cache.getCachedMachineMetadata(_machineId, version);
    if (cached != null) {
      return cached;
    }

    // Decrypt
    try {
      final encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
      final decrypted = await _decryptor.decrypt([encryptedData]);
      if (decrypted[0] == null) {
        return null;
      }

      final data = decrypted[0] as Map<String, dynamic>;
      _cache.setCachedMachineMetadata(_machineId, version, data);
      return data;
    } catch (e) {
      logger.warning('MachineEncryption.decryptMetadata failed', e);
      return null;
    }
  }

  /// Encrypt daemon state
  Future<String> encryptDaemonState(dynamic state) async {
    final encrypted = await _encryptor.encrypt([state]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt daemon state with caching
  Future<dynamic> decryptDaemonState(
    int version,
    String? encrypted,
  ) async {
    if (encrypted == null || encrypted.isEmpty) {
      return null;
    }

    // Check cache first
    final cached = _cache.getCachedDaemonState(_machineId, version);
    if (cached != null) {
      return cached;
    }

    // Decrypt
    try {
      final encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
      final decrypted = await _decryptor.decrypt([encryptedData]);
      final result = decrypted[0];

      // Cache result (including null)
      _cache.setCachedDaemonState(_machineId, version, result);
      return result;
    } catch (e) {
      logger.warning('MachineEncryption.decryptDaemonState failed', e);
      // Cache null to avoid repeated decryption attempts
      _cache.setCachedDaemonState(_machineId, version, null);
      return null;
    }
  }

  /// Encrypt raw data
  Future<String> encryptRaw(dynamic data) async {
    final encrypted = await _encryptor.encrypt([data]);
    return Base64Utils.encode(encrypted[0], Encoding.base64);
  }

  /// Decrypt raw data
  Future<dynamic> decryptRaw(String encrypted) async {
    try {
      final encryptedData = Base64Utils.decode(encrypted, Encoding.base64);
      final decrypted = await _decryptor.decrypt([encryptedData]);
      return decrypted[0];
    } catch (e) {
      logger.warning('MachineEncryption.decryptRaw failed', e);
      return null;
    }
  }
}
