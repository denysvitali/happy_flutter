import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/features_settings_screen.dart';

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

  testWidgets('renders hide inactive sessions toggle and updates setting', (
    tester,
  ) async {
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
          home: const FeaturesSettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hide Inactive Sessions'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FeaturesSettingsScreen)),
    );
    expect(
      container.read(settingsNotifierProvider).hideInactiveSessions,
      isFalse,
    );

    await tester.tap(find.text('Hide Inactive Sessions'));
    await tester.pumpAndSettle();

    expect(
      container.read(settingsNotifierProvider).hideInactiveSessions,
      isTrue,
    );
  });
}
