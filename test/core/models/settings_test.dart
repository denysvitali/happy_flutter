import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';

void main() {
  group('Settings last-used profiles', () {
    test('scopes selected profiles by agent', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {'codex': 'openai', 'claude': 'anthropic'};

      expect(settings.lastUsedProfileForAgent('codex'), 'openai');
      expect(settings.lastUsedProfileForAgent('claude'), 'anthropic');
      expect(settings.lastUsedProfileForAgent('gemini'), isNull);
    });

    test('does not share a scoped Codex profile with Claude', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {'codex': 'openai'};

      expect(settings.lastUsedProfileForAgent('codex'), 'openai');
      expect(settings.lastUsedProfileForAgent('claude'), isNull);
    });

    test('legacy lastUsedProfile only applies to the last-used agent', () {
      final settings = Settings()
        ..lastUsedAgent = 'codex'
        ..lastUsedProfile = 'openai';

      expect(settings.lastUsedProfileForAgent('codex'), 'openai');
      expect(settings.lastUsedProfileForAgent('claude'), isNull);
    });

    test('serializes and restores scoped profile selections', () {
      final settings = Settings()
        ..lastUsedProfilesByAgent = {'claude': 'anthropic', 'codex': 'openai'};

      final restored = Settings.fromJson(settings.toJson());

      expect(restored.lastUsedProfileForAgent('claude'), 'anthropic');
      expect(restored.lastUsedProfileForAgent('codex'), 'openai');
    });
  });
}
