import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/find_text_ci.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/components/settings_section.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/models/settings_update.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/settings/settings_screen.dart';
import 'package:happy_flutter/features/settings/widgets/profile_header.dart';

class _TestSettingsNotifier extends SettingsNotifier {
  _TestSettingsNotifier(this._initial);

  final Settings _initial;

  @override
  Settings build() => _initial;

  @override
  Future<void> updateSetting<T>(String key, T value) async {
    state = SettingsUpdate.copyWithUpdated(state, key, value);
  }

  @override
  Future<void> applySettings(Map<String, dynamic> values) async {
    var updated = state;
    for (final entry in values.entries) {
      updated = SettingsUpdate.copyWithUpdated(updated, entry.key, entry.value);
    }
    state = updated;
  }
}

class _TestMachinesNotifier extends MachinesNotifier {
  _TestMachinesNotifier(this._initial);

  final Map<String, Machine> _initial;

  @override
  Map<String, Machine> build() => _initial;
}

Machine _machine({
  required String id,
  required bool active,
  required int activeAt,
  bool? sandboxAvailable,
  String? sandboxReason,
}) {
  return Machine(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: active,
    activeAt: activeAt,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: MachineMetadata(
      displayName: id,
      sandboxAvailable: sandboxAvailable,
      sandboxReason: sandboxReason,
    ),
  );
}

Widget _buildApp(
  Settings initialSettings, {
  Map<String, Machine> machines = const {},
}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _TestSettingsNotifier(initialSettings),
      ),
      machinesNotifierProvider.overrideWith(
        () => _TestMachinesNotifier(machines),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

/// Same provider wiring as [_buildApp], but hosted under a real
/// [GoRouter] so navigation assertions can run.
Widget _buildRouterApp(Settings initialSettings) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/settings/server',
        // NavRouteRowSpec taps call context.pushNamed, so the harness
        // route must carry the same name the real router registers.
        name: 'server-settings',
        builder: (_, _) =>
            const Scaffold(body: Text('Server settings placeholder')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(
        () => _TestSettingsNotifier(initialSettings),
      ),
      machinesNotifierProvider.overrideWith(
        () => _TestMachinesNotifier(const {}),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('uses a compact account header and puts search before status', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    final profileSize = tester.getSize(find.byType(ProfileHeader));
    expect(profileSize.height, lessThanOrEqualTo(80));
    expect(profileSize.height, greaterThanOrEqualTo(44));
    expect(find.text('Quick access'), findsNothing);

    final searchY = tester.getTopLeft(find.byType(TextField)).dy;
    final statusY = tester.getTopLeft(findTextIgnoreCase('STATUS')).dy;
    expect(searchY, lessThan(statusY));
  });

  testWidgets('account lives in one section with devices and sign out', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    // The header is display-only so the Account section is the single
    // way into account management.
    expect(
      tester.widget<ProfileHeader>(find.byType(ProfileHeader)).onTap,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Backup key and devices'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Account and recovery'), findsNothing);
  });

  testWidgets('hub has no duplicated or removed entries', (tester) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    final list = find.byType(Scrollable).first;
    // Walk the whole hub: no title may be built twice at the same time,
    // and every visited title is recorded for the removal checks below.
    final seen = <String>{};
    final duplicates = <String>{};
    for (var i = 0; i < 40; i++) {
      final titles = [
        for (final row in tester.widgetList<SettingsRow>(
          find.byType(SettingsRow),
        ))
          row.title,
        for (final row in tester.widgetList<SettingsToggleRow>(
          find.byType(SettingsToggleRow),
        ))
          row.title,
      ];
      final onScreen = <String>{};
      for (final title in titles) {
        if (!onScreen.add(title)) duplicates.add(title);
      }
      seen.addAll(titles);
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(duplicates, isEmpty);
    // Workflow presets, the Features screen and the hub Usage row are gone.
    expect(seen, isNot(contains('Focus')));
    expect(seen, isNot(contains('Features')));
    expect(seen, isNot(contains('Token usage and cost')));
    expect(seen, isNot(contains('Text-to-Speech')));
  });

  testWidgets('search filters sections down to matching rows', (tester) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    expect(find.text('Sync needs attention'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'server url');
    await tester.pumpAndSettle();

    // Machines & server keeps only the row matching every token.
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Sandbox'), findsNothing);
    expect(find.text('Machines'), findsNothing);
    expect(find.textContaining('MCP Servers'), findsNothing);
    // Non-matching blocks are dropped entirely.
    expect(find.text('Sync needs attention'), findsNothing);
  });

  testWidgets('row-level search surfaces a single subtitle match', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'archive');
    await tester.pumpAndSettle();

    // Only the auto-archive row survives inside Sessions.
    expect(findTextIgnoreCase('SESSIONS'), findsOneWidget);
    expect(find.text('Auto-Archive'), findsOneWidget);
    expect(find.text('Session Folders'), findsNothing);
    expect(find.text('Session view style'), findsNothing);
    expect(findTextIgnoreCase('STATUS'), findsNothing);
  });

  testWidgets('server row opens the server-settings route', (tester) async {
    await tester.pumpWidget(_buildRouterApp(Settings()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Server URL'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Server URL'));
    await tester.pumpAndSettle();

    expect(find.text('Server settings placeholder'), findsOneWidget);
  });

  testWidgets('former Features toggles live in their sections', (tester) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    final list = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      find.text('Hide Inactive Sessions'),
      300,
      scrollable: list,
    );
    await tester.ensureVisible(find.text('Hide Inactive Sessions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide Inactive Sessions'));
    await tester.pumpAndSettle();
    expect(
      container.read(settingsNotifierProvider).hideInactiveSessions,
      isTrue,
    );

    await tester.scrollUntilVisible(
      find.text('Codex Fast Mode'),
      300,
      scrollable: list,
    );
    expect(container.read(settingsNotifierProvider).codexFastMode, isFalse);
    await tester.ensureVisible(find.text('Codex Fast Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex Fast Mode'));
    await tester.pumpAndSettle();
    expect(container.read(settingsNotifierProvider).codexFastMode, isTrue);
  });

  testWidgets('session view style offers the agent and recent layouts', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Session view style'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Session view style'));
    await tester.pumpAndSettle();

    expect(find.text('By agent'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recent activity'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('Recent activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recent activity'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
    expect(
      container.read(settingsNotifierProvider).sessionsViewStyle,
      'recent',
    );
  });

  testWidgets('machines row counts only online machines', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final staleAt = now - machineOnlineThresholdMs;

    await tester.pumpWidget(
      _buildApp(
        Settings(),
        machines: {
          'online': _machine(id: 'online', active: true, activeAt: now),
          'stale': _machine(id: 'stale', active: true, activeAt: staleAt),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 online of 2 linked'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('1 online of 2 linked'), findsOneWidget);
  });

  testWidgets('sandbox settings are disabled with the daemon reason', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await tester.pumpWidget(
      _buildApp(
        Settings(),
        machines: {
          'machine': _machine(
            id: 'machine',
            active: true,
            activeAt: now,
            sandboxAvailable: false,
            sandboxReason: 'boxy doctor failed',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sandbox'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('boxy doctor failed'), findsOneWidget);
    final sandboxRow = tester.widget<SettingsRow>(
      find.ancestor(
        of: find.text('Sandbox'),
        matching: find.byType(SettingsRow),
      ),
    );
    expect(sandboxRow.onTap, isNull);
  });
}
