import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  testWidgets('uses a compact account row and puts search before settings', (
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
