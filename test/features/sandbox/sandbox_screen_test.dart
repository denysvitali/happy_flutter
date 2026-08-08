import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/sandbox/sandbox_screen.dart';

class _StubMachinesNotifier extends MachinesNotifier {
  _StubMachinesNotifier(this._initial);

  final Map<String, Machine> _initial;

  @override
  Map<String, Machine> build() => _initial;
}

Machine _onlineMachine({
  required String id,
  required bool sandboxAvailable,
  String? sandboxReason,
}) => Machine(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: true,
  activeAt: DateTime.now().millisecondsSinceEpoch,
  metadataVersion: 1,
  daemonStateVersion: 1,
  metadata: MachineMetadata(
    displayName: id,
    sandboxAvailable: sandboxAvailable,
    sandboxReason: sandboxReason,
  ),
);

void main() {
  testWidgets(
    'selects a sandbox-capable machine and disables unsupported choices',
    (tester) async {
      final sync = Sync();
      final calledMachineIds = <String>[];
      sync.testMachineRPCOverride = (machineId, method, params) async {
        calledMachineIds.add(machineId);
        return <String, dynamic>{
          'success': true,
          'available': true,
          'enabled': true,
          'effectiveEnabled': true,
          'projects': <dynamic>[],
          'grants': <dynamic>[],
          'allowHosts': <dynamic>[],
        };
      };
      addTearDown(() => sync.testMachineRPCOverride = null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier({
                'a-unsupported': _onlineMachine(
                  id: 'a-unsupported',
                  sandboxAvailable: false,
                  sandboxReason: 'boxy is not installed',
                ),
                'b-capable': _onlineMachine(
                  id: 'b-capable',
                  sandboxAvailable: true,
                ),
              }),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SandboxScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(calledMachineIds, isNotEmpty);
      expect(calledMachineIds, everyElement('b-capable'));

      final picker = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(picker.initialValue, 'b-capable');

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      final unsupported = tester
          .widgetList<DropdownMenuItem<String>>(
            find.byType(DropdownMenuItem<String>),
          )
          .singleWhere((item) => item.value == 'a-unsupported');
      expect(unsupported.enabled, isFalse);
      expect(find.textContaining('boxy is not installed'), findsOneWidget);
    },
  );
}
