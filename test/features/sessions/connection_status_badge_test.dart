import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/sessions/widgets/connection_status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBadge(
    WidgetTester tester,
    ConnectionStatus status,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ConnectionStatusBadge(status: status)),
      ),
    );
  }

  group('ConnectionStatusBadge', () {
    // Finding 2: colour alone cannot carry the state — each status
    // needs its own glyph and its own screen-reader label.
    testWidgets('uses a distinct glyph per state', (tester) async {
      await pumpBadge(tester, ConnectionStatus.connected);
      expect(find.byIcon(Icons.circle), findsOneWidget);

      await pumpBadge(tester, ConnectionStatus.disconnected);
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsNothing);

      await pumpBadge(tester, ConnectionStatus.error);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await pumpBadge(tester, ConnectionStatus.connecting);
      await tester.pump();
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('announces the state to screen readers', (tester) async {
      final handle = tester.ensureSemantics();

      await pumpBadge(tester, ConnectionStatus.connected);
      expect(find.bySemanticsLabel('Online'), findsOneWidget);

      await pumpBadge(tester, ConnectionStatus.disconnected);
      expect(find.bySemanticsLabel('Disconnected'), findsOneWidget);

      await pumpBadge(tester, ConnectionStatus.error);
      expect(find.bySemanticsLabel('Error'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('changes from connected to disconnected', (tester) async {
      await pumpBadge(tester, ConnectionStatus.connected);
      expect(find.byIcon(Icons.circle), findsOneWidget);

      await pumpBadge(tester, ConnectionStatus.disconnected);
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });
  });
}
