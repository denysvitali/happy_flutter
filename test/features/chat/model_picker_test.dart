import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';
import 'package:happy_flutter/features/chat/widgets/picker_sheets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPickerHost(
    WidgetTester tester, {
    required List<ChatModelMode> models,
  }) async {
    // The Claude picker now has up to 13 tiles (default + sonnet/opus +
    // 5 efforts each). Use a tall viewport so every tile is hit-testable.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModelPickerSheet(
                    context,
                    ChatModelMode.defaultModel,
                    models,
                    (_) {},
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('codex sessions show OpenAI model and effort choices', (
    tester,
  ) async {
    final models = ChatModelMode.fromCodexCatalog([
      const CodexModelInfo(
        slug: 'gpt-5.5',
        displayName: 'GPT-5.5',
        supportedReasoningEfforts: ['low', 'medium'],
      ),
      const CodexModelInfo(
        slug: 'gpt-5.4-mini',
        displayName: 'GPT-5.4 Mini',
        supportedReasoningEfforts: ['medium', 'high'],
      ),
    ]);

    await pumpPickerHost(tester, models: models);

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('GPT-5.5'), findsOneWidget);
    expect(find.text('GPT-5.4 Mini'), findsOneWidget);
    expect(find.text('Effort'), findsOneWidget);
    // Effort sub-list shows just the effort label.
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('High'), findsNothing);

    await tester.tap(find.text('GPT-5.4 Mini'));
    await tester.pumpAndSettle();

    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('Sonnet'), findsNothing);
    expect(find.text('Opus'), findsNothing);
  });

  testWidgets('claude sessions show sonnet, opus, and effort levels', (
    tester,
  ) async {
    await pumpPickerHost(
      tester,
      models: ChatModelMode.availableForFlavor('claude'),
    );

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Fable'), findsOneWidget);
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
    expect(find.text('Effort'), findsOneWidget);
    // The effort levels are rendered as labels under a slider.
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.text('XHigh'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);

    // Tap Opus to switch to its effort sub-list.
    await tester.tap(find.text('Opus'));
    await tester.pumpAndSettle();
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);
  });

  testWidgets('claude effort selection emits the wire-format string', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModelPickerSheet(
                    context,
                    ChatModelMode.defaultModel,
                    ChatModelMode.availableForFlavor('claude'),
                    (m) => selected = m.modeString,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opus'));
    await tester.pumpAndSettle();
    // Drag the effort slider fully to the right → Max.
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(selected, 'opus:max');
  });

  testWidgets('fable effort selection emits the wire-format string', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModelPickerSheet(
                    context,
                    ChatModelMode.defaultModel,
                    ChatModelMode.availableForFlavor('claude'),
                    (m) => selected = m.modeString,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fable'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(1000, 0));
    await tester.pumpAndSettle();
    expect(selected, 'fable:max');
  });

  test('fromString round-trips the fable tier and its effort variants', () {
    expect(ChatModelMode.fromString('fable'), ChatModelMode.fable);
    final fableHigh = ChatModelMode.fromString('fable:high');
    expect(fableHigh.modeString, 'fable:high');
    expect(fableHigh.modelSlug, 'fable');
    expect(fableHigh.reasoningEffort, 'high');
    expect(fableHigh.isClaude, isTrue);
    expect(fableHigh.isCustom, isFalse);
  });

  testWidgets('custom models can be removed from the picker', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = Settings()
      ..customModelModes = ['claude-opus-4-8', 'claude-sonnet-4-6'];
    List<String>? lastSaved;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModelPickerSheet(
                    context,
                    ChatModelMode.defaultModel,
                    ChatModelMode.availableForFlavor('claude'),
                    (_) {},
                    settings: settings,
                    onCustomModelsChanged: (models) => lastSaved = models,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('claude-opus-4-8'), findsOneWidget);
    expect(find.text('claude-sonnet-4-6'), findsOneWidget);

    // Each custom row exposes a remove button.
    final removeButtons = find.byIcon(Icons.close_rounded);
    expect(removeButtons, findsNWidgets(2));

    await tester.tap(removeButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('claude-opus-4-8'), findsNothing);
    expect(find.text('claude-sonnet-4-6'), findsOneWidget);
    expect(lastSaved, ['claude-sonnet-4-6']);
  });

  group('provider-owned Codex model effort picker', () {
    test('providerOwnedCodexEfforts fixes the slug and offers efforts', () {
      final models = ChatModelMode.providerOwnedCodexEfforts('qwen3.7-max');

      // First entry is the effort-less "Auto" variant (provider default).
      expect(models.first.modeString, 'qwen3.7-max');
      expect(models.first.hasEffort, isFalse);
      expect(models.first.isCodex, isTrue);
      expect(models.first.modelSlug, 'qwen3.7-max');

      // Followed by the standard Codex effort range, all on the same slug.
      final efforts = models.sublist(1);
      expect(
        efforts.map((m) => m.modeString).toList(),
        ['qwen3.7-max:low', 'qwen3.7-max:medium', 'qwen3.7-max:high'],
      );
      for (final m in efforts) {
        expect(m.modelSlug, 'qwen3.7-max');
        expect(m.isCodex, isTrue);
      }
    });

    test('strips an existing effort suffix from the provider model', () {
      final models = ChatModelMode.providerOwnedCodexEfforts(
        'qwen3.7-max:high',
      );
      expect(models.first.modeString, 'qwen3.7-max');
      expect(
        models.map((m) => m.modelSlug).toSet(),
        {'qwen3.7-max'},
      );
    });

    test('availableForProfile prefers the provider-owned model over the '
        'machine catalog', () {
      final catalog = ChatModelMode.fromCodexCatalog([
        const CodexModelInfo(
          slug: 'gpt-5.5',
          displayName: 'GPT-5.5',
          supportedReasoningEfforts: ['low', 'medium'],
        ),
      ]);

      final models = ChatModelMode.availableForProfile(
        flavor: 'codex',
        claudeCompatible: false,
        codexModels: catalog,
        providerOwnedCodexModel: 'qwen3.7-max',
      );

      // The OpenAI catalog model must not leak in when the provider owns
      // the model; only the provider slug + its effort variants appear.
      expect(models.any((m) => m.modelSlug == 'gpt-5.5'), isFalse);
      expect(
        models.map((m) => m.modeString).toList(),
        [
          'qwen3.7-max',
          'qwen3.7-max:low',
          'qwen3.7-max:medium',
          'qwen3.7-max:high',
        ],
      );
    });

    test('availableForProfile falls back to the catalog when no provider '
        'model is owned', () {
      final catalog = ChatModelMode.fromCodexCatalog([
        const CodexModelInfo(
          slug: 'gpt-5.5',
          displayName: 'GPT-5.5',
          supportedReasoningEfforts: ['low', 'medium'],
        ),
      ]);

      final models = ChatModelMode.availableForProfile(
        flavor: 'codex',
        claudeCompatible: false,
        codexModels: catalog,
      );
      expect(models, catalog);
    });

    testWidgets('shows an effort slider and emits slug:effort', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? selected;
      final models = ChatModelMode.providerOwnedCodexEfforts('qwen3.7-max');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    showModelPickerSheet(
                      context,
                      ChatModelMode.fromString('qwen3.7-max'),
                      models,
                      (m) => selected = m.modeString,
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The provider model family is shown with an effort slider.
      expect(find.text('qwen3.7-max'), findsWidgets);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);

      // Drag the effort slider fully right -> High, emitting slug:effort.
      await tester.drag(find.byType(Slider), const Offset(1000, 0));
      await tester.pumpAndSettle();
      expect(selected, 'qwen3.7-max:high');
    });
  });

  test('raw model normalization drops Claude effort modes for Codex', () {
    expect(ChatModelMode.normalizeRawForFlavor('opus:max', 'codex'), 'default');
    expect(
      ChatModelMode.normalizeRawForFlavor('MiniMax-M3', 'codex'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor('MiniMax-M3:high', 'codex'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor('claude-fable-5', 'codex'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor('anthropic/claude-opus-4-6', 'codex'),
      'default',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor('sonnet:high', 'codex'),
      'default',
    );
  });

  test('raw model normalization preserves known Codex models', () {
    expect(
      ChatModelMode.normalizeRawForFlavor('gpt-5.5:high', 'codex'),
      'gpt-5.5:high',
    );
    expect(ChatModelMode.fromString('gpt-5-codex').isCodex, isTrue);
    expect(
      ChatModelMode.normalizeRawForFlavor('gpt-5-codex', 'codex'),
      'gpt-5-codex',
    );
  });

  test('raw model normalization preserves Qwen Token Plan slugs for Codex',
      () {
        // The daemon's get-codex-models catalog only reports gpt-*; the
        // Token Plan slugs must survive normalization via the static
        // catalog extension, with and without a reasoning-effort suffix.
        for (final slug in qwenTokenPlanCodexModels) {
          expect(ChatModelMode.isKnownCodexModelString(slug), isTrue);
          expect(ChatModelMode.fromString(slug).isCodex, isTrue);
          expect(ChatModelMode.normalizeRawForFlavor(slug, 'codex'), slug);
          expect(
            ChatModelMode.normalizeRawForFlavor('$slug:high', 'codex'),
            '$slug:high',
          );
        }
      });

  test('raw model normalization preserves provider-owned strings', () {
    expect(
      ChatModelMode.normalizeRawForFlavor('claude-fable-5', 'claude'),
      'claude-fable-5',
    );
    expect(
      ChatModelMode.normalizeRawForFlavor(
        'anthropic/claude-opus-4-6',
        'claude',
      ),
      'anthropic/claude-opus-4-6',
    );
    expect(ChatModelMode.normalizeRawForFlavor('GLM-5', 'claude'), 'GLM-5');
    expect(
      ChatModelMode.normalizeRawForFlavor('MiniMax-Text-01', 'claude'),
      'MiniMax-Text-01',
    );
  });

  group('profile-configured models allowlist', () {
    test('normalizeForFlavor keeps profile models instead of dropping to '
        'default', () {
      // Regression: tapping a profile-configured model ('GLM-5') ran
      // through normalizeForFlavor in _onModelModeChanged, which mapped
      // the unknown slug to 'default' — the sheet closed but the model
      // never took effect.
      final picked = ChatModelMode.fromString('GLM-5');
      expect(
        ChatModelMode.normalizeForFlavor(picked, 'claude'),
        ChatModelMode.defaultModel,
      );
      expect(
        ChatModelMode.normalizeForFlavor(
          picked,
          'claude',
          allowedRawModels: const ['GLM-5', 'GLM-4.6'],
        ),
        picked,
      );
    });

    test('normalizeForFlavor keeps effort-suffixed profile models', () {
      final picked = ChatModelMode.fromString('GLM-5:high');
      expect(
        ChatModelMode.normalizeForFlavor(
          picked,
          'claude',
          allowedRawModels: const ['GLM-5', 'GLM-5:high'],
        ).modeString,
        'GLM-5:high',
      );
    });

    test('allowlist does not leak into Codex sessions', () {
      // A plain provider slug parses with no flavor; on a Codex session
      // it must still normalize to default even when allowlisted —
      // profile models are only offered for Claude-compatible sessions.
      final picked = ChatModelMode.fromString('GLM-5');
      expect(
        ChatModelMode.normalizeForFlavor(
          picked,
          'codex',
          allowedRawModels: const ['GLM-5'],
        ),
        ChatModelMode.defaultModel,
      );
      expect(
        ChatModelMode.normalizeRawForFlavor(
          'GLM-5:high',
          'codex',
          allowedRawModels: const ['GLM-5:high'],
        ),
        'default',
      );
    });

    test('normalizeRawForFlavor keeps effort-suffixed profile models on '
        'Claude sessions', () {
      // Without the allowlist this parses as a Codex variant and is
      // rewritten to 'default', losing the saved pick on restore.
      expect(
        ChatModelMode.normalizeRawForFlavor('GLM-5:high', 'claude'),
        'default',
      );
      expect(
        ChatModelMode.normalizeRawForFlavor(
          'GLM-5:high',
          'claude',
          allowedRawModels: const ['GLM-5', 'GLM-5:high'],
        ),
        'GLM-5:high',
      );
    });
  });

  testWidgets('plain profile slugs render next to effort-suffixed family '
      'and commit on tap', (tester) async {
    // Regression: 'GLM-5' parses with no modelSlug, so when the profile
    // list also contained 'GLM-5:high' (which has a slug) the grouped
    // picker dropped the plain variant entirely.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? selected;
    final models = ChatModelMode.availableForProfile(
      flavor: 'claude',
      claudeCompatible: true,
      profileModels: const ['GLM-5', 'GLM-5:high'],
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModelPickerSheet(
                    context,
                    ChatModelMode.defaultModel,
                    models,
                    (model) => selected = model.modeString,
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // The plain slug is visible as its own tile even though the grouped
    // family ('GLM 5') is also present.
    expect(find.text('GLM-5'), findsOneWidget);
    expect(find.text('GLM 5'), findsOneWidget);

    await tester.tap(find.text('GLM-5'));
    await tester.pumpAndSettle();

    // Sheet pops and the exact raw string is committed.
    expect(selected, 'GLM-5');
    expect(find.text('GLM-5'), findsNothing);
  });
}
