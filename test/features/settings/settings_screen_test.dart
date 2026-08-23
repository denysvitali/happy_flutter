import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/server',
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
    final statusY = tester.getTopLeft(find.text('STATUS')).dy;
    expect(searchY, lessThan(statusY));
  });

  testWidgets('account section is gone; danger zone keeps sign out', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    // The old one-row Account section is fully replaced by ProfileHeader
    // and the status block's account-recovery row.
    expect(find.text('Account Settings'), findsNothing);
    // The only remaining "Account"-titled section is the danger zone.
    expect(find.text('ACCOUNT'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('search filters sections down to matching rows', (tester) async {
    await tester.pumpWidget(_buildApp(Settings()));
    await tester.pumpAndSettle();

    expect(find.text('Sync needs attention'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'server');
    await tester.pumpAndSettle();

    // Infrastructure keeps only the rows matching "server".
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.textContaining('MCP Servers'), findsWidgets);
    expect(find.text('Sandbox'), findsNothing);
    expect(find.text('Machines'), findsNothing);
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

    // Only the auto-archive row survives inside Sessions (title and
    // subtitle both render the same string).
    expect(find.text('SESSIONS'), findsOneWidget);
    expect(find.text('Auto-Archive'), findsNWidgets(2));
    expect(find.text('Session Folders'), findsNothing);
    expect(find.text('Session view style'), findsNothing);
    expect(find.text('STATUS'), findsNothing);
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

  testWidgets('status summary counts only online machines', (tester) async {
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
