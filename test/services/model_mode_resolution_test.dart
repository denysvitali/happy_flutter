import 'package:flutter_test/flutter_test.dart';
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

    test('returns null for default', () {
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

    test('passes explicit Claude alias for Claude sessions', () {
      expect(
        sync.testGetModelOverride(agent: 'claude', modelMode: 'opus'),
        'opus',
      );
    });

    test('drops explicit Claude alias for Codex sessions', () {
      expect(
        sync.testGetModelOverride(agent: 'codex', modelMode: 'opus'),
        isNull,
      );
      expect(
        sync.testGetModelOverride(agent: 'codex', modelMode: 'sonnet'),
        isNull,
      );
      expect(
        sync.testGetModelOverride(agent: 'codex', modelMode: 'opus:max'),
        isNull,
      );
      expect(
        sync.testGetModelOverride(agent: 'codex', modelMode: 'sonnet:high'),
        isNull,
      );
    });

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
        isNull,
      );
    });

    test('passes explicit Codex model for Codex sessions', () {
      expect(
        sync.testGetModelOverride(agent: 'codex', modelMode: 'gpt-5.5:high'),
        'gpt-5.5:high',
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
    });

    test('preserves non-Claude model names for Codex profiles', () {
      expect(
        sync.testNormalizeModelModeForAgent('gpt-5.5:high', 'codex'),
        'gpt-5.5:high',
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
  });
}
