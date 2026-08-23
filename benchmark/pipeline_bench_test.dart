@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/aes_gcm.dart';
import 'package:happy_flutter/core/encryption/base64.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/ansi_span_cache.dart';

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

  test('ANSI parse of a 20KB tool output (memoized warm hit)', () {
    final output = ansiToolOutput(20000);
    // Warm the entry so every measured iteration is a cache hit — the
    // steady state of a rebuilt tool view whose output did not change.
    final warmed = AnsiSpanCache.instance.parse(output);
    var spans = 0;
    reporter.measureSync(
      'ansi_parse_20kb_cached_hit',
      () {
        spans = AnsiSpanCache.instance.parse(output).length;
      },
      iterations: 100,
    );
    expect(spans, warmed.length);
  });

  test('ANSI memoized parse under streaming growth (miss per tick)', () {
    var output = ansiToolOutput(20000);
    var spans = 0;
    reporter.measureSync(
      'ansi_parse_20kb_cached_miss_growing',
      () {
        // Output grows every iteration like a streaming tool result:
        // length changes -> guaranteed miss -> reparse + store.
        output += '\x1b[32mstreaming tick line\x1b[0m\n';
        spans = AnsiSpanCache.instance.parse(output).length;
      },
      iterations: 40,
    );
    expect(spans, greaterThan(0));
  });

  test('AES page stage composition over a real 500-row page', () async {
    final key = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      key[i] = (i * 11 + 1) & 0xff;
    }
    // One shared page so every stage measures the same bytes: fixture
    // pairs give the plaintext bodies, AES256Encryption.encrypt produces
    // the production wire rows (0x00 version byte + base64 envelope).
    final pairs = makeTranscriptPairs(500);
    final encryptor = AES256Encryption(key);
    final ciphers =
        await encryptor.encrypt(pairs.map((p) => p.plain).toList());
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < pairs.length; i++) {
      final w = Map<String, dynamic>.of(pairs[i].wire);
      w['content'] = <String, dynamic>{
        't': 'encrypted',
        'c': base64Encode(ciphers[i]),
      };
      rows.add(w);
    }
    final b64List = <String>[
      for (final row in rows)
        (row['content'] as Map<String, dynamic>)['c'] as String,
    ];
    final rawBytes = <Uint8List>[
      for (final b64 in b64List) Base64Utils.decode(b64),
    ];
    final stripped = <Uint8List>[
      for (final bytes in rawBytes)
        bytes.isNotEmpty && bytes[0] == 0 ? bytes.sublist(1) : bytes,
    ];
    // Same plaintext byte content decryptBatch sees after cipher.decrypt.
    final plainBytes = <Uint8List>[
      for (final pair in pairs) utf8.encode(jsonEncode(pair.plain)),
    ];

    var sink = 0;

    // Stage 1 — caller-isolate base64 decode (moved into the worker by
    // this change; measured here to document what it used to cost the UI
    // thread).
    reporter.measureSync(
      'aes_stage_b64_decode_500',
      () {
        for (final b64 in b64List) {
          sink += Base64Utils.decode(b64, Encoding.base64).length;
        }
      },
      iterations: 15,
      warmup: 3,
      opsPerIteration: 500,
    );

    // Stage 2 — version-byte check + strip (caller isolate today).
    reporter.measureSync(
      'aes_stage_version_split_500',
      () {
        for (final bytes in rawBytes) {
          if (bytes.isNotEmpty && bytes[0] == 0) {
            sink += bytes.sublist(1).length;
          }
        }
      },
      iterations: 30,
      warmup: 3,
      opsPerIteration: 500,
    );

    // Stage 3 — full batch body decode (utf8 + jsonDecode), which
    // decryptBatch runs after each cipher.decrypt inside the worker.
    reporter.measureSync(
      'aes_stage_utf8_json_decode_500',
      () {
        for (final bytes in plainBytes) {
          sink += (jsonDecode(utf8.decode(bytes)) as Map<dynamic, dynamic>)
              .length;
        }
      },
      iterations: 10,
      warmup: 2,
      opsPerIteration: 500,
    );

    // Stage 4 — whole decryptBatch inline (AES-GCM + stage 3): the
    // worker-side substrate. AES-only cost is roughly stage 4 minus
    // stage 3.
    await reporter.measure(
      'aes_stage_decrypt_batch_500',
      () async {
        final out = await AesGcmEncryption.decryptBatch(stripped, key);
        sink += out.length;
      },
      iterations: 6,
      warmup: 2,
      opsPerIteration: 500,
    );

    // Stage 5 — isolate spawn + ciphertext-byte transfer floor: no work,
    // bytes in and out.
    await reporter.measure(
      'aes_stage_isolate_bytes_roundtrip_500',
      () async {
        final copy = await Isolate.run(() => stripped);
        sink += copy.length;
      },
      iterations: 8,
      warmup: 2,
      opsPerIteration: 500,
    );

    // Stage 5b — same floor for the encoded path: base64 strings in
    // (what decryptEncodedInIsolate ships to the worker), nothing out.
    await reporter.measure(
      'aes_stage_isolate_strings_in_500',
      () async {
        final copy = await Isolate.run(() => b64List);
        sink += copy.length;
      },
      iterations: 8,
      warmup: 2,
      opsPerIteration: 500,
    );

    // Stage 6 — decoded-page copy-out floor: what shipping decrypted JSON
    // values back to the caller isolate costs even with no crypto.
    await reporter.measure(
      'aes_stage_decoded_copyout_500',
      () async {
        final copy = await Isolate.run(() => pairs.map((p) => p.plain)
            .toList());
        sink += copy.length;
      },
      iterations: 8,
      warmup: 2,
      opsPerIteration: 500,
    );

    // Reference — full SessionEncryption.decryptMessages on the same page
    // with a fresh cache per iteration (the decrypt half of
    // decrypt_and_process_aes_page_500).
    var produced = -1;
    Future<double> body() async {
      final encryption = SessionEncryption(
        sessionId: 'bench',
        encryptor: AES256Encryption(key),
        decryptor: AES256Encryption(key),
        cache: EncryptionCache(),
      );
      final watch = Stopwatch()..start();
      final out = await encryption.decryptMessages(rows);
      watch.stop();
      produced = out.length;
      return watch.elapsedMicroseconds / 1000.0;
    }

    await reporter.measureTimed(
      'decrypt_messages_aes_page_500',
      body,
      iterations: 6,
      warmup: 2,
      opsPerIteration: 500,
    );
    expect(produced, 500);
    expect(sink, greaterThan(0));
  });
}
