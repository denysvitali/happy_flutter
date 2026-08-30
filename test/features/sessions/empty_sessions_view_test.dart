import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/sessions/widgets/empty_sessions_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap({
    Map<String, Machine> machines = const {},
    Future<void> Function()? onCreateSession,
    Future<void> Function()? onRefreshMachines,
    VoidCallback? onManageMachines,
  }) {
    return ProviderScope(
      overrides: [
        machinesNotifierProvider.overrideWith(
          () => _StubMachinesNotifier(machines),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EmptySessionsView(
            onCreateSession: onCreateSession,
            onRefreshMachines: onRefreshMachines,
            onManageMachines: onManageMachines,
          ),
        ),
      ),
    );
  }

  group('EmptySessionsView (first-time user)', () {
    testWidgets('renders rocket icon and 3 onboarding steps', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.byIcon(Icons.rocket_launch_outlined), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('connect CTA invokes the computer connection flow', (
      tester,
    ) async {
      var connects = 0;
      await tester.pumpWidget(
        wrap(
          onCreateSession: () async {
            connects++;
          },
        ),
      );

      expect(find.text('Connect computer'), findsOneWidget);
      await tester.tap(find.text('Connect computer'));
      await tester.pump();
      expect(connects, 1);
    });
  });

  group('EmptySessionsView (offline computer)', () {
    final offlineMachines = <String, Machine>{
      'm1': const Machine(
        id: 'm1',
        seq: 0,
        active: false,
        activeAt: 0,
        createdAt: 0,
        updatedAt: 0,
        metadataVersion: 0,
        daemonStateVersion: 0,
      ),
    };

    testWidgets('offers refresh and computer management', (tester) async {
      var refreshes = 0;
      var manages = 0;
      await tester.pumpWidget(
        wrap(
          machines: offlineMachines,
          onRefreshMachines: () async {
            refreshes++;
          },
          onManageMachines: () => manages++,
        ),
      );

      expect(find.byIcon(Icons.computer_outlined), findsOneWidget);
      expect(find.text('Computer offline'), findsOneWidget);
      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(refreshes, 1);
      await tester.tap(find.text('View computers'));
      await tester.pump();
      expect(manages, 1);
    });
  });

  group('EmptySessionsView (ready computer)', () {
    final onlineMachines = <String, Machine>{
      'm1': Machine(
        id: 'm1',
        seq: 0,
        active: true,
        activeAt: DateTime.now().millisecondsSinceEpoch,
        createdAt: 0,
        updatedAt: 0,
        metadataVersion: 0,
        daemonStateVersion: 0,
      ),
    };

    testWidgets('starts a session when a computer is ready', (tester) async {
      var creates = 0;
      await tester.pumpWidget(
        wrap(
          machines: onlineMachines,
          onCreateSession: () async {
            creates++;
          },
        ),
      );

      expect(find.text('Start session'), findsOneWidget);
      await tester.tap(find.text('Start session'));
      await tester.pump();
      expect(creates, 1);
    });
  });
}

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
