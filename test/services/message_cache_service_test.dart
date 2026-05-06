import 'package:happy_flutter/core/services/message_cache_service.dart';
import 'package:test/test.dart';

void main() {
  group('MessageCacheService', () {
    test('trimForTesting keeps the most recent cache window', () {
      final messages = List<Map<String, dynamic>>.generate(
        250,
        (index) => {'id': 'message-$index', 'seq': index + 1},
      );

      final trimmed = MessageCacheService.trimForTesting(messages);

      expect(trimmed, hasLength(200));
      expect(trimmed.first['id'], 'message-50');
      expect(trimmed.last['id'], 'message-249');
    });

    test('trimForTesting preserves small caches unchanged', () {
      final messages = List<Map<String, dynamic>>.generate(
        12,
        (index) => {'id': 'message-$index', 'seq': index + 1},
      );

      final trimmed = MessageCacheService.trimForTesting(messages);

      expect(identical(trimmed, messages), isTrue);
      expect(trimmed, hasLength(12));
    });
  });
}
