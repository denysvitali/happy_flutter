import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/developer_screen.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  _StorageFreeSettingsNotifier([this._initial]);

  final Settings? _initial;

  @override
  Settings build() => _initial ?? Settings();

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

Settings _devModeSettings() {
  return Settings.fromJson({
    ...Settings().toJson(),
    'developerModeEnabled': true,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeveloperScreen', () {
    testWidgets('renders app bar with developer title', (tester) async {
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
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Developer'), findsOneWidget);
    });

    testWidgets('renders developer mode toggle', (tester) async {
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
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Developer Mode'), findsOneWidget);
      expect(find.byIcon(Icons.developer_mode), findsOneWidget);
    });

    testWidgets('shows disabled description when developer mode is off',
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
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Disabled - Tap 10 times to enable'),
        findsOneWidget,
      );
    });

    testWidgets('hides debug tools when developer mode is off',
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
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network Inspector'), findsNothing);
      expect(find.text('Logs'), findsNothing);
    });

    testWidgets('shows debug tools when developer mode is on',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(_devModeSettings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network Inspector'), findsOneWidget);
      expect(find.text('Logs'), findsOneWidget);
      expect(find.text('Encryption Debug'), findsOneWidget);
      expect(find.text('Session Debug'), findsOneWidget);
    });

    testWidgets('shows enabled description when developer mode is on',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(_devModeSettings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Enabled - Debug tools are visible'),
        findsOneWidget,
      );
    });

    testWidgets('shows testing section when developer mode is on',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(_devModeSettings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Notifications'), findsOneWidget);
    });

    testWidgets('shows cache and storage section when developer mode is on',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(_devModeSettings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal cache section
      await tester.scrollUntilVisible(
        find.text('Clear Cache'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear Cache'), findsOneWidget);
      expect(find.text('Reset Settings'), findsOneWidget);
    });

    testWidgets('shows build info section when developer mode is on',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(_devModeSettings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal build info section
      await tester.scrollUntilVisible(
        find.text('App Version'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('App Version'), findsOneWidget);
      expect(find.text('Build Number'), findsOneWidget);
      expect(find.text('Flutter Version'), findsOneWidget);
      expect(find.text('Dart Version'), findsOneWidget);
      expect(find.text('3.38.7'), findsOneWidget);
    });

    testWidgets('toggling developer mode on reveals debug tools',
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
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Network Inspector'), findsNothing);

      // Tap the toggle to enable developer mode
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeveloperScreen)),
      );
      expect(
        container.read(settingsNotifierProvider).developerModeEnabled,
        isTrue,
      );
      expect(find.text('Network Inspector'), findsOneWidget);
    });

    testWidgets('debug tools section shows network inspector icon',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(_devModeSettings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.network_check), findsOneWidget);
      expect(find.byIcon(Icons.terminal), findsOneWidget);
      expect(find.byIcon(Icons.security), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('cache section shows correct icons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(_devModeSettings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal cache section
      await tester.scrollUntilVisible(
        find.byIcon(Icons.delete_sweep),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
      expect(find.byIcon(Icons.restart_alt), findsOneWidget);
    });

    testWidgets('build info section shows correct icons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsNotifierProvider.overrideWith(
              () => _StorageFreeSettingsNotifier(_devModeSettings()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DeveloperScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to reveal build info section
      await tester.scrollUntilVisible(
        find.byIcon(Icons.info_outline),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.numbers), findsOneWidget);
      expect(find.byIcon(Icons.flutter_dash), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
    });
  });
}
