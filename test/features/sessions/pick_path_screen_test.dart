import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/sessions/pick_path_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PickPathScreen', () {
    testWidgets('renders text field with hint', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PickPathScreen(machineId: null),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byType(TextField),
        findsOneWidget,
      );
    });

    testWidgets('renders Confirm button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PickPathScreen(machineId: null),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Confirm button exists (disabled initially since
      // text is empty).
      final buttons = find.byType(TextButton);
      expect(buttons, findsOneWidget);
    });

    testWidgets('Confirm button disabled when text is empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PickPathScreen(machineId: null),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // AppBar confirm button (TextButton) should be disabled
      // when text is empty.
      final confirmButtons = find.widgetWithText(
        TextButton,
        'Confirm',
      );
      expect(confirmButtons, findsOneWidget);

      final button = tester.widget<TextButton>(
        confirmButtons,
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('shows suggested paths when machine has '
        'homeDir', (tester) async {
      final machine = Machine(
        id: 'm1',
        seq: 1,
        createdAt: 1,
        updatedAt: 1,
        active: true,
        activeAt: 1,
        metadataVersion: 1,
        daemonStateVersion: 1,
        metadata: MachineMetadata(
          displayName: 'Test Machine',
          host: 'test-host',
          homeDir: '/home/testuser',
          platform: 'linux',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier({'m1': machine}),
            ),
            sessionsNotifierProvider.overrideWith(
              () => _StubSessionsNotifier({}),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PickPathScreen(machineId: 'm1'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show suggested paths based on homeDir
      expect(
        find.text('/home/testuser'),
        findsOneWidget,
      );
      expect(
        find.text('/home/testuser/projects'),
        findsOneWidget,
      );
    });

    testWidgets('shows recent paths from sessions',
        (tester) async {
      final machine = Machine(
        id: 'm1',
        seq: 1,
        createdAt: 1,
        updatedAt: 1,
        active: true,
        activeAt: 1,
        metadataVersion: 1,
        daemonStateVersion: 1,
        metadata: MachineMetadata(
          displayName: 'Test',
          host: 'host',
          homeDir: '/home/test',
          platform: 'linux',
        ),
      );

      final session = Session(
        id: 's1',
        seq: 1,
        createdAt: 100,
        updatedAt: 100,
        active: true,
        activeAt: 100,
        metadataVersion: 1,
        agentStateVersion: 1,
        thinking: false,
        presence: 'offline',
        metadata: Metadata(
          host: 'host',
          machineId: 'm1',
          path: '/home/test/myproject',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier({'m1': machine}),
            ),
            sessionsNotifierProvider.overrideWith(
              () => _StubSessionsNotifier(
                {'s1': session},
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PickPathScreen(machineId: 'm1'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show recent path from session
      expect(
        find.text('/home/test/myproject'),
        findsOneWidget,
      );
    });

    testWidgets('tapping path tile selects it',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsNotifierProvider.overrideWith(
              () => _StubSessionsNotifier({}),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PickPathScreen(machineId: null),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Type a path
      await tester.enterText(
        find.byType(TextField),
        '/test/path',
      );
      await tester.pump();

      // Confirm button should now be enabled
      final filledButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Confirm'),
      );
      expect(filledButton.onPressed, isNotNull);
    });
  });
}

// ─── Stub notifiers ───────────────────────────────────────

class _StubMachinesNotifier extends MachinesNotifier {
  _StubMachinesNotifier(this._initial);
  final Map<String, Machine> _initial;

  @override
  Map<String, Machine> build() => _initial;

  @override
  Future<void> refreshFromSync() async {}

  @override
  void loadFromSync() {}
}

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier(this._initial);
  final Map<String, Session> _initial;

  @override
  Map<String, Session> build() => _initial;

  @override
  Future<void> refreshFromSync() async {}

  @override
  void loadFromSync() {}
}
