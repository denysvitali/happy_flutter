import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/profiles_screen.dart';

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

/// Settings notifier that starts with a pre-configured state.
class _PresetSettingsNotifier extends _StorageFreeSettingsNotifier {
  _PresetSettingsNotifier(this._preset);

  final Settings _preset;

  @override
  Settings build() => _preset;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfilesScreen', () {
    setUp(() {
      // Force a phone-sized viewport (< AppBreakpoint.tablet=600) so the
      // screen renders in single-pane mode. The default 800x600 test
      // viewport otherwise triggers MasterDetailScaffold's tablet layout,
      // which (a) clips the master ListView so off-screen sections like
      // "Codex" don't render and (b) routes profile taps into the editor
      // pane instead of updating lastUsedProfile.
      final binding = TestWidgetsFlutterBinding.instance;
      binding.platformDispatcher.views.first.physicalSize = const Size(
        390 * 3,
        4000 * 3,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 3.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('renders app bar with profiles title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      // 'Profiles' appears in AppBar title and SettingsSection
      expect(find.text('Profiles'), findsWidgets);
    });

    testWidgets('renders None option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('renders built-in profiles', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anthropic (Default)'), findsOneWidget);
      expect(find.text('DeepSeek (Chat)'), findsOneWidget);
      expect(find.text('OpenAI (Codex)'), findsOneWidget);
      expect(find.text('Azure OpenAI'), findsOneWidget);
    });

    testWidgets('renders add button in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('renders import button in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.paste), findsOneWidget);
    });

    testWidgets('selected profile shows check icon', (tester) async {
      final preset = Settings.fromJson({
        ...Settings().toJson(),
        'lastUsedProfile': 'anthropic',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _PresetSettingsNotifier(preset),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The check icon should appear for the selected profile
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping None clears selected profile', (tester) async {
      final preset = Settings.fromJson({
        ...Settings().toJson(),
        'lastUsedProfile': 'anthropic',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _PresetSettingsNotifier(preset),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfilesScreen)),
      );
      expect(
        container
            .read(settingsNotifierProvider)
            .lastUsedProfileForAgent('claude'),
        isNull,
      );
      expect(container.read(settingsNotifierProvider).lastUsedAgent, 'claude');
      expect(container.read(settingsNotifierProvider).lastUsedProfile, isNull);
    });

    testWidgets('tapping built-in profile selects it', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('DeepSeek (Chat)'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfilesScreen)),
      );
      expect(
        container
            .read(settingsNotifierProvider)
            .lastUsedProfileForAgent('claude'),
        equals('deepseek'),
      );
      expect(container.read(settingsNotifierProvider).lastUsedAgent, 'claude');
      expect(
        container.read(settingsNotifierProvider).lastUsedProfile,
        'deepseek',
      );
    });

    testWidgets('shows profile descriptions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Official Anthropic Claude API'), findsOneWidget);
      expect(find.text('OpenAI Codex API'), findsOneWidget);
    });

    testWidgets('shows custom profiles only in compatible agent sections', (
      tester,
    ) async {
      final preset = Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'claude-only',
            name: 'Claude Only',
            compatibility: const ProfileCompatibility(
              claude: true,
              codex: false,
              agy: false,
            ),
          ),
          AIBackendProfile(
            id: 'codex-only',
            name: 'Codex Only',
            compatibility: const ProfileCompatibility(
              claude: false,
              codex: true,
              agy: false,
            ),
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _PresetSettingsNotifier(preset),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ProfilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Claude Only'), findsOneWidget);
      expect(find.text('Codex Only'), findsOneWidget);
    });
  });
}
