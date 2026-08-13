import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/connection_notifier.dart';
import 'package:happy_flutter/core/providers/network_notifier.dart';
import 'package:happy_flutter/core/widgets/offline_banner.dart';
import 'package:happy_flutter/l10n_generated/app_localizations.dart';

class _StubNetworkNotifier extends NetworkNotifier {
  @override
  bool build() => true;
}

class _StubConnectionNotifier extends ConnectionNotifier {
  _StubConnectionNotifier(this.status);

  final ConnectionStatus status;

  @override
  ConnectionStatus build() => status;
}

void main() {
  testWidgets('hides a routine reconnect during the startup grace period', (
    tester,
  ) async {
    await tester.pumpWidget(_app(ConnectionStatus.connecting));

    expect(find.text('Live updates disconnected'), findsNothing);
    expect(find.text('Reconnect now'), findsNothing);

    await tester.pump(OfflineBanner.reconnectGracePeriod);

    expect(find.text('Live updates disconnected'), findsOneWidget);
    expect(find.text('Reconnect now'), findsOneWidget);
  });

  testWidgets('shows an explicit socket error immediately', (tester) async {
    await tester.pumpWidget(_app(ConnectionStatus.error));

    expect(find.text('Live updates disconnected'), findsOneWidget);
    expect(find.text('Reconnect now'), findsOneWidget);
  });
}

Widget _app(ConnectionStatus status) => ProviderScope(
  overrides: [
    networkNotifierProvider.overrideWith(_StubNetworkNotifier.new),
    connectionNotifierProvider.overrideWith(
      () => _StubConnectionNotifier(status),
    ),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: OfflineBanner()),
  ),
);
