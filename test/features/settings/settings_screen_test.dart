import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/settings_update.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/settings_screen.dart';

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(this._initial);

  final Settings _initial;

  @override
  Settings build() => _initial;

  @override
  Future<void> updateSetting<T>(String key, T value) async {
    state = SettingsUpdate.copyWithUpdated(state, key, value);
  }
}

Widget _buildApp(Settings initialSettings) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _TestSettingsNotifier(initialSettings),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('search filters settings sections', (tester) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    expect(find.text('Sync needs attention'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'server');
    await tester.pumpAndSettle();

    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Sync needs attention'), findsNothing);
  });

  testWidgets('workflow preset applies existing settings', (tester) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Focus'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final settings = container.read(settingsNotifierProvider);

    expect(settings.hideToolCalls, isTrue);
    expect(settings.expandTodos, isFalse);
    expect(settings.ttsEnabled, isFalse);
    expect(settings.compactSessionView, isTrue);
    expect(settings.hideInactiveSessions, isTrue);
    expect(settings.sessionsViewStyle, 'unread_focus');
  });
}
