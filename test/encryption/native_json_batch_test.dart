import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/encryptor.dart';
import 'package:happy_flutter/core/encryption/json_text.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/native/native_core.dart';

/// Perf pass 9: decrypt **and** JSON-parse in the Rust core.
///
/// Contract: with the native core live, a page's bodies reach Dart as
/// validated [JsonText] and are materialized inside the processing worker —
/// never `jsonDecode`d on the calling isolate — and the processed output is
/// identical to the pure-Dart path's, row for row. Failures keep their exact
/// class, and a broken row never aborts the batch.
///
/// Tests that need the real FFI skip themselves when the library is absent
/// (a platform without it is an expected configuration).
void main() {
  final key = Uint8List.fromList(List<int>.generate(32, (i) => (i * 11) % 256));
  late AES256Encryption encryptor;

  setUp(() async {
    NativeCore.instance.debugReset();
    await NativeCore.instance.ensureInitialized();
    encryptor = AES256Encryption(key);
  });

  tearDown(NativeCore.instance.debugReset);

  Future<String> seal(dynamic body) async =>
      base64Encode((await encryptor.encrypt([body])).single);

  Future<Map<String, dynamic>> wire(String id, int seq, dynamic body) async => {
    'id': id,
    'seq': seq,
    'createdAt': seq * 1000,
    'content': {'t': 'encrypted', 'c': await seal(body)},
  };

  test('native rows come back as validated JsonText, byte-identical', () async {
    if (!NativeCore.instance.isAvailable) return;
    final body = {
      'role': 'agent',
      'content': {
        'type': 'output',
        'data': {
          'unicode': 'caffè ☕ 日本',
          'n': 1.5e-7,
          'deep': [
            [[]],
          ],
        },
      },
    };
    final result = await encryptor.decryptEncodedJsonInIsolate([
      await seal(body),
    ]);

    expect(result.values.single, isA<JsonText>());
    final text = (result.values.single as JsonText).text;
    expect(text, jsonEncode(body), reason: 'no re-serialization in Rust');
    expect(materializeJsonText(JsonText(text)), body);
    expect(result.decodeFailures, isEmpty);
  });

  test('every failure class stays aligned and the batch survives', () async {
    if (!NativeCore.instance.isAvailable) return;
    final good = await seal({'ok': true});
    final tamperedBytes = base64Decode(await seal({'x': 1}));
    tamperedBytes[tamperedBytes.length - 1] ^= 0x01;
    final notJson = base64Encode(
      (await AES256Encryption(key).encrypt(['plain string body'])).single,
    );

    final result = await encryptor.decryptEncodedJsonInIsolate([
      good,
      base64Encode(tamperedBytes),
      '%%not base64%%',
      notJson,
    ]);

    expect(result.values, hasLength(4));
    expect(result.values[0], isA<JsonText>());
    expect(result.values[1], isNull, reason: 'auth failed');
    expect(result.values[2], isNull, reason: 'bad base64');
    // A JSON string value *is* well-formed JSON — same as jsonDecode.
    expect(result.values[3], isA<JsonText>());
    expect(result.decodeFailures, [
      2,
    ], reason: 'only the base64 failure is a decode failure');
  });

  test(
    'processed page is identical through the native and Dart paths',
    () async {
      if (!NativeCore.instance.isAvailable) return;
      final page = <Map<String, dynamic>>[
        for (var i = 0; i < 40; i++)
          await wire('m-$i', i + 1, {
            'role': i.isEven ? 'user' : 'agent',
            'content': i.isEven
                ? {'type': 'text', 'text': 'hello $i'}
                : {
                    'type': 'output',
                    'data': {
                      'type': 'assistant',
                      'message': {
                        'role': 'assistant',
                        'content': [
                          {'type': 'text', 'text': 'reply $i ☕'},
                        ],
                      },
                      'uuid': 'u-$i',
                    },
                  },
          }),
      ];

      Future<ProcessedMessages> run() => SessionEncryption(
        sessionId: 's',
        encryptor: encryptor,
        decryptor: encryptor,
        cache: EncryptionCache(),
      ).decryptAndProcessMessages(page, 's');

      final native = await run();
      NativeCore.instance.debugSetAvailable(available: false);
      final dart = await run();

      expect(native.messages, dart.messages);
      expect(native.toolResults, dart.toolResults);
      expect(native.usageUpdates, dart.usageUpdates);
      expect(native.maxSeq, dart.maxSeq);
      expect(native.droppedReasons, dart.droppedReasons);
      expect(native.messages.length, greaterThan(0));
    },
  );

  test('a cached JsonText row is served and materialized on the single-row '
      'path', () async {
    if (!NativeCore.instance.isAvailable) return;
    final cache = EncryptionCache();
    final session = SessionEncryption(
      sessionId: 's',
      encryptor: encryptor,
      decryptor: encryptor,
      cache: cache,
    );
    final row = await wire('m-1', 1, {'role': 'user', 'content': 'hi'});

    // Page path populates the cache with the lazy body …
    await session.decryptAndProcessMessages([row], 's');
    // … and the convenience path must hand back objects, not text.
    final single = await session.decryptMessage(row);
    expect(single?.content, {'role': 'user', 'content': 'hi'});
  });

  test('an unavailable core falls back to the decoded-object path', () async {
    NativeCore.instance.debugSetAvailable(available: false);
    final result = await encryptor.decryptEncodedJsonInIsolate([
      await seal({'a': 1}),
    ]);
    expect(result.values.single, {'a': 1});
  });
}
