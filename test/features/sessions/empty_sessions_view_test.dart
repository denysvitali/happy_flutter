import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/sessions/widgets/empty_sessions_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap({Map<String, Machine> machines = const {}}) {
    return ProviderScope(
      overrides: [
        machinesNotifierProvider.overrideWith(
          () => _StubMachinesNotifier(machines),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: EmptySessionsView()),
      ),
    );
  }

  group('EmptySessionsView (first-time user)', () {
    testWidgets('renders rocket icon and 3 onboarding steps',
        (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.byIcon(Icons.rocket_launch_outlined), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders "New Session" button', (tester) async {
      await tester.pumpWidget(wrap());
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });

  group('EmptySessionsView (returning user)', () {
    final machines = <String, Machine>{
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

    testWidgets('renders computer icon', (tester) async {
      await tester.pumpWidget(wrap(machines: machines));
      expect(find.byIcon(Icons.computer_outlined), findsOneWidget);
    });

    testWidgets('renders FilledButton CTA', (tester) async {
      await tester.pumpWidget(wrap(machines: machines));
      expect(find.byType(FilledButton), findsOneWidget);
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
