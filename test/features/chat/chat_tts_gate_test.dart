import 'package:happy_flutter/features/chat/chat_tts_gate.dart';
import 'package:test/test.dart';

Map<String, dynamic> _agentText(String id, String content) => {
  'id': id,
  'role': 'agent',
  'kind': 'text',
  'content': content,
};

Map<String, dynamic> _user(String id, String content) => {
  'id': id,
  'role': 'user',
  'kind': 'text',
  'content': content,
};

Map<String, dynamic> _toolCall(String id) => {
  'id': id,
  'role': 'agent',
  'kind': 'tool-call',
  'name': 'Bash',
};

Map<String, dynamic> _thinking(String id) => {
  'id': id,
  'role': 'agent',
  'kind': 'text',
  'isThinking': true,
  'content': '*Thinking...*\n\n*planning...*',
};

void main() {
  group('ChatTtsGate (default predicate)', () {
    test(
      'returns null before initial load is marked complete',
      () {
        final gate = ChatTtsGate();
        final result = gate.evaluate(
          messages: [_user('u1', 'hi'), _agentText('a1', 'hello')],
          ttsEnabled: true,
        );
        expect(result, isNull);
        expect(gate.isInitialLoadComplete, isFalse);
      },
    );

    test(
      'does not speak the existing tail when initial load completes',
      () {
        final gate = ChatTtsGate();
        final history = [
          _user('u1', 'hi'),
          _agentText('a1', 'hello there'),
        ];
        gate.markInitialLoadComplete(history);

        final speech = gate.evaluate(
          messages: history,
          ttsEnabled: true,
        );
        expect(
          speech,
          isNull,
          reason: 'Historical reply must not be replayed on entry.',
        );
        expect(gate.lastSpokenMessageId, 'a1');
      },
    );

    test('speaks the latest agent text when a new id arrives', () {
      final gate = ChatTtsGate()
        ..markInitialLoadComplete([_agentText('a1', 'hi')]);

      final speech = gate.evaluate(
        messages: [
          _agentText('a1', 'hi'),
          _user('u2', 'thanks'),
          _agentText('a2', 'you are welcome'),
        ],
        ttsEnabled: true,
      );
      expect(speech, 'you are welcome');
      expect(gate.lastSpokenMessageId, 'a2');
    });

    test(
      'does not speak when the trailing speakable id is unchanged',
      () {
        final gate = ChatTtsGate()
          ..markInitialLoadComplete([_agentText('a1', 'first reply')]);

        // First new arrival speaks.
        expect(
          gate.evaluate(
            messages: [
              _agentText('a1', 'first reply'),
              _agentText('a2', 'second reply'),
            ],
            ttsEnabled: true,
          ),
          'second reply',
        );

        // Replay/cache reload with the same trailing id must not
        // re-speak.
        expect(
          gate.evaluate(
            messages: [
              _agentText('a1', 'first reply'),
              _agentText('a2', 'second reply'),
            ],
            ttsEnabled: true,
          ),
          isNull,
        );

        // A streaming-style content update on a2 must also not
        // re-speak.
        expect(
          gate.evaluate(
            messages: [
              _agentText('a1', 'first reply'),
              _agentText('a2', 'second reply now with more text'),
            ],
            ttsEnabled: true,
          ),
          isNull,
        );
      },
    );

    test('skips tool-call as the trailing message but speaks earlier '
        'agent text once new', () {
      final gate = ChatTtsGate()
        ..markInitialLoadComplete([_agentText('a1', 'first')]);

      // a2 (text) is followed by a tool-call. We should still speak a2.
      final speech = gate.evaluate(
        messages: [
          _agentText('a1', 'first'),
          _agentText('a2', 'sure, searching now'),
          _toolCall('tc1'),
        ],
        ttsEnabled: true,
      );
      expect(speech, 'sure, searching now');
      expect(gate.lastSpokenMessageId, 'a2');
    });

    test(
      'never speaks user messages, tool-calls, or thinking placeholders',
      () {
        final gate = ChatTtsGate()
          ..markInitialLoadComplete([_agentText('a1', 'first')]);

        expect(
          gate.evaluate(
            messages: [_agentText('a1', 'first'), _user('u2', 'hi')],
            ttsEnabled: true,
          ),
          isNull,
        );
        expect(
          gate.evaluate(
            messages: [_agentText('a1', 'first'), _toolCall('tc1')],
            ttsEnabled: true,
          ),
          isNull,
        );
        expect(
          gate.evaluate(
            messages: [_agentText('a1', 'first'), _thinking('th1')],
            ttsEnabled: true,
          ),
          isNull,
        );
      },
    );

    test(
      'does not speak the role==assistant string (parser regression '
      'guard)',
      () {
        final gate = ChatTtsGate()..markInitialLoadComplete(const []);

        // The parser tags Claude replies with role 'agent' — anything
        // labelled 'assistant' is foreign to this codebase and must
        // not slip through.
        final speech = gate.evaluate(
          messages: [
            {
              'id': 'x1',
              'role': 'assistant',
              'kind': 'text',
              'content': 'hello',
            },
          ],
          ttsEnabled: true,
        );
        expect(speech, isNull);
      },
    );

    test(
      'updates baseline silently when ttsEnabled is false so toggling '
      'on later does not replay old text',
      () {
        final gate = ChatTtsGate()
          ..markInitialLoadComplete([_agentText('a1', 'first')]);

        // ttsEnabled is false: no speech, but baseline must advance to
        // a2 so the user doesn't hear it later.
        expect(
          gate.evaluate(
            messages: [
              _agentText('a1', 'first'),
              _agentText('a2', 'silent reply'),
            ],
            ttsEnabled: false,
          ),
          isNull,
        );
        expect(gate.lastSpokenMessageId, 'a2');

        // Now toggling on must not cause a2 to be replayed when the
        // same list is evaluated again.
        expect(
          gate.evaluate(
            messages: [
              _agentText('a1', 'first'),
              _agentText('a2', 'silent reply'),
            ],
            ttsEnabled: true,
          ),
          isNull,
        );
      },
    );

    test(
      'rapid-fire sequence of agent replies speaks only the most '
      'recent one (no queue spam)',
      () {
        final gate = ChatTtsGate()..markInitialLoadComplete(const []);

        // Three agent replies arrive in one update batch.
        final speech = gate.evaluate(
          messages: [
            _agentText('a1', 'one'),
            _agentText('a2', 'two'),
            _agentText('a3', 'three'),
          ],
          ttsEnabled: true,
        );
        expect(
          speech,
          'three',
          reason:
              'Only the most recent reply should be spoken; earlier '
              'replies in the same batch are skipped to avoid '
              'overlapping speech.',
        );
      },
    );

    test('reset() clears state so the gate can be reused', () {
      final gate = ChatTtsGate()
        ..markInitialLoadComplete([_agentText('a1', 'first')]);

      gate.evaluate(
        messages: [_agentText('a1', 'first'), _agentText('a2', 'two')],
        ttsEnabled: true,
      );
      expect(gate.lastSpokenMessageId, 'a2');

      gate.reset();
      expect(gate.isInitialLoadComplete, isFalse);
      expect(gate.lastSpokenMessageId, isNull);

      // Pre-baseline calls return null again.
      expect(
        gate.evaluate(
          messages: [_agentText('a3', 'three')],
          ttsEnabled: true,
        ),
        isNull,
      );
    });
  });

  group('ChatTtsGate (custom predicate, agent_conversation use)', () {
    bool subagentSpeakable(Map<String, dynamic> m) =>
        (m['kind'] as String?) == 'text' && m['isThinking'] != true;

    test('uses the supplied predicate to find speakable items', () {
      final gate = ChatTtsGate(isSpeakable: subagentSpeakable)
        ..markInitialLoadCompleteDynamic(<dynamic>[
          {'id': 'c1', 'kind': 'text', 'content': 'first'},
        ]);

      final speech = gate.evaluateDynamic(
        items: <dynamic>[
          {'id': 'c1', 'kind': 'text', 'content': 'first'},
          {'id': 'c2', 'kind': 'tool-call'},
          {'id': 'c3', 'kind': 'text', 'content': 'reply two'},
        ],
        ttsEnabled: true,
      );
      expect(speech, 'reply two');
    });

    test(
      'evaluateDynamic tolerates non-map items in the iterable',
      () {
        final gate = ChatTtsGate(isSpeakable: subagentSpeakable)
          ..markInitialLoadCompleteDynamic(null);

        final speech = gate.evaluateDynamic(
          items: <dynamic>[
            'not a map',
            42,
            {'id': 'c1', 'kind': 'text', 'content': 'hello'},
          ],
          ttsEnabled: true,
        );
        expect(speech, 'hello');
      },
    );
  });
}
