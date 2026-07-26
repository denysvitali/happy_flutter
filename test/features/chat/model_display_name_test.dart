import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/model_display_name.dart';

void main() {
  group('modelDisplayName', () {
    test('compacts current Anthropic ids', () {
      expect(modelDisplayName('claude-opus-4-5-20251101'), 'Opus 4.5');
      expect(modelDisplayName('claude-sonnet-5'), 'Sonnet 5');
      expect(modelDisplayName('claude-haiku-4-5-20251001'), 'Haiku 4.5');
      expect(modelDisplayName('claude-fable-5'), 'Fable 5');
    });

    test('keeps segment order for legacy version-first ids', () {
      expect(modelDisplayName('claude-3-5-sonnet-20241022'), '3.5 Sonnet');
    });

    test('drops routing prefixes and marketing suffixes', () {
      expect(modelDisplayName('anthropic/claude-opus-4-5'), 'Opus 4.5');
      expect(modelDisplayName('claude-sonnet-5-latest'), 'Sonnet 5');
    });

    test('uppercases acronym families', () {
      expect(modelDisplayName('gpt-5-codex'), 'GPT 5 Codex');
      expect(modelDisplayName('GLM-5'), 'GLM 5');
    });

    test('falls back to the raw string when the shape is unknown', () {
      expect(modelDisplayName('  '), '');
      expect(modelDisplayName('claude'), 'claude');
      expect(modelDisplayName('some_model'), 'Some_model');
    });
  });
}
