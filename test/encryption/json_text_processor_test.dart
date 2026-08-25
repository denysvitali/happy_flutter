import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/encryption_cache.dart';
import 'package:happy_flutter/core/encryption/json_text.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

/// [JsonText] is materialized where the row is consumed, so the processor
/// must treat it exactly like the already-decoded object — pure Dart, no
/// FFI needed to pin that.
void main() {
  Map<String, dynamic> wire(int seq) => {
    'id': 'm-$seq',
    'seq': seq,
    'createdAt': seq * 1000,
  };

  test('JsonText rows process identically to decoded rows', () {
    const body = {
      'role': 'user',
      'content': {'type': 'text', 'text': 'hi there'},
    };
    final decoded = processDecryptedMessages(
      decryptedJsonList: [body],
      wireMessages: [wire(1)],
      sessionId: 's',
    );
    final lazy = processDecryptedMessages(
      decryptedJsonList: [
        const JsonText(
          '{"role":"user","content":{"type":"text","text":"hi there"}}',
        ),
      ],
      wireMessages: [wire(1)],
      sessionId: 's',
    );
    expect(lazy.messages, decoded.messages);
    expect(lazy.maxSeq, decoded.maxSeq);
  });

  test('a JSON string value materializes to the same text row as before', () {
    final lazy = processDecryptedMessages(
      decryptedJsonList: [const JsonText('"just text"')],
      wireMessages: [wire(2)],
      sessionId: 's',
    );
    final decoded = processDecryptedMessages(
      decryptedJsonList: ['just text'],
      wireMessages: [wire(2)],
      sessionId: 's',
    );
    expect(lazy.messages, decoded.messages);
  });

  test('corrupt JsonText degrades to the decryption-failed bubble, not a '
      'throw', () {
    final result = processDecryptedMessages(
      decryptedJsonList: [const JsonText('{not json')],
      wireMessages: [wire(3)],
      sessionId: 's',
      wasEncrypted: const [true],
    );
    expect(result.messages.single['errorType'], 'decryption_failed');
    expect(result.undecryptableRenderedCount, 1);
  });

  test('the cache budget counts JsonText characters', () {
    final cache = EncryptionCache();
    final huge = JsonText(
      '"${'x' * (EncryptionCache.maxCachedMessageChars + 1)}"',
    );
    cache.setCachedMessage(
      'big',
      DecryptedMessage(
        id: 'big',
        seq: 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(1),
        content: huge,
      ),
    );
    cache.setCachedMessage(
      'small',
      DecryptedMessage(
        id: 'small',
        seq: 2,
        createdAt: DateTime.fromMillisecondsSinceEpoch(2),
        content: const JsonText('{}'),
      ),
    );
    expect(cache.getCachedMessage('big'), isNull);
    expect(cache.getCachedMessage('small'), isNotNull);
  });
}
