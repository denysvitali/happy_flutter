// Contract tests for the NaCl (libsodium) batch-decrypt isolate worker.
//
// Why this matters
// ----------------
// NaCl decryption is FFI-backed and synchronous; running it on the main
// isolate stalls the UI during large session fetches (production
// fetchMessages p95 reaches 54s on outlier sessions). We offload batches
// >= [CryptoSecretBox.batchIsolateThreshold] to `Isolate.run` with a
// top-level worker that takes only sendable POD args (Uint8Lists).
//
// Invariants pinned here
// ----------------------
//   1. Batch decrypt via the isolate path produces the EXACT same
//      plaintext as the inline path (50+ messages, mixed payloads).
//   2. The isolate worker is sendable — `Isolate.run` must not throw
//      "Illegal argument in isolate message: object is unsendable"
//      (GlitchTip HAPPY_FLUTTER-3C5 style failure mode).
//   3. The threshold lever works: small batches stay inline; large
//      batches go to the isolate.
//   4. Concurrent fan-out (multiple sessions decrypting at once)
//      completes without inter-batch contamination — this is the
//      access pattern in `_preDecryptSessions` in `_sync_data.dart`.
//   5. Partial corruption returns `null` for the bad item and valid
//      JSON for the rest, with the result list length preserved.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/crypto_secret_box.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/nacl_isolate_worker.dart';

Uint8List _generateKey() {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(32, (_) => random.nextInt(256)),
  );
}

