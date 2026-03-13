import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/features/sessions/widgets/connection_status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectionStatusBadge', () {
    testWidgets('renders circle icon for connected state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              status: ConnectionStatus.connected,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.circle), findsOneWidget);
    });

    testWidgets('renders circle icon for disconnected state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              status: ConnectionStatus.disconnected,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.circle), findsOneWidget);
    });

    testWidgets('renders circle icon for error state',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              status: ConnectionStatus.error,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.circle), findsOneWidget);
    });

    testWidgets('renders animated builder for connecting '
        'state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              status: ConnectionStatus.connecting,
            ),
          ),
        ),
      );

      await tester.pump();

      // Connecting state uses AnimatedBuilder
      // with a pulsing icon
      expect(find.byIcon(Icons.circle), findsOneWidget);
    });

    testWidgets('changes from connected to disconnected',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              status: ConnectionStatus.connected,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.circle), findsOneWidget);

      // Update to disconnected
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConnectionStatusBadge(
              status: ConnectionStatus.disconnected,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.circle), findsOneWidget);
    });
  });
}
