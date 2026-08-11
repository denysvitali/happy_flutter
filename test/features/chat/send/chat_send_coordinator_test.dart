import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/send/chat_send_coordinator.dart';

void main() {
  group('canonicalMessageIdentityKey', () {
    test('prefers localId after the server replaces the optimistic id', () {
      final message = <String, dynamic>{
        'id': 'server-42',
        'localId': 'local-42',
        'role': 'user',
        'content': 'continue',
      };

      expect(canonicalMessageIdentityKey(message), 'local-42');
    });

    test('falls back to id and never uses repeated text as identity', () {
      final first = <String, dynamic>{
        'id': 'server-1',
        'role': 'user',
        'content': 'continue',
      };
      final second = <String, dynamic>{
        'id': 'server-2',
        'role': 'user',
        'content': 'continue',
      };

      expect(canonicalMessageIdentityKey(first), 'server-1');
      expect(canonicalMessageIdentityKey(second), 'server-2');
      expect(
        canonicalMessageIdentityKey(first),
        isNot(canonicalMessageIdentityKey(second)),
      );
    });
  });

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

    test('marks an explicit Codex next-turn message in its raw record', () {
      final msg = buildOptimisticUserMessage(
        localId: 'next-1',
        text: 'Do this next',
        codexDeliveryMode: 'next-turn',
      );

      expect(msg['localId'], 'next-1');
      final raw = msg['raw'] as Map<String, dynamic>;
      final meta = raw['meta'] as Map<String, dynamic>;
      expect(meta['codexDeliveryMode'], 'next-turn');
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
      expect(next[1]['content'], 'two');
      expect(next.where((m) => m['localId'] == 'b'), hasLength(1));
    });

    test('matches by id when localId field missing', () {
      final list = [
        <String, dynamic>{'id': 'x', 'role': 'user', 'sendStatus': 'sending'},
      ];
      final next = markOptimisticMessageFailed(list, 'x');
      expect(next.single['sendStatus'], 'failed');
    });

    test('returns original list when no match', () {
      final list = [buildOptimisticUserMessage(localId: 'a', text: 'one')];
      final next = markOptimisticMessageFailed(list, 'missing');
      expect(identical(next, list), isTrue);
    });
  });

  group('markOptimisticMessageStalled', () {
    test('escalates a still-sending row to pending', () {
      final list = [
        buildOptimisticUserMessage(localId: 'a', text: 'one'),
        buildOptimisticUserMessage(localId: 'b', text: 'two'),
      ];
      final next = markOptimisticMessageStalled(list, 'b');
      expect(next[0]['sendStatus'], 'sending');
      expect(next[1]['sendStatus'], 'pending');
      // Identity survives the escalation so retry still works.
      expect(next[1]['localId'], 'b');
      expect(next[1]['id'], 'b');
    });

    test('leaves terminal states alone', () {
      for (final status in ['sent', 'failed', 'pending']) {
        final list = [
          <String, dynamic>{
            'id': 'a',
            'localId': 'a',
            'role': 'user',
            'sendStatus': status,
          },
        ];
        final next = markOptimisticMessageStalled(list, 'a');
        expect(
          identical(next, list),
          isTrue,
          reason: '$status must not be escalated',
        );
      }
    });

    test('returns original list when no match', () {
      final list = [buildOptimisticUserMessage(localId: 'a', text: 'one')];
      expect(
        identical(markOptimisticMessageStalled(list, 'missing'), list),
        isTrue,
      );
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
