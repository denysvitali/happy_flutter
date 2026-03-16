// Architecture guard: crypto files must never use Isolate.run() or
// import dart:isolate.  Platform-channel-backed crypto libraries (NaCl /
// AES-256-GCM) cannot cross isolate boundaries on Android — doing so
// causes silent failures (empty decryption, "No machines found").
//
// See: git commit 6fbe95e — "fix: remove Isolate.run() for crypto
// decryption — crashes on Android"

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architecture guard: no Isolate.run() in crypto/sync files', () {
    // Files that are explicitly allowed to use dart:isolate (e.g. for
    // error-handler wiring via RawReceivePort, not for crypto work).
    const _allowedIsolateFiles = <String>{
      'remote_logger.dart',
    };

    /// Returns every non-comment, non-blank line from [file].
    ///
    /// Single-line (`//`) comments are stripped.  Block comments (`/* */`)
    /// are not common in this codebase so a line-level check is sufficient.
    List<String> _codeLines(File file) {
      final lines = file.readAsLinesSync();
      return [
        for (final line in lines)
          if (!line.trimLeft().startsWith('//')) line,
      ];
    }

    /// Collects all `.dart` files to audit.
    List<File> _filesToAudit() {
      final files = <File>[];

      // All files under lib/core/encryption/
      final encryptionDir = Directory(
        'lib/core/encryption',
      );
      if (encryptionDir.existsSync()) {
        for (final entity in encryptionDir.listSync()) {
          if (entity is File && entity.path.endsWith('.dart')) {
            final name = entity.uri.pathSegments.last;
            if (!_allowedIsolateFiles.contains(name)) {
              files.add(entity);
            }
          }
        }
      }

      // lib/core/services/sync_service.dart
      final syncService = File('lib/core/services/sync_service.dart');
      if (syncService.existsSync()) {
        files.add(syncService);
      }

      return files;
    }

    test(
      "no file imports 'dart:isolate'",
      () {
        final violations = <String>[];

        for (final file in _filesToAudit()) {
          final codeLines = _codeLines(file);
          for (var i = 0; i < codeLines.length; i++) {
            if (codeLines[i].contains("import 'dart:isolate'") ||
                codeLines[i].contains('import "dart:isolate"')) {
              violations.add('${file.path}:${i + 1}: ${codeLines[i].trim()}');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Crypto and sync files must not import dart:isolate.\n'
              'Platform-channel-backed crypto (NaCl / AES-256-GCM) cannot\n'
              'cross isolate boundaries on Android — use the main isolate.\n'
              'Violations found:\n${violations.join('\n')}',
        );
      },
    );

    test(
      'no file calls Isolate.run()',
      () {
        final violations = <String>[];

        for (final file in _filesToAudit()) {
          final codeLines = _codeLines(file);
          for (var i = 0; i < codeLines.length; i++) {
            if (codeLines[i].contains('Isolate.run(')) {
              violations.add('${file.path}:${i + 1}: ${codeLines[i].trim()}');
            }
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Crypto and sync files must not call Isolate.run().\n'
              'Platform-channel-backed crypto (NaCl / AES-256-GCM) cannot\n'
              'cross isolate boundaries on Android — silent failures result.\n'
              'See commit 6fbe95e for context.\n'
              'Violations found:\n${violations.join('\n')}',
        );
      },
    );

    test(
      'audit covers expected source files',
      () {
        final files = _filesToAudit();
        final paths = files.map((f) => f.path).toList();

        // The two historically vulnerable files must always be present.
        expect(
          paths,
          contains('lib/core/encryption/session_encryption.dart'),
          reason: 'session_encryption.dart must be in the audit list',
        );
        expect(
          paths,
          contains('lib/core/services/sync_service.dart'),
          reason: 'sync_service.dart must be in the audit list',
        );

        // Sanity-check: at least several encryption files are scanned.
        final encryptionFiles = paths
            .where((p) => p.startsWith('lib/core/encryption/'))
            .toList();
        expect(
          encryptionFiles.length,
          greaterThanOrEqualTo(5),
          reason:
              'Expected at least 5 encryption files to be audited; '
              'got ${encryptionFiles.length}',
        );
      },
    );
  });
}
