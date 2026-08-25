import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';

void main() {
  group('applyProfileContextWindowSuffix', () {
    test('suffixes a concrete provider model for a 1M profile', () {
      expect(
        applyProfileContextWindowSuffix(
          raw: 'opencode/x-preview-f-free',
          contextWindow: 1000000,
          flavor: 'claude',
        ),
        'opencode/x-preview-f-free[1m]',
      );
    });

    test('removes a stale suffix when the profile uses its default window', () {
      expect(
        applyProfileContextWindowSuffix(
          raw: 'opencode/x-preview-f-free[1m]',
          contextWindow: null,
          flavor: 'claude',
        ),
        'opencode/x-preview-f-free',
      );
    });

    test('does not suffix daemon-resolved aliases', () {
      expect(
        applyProfileContextWindowSuffix(
          raw: 'default',
          contextWindow: 1000000,
          flavor: 'claude',
        ),
        'default',
      );
    });

    test('does not apply the Claude suffix to another agent flavor', () {
      expect(
        applyProfileContextWindowSuffix(
          raw: 'provider-model',
          contextWindow: 1000000,
          flavor: 'codex',
        ),
        'provider-model',
      );
    });
  });
}
