// Direct unit tests for `Sync.hasSidechainMessage` — the eligibility gate
// in `message_ingestion_orchestrator.dart` (and mirrored in
// `_sync_messaging.dart`'s `pageHasSidechain`) that decides whether a
// batch should trigger sidechain grouping.
//
// Background: the original predicate only matched `isSidechain == true`
// and `kind == 'sidechain-root'`. A batch carrying only `sidechain-link`
// or `taskEvent` or `parentToolUseId`-routed children therefore fell
// through to a no-grouping path, and an overlapping fetch copy of an
// already-grouped child could land back in the flat list and render
// twice. The fix broadens the predicate so every shape the grouper can
// attach triggers grouping.
//
// These tests pin each trigger in isolation so any future narrowing is
// caught immediately, rather than only via the integration lanes.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

void main() {
  // Sync is a singleton; the extension is defined on the type, so any
  // pre-initialized instance will do. We just need an instance to call
  // the extension method on.
  late Sync sync;

  setUp(() {
    sync = Sync();
  });

  group('hasSidechainMessage — eligibility triggers', () {
    test('returns false on an empty batch', () {
      expect(sync.hasSidechainMessage(const []), isFalse);
    });

    test('returns false when no message carries any sidechain signal', () {
      const messages = <Map<String, dynamic>>[
        {'id': 'a', 'kind': 'user', 'text': 'hi'},
        {'id': 'b', 'kind': 'assistant', 'text': 'hello'},
      ];
      expect(sync.hasSidechainMessage(messages), isFalse);
    });

    test('returns true when isSidechain == true on any message', () {
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'kind': 'user'},
        {'id': 'b', 'isSidechain': true, 'kind': 'tool-result'},
      ];
      expect(sync.hasSidechainMessage(messages), isTrue);
    });

    test('returns true when any message is a sidechain-root', () {
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'kind': 'sidechain-root'},
      ];
      expect(sync.hasSidechainMessage(messages), isTrue);
    });

    test('returns true when any message is a sidechain-link (new trigger)',
        () {
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'kind': 'user'},
        {'id': 'b', 'kind': 'sidechain-link'},
      ];
      // Pre-fix this would return false — the regression we are pinning.
      expect(sync.hasSidechainMessage(messages), isTrue);
    });

    test('returns true when any message carries taskEvent (new trigger)',
        () {
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'taskEvent': true},
      ];
      expect(sync.hasSidechainMessage(messages), isTrue);
    });

    test(
        'returns true when any message carries a non-empty parentToolUseId '
        '(new trigger)', () {
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'parentToolUseId': 'toolu_01abc'},
      ];
      expect(sync.hasSidechainMessage(messages), isTrue);
    });

    test('returns false when parentToolUseId is empty (no groupable child)',
        () {
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'parentToolUseId': ''},
      ];
      // Empty string is intentionally NOT groupable — same as pre-fix
      // behavior. Pinning this so the predicate doesn't drift.
      expect(sync.hasSidechainMessage(messages), isFalse);
    });

    test(
        'returns false when parentToolUseId is missing entirely (no field '
        'at all)', () {
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'text': 'plain assistant turn'},
      ];
      expect(sync.hasSidechainMessage(messages), isFalse);
    });

    test(
        'does not throw when parentToolUseId is the wrong runtime type '
        '(e.g. int)', () {
      // Defensive coercion — the predicate must tolerate a `num` or other
      // non-String type without throwing on `as String?`.
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'parentToolUseId': 42},
      ];
      expect(() => sync.hasSidechainMessage(messages), returnsNormally);
      expect(sync.hasSidechainMessage(messages), isFalse);
    });

    test(
        'fires on the later message when the trigger appears in the second '
        'slot (not the first)', () {
      final messages = <Map<String, dynamic>>[
        {'id': 'a', 'kind': 'user'},
        {'id': 'b', 'isSidechain': true},
      ];
      expect(sync.hasSidechainMessage(messages), isTrue);
    });
  });
}
