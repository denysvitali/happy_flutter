import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/sessions/pick_profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PickProfileScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StubSettingsNotifier(Settings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PickProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // AppBar title should be present
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders "None" option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StubSettingsNotifier(Settings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PickProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('None'), findsOneWidget);
      expect(
        find.text('Use default configuration'),
        findsOneWidget,
      );
    });

    testWidgets('renders all built-in profiles',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StubSettingsNotifier(Settings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PickProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that built-in profile names appear
      for (final profile in builtInProfiles) {
        expect(
          find.text(profile.name),
          findsOneWidget,
        );
      }
    });

    testWidgets('shows check icon for selected profile',
        (tester) async {
      final settings = Settings();
      settings.lastUsedProfile = 'anthropic';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StubSettingsNotifier(settings),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PickProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The selected profile should show a check icon
      expect(
        find.byIcon(Icons.check_circle_rounded),
        findsOneWidget,
      );
    });

    testWidgets('shows BUILT-IN section header',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StubSettingsNotifier(Settings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PickProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('BUILT-IN'), findsOneWidget);
    });

    testWidgets('shows custom profile in list when set',
        (tester) async {
      final settings = Settings()
        ..profiles = [
          AIBackendProfile(
            id: 'custom-1',
            name: 'My Custom Profile',
            description: 'A custom backend',
            isBuiltIn: false,
          ),
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StubSettingsNotifier(settings),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PickProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll down to find custom profiles
      final listView = find.byType(ListView);
      await tester.fling(listView, const Offset(0, -500), 800);
      await tester.pumpAndSettle();

      expect(
        find.text('My Custom Profile'),
        findsOneWidget,
      );
    });

    testWidgets('does not show custom profile when none '
        'exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StubSettingsNotifier(Settings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PickProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('My Custom Profile'),
        findsNothing,
      );
    });
  });
}

// ─── Stub notifier ────────────────────────────────────────

class _StubSettingsNotifier extends SettingsNotifier {
  _StubSettingsNotifier(this._initial);
  final Settings _initial;

  @override
  Settings build() => _initial;
}
