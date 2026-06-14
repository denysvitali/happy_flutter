// Coverage for the dropped-reason telemetry split introduced to quiet
// GlitchTip warnings produced by well-understood "skip — not
// user-visible" outcomes during `fetchMessages` (ROADMAP.md
// "fetchMessages dropped (output filter)").
//
// The summarizer (`_logDroppedReasonSummary`) routes known-skip
// categories — empty assistant acks, unsupported user sub-blocks the
// UI already replaces with a placeholder, and recurring shape-drift
// drops — to `logger.info`, while genuine drift (unknown dataTypes,
// malformed envelopes) stays at `logger.warning`.  Both buckets
// continue to land in the local devlog ring buffer; `warning` also
// reaches GlitchTip through an explicit low-cardinality Sentry capture.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  group('dropped-reason summary level split', () {
    setUp(LoggerService().clear);
    tearDown(LoggerService().clear);

    test('normalizer strips seq= / id= prefixes', () {
      expect(
        SyncTestHelpers.testNormalizeDroppedReason(
          'seq=42 id=cabc123: assistant content list is empty',
        ),
        'assistant content list is empty',
      );
      expect(
        SyncTestHelpers.testNormalizeDroppedReason(
          'user content block type=image not handled',
        ),
        'user content block type=image not handled',
      );
    });

    test('classifies known-skip reasons as info-level', () {
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'assistant content list is empty',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'assistant content missing',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'assistant message field missing',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'output message empty',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'redacted thinking',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'event data type tool-execution-update',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'session eventType turn-start',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'unrecognized output content block',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'pi result with no tool rows',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'user content block type=image not handled',
        ),
        isTrue,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'user content block type=audio not handled',
        ),
        isTrue,
      );
    });

    test('classifies unknown-dataType drift as warning-level', () {
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'output data type not handled',
        ),
        isFalse,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'output data is not a Map',
        ),
        isFalse,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'assistant message field unexpected type',
        ),
        isFalse,
      );
      expect(
        SyncTestHelpers.testIsKnownSkipDroppedReason(
          'codex dataType=somethingNew not handled (keys=[a, b])',
        ),
        isFalse,
      );
    });

    test('known-skip reasons log at info and never at warning', () {
      SyncTestHelpers.testLogDroppedReasonSummary(
        '[fetchMessages] s1',
        const [
          'seq=10 id=cA: assistant content list is empty',
          'seq=11 id=cB: assistant content list is empty',
          'user content block type=image not handled',
        ],
      );

      final infos = LoggerService().getLogsByLevel(LogLevel.info);
      final warnings = LoggerService().getLogsByLevel(LogLevel.warning);

      expect(
        warnings,
        isEmpty,
        reason: 'known-skip reasons must not produce a warning — they '
            'create Sentry noise without indicating a real bug',
      );
      expect(infos, hasLength(1));
      expect(infos.single.message, contains('[fetchMessages] s1 dropped'));
      expect(infos.single.message, contains('3 item(s)'));
      expect(
        infos.single.message,
        contains('assistant content list is empty'),
      );
      expect(
        infos.single.message,
        contains('user content block type=image not handled'),
      );
    });

    test('unknown reasons still log at warning so drift surfaces', () {
      SyncTestHelpers.testLogDroppedReasonSummary(
        '[fetchMessages] s1',
        const [
          'seq=10 id=cA: output data type not handled',
          'codex dataType=newWireFormat not handled (keys=[x, y])',
        ],
      );

      final warnings = LoggerService().getLogsByLevel(LogLevel.warning);
      expect(warnings, hasLength(1));
      expect(warnings.single.message, contains('2 item(s)'));
      expect(
        warnings.single.message,
        contains('output data type not handled'),
      );
    });

    test('mixed batch splits across info and warning buckets', () {
      SyncTestHelpers.testLogDroppedReasonSummary(
        '[fetchMessages] s1',
        const [
          'seq=10 id=cA: assistant content list is empty',
          'seq=11 id=cB: assistant content list is empty',
          'seq=12 id=cC: output data type not handled',
        ],
      );

      final infos = LoggerService().getLogsByLevel(LogLevel.info);
      final warnings = LoggerService().getLogsByLevel(LogLevel.warning);

      expect(infos, hasLength(1));
      expect(warnings, hasLength(1));
      expect(infos.single.message, contains('2 item(s)'));
      expect(warnings.single.message, contains('1 item(s)'));
    });

    test('empty reason list emits no log entries', () {
      SyncTestHelpers.testLogDroppedReasonSummary(
        '[fetchMessages] s1',
        const [],
      );
      expect(LoggerService().getLogs(), isEmpty);
    });

    test('seq jump placeholder is visible and keeps diagnostic context', () {
      final event = SyncTestHelpers.testBuildDroppedSeqJumpEvent(
        sessionId: 's1',
        fromSeq: 4146,
        toSeq: 5153,
        rawCount: 200,
        droppedReasons: const [
          'seq=4146 id=a: assistant content list is empty',
          'seq=4147 id=b: output data type not handled',
        ],
      );

      expect(event['id'], 'unrendered-s1-4146-5153');
      expect(event['seq'], 5153);
      expect(event['kind'], 'agent-event');
      expect(event['role'], 'agent');

      final payload = event['event'] as Map<String, dynamic>;
      expect(payload['type'], 'unrendered');
      expect(payload['message'], contains('seq 4146-5153'));

      final debugData = event['debugData'] as Map<String, dynamic>;
      expect(debugData['seqCount'], 1008);
      expect(debugData['rawCount'], 200);
      expect(
        debugData['droppedReasons'],
        contains('output data type not handled'),
      );
    });

    test('all-known-skip drops are not treated as unsupported seq jump', () {
      expect(
        SyncTestHelpers.testAreAllKnownSkipDrops(const [
          'seq=10 id=a: assistant content list is empty',
          'seq=11 id=b: assistant content missing',
          'event data type ready',
        ]),
        isTrue,
      );
    });

    test('any drift reason means the seq jump is unsupported', () {
      expect(
        SyncTestHelpers.testAreAllKnownSkipDrops(const [
          'seq=10 id=a: assistant content list is empty',
          'seq=11 id=b: output data type not handled',
        ]),
        isFalse,
      );
    });

    test('empty reason list is not assumed to be known-skip', () {
      expect(
        SyncTestHelpers.testAreAllKnownSkipDrops(const []),
        isFalse,
        reason: 'silent drops with no telemetry must still surface as '
            'potential drift until they are classified',
      );
    });
  });
}
