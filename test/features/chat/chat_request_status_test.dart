import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/chat_request_status.dart';

void main() {
  Map<String, dynamic> user(String id, [String status = 'sent']) => {
    'id': id,
    'localId': id,
    'role': 'user',
    'content': 'continue',
    'sendStatus': status,
  };
  const answer = {'id': 'answer', 'role': 'agent', 'content': 'Hello'};
  const reasoning = {
    'id': 'reasoning',
    'role': 'agent',
    'kind': 'text',
    'isThinking': true,
    'content': '',
  };

  test('sending becomes waiting on acknowledgement, preserving identity', () {
    final sending = resolveChatRequestStatus([user('local-1', 'sending')]);
    final waiting = resolveChatRequestStatus([
      {...user('local-1'), 'id': 'server-1'},
    ]);
    expect(sending.phase, ChatRequestPhase.sending);
    expect(waiting.phase, ChatRequestPhase.waiting);
    expect(waiting.localId, sending.localId);
  });

  test('empty reasoning signals count as processing, not as an answer', () {
    final status = resolveChatRequestStatus([user('one'), reasoning]);
    expect(status.phase, ChatRequestPhase.reasoning);
    expect(
      resolveChatRequestStatus([user('one'), reasoning, answer]).phase,
      ChatRequestPhase.none,
    );
  });

  test(
    'a repeated identical send waits independently of the previous reply',
    () {
      final status = resolveChatRequestStatus([
        user('one'),
        answer,
        user('two'),
      ]);
      expect(status.phase, ChatRequestPhase.waiting);
      expect(status.localId, 'two');
    },
  );

  test('failed and queued retries never claim the model is processing', () {
    for (final state in ['failed', 'pending']) {
      expect(
        resolveChatRequestStatus([user('one', state)]).phase,
        ChatRequestPhase.none,
      );
    }
    final retry = resolveChatRequestStatus([user('one', 'sending')]);
    expect(retry.localId, 'one');
    expect(retry.phase, ChatRequestPhase.sending);
  });

  test('old replies and sidechains do not satisfy a send', () {
    final status = resolveChatRequestStatus([
      answer,
      user('two'),
      {...answer, 'isSidechain': true},
    ]);
    expect(status.phase, ChatRequestPhase.waiting);
    expect(status.localId, 'two');
  });

  test('a generic agent message retained by Sync is a real response', () {
    expect(
      resolveChatRequestStatus([
        user('one'),
        {...answer, 'isPromptEchoCandidate': true},
      ]).phase,
      ChatRequestPhase.none,
    );
  });

  test('errors and terminal events clear the waiting state', () {
    for (final terminal in [
      {'role': 'agent', 'kind': 'error'},
      {
        'role': 'agent',
        'kind': 'agent-event',
        'event': {'type': 'turn-end'},
      },
      {
        'role': 'agent',
        'kind': 'agent-event',
        'event': {'type': 'ready'},
      },
    ]) {
      expect(
        resolveChatRequestStatus([user('one'), reasoning, terminal]).phase,
        ChatRequestPhase.none,
      );
    }
  });
}
