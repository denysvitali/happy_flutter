import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';

void main() {
  group('Settings last-used profiles', () {
    test('serializes and restores hide tool calls preference', () {
      final settings = Settings()..hideToolCalls = true;

      final restored = Settings.fromJson(settings.toJson());

      expect(restored.hideToolCalls, isTrue);
    });

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

    test('fallback decode preserves existing values for partial payloads', () {
      final existing = Settings()
        ..themeMode = 'dark'
        ..avatarStyle = 'gradient'
        ..agentInputEnterToSend = true
        ..ttsEnabled = true
        ..ttsEngine = 'system'
        ..usagePeriod = 'sevenDays'
        ..folders = ['Work'];

      final restored = Settings.fromJsonWithFallback(
        {
          'themeMode': 'light',
          'avatarStyle': null,
          'folders': 'invalid',
        },
        existing,
      );

      expect(restored.themeMode, 'light');
      expect(restored.avatarStyle, 'gradient');
      expect(restored.agentInputEnterToSend, isTrue);
      expect(restored.ttsEnabled, isTrue);
      expect(restored.ttsEngine, 'system');
      expect(restored.usagePeriod, 'sevenDays');
      expect(restored.folders, ['Work']);
    });

    test('json storage roundtrip preserves all non-secret settings fields', () {
      final settings = Settings()
        ..avatarStyle = 'wave'
        ..agentInputEnterToSend = true
        ..ttsEnabled = true
        ..ttsEngine = 'system'
        ..voiceAssistantLanguage = 'en-US'
        ..usagePeriod = 'sevenDays'
        ..folders = ['Work', 'Personal'];

      final restored = Settings.fromJson(settings.toJson());

      expect(restored.avatarStyle, 'wave');
      expect(restored.agentInputEnterToSend, isTrue);
      expect(restored.ttsEnabled, isTrue);
      expect(restored.ttsEngine, 'system');
      expect(restored.voiceAssistantLanguage, 'en-US');
      expect(restored.usagePeriod, 'sevenDays');
      expect(restored.folders, ['Work', 'Personal']);
    });
  });
}
