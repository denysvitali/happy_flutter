@Timeout(Duration(minutes: 10))
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';

import 'bench_runner.dart';
import 'fixtures.dart';

/// Message-pipeline stage costs over a production-shaped 500-row page.
///
/// Stages, cheapest composition first:
/// - `processDecryptedMessages` — pure normalization/grouping given
///   already-decrypted bodies (the post-isolate half of ingestion).
/// - `decryptAndProcessMessages` — full page cost with real AES-256-GCM
///   (batch decrypt + the same processing), fresh cache per iteration so
///   the decrypt cache cannot collapse iterations into no-ops.
/// - `AnsiParser.parse` — render-time ANSI parsing of tool output, which
///   tool views re-run on every build.
void main() {
  final reporter = BenchReporter(group: 'pipeline');

  tearDownAll(() => reporter.finish());

  test('process 500-row decrypted page (normalize + group)', () {
    final pairs = makeTranscriptPairs(500);
    final wires = pairs.map((p) => p.wire).toList();
    final plains = pairs.map((p) => p.plain).toList();

    var rows = -1;
    reporter.measureSync(
      'process_decrypted_page_500',
      () {
        final out = processDecryptedMessages(
          decryptedJsonList: plains,
          wireMessages: wires,
          sessionId: 'bench',
        );
        rows = out.messages.length + out.toolResults.length;
      },
      iterations: 10,
      warmup: 2,
      opsPerIteration: 500,
    );
    expect(rows, greaterThan(0),
        reason: 'processing must yield displayable rows');
  });

  test('full AES page: decrypt + process 500 encrypted rows', () async {
    final key = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      key[i] = (i * 11 + 1) & 0xff;
    }
    final rows = await makeAesTranscript(500, key);
    var produced = -1;

    Future<double> body() async {
      // Fresh cache per iteration: a warm decrypt cache would turn every
      // iteration after the first into a cache-hit no-op.
      final encryption = SessionEncryption(
        sessionId: 'bench',
        encryptor: AES256Encryption(key),
        decryptor: AES256Encryption(key),
        cache: EncryptionCache(),
      );
      final watch = Stopwatch()..start();
      final out = await encryption.decryptAndProcessMessages(rows, 'bench');
      watch.stop();
      produced = out.messages.length + out.toolResults.length;
      return watch.elapsedMicroseconds / 1000.0;
    }

    await reporter.measureTimed(
      'decrypt_and_process_aes_page_500',
      body,
      iterations: 8,
      warmup: 2,
      opsPerIteration: 500,
    );
    expect(produced, greaterThan(0));
  });

  test('ANSI parse of a 20KB tool output', () {
    final output = ansiToolOutput(20000);
    var spans = 0;
    reporter.measureSync(
      'ansi_parse_20kb',
      () {
        spans = AnsiParser.parse(output).length;
      },
      iterations: 40,
    );
    expect(spans, greaterThan(0));
  });

  test('ANSI strip of a 20KB tool output', () {
    final output = ansiToolOutput(20000);
    var len = 0;
    reporter.measureSync(
      'ansi_strip_20kb',
      () {
        len = AnsiParser.strip(output).length;
      },
      iterations: 40,
    );
    expect(len, greaterThan(0));
    expect(len, lessThan(output.length));
  });
}
