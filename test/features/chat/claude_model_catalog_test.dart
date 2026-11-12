import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';

void main() {
  const catalog = [
    ClaudeModelInfo(
      id: 'default',
      name: 'Default (recommended)',
      efforts: ['low', 'high'],
    ),
    ClaudeModelInfo(
      id: 'haiku',
      name: 'Haiku 5.5',
      efforts: ['low', 'medium', 'high', 'xhigh', 'max'],
    ),
    ClaudeModelInfo(
      id: 'claude-opus-4-6',
      name: 'Opus 4.6',
      efforts: ['low', 'medium', 'high', 'max'],
    ),
    ClaudeModelInfo(id: 'claude-haiku-4-5-20251001', name: 'Haiku 4.5'),
  ];

  group('ClaudeModelInfo metadata', () {
    test('parses the CLI-published claudeModels metadata', () {
      final metadata = Metadata.fromJson({
        'host': 'h',
        'claudeModels': [
          {
            'id': 'opus',
            'name': 'Opus 5.5',
            'description': 'For complex work',
            'efforts': ['low', 'max', ''],
          },
          {'id': 'claude-haiku-4-5-20251001', 'efforts': []},
          {'name': 'missing id'},
          'garbage',
        ],
      });
      final models = metadata.claudeModels!;
      expect(models.map((m) => m.id), ['opus', 'claude-haiku-4-5-20251001']);
      expect(models.first.name, 'Opus 5.5');
      expect(models.first.description, 'For complex work');
      expect(models.first.efforts, ['low', 'max']);
      expect(models.last.name, 'claude-haiku-4-5-20251001');
      expect(models.last.efforts, isEmpty);
    });

    test('is null when the CLI published no catalog', () {
      expect(Metadata.fromJson({'host': 'h'}).claudeModels, isNull);
    });
  });

  group('ChatModelMode.fromClaudeCatalog', () {
    test('keeps Default as the app entry and does not duplicate it', () {
      final models = ChatModelMode.fromClaudeCatalog(catalog);
      expect(models.first, ChatModelMode.defaultModel);
      expect(models.where((m) => m.isDefault), hasLength(1));
    });

    test('offers only the effort levels each model supports', () {
      final models = ChatModelMode.fromClaudeCatalog(catalog);
      final strings = models.map((m) => m.modeString).toList();
      expect(strings, contains('haiku:xhigh'));
      expect(strings, contains('claude-opus-4-6:max'));
      expect(strings, isNot(contains('claude-opus-4-6:xhigh')));
      expect(strings.where((s) => s.startsWith('claude-haiku-4-5-20251001')), [
        'claude-haiku-4-5-20251001',
      ]);
    });

    test('uses CLI display names and groups variants by model id', () {
      final models = ChatModelMode.fromClaudeCatalog(catalog);
      final haiku = models.firstWhere((m) => m.modeString == 'haiku');
      expect(haiku.label, 'Haiku 5.5');
      expect(haiku.modelSlug, 'haiku');
      expect(haiku.isClaude, isTrue);
      final effort = models.firstWhere((m) => m.modeString == 'haiku:high');
      expect(effort.modelSlug, 'haiku');
      expect(effort.reasoningEffort, 'high');
    });

    test('drops effort levels the app cannot express', () {
      final models = ChatModelMode.fromClaudeCatalog(const [
        ClaudeModelInfo(id: 'x', name: 'X', efforts: ['low', 'bogus', 'low']),
      ]);
      expect(models.map((m) => m.modeString), ['default', 'x', 'x:low']);
    });
  });

  group('ChatModelMode.availableForProfile for Claude', () {
    test('prefers the CLI catalog over the built-in tiers', () {
      final models = ChatModelMode.availableForProfile(
        flavor: 'claude',
        claudeCompatible: true,
        claudeCatalog: catalog,
      );
      expect(models.map((m) => m.modeString), contains('claude-opus-4-6'));
      expect(models.map((m) => m.modeString), isNot(contains('fable')));
    });

    test('falls back to built-in tiers, including haiku, without one', () {
      final models = ChatModelMode.availableForProfile(
        flavor: 'claude',
        claudeCompatible: true,
      );
      final strings = models.map((m) => m.modeString).toList();
      for (final tier in ['fable', 'sonnet', 'opus', 'haiku']) {
        expect(strings, contains(tier));
        expect(strings, contains('$tier:max'));
      }
    });

    test('ignores the catalog for third-party Anthropic gateways', () {
      final models = ChatModelMode.availableForProfile(
        flavor: 'claude',
        claudeCompatible: true,
        allowClaudeAliases: false,
        claudeCatalog: catalog,
      );
      expect(models, [ChatModelMode.defaultModel]);
    });
  });

  group('haiku selections', () {
    test('parse as Claude models and survive flavor normalization', () {
      for (final raw in ['haiku', 'haiku:high']) {
        final parsed = ChatModelMode.fromString(raw);
        expect(parsed.isClaude, isTrue, reason: raw);
        expect(parsed.modelSlug, 'haiku', reason: raw);
        expect(
          ChatModelMode.normalizeForFlavor(parsed, 'claude').modeString,
          raw,
        );
      }
    });
  });
}
