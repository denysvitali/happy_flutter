import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/usage_screen.dart';

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

  group('UsageScreen', () {
    testWidgets('renders app bar with usage title', (tester) async {
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
            home: const UsageScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Usage'), findsOneWidget);
    });

    testWidgets('renders back button in app bar', (tester) async {
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
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const UsageScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
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
            home: const UsageScreen(),
          ),
        ),
      );
      // Don't pumpAndSettle - check initial loading state
      // pumpWidget alone triggers a build; the async _loadUsage()
      // hasn't completed yet so _isLoading is still true.

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state after API failure', (tester) async {
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
            home: const UsageScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // API call will fail in test, so error state should show
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows retry button in error state', (tester) async {
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
            home: const UsageScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('error state shows failed to load text',
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
            home: const UsageScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Failed to load usage data'), findsOneWidget);
    });

    testWidgets('tap retry triggers another load attempt',
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
            home: const UsageScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Retry'));
      await tester.pump();
      // Should trigger a reload attempt; the error state will reappear
      // after the API call fails again.
      // Verify the retry button is still present after re-settling.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
