import 'dart:async' show unawaited;
import 'dart:math';
import 'dart:typed_data';

import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/logger_service.dart' show logger;
import 'base64.dart';
import 'encryptor.dart';

/// Artifact-specific encryption management
class ArtifactEncryption {

  ArtifactEncryption(Uint8List dataEncryptionKey)
      : _encryptor = AES256Encryption(dataEncryptionKey);
  final AES256Encryption _encryptor;

  /// Generate a new data encryption key for an artifact
  static Uint8List generateDataEncryptionKey() {
    final random = Random.secure();
    final key = Uint8List(32); // 256 bits for AES-256
    for (var i = 0; i < 32; i++) {
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
      final encryptedData = Base64Utils.decode(
        encryptedHeader,
        Encoding.base64,
      );
      final decrypted = await _encryptor.decrypt([encryptedData]);
      if (decrypted[0] == null) {
        return null;
      }

      final header = decrypted[0];
      if (header is! Map<String, dynamic>) {
        return null;
      }

      return Map<String, dynamic>.from(header);
    } catch (e, stack) {
      // Recoverable: caller treats null as "decryption unavailable". Surface
      // as a warning + tagged Sentry capture so the rate is visible without
      // contributing to the fatal/error budget.
      logger.warning('ArtifactEncryption.decryptHeader failed', e, stack);
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope
              ..level = SentryLevel.warning
              ..setTag('decrypt_surface', 'artifact_header')
              ..setTag('decrypt_reason', e.runtimeType.toString());
          },
        ),
      );
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

      final body = decrypted[0];
      if (body is! Map<String, dynamic>) {
        return null;
      }

      return {
        'body': body['body'] as String?,
      };
    } catch (e, stack) {
      // Recoverable: caller treats null as "decryption unavailable". See
      // decryptHeader for the rationale on warning vs error.
      logger.warning('ArtifactEncryption.decryptBody failed', e, stack);
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: stack,
          withScope: (scope) {
            scope
              ..level = SentryLevel.warning
              ..setTag('decrypt_surface', 'artifact_body')
              ..setTag('decrypt_reason', e.runtimeType.toString());
          },
        ),
      );
      return null;
    }
  }
}
