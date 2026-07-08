import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/send/chat_send_coordinator.dart';

void main() {
  group('buildOptimisticUserMessage', () {
    test('sets id and localId to the same canonical value', () {
      final msg = buildOptimisticUserMessage(
        localId: 'local-abc',
        text: 'continue',
        createdAtMs: 1000,
      );
      expect(msg['id'], 'local-abc');
      expect(msg['localId'], 'local-abc');
      expect(msg['role'], 'user');
      expect(msg['content'], 'continue');
      expect(msg['text'], 'continue');
      expect(msg['sendStatus'], 'sending');
      expect(msg['seq'], -1);
      expect(msg['createdAt'], 1000);
    });

    test('repeated identical text still produces independent maps', () {
      final a = buildOptimisticUserMessage(localId: 'l1', text: 'continue');
      final b = buildOptimisticUserMessage(localId: 'l2', text: 'continue');
      expect(a['localId'], isNot(b['localId']));
      expect(a['text'], b['text']);
    });
  });

  group('markOptimisticMessageFailed', () {
    test('marks matching localId as failed without dropping identity', () {
      final list = [
        buildOptimisticUserMessage(localId: 'a', text: 'one'),
        buildOptimisticUserMessage(localId: 'b', text: 'two'),
      ];
      final next = markOptimisticMessageFailed(list, 'b');
      expect(next.length, 2);
      expect(next[0]['sendStatus'], 'sending');
      expect(next[1]['sendStatus'], 'failed');
      expect(next[1]['localId'], 'b');
    });

    test('matches by id when localId field missing', () {
      final list = [
        <String, dynamic>{'id': 'x', 'role': 'user', 'sendStatus': 'sending'},
      ];
      final next = markOptimisticMessageFailed(list, 'x');
      expect(next.single['sendStatus'], 'failed');
    });

    test('returns original list when no match', () {
      final list = [
        buildOptimisticUserMessage(localId: 'a', text: 'one'),
      ];
      final next = markOptimisticMessageFailed(list, 'missing');
      expect(identical(next, list), isTrue);
    });
  });

  group('command helpers', () {
    test('isClearCommand', () {
      expect(isClearCommand('/clear'), isTrue);
      expect(isClearCommand('  /clear  '), isTrue);
      expect(isClearCommand('/clear now'), isFalse);
    });

    test('isLoopCommand', () {
      expect(isLoopCommand('/loop list'), isTrue);
      expect(isLoopCommand('/LOOP 5m hi'), isTrue);
      expect(isLoopCommand('/loop'), isTrue);
      expect(isLoopCommand('/loopy'), isFalse);
    });
  });
}
