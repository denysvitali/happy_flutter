import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

void main() {
  group('processDecryptedMessages — edge cases', () {
    // -----------------------------------------------------------------------
    // Helper that builds a minimal agent/output/assistant wire+decrypted pair.
    // -----------------------------------------------------------------------
    Map<String, dynamic> _agentOutputDecrypted({
      required String uuid,
      required List<dynamic> contentList,
      bool isMeta = false,
      bool isCompactSummary = false,
    }) {
      return {
        'role': 'agent',
        'content': {
          'type': 'output',
          'data': {
            'type': 'assistant',
            'uuid': uuid,
            if (isMeta) 'isMeta': true,
            if (isCompactSummary) 'isCompactSummary': true,
            'message': {'content': contentList},
          },
        },
      };
    }

    Map<String, dynamic> _wire({
      String? id,
      int? seq,
      int? createdAt,
      String? localId,
    }) {
      final m = <String, dynamic>{};
      if (id != null) m['id'] = id;
      if (seq != null) m['seq'] = seq;
      if (createdAt != null) m['createdAt'] = createdAt;
      if (localId != null) m['localId'] = localId;
      return m;
    }

    // -----------------------------------------------------------------------
    // 1. isMeta messages are silently dropped
    // -----------------------------------------------------------------------
    group('isMeta messages', () {
      test('isMeta: true is silently dropped — no messages emitted', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            _agentOutputDecrypted(
              uuid: 'u1',
              contentList: [
                {'type': 'text', 'text': 'should be hidden'},
              ],
              isMeta: true,
            ),
          ],
          wireMessages: [_wire(id: 'm1', seq: 1, createdAt: 1000)],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty,
            reason: 'isMeta messages must not appear in output');
        expect(result.toolResults, isEmpty);
        expect(result.usageUpdates, isEmpty);
      });

      test('isMeta maxSeq is still tracked', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            _agentOutputDecrypted(
              uuid: 'u1',
              contentList: [],
              isMeta: true,
            ),
          ],
          wireMessages: [_wire(id: 'm1', seq: 7, createdAt: 1000)],
          sessionId: 's1',
        );

        expect(result.maxSeq, 7,
            reason: 'seq must advance even for dropped messages');
      });
    });

    // -----------------------------------------------------------------------
    // 2. isCompactSummary messages are silently dropped
    // -----------------------------------------------------------------------
    group('isCompactSummary messages', () {
      test(
          'isCompactSummary: true is silently dropped — no messages emitted',
          () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            _agentOutputDecrypted(
              uuid: 'u2',
              contentList: [
                {'type': 'text', 'text': 'compact summary text'},
              ],
              isCompactSummary: true,
            ),
          ],
          wireMessages: [_wire(id: 'm2', seq: 3, createdAt: 2000)],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty,
            reason: 'isCompactSummary messages must not appear in output');
        expect(result.toolResults, isEmpty);
      });

      test('isCompactSummary maxSeq is still tracked', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            _agentOutputDecrypted(
              uuid: 'u2',
              contentList: [],
              isCompactSummary: true,
            ),
          ],
          wireMessages: [_wire(id: 'm2', seq: 12, createdAt: 2000)],
          sessionId: 's1',
        );

        expect(result.maxSeq, 12);
      });
    });

    // -----------------------------------------------------------------------
    // 3. Agent output with empty content list
    // -----------------------------------------------------------------------
    group('agent output with empty content list', () {
      test('empty content list produces no messages and does not crash', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            _agentOutputDecrypted(uuid: 'u3', contentList: []),
          ],
          wireMessages: [_wire(id: 'm3', seq: 2, createdAt: 3000)],
          sessionId: 's1',
        );

        // No crash; no messages produced from an empty content list.
        expect(result.messages, isEmpty);
        expect(result.toolResults, isEmpty);
        expect(result.maxSeq, 2);
      });
    });

    // -----------------------------------------------------------------------
    // 4. Agent output with non-list content (e.g., a plain string)
    // -----------------------------------------------------------------------
    group('agent output with non-list content', () {
      test('string content emits text message as legacy fallback', () {
        // agentMsg['content'] is a String, not a List — treated as
        // legacy format and emitted as a plain text message.
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'assistant',
                  'uuid': 'u4',
                  'message': {'content': 'just a string'},
                },
              },
            },
          ],
          wireMessages: [_wire(id: 'm4', seq: 4, createdAt: 4000)],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages[0]['role'], 'agent');
        expect(result.messages[0]['kind'], 'text');
        expect(result.messages[0]['content'], 'just a string');
        expect(result.toolResults, isEmpty);
      });

      test('null content field also handled gracefully', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {
                  'type': 'assistant',
                  'uuid': 'u4b',
                  'message': <String, dynamic>{},
                  // 'content' key absent — agentMsg['content'] is null
                },
              },
            },
          ],
          wireMessages: [_wire(id: 'm4b', seq: 5, createdAt: 4500)],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // 5. Wire message with missing id, seq, createdAt
    // -----------------------------------------------------------------------
    group('wire message with missing id/seq/createdAt', () {
      test('missing id defaults to empty string in output', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'hi'}},
          ],
          wireMessages: [<String, dynamic>{}],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(1));
        expect(result.messages.first['id'], '');
      });

      test('missing seq defaults to 0', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'hi'}},
          ],
          wireMessages: [<String, dynamic>{}],
          sessionId: 's1',
        );

        expect(result.messages.first['seq'], 0);
        expect(result.maxSeq, 0);
      });

      test('missing createdAt falls back to a reasonable int timestamp', () {
        final before = DateTime.now().millisecondsSinceEpoch - 1000;
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'hi'}},
          ],
          wireMessages: [<String, dynamic>{}],
          sessionId: 's1',
        );
        final after = DateTime.now().millisecondsSinceEpoch + 1000;

        final ts = result.messages.first['createdAt'] as int;
        expect(ts, greaterThan(before));
        expect(ts, lessThan(after));
      });

      test('double createdAt is preserved instead of becoming now', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'hi'}},
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': 1700000000000.0},
          ],
          sessionId: 's1',
        );

        expect(result.messages.first['createdAt'], 1700000000000);
      });

      test('numeric-string createdAt is preserved', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'hi'}},
          ],
          wireMessages: [
            {'id': 'm1', 'seq': 1, 'createdAt': '1700000000000'},
          ],
          sessionId: 's1',
        );

        expect(result.messages.first['createdAt'], 1700000000000);
      });

      test('all fields missing — still produces a result without throwing', () {
        expect(
          () => processDecryptedMessages(
            decryptedJsonList: [
              {'role': 'user', 'content': {'type': 'text', 'text': 'x'}},
            ],
            wireMessages: [<String, dynamic>{}],
            sessionId: 's1',
          ),
          returnsNormally,
        );
      });
    });

    // -----------------------------------------------------------------------
    // 6. Result count equals input count minus dropped messages
    // -----------------------------------------------------------------------
    group('output count with mixed meta/normal/compactSummary batch', () {
      test('only non-dropped messages appear in output', () {
        // 5 wire messages:
        //   index 0 — normal user text      → 1 message
        //   index 1 — isMeta output         → dropped
        //   index 2 — isCompactSummary      → dropped
        //   index 3 — normal user text      → 1 message
        //   index 4 — agent text (codex)    → 1 message
        // Expected output count: 3
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'user',
              'content': {'type': 'text', 'text': 'msg A'},
            },
            _agentOutputDecrypted(
              uuid: 'umeta',
              contentList: [
                {'type': 'text', 'text': 'meta'},
              ],
              isMeta: true,
            ),
            _agentOutputDecrypted(
              uuid: 'ucs',
              contentList: [
                {'type': 'text', 'text': 'summary'},
              ],
              isCompactSummary: true,
            ),
            {
              'role': 'user',
              'content': {'type': 'text', 'text': 'msg B'},
            },
            {
              'role': 'agent',
              'content': {
                'type': 'codex',
                'data': {'type': 'message', 'message': 'codex reply'},
              },
            },
          ],
          wireMessages: [
            _wire(id: 'm0', seq: 1, createdAt: 1000),
            _wire(id: 'm1', seq: 2, createdAt: 2000),
            _wire(id: 'm2', seq: 3, createdAt: 3000),
            _wire(id: 'm3', seq: 4, createdAt: 4000),
            _wire(id: 'm4', seq: 5, createdAt: 5000),
          ],
          sessionId: 's1',
        );

        expect(result.messages, hasLength(3),
            reason: 'meta and compactSummary messages must be dropped');
        expect(result.maxSeq, 5);
      });
    });

    // -----------------------------------------------------------------------
    // 7. Null at a non-zero index in decryptedJsonList (mid-batch)
    // -----------------------------------------------------------------------
    group('null decrypted content in a mixed batch', () {
      test('null at index 1 of 3 emits decryption-error entry for that slot',
          () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'first'}},
            null, // decryption failed for this one
            {'role': 'user', 'content': {'type': 'text', 'text': 'third'}},
          ],
          wireMessages: [
            _wire(id: 'ma', seq: 10, createdAt: 1000),
            _wire(id: 'mb', seq: 11, createdAt: 2000),
            _wire(id: 'mc', seq: 12, createdAt: 3000),
          ],
          sessionId: 's1',
          // wasEncrypted not supplied → default true → error placeholder
        );

        expect(result.messages, hasLength(3));

        final errorMsg = result.messages[1];
        expect(errorMsg['kind'], 'error');
        expect(errorMsg['errorType'], 'decryption_failed');
        expect(errorMsg['id'], 'error-mb');

        // Flanking messages are unaffected.
        expect(result.messages[0]['content'], 'first');
        expect(result.messages[2]['content'], 'third');
      });

      test('null at index 1 is skipped when wasEncrypted[1] is false', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {'role': 'user', 'content': {'type': 'text', 'text': 'first'}},
            null,
            {'role': 'user', 'content': {'type': 'text', 'text': 'third'}},
          ],
          wireMessages: [
            _wire(id: 'ma', seq: 10, createdAt: 1000),
            _wire(id: 'mb', seq: 11, createdAt: 2000),
            _wire(id: 'mc', seq: 12, createdAt: 3000),
          ],
          sessionId: 's1',
          wasEncrypted: [true, false, true],
        );

        expect(result.messages, hasLength(2),
            reason: 'unencrypted null should be silently skipped');
        expect(result.messages[0]['content'], 'first');
        expect(result.messages[1]['content'], 'third');
      });
    });

    // -----------------------------------------------------------------------
    // 9. Dropped-reason telemetry for intentionally invisible content
    // -----------------------------------------------------------------------
    group('silent drops produce classifiable reasons', () {
      test('empty assistant content list records a known-skip reason', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            _agentOutputDecrypted(uuid: 'u-empty', contentList: []),
          ],
          wireMessages: [_wire(id: 'm-empty', seq: 1, createdAt: 1000)],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(
          result.droppedReasons,
          contains('seq=1 id=m-empty: assistant content list is empty'),
        );
      });

      test('event content control types record known-skip reasons', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'event',
                'data': {'type': 'tool-execution-update'},
              },
            },
            {
              'role': 'agent',
              'content': {
                'type': 'event',
                'data': {'type': 'ready'},
              },
            },
          ],
          wireMessages: [
            _wire(id: 'm1', seq: 1, createdAt: 1000),
            _wire(id: 'm2', seq: 2, createdAt: 2000),
          ],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(
          result.droppedReasons,
          contains('event data type tool-execution-update'),
        );
        expect(result.droppedReasons, contains('event data type ready'));
      });

      test('session control events record known-skip reasons', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'session',
              'content': {
                'type': 'session',
                'data': {
                  'type': 'session',
                  'ev': {'type': 'turn-start'},
                  'id': 'evt-1',
                },
              },
            },
          ],
          wireMessages: [_wire(id: 'm1', seq: 1, createdAt: 1000)],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(
          result.droppedReasons,
          contains('session eventType turn-start'),
        );
      });

      test('output message with empty text records a known-skip reason', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            {
              'role': 'agent',
              'content': {
                'type': 'output',
                'data': {'type': 'message', 'message': ''},
              },
            },
          ],
          wireMessages: [_wire(id: 'm1', seq: 1, createdAt: 1000)],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(result.droppedReasons, contains('output message empty'));
      });

      test('redacted thinking records a known-skip reason', () {
        final result = processDecryptedMessages(
          decryptedJsonList: [
            _agentOutputDecrypted(uuid: 'u-redacted', contentList: [
              {'type': 'redacted_thinking'},
            ]),
          ],
          wireMessages: [_wire(id: 'm1', seq: 1, createdAt: 1000)],
          sessionId: 's1',
        );

        expect(result.messages, isEmpty);
        expect(result.droppedReasons, contains('redacted thinking'));
      });
    });
  });
}
