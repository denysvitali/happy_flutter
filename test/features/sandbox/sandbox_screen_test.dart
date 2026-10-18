import 'dart:async';

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
        find.descendant(
          of: find.byKey(const ValueKey('sandbox-machine-picker')),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      expect(picker.initialValue, 'b-capable');

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('sandbox-machine-picker')),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
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

  testWidgets('a slow policy list for the previous machine never repaints the '
      'selected machine\'s projects', (tester) async {
    final sync = Sync();
    // One completer per machine list so answers can land out of order.
    final pendingLists = <String, Completer<Map<String, dynamic>>>{};
    final rpcs = <({String machineId, String method})>[];
    sync.testMachineRPCOverride = (machineId, method, params) {
      rpcs.add((machineId: machineId, method: method));
      if (method == 'sandbox-list') {
        return (pendingLists[machineId] ??= Completer<Map<String, dynamic>>())
            .future;
      }
      return Future<Map<String, dynamic>>.value(<String, dynamic>{
        'success': true,
        'available': true,
        'enabled': true,
        'effectiveEnabled': true,
        'directory': params['directory'],
        'grants': <dynamic>[],
        'allowHosts': <dynamic>[],
      });
    };
    addTearDown(() => sync.testMachineRPCOverride = null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          machinesNotifierProvider.overrideWith(
            () => _StubMachinesNotifier({
              'm1': _onlineMachine(id: 'm1', sandboxAvailable: true),
              'm2': _onlineMachine(id: 'm2', sandboxAvailable: true),
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

    // 'm1' sorts first and is auto-selected; its list is still in flight
    // while the picker stays interactive.
    expect(pendingLists.keys, ['m1']);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('sandbox-machine-picker')),
        matching: find.byType(DropdownButtonFormField<String>),
      ),
    );
    // The in-flight spinner never settles; pump the menu route by hand.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('m2').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    pendingLists['m2']!.complete(<String, dynamic>{
      'success': true,
      'available': true,
      'enabled': true,
      'effectiveEnabled': true,
      'projects': <Map<String, dynamic>>[
        <String, dynamic>{'directory': '/srv/m2-project'},
      ],
      'grants': <dynamic>[],
      'allowHosts': <dynamic>[],
    });
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('/srv/m2-project'), findsWidgets);

    // The abandoned m1 answer lands last. Adopting it would list m1's
    // projects while every write sends the selected machine id (m2).
    pendingLists['m1']!.complete(<String, dynamic>{
      'success': true,
      'available': true,
      'enabled': true,
      'effectiveEnabled': true,
      'projects': <Map<String, dynamic>>[
        <String, dynamic>{'directory': '/srv/m1-project'},
      ],
      'grants': <dynamic>[],
      'allowHosts': <dynamic>[],
    });
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('/srv/m1-project'), findsNothing);
    expect(find.textContaining('/srv/m2-project'), findsWidgets);
    // And no policy read was ever aimed at a machine/directory pair the
    // user never selected together.
    expect(
      rpcs.where((r) => r.machineId == 'm1' && r.method == 'sandbox-get'),
      isEmpty,
    );
  });
}
