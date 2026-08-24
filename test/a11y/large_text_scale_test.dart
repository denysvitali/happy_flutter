import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/components/app_empty_state.dart';
import 'package:happy_flutter/core/components/app_error_state.dart';
import 'package:happy_flutter/core/components/settings_section.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/providers/connection_notifier.dart';
import 'package:happy_flutter/core/providers/network_notifier.dart';
import 'package:happy_flutter/core/ui/tab_bar/tab_bar.dart';
import 'package:happy_flutter/core/widgets/offline_banner.dart';

class _StubNetworkNotifier extends NetworkNotifier {
  _StubNetworkNotifier({required this.online});

  final bool online;

  @override
  bool build() => online;
}

class _StubConnectionNotifier extends ConnectionNotifier {
  _StubConnectionNotifier({required this.status});

  final ConnectionStatus status;

  @override
  ConnectionStatus build() => status;
}

/// Text scale used across this suite. 2.0 is the top of the Android
/// "Largest" font-size range and roughly iOS AX3.
const double _kLargeScale = 2.0;

/// Small phone viewport — the tightest realistic layout budget.
const Size _kPhone = Size(360, 640);

/// One bounded frame step, longer than every one-shot transition in these
/// widgets (the slowest is 500 ms).
const Duration _kSettleStep = Duration(milliseconds: 600);

Widget _app({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(useMaterial3: true),
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(_kLargeScale),
      ),
      child: widget ?? const SizedBox.shrink(),
    ),
    home: Scaffold(body: child),
  );
}

/// Pumps [app] on a small phone viewport.
///
/// Deliberately bounded `pump()`s rather than `pumpAndSettle()`:
/// [AppEmptyState] runs a forever-repeating "breathe" animation on its icon,
/// so `pumpAndSettle` would burn its whole timeout budget and fail. Two
/// bounded frames are enough to lay out and finish the one-shot entrance
/// animations these tests care about.
Future<void> _pumpPhone(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = _kPhone * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pump(_kSettleStep);
  await tester.pump(_kSettleStep);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bottom navigation at 200% text scale', () {
    testWidgets('TabBar does not overflow', (tester) async {
      await _pumpPhone(
        tester,
        _app(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TabBar(
              activeTab: AppTab.sessions,
              onTabPress: (_) {},
              badgeCounts: const <AppTab, int>{AppTab.loops: 12},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('TabBar grows taller than its nominal height', (tester) async {
      await _pumpPhone(
        tester,
        _app(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TabBar(activeTab: AppTab.sessions, onTabPress: (_) {}),
          ),
        ),
      );

      // The bar must honour the system setting by growing, never by
      // clamping the scaler or clipping the label.
      final barHeight = tester.getSize(find.byType(TabBar)).height;
      expect(barHeight, greaterThan(TabBar.defaultHeight));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the badge pill grows with the digit', (tester) async {
      await _pumpPhone(
        tester,
        _app(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TabBar(
              activeTab: AppTab.sessions,
              onTabPress: (_) {},
              badgeCounts: const <AppTab, int>{AppTab.loops: 12},
            ),
          ),
        ),
      );

      // The pill used to be a fixed 16 dp box, so a 20 dp digit clipped.
      final digit = find.text('9+');
      expect(digit, findsOneWidget);
      final pill = tester.getSize(
        find.ancestor(of: digit, matching: find.byType(Container)).first,
      );
      final digitSize = tester.getSize(digit);
      expect(pill.height, greaterThanOrEqualTo(digitSize.height));
      expect(pill.width, greaterThanOrEqualTo(digitSize.width));
      expect(pill.height, greaterThan(16));
      expect(tester.takeException(), isNull);
    });

    testWidgets('CompactTabBar does not overflow', (tester) async {
      await _pumpPhone(
        tester,
        _app(
          child: Center(
            child: CompactTabBar(
              activeTab: AppTab.loops,
              onTabPress: (_) {},
              badgeCounts: const <AppTab, int>{AppTab.loops: 42},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('settings rows at 200% text scale', () {
    testWidgets('SettingsSection of dense rows does not overflow', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        _app(
          child: ListView(
            children: [
              SettingsSection(
                title: 'Status',
                description: 'Everything about the current connection state',
                children: [
                  SettingsRow(
                    icon: Icons.sync,
                    title: 'Sync needs attention',
                    subtitle:
                        'Connected, waiting for initial data to finish '
                        'loading before sessions become available',
                    trailing: const Icon(Icons.error_outline),
                    onTap: () {},
                  ),
                  SettingsNavRow(
                    icon: Icons.person_outline,
                    title: 'Account and recovery',
                    subtitle:
                        'Backup key, linked devices, restore, and services',
                    onTap: () {},
                  ),
                  SettingsToggleRow(
                    icon: Icons.notifications_outlined,
                    title: 'Notify me when an agent finishes thinking',
                    subtitle:
                        'Sends a push notification for every session that '
                        'completes while the app is in the background',
                    value: true,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('rows grow instead of ellipsising at large scale', (
      tester,
    ) async {
      const longTitle =
          'A settings row title long enough to wrap onto several lines';

      await _pumpPhone(
        tester,
        _app(
          child: ListView(
            children: [
              SettingsRow(
                icon: Icons.settings,
                title: longTitle,
                subtitle: 'And a subtitle that is also comfortably long',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      final title = tester.widget<Text>(find.text(longTitle));
      // maxLines lifted so the copy is readable in full.
      expect(title.maxLines, isNull);
      expect(
        tester.getSize(find.byType(SettingsRow)).height,
        greaterThan(kSettingsRowMinHeightWithSubtitle),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('rows still cap at two lines at normal scale', (tester) async {
      const longTitle =
          'A settings row title long enough to wrap onto several lines';

      tester.view.physicalSize = _kPhone * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsRow(
              icon: Icons.settings,
              title: longTitle,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.text(longTitle)).maxLines, 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('status banner at 200% text scale', () {
    testWidgets('offline banner does not overflow', (tester) async {
      await _pumpPhone(
        tester,
        _app(
          child: ProviderScope(
            overrides: [
              networkNotifierProvider.overrideWith(
                () => _StubNetworkNotifier(online: false),
              ),
              connectionNotifierProvider.overrideWith(
                () => _StubConnectionNotifier(
                  status: ConnectionStatus.disconnected,
                ),
              ),
            ],
            child: const Align(
              alignment: Alignment.topCenter,
              child: OfflineBanner(),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('placeholders at 200% text scale', () {
    testWidgets('AppEmptyState does not overflow', (tester) async {
      await _pumpPhone(
        tester,
        _app(
          child: AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No sessions yet',
            subtitle:
                'Start a session from a linked machine and it will show up '
                'here as soon as the daemon reports it.',
            action: FilledButton(
              onPressed: () {},
              child: const Text('New session'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('AppErrorState does not overflow', (tester) async {
      await _pumpPhone(
        tester,
        _app(
          child: AppErrorState(
            message:
                'We could not reach the server. Check the connection and '
                'try again in a moment.',
            onRetry: () {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
