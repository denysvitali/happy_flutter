import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/utils/shell_script_parser.dart';

void main() {
  group('buildAnthropicModelEnvVars', () {
    test('maps main model to every selection knob', () {
      final envVars = buildAnthropicModelEnvVars(mainModel: 'mimo-v2.5-pro');
      final byName = {for (final e in envVars) e.name: e.value};

      expect(byName['ANTHROPIC_MODEL'], 'mimo-v2.5-pro');
      expect(byName['ANTHROPIC_SMALL_FAST_MODEL'], 'mimo-v2.5-pro');
      expect(byName['ANTHROPIC_DEFAULT_OPUS_MODEL'], 'mimo-v2.5-pro');
      expect(byName['ANTHROPIC_DEFAULT_SONNET_MODEL'], 'mimo-v2.5-pro');
      expect(byName['ANTHROPIC_DEFAULT_HAIKU_MODEL'], 'mimo-v2.5-pro');
      expect(byName['ANTHROPIC_DEFAULT_FABLE_MODEL'], 'mimo-v2.5-pro');
      expect(byName['ANTHROPIC_DEFAULT_MODEL'], 'mimo-v2.5-pro');
      expect(byName['CLAUDE_CODE_SUBAGENT_MODEL'], 'mimo-v2.5-pro');
    });

    test('uses the fast model for haiku-class selections', () {
      final envVars = buildAnthropicModelEnvVars(
        mainModel: 'glm-5.1',
        fastModel: 'GLM-4.7',
      );
      final byName = {for (final e in envVars) e.name: e.value};

      expect(byName['ANTHROPIC_MODEL'], 'glm-5.1');
      expect(byName['ANTHROPIC_SMALL_FAST_MODEL'], 'GLM-4.7');
      expect(byName['ANTHROPIC_DEFAULT_SONNET_MODEL'], 'GLM-4.7');
      expect(byName['ANTHROPIC_DEFAULT_HAIKU_MODEL'], 'GLM-4.7');
      expect(byName['ANTHROPIC_DEFAULT_FABLE_MODEL'], 'glm-5.1');
      expect(byName['ANTHROPIC_DEFAULT_MODEL'], 'glm-5.1');
      expect(byName['CLAUDE_CODE_SUBAGENT_MODEL'], 'glm-5.1');
    });

    test('falls back to the main model when fast model is blank', () {
      final envVars = buildAnthropicModelEnvVars(
        mainModel: 'deepseek-chat',
        fastModel: '',
      );

      expect(
        envVars
            .firstWhere((e) => e.name == 'ANTHROPIC_DEFAULT_HAIKU_MODEL')
            .value,
        'deepseek-chat',
      );
    });
  });

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
