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
  _StubNetworkNotifier([this.online = true]);

  final bool online;

  @override
  bool build() => online;
}

class _StubConnectionNotifier extends ConnectionNotifier {
  _StubConnectionNotifier(this.status);

  final ConnectionStatus status;

  @override
  ConnectionStatus build() => status;
}

void main() {
  final defaultLastSyncedAt = OfflineBanner.lastSyncedAt;
  tearDown(() {
    OfflineBanner.lastSyncedAt = defaultLastSyncedAt;
  });

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

  testWidgets('offline banner says how old the saved conversations are', (
    tester,
  ) async {
    OfflineBanner.lastSyncedAt = () =>
        DateTime.now().subtract(const Duration(minutes: 5));
    await tester.pumpWidget(_app(ConnectionStatus.disconnected, online: false));

    expect(find.text('No internet connection'), findsOneWidget);
    expect(
      find.text('Showing saved conversations from 5m ago'),
      findsOneWidget,
    );
  });

  testWidgets('reconnecting banner also reports the saved data age', (
    tester,
  ) async {
    OfflineBanner.lastSyncedAt = () =>
        DateTime.now().subtract(const Duration(hours: 2));
    await tester.pumpWidget(_app(ConnectionStatus.error));

    expect(
      find.text('Showing saved conversations from 2h ago'),
      findsOneWidget,
    );
  });

  testWidgets('fresh or unknown sync age is not shown', (tester) async {
    OfflineBanner.lastSyncedAt = () =>
        DateTime.now().subtract(const Duration(seconds: 20));
    await tester.pumpWidget(_app(ConnectionStatus.disconnected, online: false));
    expect(find.textContaining('Showing saved conversations'), findsNothing);

    OfflineBanner.lastSyncedAt = () => null;
    await tester.pumpWidget(
      _app(ConnectionStatus.disconnected, online: false, key: UniqueKey()),
    );
    expect(find.textContaining('Showing saved conversations'), findsNothing);
  });
}

Widget _app(ConnectionStatus status, {bool online = true, Key? key}) =>
    ProviderScope(
      key: key,
      overrides: [
        networkNotifierProvider.overrideWith(
          () => _StubNetworkNotifier(online),
        ),
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
