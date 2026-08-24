import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/message_cache_service.dart';

/// Progressive-lag remediation, 2026-08-24 (sixth pass).
///
/// `compute()` deep-copies its argument synchronously on the UI isolate, so
/// every byte handed to the message-cache worker is paid for on the frame
/// thread. Inline base64 image data used to be stripped *inside* the worker,
/// which meant the copy carried multi-MB payloads the worker then discarded.
/// These tests pin that the stripping now happens before the isolate boundary
/// and that doing so leaves the persisted content unchanged (the strip is
/// idempotent, so the worker's own sanitize pass is a no-op).
void main() {
  Map<String, dynamic> imageMessage(String id, String data) => {
    'id': id,
    'seq': 1,
    'role': 'user',
    'raw': {
      'content': [
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': 'image/png',
            'data': data,
          },
        },
      ],
    },
  };

  String? dataOf(Map<String, dynamic> message) {
    final raw = message['raw'] as Map<String, dynamic>;
    final content = raw['content'] as List<dynamic>;
    final block = content.single as Map<String, dynamic>;
    final source = block['source'] as Map<String, dynamic>;
    return source['data'] as String?;
  }

  test('inline image bytes are stripped before the worker payload '
      'is built', () {
    final huge = 'A' * 200000;
    final window = MessageCacheService.debugRawCacheWindow([
      imageMessage('m-1', huge),
    ]);

    expect(
      dataOf(window.single),
      isEmpty,
      reason:
          'the base64 payload must not cross the isolate boundary — the '
          'copy is synchronous on the UI isolate',
    );
    final source =
        ((window.single['raw'] as Map<String, dynamic>)['content']
                as List<dynamic>)
            .single
        as Map<String, dynamic>;
    expect((source['source'] as Map<String, dynamic>)['omitted'], isTrue);
  });

  test("stripping does not mutate the caller's messages", () {
    final huge = 'B' * 50000;
    final original = imageMessage('m-1', huge);
    MessageCacheService.debugRawCacheWindow([original]);

    expect(
      dataOf(original),
      huge,
      reason:
          'the resident transcript must keep its image bytes — only the '
          'cache copy is stripped',
    );
  });

  test('stripping is idempotent, so the worker pass stays byte-identical', () {
    final once = MessageCacheService.debugRawCacheWindow([
      imageMessage('m-1', 'C' * 1000),
    ]);
    final twice = MessageCacheService.debugRawCacheWindow(once);

    expect(dataOf(twice.single), isEmpty);
    expect(
      identical(once.single, twice.single),
      isTrue,
      reason:
          'a second strip must return the same object — otherwise the '
          'worker would rebuild the tree for nothing',
    );
  });

  test('messages without inline images pass through untouched', () {
    final plain = <String, dynamic>{
      'id': 'm-1',
      'seq': 1,
      'role': 'assistant',
      'content': 'hello',
    };
    final window = MessageCacheService.debugRawCacheWindow([plain]);

    expect(identical(window.single, plain), isTrue);
  });

  test('the worker-storage latch starts clear and is resettable', () {
    MessageCacheService.resetWorkerStorageAvailabilityForTest();
    expect(MessageCacheService.debugWorkerStorageUnavailable, isFalse);
  });

  group('payload byte budget', () {
    Map<String, dynamic> textMessage(String id, int chars) => {
      'id': id,
      'seq': 1,
      'role': 'assistant',
      'content': 'x' * chars,
    };

    test('ordinary sessions keep the full row window', () {
      final messages = [
        for (var i = 0; i < 200; i++) textMessage('m-$i', 200),
      ];

      final window = MessageCacheService.debugRawCacheWindow(messages);

      expect(
        window,
        hasLength(200),
        reason:
            'small rows must not be trimmed — the budget only targets the '
            'giant-tool-output sessions that produce long writes',
      );
    });

    test('giant tool outputs are bounded, keeping the newest rows', () {
      // Each row ~1 MB of UTF-16 -> well past the 512 KB budget.
      final messages = [
        for (var i = 0; i < 40; i++) textMessage('m-$i', 500000),
      ];

      final window = MessageCacheService.debugRawCacheWindow(messages);

      expect(
        window.length,
        lessThan(40),
        reason: 'the payload must be bounded so the native write stays short',
      );
      expect(
        window.last['id'],
        'm-39',
        reason: 'the newest row must always survive',
      );
    });

    test('the newest row survives even when it alone blows the budget', () {
      final messages = [
        for (var i = 0; i < 30; i++) textMessage('m-$i', 2000000),
      ];

      final window = MessageCacheService.debugRawCacheWindow(messages);

      expect(
        window,
        hasLength(1),
        reason:
            'a row floor would let a handful of multi-MB tool outputs blow '
            'past the ceiling the budget exists to hold',
      );
      expect(
        window.single['id'],
        'm-29',
        reason: 'cold start must still repaint the newest row',
      );
    });

    test('rows stay in chronological order after budget trimming', () {
      final messages = [
        for (var i = 0; i < 40; i++) textMessage('m-$i', 500000),
      ];

      final window = MessageCacheService.debugRawCacheWindow(messages);

      final seqs = [
        for (final m in window) int.parse((m['id'] as String).split('-')[1]),
      ];
      expect(
        seqs,
        orderedEquals([...seqs]..sort()),
        reason: 'restore assumes oldest-to-newest ordering',
      );
    });
  });
}
