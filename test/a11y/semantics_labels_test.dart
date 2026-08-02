import 'package:flutter/material.dart' hide TabBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart'
    show ConnectionStatus;
import 'package:happy_flutter/core/components/app_empty_state.dart';
import 'package:happy_flutter/core/components/app_error_state.dart';
import 'package:happy_flutter/core/components/settings_section.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
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

Widget _app({required Widget child, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bottom navigation semantics', () {
    testWidgets('each tab announces one labelled, selectable button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TabBar(activeTab: AppTab.sessions, onTabPress: (_) {}),
          ),
        ),
      );

      // Every destination is reachable and labelled — before this sweep
      // the badge digit was announced as a loose fragment.
      for (final label in const [
        'Sessions',
        'Loops',
        'Providers',
        'Settings',
      ]) {
        expect(
          find.bySemanticsLabel(label),
          findsOneWidget,
          reason: 'tab "$label" must expose exactly one semantics node',
        );
      }

      handle.dispose();
    });

    testWidgets('active tab is marked selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TabBar(activeTab: AppTab.settings, onTabPress: (_) {}),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Settings')),
        containsSemantics(isSelected: true, isButton: true),
      );

      handle.dispose();
    });

    testWidgets('badge count folds into the tab label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TabBar(
              activeTab: AppTab.sessions,
              onTabPress: (_) {},
              badgeCounts: const <AppTab, int>{AppTab.loops: 3},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Loops, 3 new items'), findsOneWidget);
      // The bare digit must not be a separate semantics node.
      expect(find.bySemanticsLabel('3'), findsNothing);

      handle.dispose();
    });

    testWidgets('tapping a tab through semantics reports the tab', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      AppTab? pressed;
      await tester.pumpWidget(
        _app(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: TabBar(
              activeTab: AppTab.sessions,
              onTabPress: (tab) => pressed = tab,
            ),
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Providers'));
      await tester.pump();
      expect(pressed, AppTab.providers);

      handle.dispose();
    });
  });

  group('settings screen semantics', () {
    testWidgets('a section title is announced as a header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: SettingsSection(
            title: 'Status',
            children: [
              SettingsRow(
                icon: Icons.sync,
                title: 'Sync ready',
                subtitle: 'Ready for sessions',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Status')),
        containsSemantics(isHeader: true, label: 'Status'),
      );

      handle.dispose();
    });

    testWidgets('a row announces title and subtitle as one node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: SettingsSection(
            children: [
              SettingsNavRow(
                icon: Icons.person_outline,
                title: 'Account and recovery',
                subtitle: 'Backup key, linked devices, restore',
                onTap: () {},
              ),
            ],
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(SettingsRow));
      expect(node, containsSemantics(isButton: true));
      expect(node.label, contains('Account and recovery'));
      // Merged: the subtitle is part of the same node, not a fragment.
      expect(node.label, contains('Backup key, linked devices, restore'));

      handle.dispose();
    });

    testWidgets('a toggle row exposes on/off state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: SettingsToggleRow(
            icon: Icons.notifications_outlined,
            title: 'Alerts',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(SettingsToggleRow)),
        containsSemantics(isToggled: true, value: 'On'),
      );

      handle.dispose();
    });
  });

  group('status banner and placeholder semantics', () {
    testWidgets('offline banner is a labelled live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
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
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            'Connection status. No internet connection',
          ),
        ),
        containsSemantics(isLiveRegion: true),
      );

      handle.dispose();
    });

    testWidgets('empty state announces title and subtitle together', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: const AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No sessions yet',
            subtitle: 'Start one from a linked machine.',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
          'No sessions yet. Start one from a linked machine.',
        ),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('error state is an announced live region with retry', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          child: AppErrorState(
            message: 'Could not reach the server.',
            onRetry: () {},
          ),
        ),
      );

      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Error. Could not reach the server.'),
        ),
        containsSemantics(isLiveRegion: true),
      );
      // The retry button keeps its own node so it stays actionable.
      expect(find.bySemanticsLabel('Retry'), findsOneWidget);

      handle.dispose();
    });
  });
}
