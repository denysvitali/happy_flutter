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

Widget _buildScreen(SettingsNotifier Function() notifier) {
  return ProviderScope(
    overrides: [settingsNotifierProvider.overrideWith(notifier)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProfilesScreen(),
    ),
  );
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
      await tester.pumpWidget(_buildScreen(_StorageFreeSettingsNotifier.new));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      // 'Profiles' appears in AppBar title and SettingsSection
      expect(find.text('Profiles'), findsWidgets);
    });

    testWidgets('renders None option', (tester) async {
      await tester.pumpWidget(_buildScreen(_StorageFreeSettingsNotifier.new));
      await tester.pumpAndSettle();

      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('never ships built-in presets as pre-populated rows', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(_StorageFreeSettingsNotifier.new));
      await tester.pumpAndSettle();

      expect(find.text('Anthropic (Default)'), findsNothing);
      expect(find.text('DeepSeek (Chat)'), findsNothing);
      expect(find.text('OpenAI (Codex)'), findsNothing);
      expect(find.text('Azure OpenAI'), findsNothing);
      expect(find.text('Qwen (Token Plan)'), findsNothing);
    });

    testWidgets('shows empty state with a create action when list is empty', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(_StorageFreeSettingsNotifier.new));
      await tester.pumpAndSettle();

      expect(find.text('No profiles yet'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets('renders add button in app bar', (tester) async {
      await tester.pumpWidget(_buildScreen(_StorageFreeSettingsNotifier.new));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.paste), findsOneWidget);
    });

    testWidgets('renders import button in app bar', (tester) async {
      await tester.pumpWidget(_buildScreen(_StorageFreeSettingsNotifier.new));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.paste), findsOneWidget);
    });

    testWidgets('tags rows with built-in and custom badges', (tester) async {
      final preset = Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'deepseek',
            name: 'My DeepSeek',
            isBuiltIn: true,
            compatibility: const ProfileCompatibility(
              claude: true,
              codex: false,
              agy: false,
            ),
          ),
          AIBackendProfile(
            id: 'custom_1',
            name: 'My Proxy',
            compatibility: const ProfileCompatibility(
              claude: true,
              codex: false,
              agy: false,
            ),
          ),
        ];

      await tester.pumpWidget(
        _buildScreen(() => _PresetSettingsNotifier(preset)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Built-in'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('every row exposes edit, duplicate and delete actions', (
      tester,
    ) async {
      // A preset-derived (isBuiltIn) row used to be undeletable; every
      // stored row must offer the full action set now.
      final preset = Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'deepseek',
            name: 'My DeepSeek',
            isBuiltIn: true,
            compatibility: const ProfileCompatibility(
              claude: true,
              codex: false,
              agy: false,
            ),
          ),
        ];

      await tester.pumpWidget(
        _buildScreen(() => _PresetSettingsNotifier(preset)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Duplicate Profile'), findsOneWidget);
      expect(find.text('Delete Profile'), findsOneWidget);
    });

    testWidgets('deleting a preset-derived row removes it', (tester) async {
      final preset = Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'deepseek',
            name: 'My DeepSeek',
            isBuiltIn: true,
            compatibility: const ProfileCompatibility(
              claude: true,
              codex: false,
              agy: false,
            ),
          ),
        ];

      await tester.pumpWidget(
        _buildScreen(() => _PresetSettingsNotifier(preset)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfilesScreen)),
      );
      expect(container.read(settingsNotifierProvider).profiles, isEmpty);
      expect(find.text('My DeepSeek'), findsNothing);
      expect(find.text('No profiles yet'), findsOneWidget);
    });

    testWidgets('selected stored profile shows check icon', (tester) async {
      final preset = Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'custom_1',
            name: 'My Proxy',
            compatibility: const ProfileCompatibility(
              claude: true,
              codex: false,
              agy: false,
            ),
          ),
        ]
        ..lastUsedProfile = 'custom_1'
        ..lastUsedAgent = 'claude';

      await tester.pumpWidget(
        _buildScreen(() => _PresetSettingsNotifier(preset)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping a stored profile selects it', (tester) async {
      final preset = Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'custom_1',
            name: 'My Proxy',
            compatibility: const ProfileCompatibility(
              claude: true,
              codex: false,
              agy: false,
            ),
          ),
        ];

      await tester.pumpWidget(
        _buildScreen(() => _PresetSettingsNotifier(preset)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Proxy'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ProfilesScreen)),
      );
      expect(
        container
            .read(settingsNotifierProvider)
            .lastUsedProfileForAgent('claude'),
        equals('custom_1'),
      );
      expect(
        container.read(settingsNotifierProvider).lastUsedProfile,
        'custom_1',
      );
    });

    testWidgets('tapping None clears selected profile', (tester) async {
      final preset = Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'custom_1',
            name: 'My Proxy',
            compatibility: const ProfileCompatibility(
              claude: true,
              codex: false,
              agy: false,
            ),
          ),
        ]
        ..lastUsedProfile = 'custom_1'
        ..lastUsedAgent = 'claude';

      await tester.pumpWidget(
        _buildScreen(() => _PresetSettingsNotifier(preset)),
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
        _buildScreen(() => _PresetSettingsNotifier(preset)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Claude Only'), findsOneWidget);
      expect(find.text('Codex Only'), findsOneWidget);
    });
  });
}
