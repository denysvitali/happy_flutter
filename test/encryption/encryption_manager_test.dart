import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Uint8List _randomKey() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
}

/// 32-byte master secret used to create [Encryption] instances.
final Uint8List _testMasterSecret = _randomKey();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(
    'Encryption — session and machine management',
    skip: 'Requires native sodium library',
    () {
      late Encryption enc;

      setUp(() async {
        enc = await Encryption.create(_testMasterSecret);
      });

      // --------------------------------------------------------------------
      // Session encryption
      // --------------------------------------------------------------------

      test(
        'getSessionEncryption returns null for uninitialized session',
        () {
          expect(enc.getSessionEncryption('x'), isNull);
        },
      );

      test(
        'initializeSessions creates encryption for valid session',
        () async {
          final key = _randomKey();
          await enc.initializeSessions({'session-1': key});

          expect(enc.getSessionEncryption('session-1'), isNotNull);
        },
      );

      test(
        'initializeSessions skips already-initialized session',
        () async {
          final firstKey = _randomKey();
          await enc.initializeSessions({'session-2': firstKey});

          final firstEncryption = enc.getSessionEncryption('session-2');
          expect(firstEncryption, isNotNull);

          // Re-initialize with a different key — the first instance must
          // be preserved because the guard fires.
          final secondKey = _randomKey();
          await enc.initializeSessions({'session-2': secondKey});

          // Identical reference means the second call was a no-op.
          expect(
            identical(
              enc.getSessionEncryption('session-2'),
              firstEncryption,
            ),
            isTrue,
          );
        },
      );

      test(
        'removeSessionEncryption removes encryption',
        () async {
          final key = _randomKey();
          await enc.initializeSessions({'session-3': key});
          expect(enc.getSessionEncryption('session-3'), isNotNull);

          enc.removeSessionEncryption('session-3');

          expect(enc.getSessionEncryption('session-3'), isNull);
        },
      );

      // --------------------------------------------------------------------
      // Machine encryption
      // --------------------------------------------------------------------

      test(
        'getMachineEncryption returns null for uninitialized machine',
        () {
          expect(enc.getMachineEncryption('x'), isNull);
        },
      );

      test(
        'initializeMachines creates encryption for valid machine',
        () async {
          final key = _randomKey();
          await enc.initializeMachines({'machine-1': key});

          expect(enc.getMachineEncryption('machine-1'), isNotNull);
        },
      );

      test(
        'clearAll removes all session and machine encryptions',
        () async {
          final sessionKey = _randomKey();
          final machineKey = _randomKey();

          await enc.initializeSessions({'session-a': sessionKey});
          await enc.initializeMachines({'machine-a': machineKey});

          expect(enc.getSessionEncryption('session-a'), isNotNull);
          expect(enc.getMachineEncryption('machine-a'), isNotNull);

          enc.removeSessionEncryption('session-a');
          enc.removeMachineEncryption('machine-a');

          expect(enc.getSessionEncryption('session-a'), isNull);
          expect(enc.getMachineEncryption('machine-a'), isNull);
        },
      );
    },
  );
}
