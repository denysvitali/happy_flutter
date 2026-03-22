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
    // --model is never passed when spawning sessions. The model is
    // determined by profile env vars (ANTHROPIC_MODEL, OPENAI_MODEL,
    // etc.) or the CLI's own defaults. This prevents stale model
    // names (e.g. GLM-5) from leaking across profile switches.

    test('returns null for sonnet', () {
      sync.testSettingsSnapshot = Settings()
        ..lastUsedModelMode = 'sonnet';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null for opus', () {
      sync.testSettingsSnapshot = Settings()
        ..lastUsedModelMode = 'opus';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null for full model names', () {
      sync.testSettingsSnapshot = Settings()
        ..lastUsedModelMode = 'claude-3-opus';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null for non-standard model names', () {
      sync.testSettingsSnapshot = Settings()
        ..lastUsedModelMode = 'GLM-5';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null for default', () {
      sync.testSettingsSnapshot = Settings()
        ..lastUsedModelMode = 'default';

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null when lastUsedModelMode is null', () {
      sync.testSettingsSnapshot = Settings()
        ..lastUsedModelMode = null;

      expect(sync.testGetModelOverride(), isNull);
    });

    test('returns null regardless of profile', () {
      sync.testSettingsSnapshot = Settings()
        ..lastUsedModelMode = 'sonnet';

      final profile = AIBackendProfile(
        id: 'p1',
        name: 'Test',
        anthropicConfig: AnthropicConfig(
          model: 'claude-3-sonnet',
        ),
      );

      expect(
        sync.testGetModelOverride(profile: profile),
        isNull,
      );
    });

    test('returns null with fresh Settings', () {
      sync.testSettingsSnapshot = Settings();

      expect(sync.testGetModelOverride(), isNull);
    });
  });
}
