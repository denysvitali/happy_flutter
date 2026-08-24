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
}
