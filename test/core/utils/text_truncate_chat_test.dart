import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/text_truncate.dart';

void main() {
  for (final cluster in ['😀', 'é', '👩🏽‍💻', '🇮🇹']) {
    test('chat preview and semantic budgets preserve $cluster', () {
      final label = '${'a' * 99}${cluster}tail';
      expect(
        truncateGraphemes(label, 100, ellipsis: '...'),
        '${'a' * 99}$cluster...',
      );
      final document = '${'a' * 3999}${cluster}tail';
      expect(
        truncateGraphemes(document, 4000, ellipsis: ''),
        '${'a' * 3999}$cluster',
      );
    });

    test('streaming tail preserves $cluster and fitting text', () {
      final tail = '$cluster${'a' * 3999}';
      expect(tailGraphemes('discard$tail', 4000), tail);
      expect(tailGraphemes(tail, 4000), tail);
    });
  }
}
