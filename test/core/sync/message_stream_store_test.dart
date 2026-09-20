import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/sync/message_stream_store.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

Map<String, dynamic> preview(String id, String text) => {
  'role': 'agent',
  'content': {
    'type': 'codex',
    'data': {
      'type': 'model-output',
      'streamId': id,
      'fullText': text,
      'isStreaming': true,
    },
  },
};

void main() {
  test('snapshots replace by identity, never repeated text', () {
    final store = MessageStreamStore();
    expect(store.accept(preview('a', 'Hi'), nowMs: 1), isTrue);
    expect(store.accept(preview('a', 'Hi there'), nowMs: 2), isTrue);
    expect(store.accept(preview('a', 'Hi'), nowMs: 3), isFalse);
    expect(store.accept(preview('b', 'Hi there'), nowMs: 4), isTrue);
    final user = {'id': 'user', 'localId': 'canonical', 'role': 'user'};
    final rows = store.merge([user]);
    expect(rows, hasLength(3));
    expect(rows.first, same(user));
    expect(rows[1]['content'], 'Hi there');
    expect(rows[1]['id'], isNot(rows[2]['id']));
    expect(rows[1]['localId'], isNull);
  });

  test('durable completion wins over delayed preview and replay', () {
    final store = MessageStreamStore();
    store.accept(preview('a', 'partial'), nowMs: 1);
    final finalRow = {
      'id': 'server-id',
      'localId': 'durable-id',
      'streamId': 'a',
      'content': 'canonical final',
      'role': 'agent',
    };
    expect(store.merge([finalRow]), [finalRow]);
    expect(store.accept(preview('a', 'late partial'), nowMs: 2), isFalse);
    expect(store.merge([finalRow]), [finalRow]);
    final fresh = MessageStreamStore();
    fresh.merge([finalRow]);
    expect(fresh.accept(preview('a', 'late'), nowMs: 3), isFalse);
  });

  test('abandoned previews expire and memory is bounded', () {
    final store = MessageStreamStore();
    for (var i = 0; i < 100; i++) {
      store.accept(preview('$i', 'text'), nowMs: 1);
    }
    expect(store.merge([]).length, lessThanOrEqualTo(32));
    expect(store.expire(120001), isTrue);
    expect(store.merge([]), isEmpty);
    expect(
      store.accept(preview('big', 'x' * (256 * 1024 + 1)), nowMs: 2),
      isFalse,
    );
  });

  test('final processing preserves canonical storage identity', () {
    final outer = preview('stream', 'final');
    (outer['content'] as Map)['data']['isStreaming'] = false;
    final processed = processDecryptedMessages(
      decryptedJsonList: [outer],
      wireMessages: [
        {'id': 'wire-id', 'localId': 'wire-local', 'seq': 7, 'createdAt': 99},
      ],
      sessionId: 'session',
    );
    final row = processed.messages.single;
    expect(row['id'], 'wire-id');
    expect(row['localId'], 'wire-local');
    expect(row['streamId'], 'stream');
    expect(row['isStreaming'], isFalse);
  });
}
