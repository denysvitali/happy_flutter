import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/profile_editor_screen.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> updateSetting<T>(String key, T value) async {
    state = _applyUpdate(state, key, value);
  }

  Settings _applyUpdate(Settings current, String key, dynamic value) {
    final json = current.toJson();
    json[key] = value;
    return Settings.fromJson(json);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({AIBackendProfile? existing, Size? size}) {
    final child = ProviderScope(
      overrides: [
        settingsNotifierProvider.overrideWith(
          () => _StorageFreeSettingsNotifier(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileEditorScreen(existing: existing),
      ),
    );

    if (size == null) return child;

    return ProviderScope(
      overrides: [
        settingsNotifierProvider.overrideWith(
          () => _StorageFreeSettingsNotifier(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: ProfileEditorScreen(existing: existing),
            ),
          ),
        ),
      ),
    );
  }

  Iterable<EditableText> obscuredFields(WidgetTester tester) {
    return tester.widgetList<EditableText>(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.obscureText,
      ),
    );
  }

  group('ProfileEditorScreen', () {
    testWidgets('quick setup renders all built-in profile options', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      for (final profile in builtInProfiles) {
        final expectedLabel = switch (profile.id) {
          'anthropic' => 'Anthropic',
          'deepseek' => 'DeepSeek',
          'zai' => 'Z.AI GLM',
          'minimax' => 'MiniMax',
          'xiaomi-mimo' => 'Xiaomi MiMo',
          'qwen' => 'Qwen',
          'openai' => 'OpenAI',
          'qwen-token-plan-codex' => 'Qwen (Codex)',
          _ => profile.name,
        };
        expect(find.text(expectedLabel), findsOneWidget);
      }
    });

    testWidgets('obscures secret environment values by default', (
      tester,
    ) async {
      final profile = AIBackendProfile(
        id: 'custom_env',
        name: 'Env test',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_AUTH_TOKEN',
            value: 'secret-token',
          ),
        ],
      );

      await tester.pumpWidget(buildSubject(existing: profile));
      await tester.pumpAndSettle();

      expect(obscuredFields(tester), isNotEmpty);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('shows non-secret environment values without a toggle', (
      tester,
    ) async {
      final profile = AIBackendProfile(
        id: 'custom_env',
        name: 'Env test',
        environmentVariables: [
          EnvironmentVariable(
            name: 'ANTHROPIC_BASE_URL',
            value: 'https://api.anthropic.com',
          ),
          EnvironmentVariable(
            name: 'ANTHROPIC_MODEL',
            value: 'claude-opus-4-5',
          ),
        ],
      );

      await tester.pumpWidget(buildSubject(existing: profile));
      await tester.pumpAndSettle();

      expect(obscuredFields(tester), isEmpty);
      expect(find.byIcon(Icons.visibility_off), findsNothing);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('renders configured Codex providers', (tester) async {
      final profile = AIBackendProfile(
        id: 'custom-codex',
        name: 'Custom Codex',
        codexModelProvider: 'llm-proxy',
        codexProviders: [
          CodexProviderConfig(
            id: 'llm-proxy',
            name: 'LLM Proxy',
            baseUrl: 'http://llm-proxy.k2.k8s.best/v1',
            envKey: 'LLM_PROXY_API_KEY',
          ),
        ],
      );

      await tester.pumpWidget(buildSubject(existing: profile));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.text('Codex providers'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'llm-proxy'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'LLM_PROXY_API_KEY'),
        findsOneWidget,
      );
    });

    testWidgets('masks the value live when the key becomes secret', (
      tester,
    ) async {
      final profile = AIBackendProfile(
        id: 'custom_env',
        name: 'Env test',
        environmentVariables: [
          EnvironmentVariable(
            name: 'MY_BASE_URL',
            value: 'https://example.com',
          ),
        ],
      );

      await tester.pumpWidget(buildSubject(existing: profile));
      await tester.pumpAndSettle();
      expect(obscuredFields(tester), isEmpty);
      expect(find.byIcon(Icons.visibility_off), findsNothing);

      // Field order: name, description, env key, env value.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'MY_BASE_URL'),
        'MY_API_KEY',
      );
      await tester.pump();

      expect(obscuredFields(tester), isNotEmpty);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('manual reveal resets when the key name changes', (
      tester,
    ) async {
      final profile = AIBackendProfile(
        id: 'custom_env',
        name: 'Env test',
        environmentVariables: [
          EnvironmentVariable(name: 'FIRST_TOKEN', value: 'secret-token'),
        ],
      );

      await tester.pumpWidget(buildSubject(existing: profile));
      await tester.pumpAndSettle();
      expect(obscuredFields(tester), isNotEmpty);

      // Reveal the secret. The toggle can sit below the 800x600 test
      // viewport, so scroll it on-screen before tapping.
      await tester.ensureVisible(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();
      expect(obscuredFields(tester), isEmpty);

      // Renaming the key re-masks fail-closed, even to another
      // secret name. Target the key field by its current value: a
      // global TextFormField index breaks once ensureVisible scrolls
      // the name/description fields out of the lazy ListView.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'FIRST_TOKEN'),
        'SECOND_TOKEN',
      );
      await tester.pump();
      expect(obscuredFields(tester), isNotEmpty);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('env row actions expose tooltips', (tester) async {
      final profile = AIBackendProfile(
        id: 'custom_env',
        name: 'Env test',
        environmentVariables: [EnvironmentVariable(name: 'FOO', value: 'bar')],
      );

      await tester.pumpWidget(buildSubject(existing: profile));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Import from script'), findsOneWidget);
      expect(find.byTooltip('Add variable'), findsOneWidget);
      expect(find.byTooltip('Remove variable'), findsOneWidget);
    });

    testWidgets('stacks environment fields on narrow screens', (tester) async {
      final profile = AIBackendProfile(
        id: 'custom_env',
        name: 'Env test',
        environmentVariables: [
          EnvironmentVariable(name: 'OPENAI_API_KEY', value: 'secret-token'),
        ],
      );

      await tester.pumpWidget(
        buildSubject(existing: profile, size: const Size(390, 844)),
      );
      await tester.pumpAndSettle();

      // The env section starts below the fold on a phone-size viewport
      // (the codex provider hint makes the agent-compatibility card
      // taller), and the lazy ListView has not built it yet — drag the
      // form until the row exists before measuring.
      await tester.scrollUntilVisible(
        find.widgetWithText(TextFormField, 'OPENAI_API_KEY'),
        100,
        // Every TextField embeds its own Scrollable; drag the main
        // form ListView (the first in tree order).
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final keyTop = tester.getTopLeft(find.text('Key')).dy;
      final valueTop = tester.getTopLeft(find.text('Value')).dy;

      expect(valueTop, greaterThan(keyTop));
    });
  });
}
