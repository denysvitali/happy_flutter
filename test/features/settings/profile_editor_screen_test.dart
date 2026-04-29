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
          'openai' => 'OpenAI',
          _ => profile.name,
        };
        expect(find.text(expectedLabel), findsOneWidget);
      }
    });

    testWidgets('obscures environment values by default', (tester) async {
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

      final obscuredFields = tester.widgetList<EditableText>(
        find.byWidgetPredicate(
          (widget) => widget is EditableText && widget.obscureText,
        ),
      );
      expect(obscuredFields, isNotEmpty);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
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

      final keyTop = tester.getTopLeft(find.text('Key')).dy;
      final valueTop = tester.getTopLeft(find.text('Value')).dy;

      expect(valueTop, greaterThan(keyTop));
    });
  });
}
