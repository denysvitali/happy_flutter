import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/language_settings_screen.dart';

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

  group('LanguageSettingsScreen', () {
    testWidgets('renders app bar with language title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Language'), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders search field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders automatic detection option', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Automatic'), findsOneWidget);
      expect(find.textContaining('Use device language'), findsOneWidget);
    });

    testWidgets('renders language list with common languages',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // English should be visible (it's at the top of the list)
      expect(find.text('English'), findsWidgets);
      // Multiple language cards should be rendered
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('search filters language list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search for German by English name
      await tester.enterText(find.byType(TextField), 'German');
      await tester.pumpAndSettle();

      // German variants should be found (de-DE, de-AT both show as Deutsch)
      expect(find.text('Deutsch'), findsWidgets);

      // English should not appear in filtered results
      expect(find.text('English'), findsNothing);
    });

    testWidgets('shows clear button when search has text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byType(TextField), 'German');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clear button resets search', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyznotfound');
      await tester.pumpAndSettle();

      expect(find.text('No languages found'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('No languages found'), findsNothing);
      expect(find.text('Automatic'), findsOneWidget);
    });

    testWidgets('search with no results shows empty message',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'zzzzz_nonexistent_language',
      );
      await tester.pumpAndSettle();

      expect(find.text('No languages found'), findsOneWidget);
    });

    testWidgets('shows check icon for current language selection',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(LanguageSettingsScreen)),
      );

      // Set preferred language to English US (visible at top)
      container
          .read(settingsNotifierProvider.notifier)
          .updateSetting('preferredLanguage', 'en-US');
      await tester.pump();

      // Verify the provider state is updated
      expect(
        container.read(settingsNotifierProvider).preferredLanguage,
        'en-US',
      );

      // Check icons should be visible for the selected language
      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('renders divider between automatic and language list',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('language options are rendered as Cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LanguageSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Each language option is a Card containing a ListTile
      expect(find.byType(Card), findsWidgets);
      expect(find.byType(ListTile), findsWidgets);
    });
  });
}
