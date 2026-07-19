import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/utils/shell_script_parser.dart';

void main() {
  group('inferProfileCompatibility', () {
    test('targets Claude for Anthropic variables', () {
      final compatibility = inferProfileCompatibility([
        EnvironmentVariable(
          name: 'ANTHROPIC_BASE_URL',
          value: 'https://api.anthropic.com',
        ),
      ]);

      expect(compatibility.claude, isTrue);
      expect(compatibility.codex, isFalse);
      expect(compatibility.gemini, isFalse);
    });

    test('targets Codex for OpenAI variables', () {
      final compatibility = inferProfileCompatibility([
        EnvironmentVariable(name: 'OPENAI_MODEL', value: 'gpt-5-codex'),
      ]);

      expect(compatibility.claude, isFalse);
      expect(compatibility.codex, isTrue);
      expect(compatibility.gemini, isFalse);
    });

    test('supports both when provider variables are mixed', () {
      final compatibility = inferProfileCompatibility([
        EnvironmentVariable(name: 'ANTHROPIC_MODEL', value: 'claude-sonnet'),
        EnvironmentVariable(name: 'OPENAI_MODEL', value: 'gpt-5-codex'),
      ]);

      expect(compatibility.claude, isTrue);
      expect(compatibility.codex, isTrue);
      expect(compatibility.gemini, isFalse);
    });

    test('keeps generic scripts compatible with every agent', () {
      final compatibility = inferProfileCompatibility([
        EnvironmentVariable(name: 'PROJECT_NAME', value: 'example'),
      ]);

      expect(compatibility.claude, isTrue);
      expect(compatibility.codex, isTrue);
      expect(compatibility.gemini, isTrue);
    });
  });
}
