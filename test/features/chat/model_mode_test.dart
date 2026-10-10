import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';

void main() {
  test('Prime Agent rejects unowned Claude aliases but keeps owned models', () {
    expect(
      ChatModelMode.normalizeRawForFlavor('sonnet', 'prime-agent'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor(
        'sonnet',
        'prime-agent',
        allowedRawModels: const ['sonnet'],
      ),
      'sonnet',
    );
  });

  test(
    'Prime Agent exposes profile-owned models without Claude effort variants',
    () {
      final modes = ChatModelMode.availableForProfile(
        flavor: 'prime-agent',
        claudeCompatible: false,
        profileModels: const [
          'openai-codex/gpt-6-luna',
          'anthropic/claude-sonnet',
        ],
      );
      expect(modes.map((mode) => mode.modeString), [
        'default',
        'openai-codex/gpt-6-luna',
        'anthropic/claude-sonnet',
      ]);
      expect(
        modes.skip(1).every((mode) => mode.reasoningEffort == null),
        isTrue,
      );
    },
  );

  test('Har pickers and stored selections preserve Grok 4.7', () {
    const raw = 'grok/grok-4.7';
    final selected = ChatModelMode.harModels.singleWhere(
      (model) => model.modeString == raw,
    );
    expect(selected.label, 'Grok 4.7');
    expect(ChatModelMode.availableForFlavor('har'), contains(selected));
    expect(ChatModelMode.normalizeForFlavor(selected, 'har'), selected);
    expect(ChatModelMode.normalizeRawForFlavor(raw, 'har'), raw);
    expect(
      ChatModelMode.normalizeRawForFlavor('default', 'har'),
      'codex/gpt-6-luna',
    );
  });

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
