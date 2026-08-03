// The API-key reveal toggle is an icon-only IconButton whose meaning
// flips with state: while the key is obscured it offers "Show API key",
// and once revealed it offers "Hide API key". A tooltip that does not
// follow the state is worse than none, so both directions are pinned.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/profile_wizard_screen.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StorageFreeSettingsNotifier(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProfileWizardScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('API key reveal tooltip follows the obscured state', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Step 1: pick a provider so the key step can build.
    await tester.ensureVisible(find.text('Anthropic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();

    // Step 2: advance to the API key form.
    await tester.ensureVisible(find.text('Continue').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue').first);
    await tester.pumpAndSettle();

    Tooltip tooltipFor(IconData icon) {
      return tester.widget<Tooltip>(
        find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(Tooltip),
        ),
      );
    }

    // Obscured: the control offers to reveal.
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    expect(tooltipFor(Icons.visibility_off).message, 'Show API key');

    await tester.ensureVisible(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();

    // Revealed: the same control offers the inverse.
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(tooltipFor(Icons.visibility).message, 'Hide API key');
  });
}
