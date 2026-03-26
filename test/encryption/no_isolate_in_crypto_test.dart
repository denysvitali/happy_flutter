// Architecture guard: NaCl / libsodium crypto (CryptoSecretBox, CryptoBox)
// must never be called inside Isolate.run(). The sodium FFI library uses
// SecureKey objects backed by native memory that cannot cross isolate
// boundaries — doing so causes silent decryption failures.
//
// AES-256-GCM (package:cryptography → DartAesGcm) is pure Dart with no
// platform channels or FFI, so it IS safe in background isolates.
//
// See: git commit 6fbe95e — original discovery of the NaCl isolate bug.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architecture guard: NaCl crypto must not run in isolates', () {
    /// Returns every non-comment, non-blank line from [file].
    List<String> _codeLines(File file) {
      final lines = file.readAsLinesSync();
      return [
        for (final line in lines)
          if (!line.trimLeft().startsWith('//')) line,
      ];
    }

    /// Collects all `.dart` files under lib/core/encryption/ and
    /// lib/core/services/sync_service.dart.
    List<File> _filesToAudit() {
      final files = <File>[];

      final encryptionDir = Directory('lib/core/encryption');
      if (encryptionDir.existsSync()) {
        for (final entity in encryptionDir.listSync()) {
          if (entity is File && entity.path.endsWith('.dart')) {
            files.add(entity);
          }
        }
      }

      final syncService = File(
        'lib/core/services/sync_service.dart',
      );
      if (syncService.existsSync()) {
        files.add(syncService);
      }

      return files;
    }

    test(
      'CryptoSecretBox/CryptoBox are not imported alongside '
      'dart:isolate in the same file',
      () {
        // Files that use dart:isolate must not also import NaCl
        // primitives (CryptoSecretBox, CryptoBox) — those use FFI
        // with non-sendable SecureKey objects.
        //
        // These files import both but keep NaCl on the main thread:
        // - encryptor.dart: AES256Encryption.decryptInIsolate
        //   sends only pure-Dart AES data; SecretBoxEncryption
        //   (NaCl) never touches isolates.
        // - sync_service.dart: isAes/else branch ensures NaCl
        //   items stay on the main thread.
        const allowedMixedFiles = <String>{
          'encryptor.dart',
          'sync_service.dart',
        };

        final violations = <String>[];

        for (final file in _filesToAudit()) {
          final name = file.uri.pathSegments.last;
          if (allowedMixedFiles.contains(name)) continue;

          final codeLines = _codeLines(file);
          final hasIsolateImport = codeLines.any(
            (l) =>
                l.contains("import 'dart:isolate'") ||
                l.contains('import "dart:isolate"'),
          );
          if (!hasIsolateImport) continue;

          final hasNaCl = codeLines.any(
            (l) =>
                l.contains('CryptoSecretBox') ||
                l.contains('CryptoBox') ||
                l.contains('sodiumSingleton'),
          );
          if (hasNaCl) {
            violations.add(
              '${file.path}: imports dart:isolate AND NaCl '
              'primitives',
            );
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Files that import dart:isolate must not also use '
              'NaCl/libsodium primitives (CryptoSecretBox, '
              'CryptoBox, sodiumSingleton).\n'
              'NaCl FFI objects (SecureKey) cannot cross isolate '
              'boundaries.\n'
              'AES-256-GCM (pure Dart) IS isolate-safe.\n'
              'Violations:\n${violations.join('\n')}',
        );
      },
    );

    test(
      'session_encryption.dart does not import dart:isolate '
      'directly',
      () {
        // session_encryption.dart delegates to
        // AES256Encryption.decryptInIsolate() rather than calling
        // Isolate.run() directly, keeping the isolate boundary
        // management in one place.
        final file = File(
          'lib/core/encryption/session_encryption.dart',
        );
        if (!file.existsSync()) return;
        final codeLines = _codeLines(file);
        final hasIsolateImport = codeLines.any(
          (l) =>
              l.contains("import 'dart:isolate'") ||
              l.contains('import "dart:isolate"'),
        );
        expect(
          hasIsolateImport,
          isFalse,
          reason:
              'session_encryption.dart should delegate isolate '
              'work to AES256Encryption.decryptInIsolate(), not '
              'import dart:isolate directly.',
        );
      },
    );

    test(
      'audit covers expected source files',
      () {
        final files = _filesToAudit();
        final paths = files.map((f) => f.path).toList();

        expect(
          paths,
          contains('lib/core/encryption/session_encryption.dart'),
          reason:
              'session_encryption.dart must be in the audit list',
        );
        expect(
          paths,
          contains('lib/core/services/sync_service.dart'),
          reason: 'sync_service.dart must be in the audit list',
        );

        final encryptionFiles = paths
            .where(
              (p) => p.startsWith('lib/core/encryption/'),
            )
            .toList();
        expect(
          encryptionFiles.length,
          greaterThanOrEqualTo(5),
          reason:
              'Expected at least 5 encryption files to be '
              'audited; got ${encryptionFiles.length}',
        );
      },
    );
  });
}
