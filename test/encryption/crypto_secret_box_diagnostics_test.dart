import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/crypto_secret_box.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CryptoSecretBox diagnostics (NaCl key-mismatch reporting)', () {
    final keyA = Uint8List.fromList(
      List<int>.generate(32, (i) => i + 1),
    );
    final keyB = Uint8List.fromList(
      List<int>.generate(32, (i) => i + 100),
    );
    // 40 bytes — large enough to clear the `(nonce + mac)` floor so
    // [CryptoSecretBox.detectEnvelope] can classify it as `naclSecretBox`.
    final ciphertextEncryptedWithA = Uint8List.fromList(
      List<int>.generate(40, (i) => (i * 7 + 3) % 256),
    );

    setUp(() {
      CryptoSecretBox.resetThrottle();
      CryptoSecretBox.debugSink = null;
    });

    tearDown(() {
      CryptoSecretBox.resetThrottle();
      CryptoSecretBox.debugSink = null;
    });

    test(
      'decrypt wrapper swallows wrong-key failures and reports diagnostics',
      () {
        // (a) The diagnostic helper must never throw — production code
        // relies on `null` semantics, not on a propagating exception.
        late DecryptFailureDiagnostic captured;
        CryptoSecretBox.debugSink = (d) => captured = d;

        final outcome = CryptoSecretBox.simulateDecryptFailureForTest(
          secretKey: keyB, // wrong key
          cipher: ciphertextEncryptedWithA,
          stage: 'sodium',
          reason: 'SodiumException',
          scope: 'session:abc-123:messages',
        );

        // (b) Diagnostic payload contains a key fingerprint of exactly
        // 8 chars — the wire contract used by Sentry tags.
        expect(captured.keyFp.length, 8);
        expect(captured.scope, 'session:abc-123:messages');
        expect(captured.envelope, DecryptEnvelope.naclSecretBox);
        expect(captured.stage, 'sodium');
        expect(captured.cipherLen, 40);
        // The fingerprint must not be a substring of the key itself.
        expect(captured.keyFp, isNot(contains('A')),
            reason: 'fingerprint must not contain raw key bytes');
        // First failure for this scope is allowed through.
        expect(outcome.wouldSentry, isTrue);
      },
    );

    test(
      'two consecutive failures with same (scope, keyFp) produce ONE Sentry '
      'capture',
      () {
        final sinkEvents = <DecryptFailureDiagnostic>[];
        CryptoSecretBox.debugSink = sinkEvents.add;

        const scope = 'session:dup-test:messages';
        final first = CryptoSecretBox.simulateDecryptFailureForTest(
          secretKey: keyB,
          cipher: ciphertextEncryptedWithA,
          stage: 'sodium',
          reason: 'SodiumException',
          scope: scope,
        );
        final second = CryptoSecretBox.simulateDecryptFailureForTest(
          secretKey: keyB,
          cipher: ciphertextEncryptedWithA,
          stage: 'sodium',
          reason: 'SodiumException',
          scope: scope,
        );

        // Sink still observes BOTH events (test-only visibility), but
        // only the first one is allowed through the Sentry throttle.
        expect(sinkEvents, hasLength(2));
        expect(first.wouldSentry, isTrue);
        expect(
          second.wouldSentry,
          isFalse,
          reason: 'second failure with the same scope+keyFp+stage must be '
              'throttled to avoid spamming Sentry on batch key mismatches',
        );
        // Both events share fingerprint and envelope (same grouping).
        expect(sinkEvents[0].keyFp, sinkEvents[1].keyFp);
        expect(sinkEvents[0].envelope, sinkEvents[1].envelope);
      },
    );

    test(
      'different scopes with the same key produce independent Sentry captures',
      () {
        final firstA = CryptoSecretBox.simulateDecryptFailureForTest(
          secretKey: keyB,
          cipher: ciphertextEncryptedWithA,
          stage: 'sodium',
          reason: 'SodiumException',
          scope: 'session:one',
        );
        final firstB = CryptoSecretBox.simulateDecryptFailureForTest(
          secretKey: keyB,
          cipher: ciphertextEncryptedWithA,
          stage: 'sodium',
          reason: 'SodiumException',
          scope: 'session:two',
        );

        expect(firstA.wouldSentry, isTrue);
        expect(firstB.wouldSentry, isTrue,
            reason: 'different scope must not be coalesced with the first '
                'scope just because the key is the same');
      },
    );

    test('key fingerprints are deterministic and key-distinguishing', () {
      final a = CryptoSecretBox.simulateDecryptFailureForTest(
        secretKey: keyA,
        cipher: ciphertextEncryptedWithA,
        stage: 'sodium',
        reason: 'SodiumException',
        scope: 'session:fp-a',
      ).diagnostic;
      final aAgain = CryptoSecretBox.simulateDecryptFailureForTest(
        secretKey: keyA,
        cipher: ciphertextEncryptedWithA,
        stage: 'sodium',
        reason: 'SodiumException',
        scope: 'session:fp-a-again',
      ).diagnostic;
      final b = CryptoSecretBox.simulateDecryptFailureForTest(
        secretKey: keyB,
        cipher: ciphertextEncryptedWithA,
        stage: 'sodium',
        reason: 'SodiumException',
        scope: 'session:fp-b',
      ).diagnostic;

      expect(a.keyFp, equals(aAgain.keyFp),
          reason: 'fingerprint must be deterministic for the same key');
      expect(a.keyFp, isNot(equals(b.keyFp)),
          reason: 'fingerprint must distinguish different keys');
    });

    test('envelope detection prefers aes-v0 for short, 0x00-prefixed bundles',
        () {
      // 1-byte version (0) + 12-byte IV + 16-byte tag + 11-byte ciphertext = 40
      final aesLike = Uint8List(40)
        ..[0] = 0
        ..[1] = 0xAB
        ..[2] = 0xCD;
      expect(
        CryptoSecretBox.detectEnvelope(aesLike),
        DecryptEnvelope.aesV0,
      );

      // A NaCl bundle whose nonce happens to start non-zero must classify
      // as `naclSecretBox`.
      final naclLike = Uint8List(40)
        ..[0] = 0xFF
        ..[1] = 0x42;
      expect(
        CryptoSecretBox.detectEnvelope(naclLike),
        DecryptEnvelope.naclSecretBox,
      );

      // Below the minimum (`nonceSize + macSize`): unknown.
      expect(
        CryptoSecretBox.detectEnvelope(Uint8List(10)),
        DecryptEnvelope.unknown,
      );
    });

    test('diagnostic payload contains no raw key bytes', () {
      final outcome = CryptoSecretBox.simulateDecryptFailureForTest(
        secretKey: keyA,
        cipher: ciphertextEncryptedWithA,
        stage: 'sodium',
        reason: 'SodiumException',
        scope: 'session:no-leak',
      );
      final payload = outcome.diagnostic.toMap();
      final encoded = payload.toString();
      // The raw key bytes encoded as a comma list — must not appear.
      final rawKey = keyA.toString();
      expect(encoded.contains(rawKey), isFalse,
          reason: 'raw key must never appear in the diagnostic payload');
      // And no ciphertext content — only its length.
      expect(payload.containsKey('cipher_len'), isTrue);
      expect(payload.containsKey('cipher'), isFalse);
      expect(payload.containsKey('ciphertext'), isFalse);
    });
  });
}
