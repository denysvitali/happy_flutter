// The sidebar header's navigation icons are icon-only tap targets, so
// the only accessible name they can have is the tooltip/semantics label
// that `_buildNavIcon` now requires. These tests pin both header icons
// and prove the wrapper does not swallow the tap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/components/sidebar_view.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';

class _StorageFreeSettingsNotifier extends SettingsNotifier {
  @override
  Future<void> updateSetting<T>(String key, T value) async {
    final json = state.toJson();
    json[key] = value;
    state = Settings.fromJson(json);
  }
}

/// Keeps the socket client out of the widget test.
class _OfflineConnectionNotifier extends ConnectionNotifier {
  @override
  ConnectionStatus build() => ConnectionStatus.disconnected;
}

Widget _wrap({VoidCallback? onNewSession}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _StorageFreeSettingsNotifier(),
      ),
      connectionNotifierProvider.overrideWith(
        () => _OfflineConnectionNotifier(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SidebarView(
          onNewSession: onNewSession,
          // Keep the session list out of this test: only the header's
          // nav icons are under assertion here.
          content: const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

Tooltip _tooltipFor(WidgetTester tester, IconData icon) {
  return tester.widget<Tooltip>(
    find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(Tooltip),
    ),
  );
}

/// The sidebar is a tablet/desktop surface; at the default 800px test
/// viewport it clamps to 250px and the header's fixed children overflow.
/// Use a desktop-sized logical viewport so the header lays out as it
/// does in production.
void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(2560, 1600);
  tester.view.devicePixelRatio = 2.0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SidebarView nav icons', () {
    testWidgets('settings and new-session icons carry tooltips', (
      tester,
    ) async {
      _useDesktopViewport(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(_tooltipFor(tester, Icons.settings_outlined).message, 'Settings');
      expect(_tooltipFor(tester, Icons.add).message, 'New Session');
    });

    testWidgets('nav icons expose a button semantics label', (tester) async {
      _useDesktopViewport(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.byIcon(Icons.settings_outlined),
          matching: find.bySemanticsLabel('Settings'),
        ),
        findsWidgets,
      );
    });

    testWidgets('the tooltip wrapper does not swallow the tap', (
      tester,
    ) async {
      var tapped = 0;
      _useDesktopViewport(tester);
      await tester.pumpWidget(_wrap(onNewSession: () => tapped++));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });
  });
}
