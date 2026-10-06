import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/utils/model_context_window.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';

AIBackendProfile _profile({
  int? contextWindow,
  List<String> models = const [],
}) {
  return AIBackendProfile(
    id: 'llm-proxy',
    name: 'llm-proxy',
    contextWindow: contextWindow,
    models: models,
  );
}

void main() {
  group('parseModelContextChoice', () {
    test('keeps a bare id and a non-numeric suffix intact', () {
      expect(parseModelContextChoice('grok/grok-4.7').model, 'grok/grok-4.7');
      expect(parseModelContextChoice('grok/grok-4.7').contextWindow, isNull);
      expect(
        parseModelContextChoice('vendor/model@beta').model,
        'vendor/model@beta',
      );
      expect(parseModelContextChoice('vendor/model@').model, 'vendor/model@');
    });

    test('splits a positive token window off the id', () {
      final choice = parseModelContextChoice('grok/grok-4.7@500000');
      expect(choice.model, 'grok/grok-4.7');
      expect(choice.contextWindow, 500000);
    });

    test('round-trips a choice and omits the window when unset', () {
      expect(
        encodeModelContextChoice(
          const ModelContextChoice(
            model: ' grok/grok-4.7 ',
            contextWindow: 1000000,
          ),
        ),
        'grok/grok-4.7@1000000',
      );
      expect(
        encodeModelContextChoice(const ModelContextChoice(model: 'x')),
        'x',
      );
    });
  });

  group('contextWindowForModel', () {
    test('a per-model window wins over the profile window', () {
      final profile = _profile(
        contextWindow: extendedContextWindowTokens,
        models: const ['grok/grok-4.7@200000', 'nous/hermes'],
      );
      expect(
        contextWindowForModel(profile: profile, model: 'grok/grok-4.7:high'),
        200000,
      );
    });

    test('a bare list entry opts that model out of the profile window', () {
      final profile = _profile(
        contextWindow: extendedContextWindowTokens,
        models: const ['grok/grok-4.7'],
      );
      expect(
        contextWindowForModel(profile: profile, model: 'grok/grok-4.7[1m]'),
        isNull,
      );
    });

    test('models the list does not name keep the profile window', () {
      final profile = _profile(
        contextWindow: extendedContextWindowTokens,
        models: const ['grok/grok-4.7@200000'],
      );
      expect(
        contextWindowForModel(profile: profile, model: 'openrouter/other'),
        extendedContextWindowTokens,
      );
    });
  });

  group('defaultContextWindowForModel', () {
    test('names the windows that are stable per model id', () {
      expect(defaultContextWindowForModel('grok/grok-4.7'), 500000);
      expect(defaultContextWindowForModel('grok/grok-4.6:high'), 500000);
      expect(defaultContextWindowForModel('grok/grok-4-0709'), isNull);
      expect(defaultContextWindowForModel('google/gemini-2.5-pro'), 1000000);
      expect(defaultContextWindowForModel('google/gemini-1.5-pro'), isNull);
      expect(defaultContextWindowForModel('openai/gpt-4.1'), 1000000);
      expect(defaultContextWindowForModel('minimax/minimax-m3'), 200000);
      expect(defaultContextWindowForModel('anthropic/claude-opus-4-6'), isNull);
      expect(
        defaultContextWindowForModel('anthropic/claude-opus-4-6-context-1m'),
        1000000,
      );
    });
  });

  group('applyProfileContextWindowSuffix', () {
    test('suffixes only the model whose entry asks for 1M', () {
      final profile = _profile(
        models: const ['opencode/big@1000000', 'opencode/small@200000'],
      );
      expect(
        applyProfileContextWindowSuffix(
          raw: 'opencode/big',
          profile: profile,
          flavor: 'claude',
        ),
        'opencode/big[1m]',
      );
      expect(
        applyProfileContextWindowSuffix(
          raw: 'opencode/small:high',
          profile: profile,
          flavor: 'claude',
        ),
        'opencode/small:high',
      );
    });

    test('a known 1M default does not invent a suffix', () {
      expect(
        applyProfileContextWindowSuffix(
          raw: 'google/gemini-2.5-pro',
          profile: _profile(),
          flavor: 'claude',
        ),
        'google/gemini-2.5-pro',
      );
    });

    test('an explicit window overrides a profile that wants 1M', () {
      expect(
        applyProfileContextWindowSuffix(
          raw: 'opencode/big[1m]',
          contextWindow: 200000,
          profile: _profile(contextWindow: extendedContextWindowTokens),
          flavor: 'claude',
        ),
        'opencode/big',
      );
    });

    test('strips a stale suffix from a model opted out of the profile 1M', () {
      final profile = _profile(
        contextWindow: extendedContextWindowTokens,
        models: const ['opencode/small'],
      );
      expect(
        applyProfileContextWindowSuffix(
          raw: 'opencode/small[1m]',
          profile: profile,
          flavor: 'claude',
        ),
        'opencode/small',
      );
    });
  });

  group('picker allowlist', () {
    test('matches a stored id@window entry by its bare id', () {
      const stored = ['grok/grok-4.7@500000'];
      expect(
        ChatModelMode.isAllowedRawSelection('grok/grok-4.7', stored),
        isTrue,
      );
      expect(
        ChatModelMode.isAllowedRawSelection('grok/grok-4.7:high', stored),
        isTrue,
      );
      final modes = ChatModelMode.availableForProfile(
        flavor: 'claude',
        claudeCompatible: true,
        profileModels: stored,
      );
      expect(
        modes.map((mode) => mode.modelSlug),
        contains('grok/grok-4.7'),
      );
      expect(
        modes.map((mode) => mode.modeString),
        isNot(contains(stored.first)),
      );
    });
  });
}
