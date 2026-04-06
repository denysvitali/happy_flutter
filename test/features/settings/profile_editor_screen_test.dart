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

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        settingsNotifierProvider.overrideWith(
          () => _StorageFreeSettingsNotifier(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfileEditorScreen(),
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
  });
}
