import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/model_selection.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';

void main() {
  test('OpenCode catalog overrides profiles and preserves exact model IDs', () {
    const catalog = [
      PrimeAgentModelInfo(id: 'opencode/big-pickle', name: 'Big Pickle'),
      PrimeAgentModelInfo(id: 'provider/model:variant', name: 'Variant'),
      PrimeAgentModelInfo(id: 'opencode/big-pickle', name: 'Duplicate'),
    ];
    final modes = ChatModelMode.availableForProfile(
      flavor: 'opencode',
      claudeCompatible: true,
      profileModels: ['sonnet', 'gpt-6-luna'],
      opencodeModels: catalog,
    );
    expect(modes.map((m) => m.modeString), [
      'default',
      'opencode/big-pickle',
      'provider/model:variant',
    ]);
    expect(modes[2].reasoningEffort, isNull);
    expect(
      ChatModelMode.availableForProfile(
        flavor: 'opencode',
        claudeCompatible: true,
        profileModels: ['sonnet'],
      ),
      [ChatModelMode.defaultModel],
    );
    for (final raw in ['sonnet', 'gpt-6-luna', 'grok-4.7', 'stale/model']) {
      expect(
        messageModelMetadata(
          raw,
          'opencode',
          opencodeModels: catalog.map((m) => m.id),
        ),
        {'model': null},
      );
      expect(
        ChatModelMode.normalizeRawForFlavor(
          raw,
          'opencode',
          allowedRawModels: catalog.map((m) => m.id).toList(),
        ),
        'default',
      );
    }
    expect(
      messageModelMetadata(
        modes[2].modeString,
        'opencode',
        opencodeModels: catalog.map((m) => m.id),
      ),
      {'model': 'provider/model:variant'},
    );
    expect(
      messageModelMetadata(
        'default',
        'opencode',
        opencodeModels: catalog.map((m) => m.id),
      ),
      {'model': null},
    );
  });

  test(
    'Prime message configuration separates effort and clears old effort',
    () {
      expect(
        messageModelMetadata('openai-codex/gpt-6-luna:off', 'prime-agent'),
        {'model': 'openai-codex/gpt-6-luna', 'reasoning_effort': 'off'},
      );
      final old = <String, dynamic>{'reasoning_effort': 'high'};
      expect(
        {
          ...old,
          ...messageModelMetadata('openai-codex/gpt-6-luna', 'prime-agent'),
        }['reasoning_effort'],
        isNull,
      );
      expect(messageModelMetadata('sonnet:high', 'claude'), {
        'model': 'sonnet:high',
      });
    },
  );

  test(
    'Prime Agent exposes only advertised effort choices and keeps selection',
    () {
      final metadata = Metadata.fromJson(const {
        'primeagentModels': [
          {'id': 'openai-codex/gpt-6-luna', 'name': 'Luna'},
        ],
        'primeagentEfforts': [
          {'id': 'off', 'name': 'Off'},
          {'id': 'minimal', 'name': 'Minimal'},
          {'id': 'high', 'name': 'High'},
        ],
        'reasoningEffort': 'minimal',
      });
      final modes = ChatModelMode.availableForProfile(
        flavor: 'prime-agent',
        claudeCompatible: false,
        primeAgentModels: metadata.primeAgentModels,
        primeAgentEfforts: metadata.primeAgentEfforts,
      );
      expect(modes.map((mode) => mode.modeString), [
        'default',
        'openai-codex/gpt-6-luna',
        'openai-codex/gpt-6-luna:off',
        'openai-codex/gpt-6-luna:minimal',
        'openai-codex/gpt-6-luna:high',
      ]);
      final selected = modes[3];
      expect(
        ChatModelMode.normalizeForFlavor(
          selected,
          'prime-agent',
        ).reasoningEffort,
        'minimal',
      );
      expect(
        ChatModelMode.fromString(selected.modeString).reasoningEffort,
        'minimal',
      );
      expect(
        Metadata.fromJson(metadata.toJson()).primeAgentEfforts,
        metadata.primeAgentEfforts,
      );
      expect(metadata.reasoningEffort, 'minimal');
    },
  );

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

  test('Prime Agent picker lists the models the running agent advertises', () {
    final metadata = Metadata.fromJson(const {
      'flavor': 'prime-agent',
      'primeagentModels': [
        {'id': 'openai-codex/gpt-6-luna', 'name': 'GPT-6 Luna (openai-codex)'},
        {'id': 'openai-codex/gpt-6-sol'},
        {'id': '  ', 'name': 'blank id'},
        'not-a-model',
        {'id': 'openai-codex/gpt-6-luna', 'name': 'duplicate'},
      ],
    });
    final modes = ChatModelMode.availableForProfile(
      flavor: 'prime-agent',
      claudeCompatible: false,
      // The agent's own catalog wins: a profile entry it does not advertise
      // could never be selected.
      profileModels: const ['codex/gpt-6.1-sol'],
      primeAgentModels: metadata.primeAgentModels,
    );
    expect(modes.map((mode) => mode.modeString), [
      'default',
      'openai-codex/gpt-6-luna',
      'openai-codex/gpt-6-sol',
    ]);
    expect(modes.map((mode) => mode.label), [
      'Default',
      'GPT-6 Luna (openai-codex)',
      'openai-codex/gpt-6-sol',
    ]);
    // A picked entry survives the composer's flavor normalization unchanged.
    expect(
      ChatModelMode.normalizeForFlavor(modes[2], 'prime-agent').modeString,
      'openai-codex/gpt-6-sol',
    );
    expect(
      Metadata.fromJson(metadata.toJson()).primeAgentModels,
      metadata.primeAgentModels,
    );
  });

  test('Prime Agent without an advertised catalog keeps profile models', () {
    final modes = ChatModelMode.availableForProfile(
      flavor: 'prime-agent',
      claudeCompatible: false,
      profileModels: const ['openai-codex/gpt-6-luna'],
      primeAgentModels: const [],
    );
    expect(modes.map((mode) => mode.modeString), [
      'default',
      'openai-codex/gpt-6-luna',
    ]);
  });

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
