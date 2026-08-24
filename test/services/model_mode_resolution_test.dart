import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  late Sync sync;

  setUp(() {
    sync = createTestSync();
  });

  group('_getModelOverride', () {
    // --model is only passed when the caller supplies a valid explicit
    // model for the target agent. Claude aliases must not leak into Codex
    // sessions because Codex with a ChatGPT account rejects them.

    test('returns null for sonnet', () {
      sync.testSettingsSnapshot = Settings()..lastUsedModelMode = 'sonnet';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null for opus', () {
      sync.testSettingsSnapshot = Settings()..lastUsedModelMode = 'opus';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null for full model names', () {
      sync.testSettingsSnapshot = Settings()
        ..lastUsedModelMode = 'claude-3-opus';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null for non-standard model names', () {
      sync.testSettingsSnapshot = Settings()..lastUsedModelMode = 'GLM-5';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null for default lastUsed without explicit modelMode', () {
      sync.testSettingsSnapshot = Settings()..lastUsedModelMode = 'default';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null when lastUsedModelMode is null', () {
      sync.testSettingsSnapshot = Settings()..lastUsedModelMode = null;

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null with fresh Settings', () {
      sync.testSettingsSnapshot = Settings();

      expect(sync.testGetModelOverride(), isNull);
    });

    test('keeps explicit default on the wire for Codex clear-switch', () {
      // Switching Qwen → Default must send model="default" so the daemon
      // clears sticky metadata.model / codexThreadId. Collapsing to null
      // re-applied the previous third-party model on restore.
      expect(
        sync.testGetModelOverride(agent: 'codex', modelMode: 'default'),
        'default',
      );
      expect(
        sync.testGetModelOverride(agent: 'claude', modelMode: 'default'),
        'default',
      );
    });

    test('passes explicit Claude alias for Claude sessions', () {
      expect(
        sync.testGetModelOverride(agent: 'claude', modelMode: 'opus'),
        'opus',
      );
    });

    test(
      'drops explicit Claude alias for Codex sessions by returning default',
      () {
        // Claude aliases are stripped for Codex spawns so they do not
        // leak into a ChatGPT session. The wire value 'default' is kept
        // (not collapsed to null) so the daemon clears the sticky model.
        expect(
          sync.testGetModelOverride(agent: 'codex', modelMode: 'opus'),
          'default',
        );
        expect(
          sync.testGetModelOverride(agent: 'codex', modelMode: 'sonnet'),
          'default',
        );
        expect(
          sync.testGetModelOverride(agent: 'codex', modelMode: 'opus:max'),
          'default',
        );
        expect(
          sync.testGetModelOverride(agent: 'codex', modelMode: 'sonnet:high'),
          'default',
        );
        expect(
          sync.testGetModelOverride(
            agent: 'codex',
            modelMode: 'claude-fable-5',
          ),
          'default',
        );
        expect(
          sync.testGetModelOverride(
            agent: 'codex',
            modelMode: 'anthropic/claude-opus-4-6',
          ),
          'default',
        );
      },
    );

    test('drops explicit Claude alias for Codex-only profiles', () {
      final profile = AIBackendProfile(
        id: 'openai',
        name: 'OpenAI',
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
        ),
      );

      expect(
        sync.testGetModelOverride(profile: profile, modelMode: 'opus'),
        'default',
      );
    });

    test('passes explicit Codex model for Codex sessions', () {
      expect(
        sync.testGetModelOverride(agent: 'codex', modelMode: 'gpt-5.5:high'),
        'gpt-5.5:high',
      );
    });

    test('passes Qwen Token Plan model for the built-in Codex profile', () {
      final profile = getBuiltInProfile('qwen-token-plan-codex');
      expect(profile, isNotNull);

      // The built-in profile's non-official OPENAI_BASE_URL makes it a
      // custom Codex profile, so the provider-owned slug is passed
      // through instead of being normalized away.
      expect(
        sync.testGetModelOverride(
          agent: 'codex',
          profile: profile,
          modelMode: 'qwen3.7-max',
        ),
        'qwen3.7-max',
      );
      expect(
        sync.testGetModelOverride(
          agent: 'codex',
          profile: profile,
          modelMode: 'glm-5.2:high',
        ),
        'glm-5.2:high',
      );
    });

    test(
      'returns default for provider-owned model names in Codex default sessions',
      () {
        // MiniMax-M3 is not a known Codex model, so normalization
        // collapses it to 'default' which is kept explicit on the wire
        // (not collapsed to null) so the daemon clears the sticky model.
        expect(
          sync.testGetModelOverride(agent: 'codex', modelMode: 'MiniMax-M3'),
          'default',
        );
        expect(
          sync.testGetModelOverride(
            agent: 'codex',
            modelMode: 'MiniMax-M3:high',
          ),
          'default',
        );
      },
    );

    test('passes provider-owned model names for custom Codex profiles', () {
      final profile = AIBackendProfile(
        id: 'kimi-codex',
        name: 'Kimi Codex',
        openaiConfig: OpenAIConfig(
          baseUrl: 'https://api.kimi.com/coding/v1',
          model: 'kimi-k2.7-code',
        ),
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
        ),
      );

      expect(
        sync.testNormalizeModelModeForAgentWithProfile(
          'vendor/model:free',
          'codex',
          profile,
        ),
        'vendor/model:free',
      );
      expect(
        sync.testGetModelOverride(
          agent: 'codex',
          profile: profile,
          modelMode: 'kimi-k2.7-code',
        ),
        'kimi-k2.7-code',
      );
    });

    test('passes models for a configured Codex provider definition', () {
      final profile = AIBackendProfile(
        id: 'venice-codex',
        name: 'Venice Codex',
        codexModelProvider: 'llm-proxy',
        codexProviders: [
          CodexProviderConfig(
            id: 'llm-proxy',
            baseUrl: 'https://proxy.example/v1',
            envKey: 'LLM_PROXY_API_KEY',
          ),
        ],
        models: const ['venice/stealth-ox-alpha'],
        compatibility: const ProfileCompatibility(
          claude: false,
          codex: true,
          gemini: false,
        ),
      );

      expect(
        sync.testNormalizeModelModeForAgentWithProfile(
          'venice/stealth-ox-alpha',
          'codex',
          profile,
        ),
        'venice/stealth-ox-alpha',
      );
      expect(
        sync.testGetModelOverride(
          agent: 'codex',
          profile: profile,
          modelMode: 'venice/stealth-ox-alpha:high',
        ),
        'venice/stealth-ox-alpha:high',
      );
    });

    test('drops provider-owned override when no profile resolved', () {
      // A respawn without the profile env cannot reach the gateway:
      // with no ANTHROPIC_BASE_URL the daemon rewrites unknown slugs to
      // claude-sonnet-4-6 and the session silently runs the wrong
      // model. Drop to an explicit default instead.
      expect(
        sync.testGetModelOverride(
          agent: 'claude',
          modelMode: 'deepseek-chat:high',
        ),
        'default',
      );
      expect(
        sync.testGetModelOverride(agent: 'claude', modelMode: 'GLM-5'),
        'default',
      );
    });

    test('keeps official tier aliases without a profile', () {
      // Tier aliases are valid against the default provider, so they
      // survive even when the profile could not be resolved.
      expect(
        sync.testGetModelOverride(agent: 'claude', modelMode: 'sonnet:high'),
        'sonnet:high',
      );
      expect(
        sync.testGetModelOverride(agent: 'claude', modelMode: 'opus'),
        'opus',
      );
    });

    test('keeps provider-owned override with its profile', () {
      final profile = getBuiltInProfile('deepseek');
      expect(profile, isNotNull);

      expect(
        sync.testGetModelOverride(
          agent: 'claude',
          profile: profile,
          modelMode: 'deepseek-chat:high',
        ),
        'deepseek-chat:high',
      );
    });
  });

  group('_normalizeModelModeForAgent', () {
    test('preserves null and default', () {
      expect(sync.testNormalizeModelModeForAgent(null, 'codex'), isNull);
      expect(
        sync.testNormalizeModelModeForAgent('default', 'codex'),
        'default',
      );
    });

    test('normalizes stale Claude aliases away from Codex', () {
      expect(sync.testNormalizeModelModeForAgent('opus', 'codex'), 'default');
      expect(sync.testNormalizeModelModeForAgent('sonnet', 'codex'), 'default');
      expect(
        sync.testNormalizeModelModeForAgent('opus:max', 'codex'),
        'default',
      );
      expect(
        sync.testNormalizeModelModeForAgent('sonnet:high', 'codex'),
        'default',
      );
      expect(
        sync.testNormalizeModelModeForAgent('claude-fable-5', 'codex'),
        'default',
      );
      expect(
        sync.testNormalizeModelModeForAgent(
          'anthropic/claude-opus-4-6',
          'codex',
        ),
        'default',
      );
    });

    test('preserves non-Claude model names for Codex profiles', () {
      expect(
        sync.testNormalizeModelModeForAgent('gpt-5.5:high', 'codex'),
        'gpt-5.5:high',
      );
    });

    test('preserves Qwen Token Plan slugs for Codex sessions', () {
      for (final slug in qwenTokenPlanCodexModels) {
        expect(sync.testNormalizeModelModeForAgent(slug, 'codex'), slug);
        expect(
          sync.testNormalizeModelModeForAgent('$slug:high', 'codex'),
          '$slug:high',
        );
      }
    });

    test('normalizes provider-owned names away from Codex defaults', () {
      expect(
        sync.testNormalizeModelModeForAgent('MiniMax-M3', 'codex'),
        'default',
      );
      expect(
        sync.testNormalizeModelModeForAgent('MiniMax-M3:high', 'codex'),
        'default',
      );
    });

    test('normalizes stale Codex selections away from Claude', () {
      expect(
        sync.testNormalizeModelModeForAgent('gpt-5.5:medium', 'claude'),
        'default',
      );
      expect(
        sync.testNormalizeModelModeForAgent('gpt-5-codex:high', 'claude'),
        'default',
      );
      expect(
        sync.testNormalizeModelModeForAgent('gpt-4o', 'claude'),
        'default',
      );
    });

    test('normalizes stale Gemini selections away from Claude', () {
      expect(
        sync.testNormalizeModelModeForAgent('gemini-2.5-pro', 'claude'),
        'default',
      );
    });

    test('preserves Claude aliases for Claude sessions', () {
      expect(sync.testNormalizeModelModeForAgent('opus', 'claude'), 'opus');
      expect(sync.testNormalizeModelModeForAgent('sonnet', 'claude'), 'sonnet');
      expect(
        sync.testNormalizeModelModeForAgent('claude-fable-5', 'claude'),
        'claude-fable-5',
      );
    });

    test('preserves Claude-compatible custom model names', () {
      // GLM, MiniMax, etc. are Claude-API-compatible providers — their
      // model identifiers must not be stripped.
      expect(sync.testNormalizeModelModeForAgent('GLM-5', 'claude'), 'GLM-5');
      expect(
        sync.testNormalizeModelModeForAgent('MiniMax-Text-01', 'claude'),
        'MiniMax-Text-01',
      );
    });

    test('normalizes vendor/model strings away from Claude', () {
      // Models with a vendor prefix like inclusionai/ling-3.0-flash:free
      // carry a slash that identifies them as third-party — Claude CLI
      // rejects these with "There's an issue with the selected model".
      expect(
        sync.testNormalizeModelModeForAgent(
          'inclusionai/ling-3.0-flash:free',
          'claude',
        ),
        'default',
      );
      expect(
        sync.testNormalizeModelModeForAgent(
          'inclusionai/ling-3.0-flash',
          'claude',
        ),
        'default',
      );
      expect(
        sync.testNormalizeModelModeForAgent(
          'anthropic/claude-opus-4-6',
          'claude',
        ),
        'anthropic/claude-opus-4-6',
      );
    });

    test('preserves configured vendor/model strings for Claude gateways', () {
      final profile = AIBackendProfile(
        id: 'venice-claude',
        name: 'Venice Claude',
        anthropicConfig: AnthropicConfig(
          baseUrl: 'https://proxy.example/anthropic',
        ),
        models: const ['venice/stealth-ox-alpha'],
        compatibility: const ProfileCompatibility(
          claude: true,
          codex: false,
          gemini: false,
        ),
      );

      expect(
        sync.testNormalizeModelModeForAgentWithProfile(
          'venice/stealth-ox-alpha',
          'claude',
          profile,
        ),
        'venice/stealth-ox-alpha',
      );
      expect(
        sync.testGetModelOverride(
          agent: 'claude',
          profile: profile,
          modelMode: 'venice/stealth-ox-alpha:high',
        ),
        'venice/stealth-ox-alpha:high',
      );
    });
  });
}