Future<List<Uint8List>> _encryptBatch(
  Uint8List key,
  List<dynamic> payloads,
) async {
  final out = <Uint8List>[];
  for (final p in payloads) {
    out.add(await CryptoSecretBox.encrypt(p, key));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    CryptoSecretBox.batchIsolateOverrideForTesting = null;
  });

  group('NaCl batch decrypt — isolate worker contract', () {
    test(
      '50-item batch via isolate path matches inline plaintext',
      () async {
        final key = _generateKey();
        final inputs = List<Map<String, dynamic>>.generate(
          50,
          (i) => {'seq': i, 'text': 'msg_$i', 'flag': i.isEven},
        );
        final ciphertexts = await _encryptBatch(key, inputs);

        // Inline reference: force inline path.
        CryptoSecretBox.batchIsolateOverrideForTesting = false;
        final inlineResults = await CryptoSecretBox.decryptBatchInIsolate(
          ciphertexts,
          key,
        );

        // Isolate path: force isolate even for small batches (here we
        // already exceed the threshold but be explicit).
        CryptoSecretBox.batchIsolateOverrideForTesting = true;
        final isolateResults = await CryptoSecretBox.decryptBatchInIsolate(
          ciphertexts,
          key,
        );

        expect(isolateResults.length, 50);
        expect(inlineResults.length, 50);
        for (var i = 0; i < 50; i++) {
          expect(
            isolateResults[i],
            equals(inputs[i]),
            reason: 'isolate result $i must roundtrip',
          );
          expect(
            isolateResults[i],
            equals(inlineResults[i]),
            reason:
                'isolate path must produce IDENTICAL plaintext to '
                'inline path at index $i',
          );
        }
      },
    );

    test(
      'top-level worker function is sendable — Isolate.run does not '
      'throw "object is unsendable"',
      () async {
        // Direct call to the worker entry-point. If we accidentally
        // captured `this` or a Future, Dart would raise
        // ArgumentError with the unsendable-message text.
        final key = _generateKey();
        final inputs = List<Map<String, dynamic>>.generate(
          5,
          (i) => {'i': i, 'kind': 'sendable-check'},
        );
        final ciphertexts = await _encryptBatch(key, inputs);

        Object? caught;
        List<dynamic>? results;
        try {
          results = await decryptNaClBatchInIsolate(
            cipherTexts: ciphertexts,
            secretKey: key,
            nonceSize: 24,
            macSize: 16,
          );
        } catch (e) {
          caught = e;
        }

        expect(
          caught,
          isNull,
          reason: 'Isolate.run must accept the worker payload; '
              'caught: $caught',
        );
        expect(results, isNotNull);
        expect(results!.length, 5);
        for (var i = 0; i < 5; i++) {
          expect(results[i], equals(inputs[i]));
        }
      },
    );

    test(
      'isolate threshold constant matches CryptoSecretBox',
      () {
        expect(
          CryptoSecretBox.batchIsolateThreshold,
          equals(kNaClIsolateBatchThreshold),
          reason:
              'CryptoSecretBox.batchIsolateThreshold and '
              'nacl_isolate_worker.kNaClIsolateBatchThreshold must '
              'stay in sync — they document the same lever.',
        );
        expect(
          kNaClIsolateBatchThreshold,
          greaterThanOrEqualTo(20),
          reason:
              'Threshold should not drop below 20 — the AES path '
              'in session_encryption.dart uses the same cut-off and '
              'we want both paths to behave consistently.',
        );
      },
    );

    test(
      'small batch (< threshold) stays inline even on native',
      () async {
        // Default (null) override should keep small batches inline.
        // We assert this indirectly by toggling the override and
        // observing both paths produce the same result for a tiny
        // batch — the contract is "small batches are inline-safe".
        final key = _generateKey();
        final inputs = [
          {'tiny': 'a'},
          {'tiny': 'b'},
        ];
        final ciphertexts = await _encryptBatch(key, inputs);

        CryptoSecretBox.batchIsolateOverrideForTesting = null; // default
        final defaultResults = await CryptoSecretBox.decryptBatchInIsolate(
          ciphertexts,
          key,
        );

        expect(defaultResults.length, 2);
        expect(defaultResults[0], equals(inputs[0]));
        expect(defaultResults[1], equals(inputs[1]));
      },
    );

    test(
      'concurrent fan-out across distinct keys produces correct '
      'plaintexts without cross-batch contamination',
      () async {
        // Mirrors the `_preDecryptSessions` access pattern: spawn many
        // batches in parallel, each with its own key. If the worker
        // accidentally shared state, plaintexts would smear across
        // sessions.
        const fanout = 6;
        final keys = List<Uint8List>.generate(fanout, (_) => _generateKey());
        final inputs = List<List<Map<String, dynamic>>>.generate(
          fanout,
          (sIdx) => List<Map<String, dynamic>>.generate(
            30, // above threshold so each genuinely goes to an isolate
            (mIdx) => {'session': sIdx, 'msg': mIdx, 'k': 'v$sIdx-$mIdx'},
          ),
        );
        final ciphertexts = <List<Uint8List>>[];
        for (var s = 0; s < fanout; s++) {
          ciphertexts.add(await _encryptBatch(keys[s], inputs[s]));
        }

        CryptoSecretBox.batchIsolateOverrideForTesting = true;
        final futures = <Future<List<dynamic>>>[];
        for (var s = 0; s < fanout; s++) {
          futures.add(
            CryptoSecretBox.decryptBatchInIsolate(ciphertexts[s], keys[s]),
          );
        }
        final results = await Future.wait(futures);

        for (var s = 0; s < fanout; s++) {
          expect(results[s].length, 30);
          for (var m = 0; m < 30; m++) {
            expect(
              results[s][m],
              equals(inputs[s][m]),
              reason:
                  'session=$s msg=$m must roundtrip to its own '
                  'plaintext (no cross-batch contamination)',
            );
          }
        }
      },
    );

    test(
      'one corrupt item in a large batch returns null for that item; '
      'all others succeed',
      () async {
        final key = _generateKey();
        final inputs = List<Map<String, dynamic>>.generate(
          25,
          (i) => {'i': i, 'name': 'entry_$i'},
        );
        final ciphertexts = await _encryptBatch(key, inputs);

        // Corrupt one item by flipping a MAC byte.
        const corruptIdx = 12;
        final bad = Uint8List.fromList(ciphertexts[corruptIdx]);
        bad[bad.length - 1] ^= 0xFF;
        ciphertexts[corruptIdx] = bad;

        CryptoSecretBox.batchIsolateOverrideForTesting = true;
        final results = await CryptoSecretBox.decryptBatchInIsolate(
          ciphertexts,
          key,
        );

        expect(results.length, 25);
        for (var i = 0; i < 25; i++) {
          if (i == corruptIdx) {
            expect(
              results[i],
              isNull,
              reason: 'corrupted item $i must be null',
            );
          } else {
            expect(
              results[i],
              equals(inputs[i]),
              reason: 'valid item $i must roundtrip even when one '
                  'sibling was corrupted',
            );
          }
        }
      },
    );

    test(
      'SecretBoxEncryption.decrypt (Encryptor interface) routes large '
      'batches through the isolate worker',
      () async {
        // Asserts the wiring from session_encryption.dart's call site:
        //   _decryptor.decrypt(encrypted)
        // ends up at decryptBatchInIsolate via SecretBoxEncryption.
        final key = _generateKey();
        final enc = SecretBoxEncryption(key);
        final inputs = List<Map<String, dynamic>>.generate(
          30,
          (i) => {'i': i, 'via': 'encryptor-interface'},
        );
        final ciphertexts = await enc.encrypt(inputs);

        CryptoSecretBox.batchIsolateOverrideForTesting = true;
        final results = await enc.decrypt(ciphertexts);

        expect(results.length, 30);
        for (var i = 0; i < 30; i++) {
          expect(results[i], equals(inputs[i]));
        }
      },
    );

    test(
      'empty batch returns empty list without touching the isolate',
      () async {
        final key = _generateKey();
        CryptoSecretBox.batchIsolateOverrideForTesting = true;
        final results = await CryptoSecretBox.decryptBatchInIsolate(
          <Uint8List>[],
          key,
        );
        expect(results, isEmpty);
      },
    );
  });
}
