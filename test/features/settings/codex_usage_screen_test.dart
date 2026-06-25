import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/machines_notifier.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/settings/codex_usage_screen.dart';

class _StubMachinesNotifier extends MachinesNotifier {
  _StubMachinesNotifier(this._initial);

  final Map<String, Machine> _initial;

  @override
  Map<String, Machine> build() => _initial;

  @override
  Future<void> refreshFromSync() async {}
}

Machine _onlineMachine({required String id, String? displayName}) {
  return Machine(
    id: id,
    seq: 1,
    createdAt: 1000,
    updatedAt: 2000,
    active: true,
    // activeAt within the 120s online window so _autoSelectMachine picks it.
    activeAt: DateTime.now().millisecondsSinceEpoch,
    metadataVersion: 1,
    daemonStateVersion: 1,
    metadata: MachineMetadata(displayName: displayName ?? id),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensure_initialized();

  group('CodexUsageScreen error state', () {
    testWidgets(
      'renders the machine picker so the user can switch off a machine '
      'that has no Codex installed',
      (tester) async {
        final machines = {
          'm-no-codex': _onlineMachine(
            id: 'm-no-codex',
            displayName: 'No Codex Box',
          ),
        };

        final sync = Sync();
        sync.testMachineRPCOverride =
            (machineId, method, params) async => <String, dynamic>{
                  'success': false,
                  'error': 'no Codex credentials on this machine',
                };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              machinesNotifierProvider.overrideWith(
                () => _StubMachinesNotifier(machines),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const CodexUsageScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Before the fix the error body rendered only a Retry button and
        // no picker — pinning the user onto a machine that has no Codex.
        expect(
          find.byType(DropdownButtonFormField<String>),
          findsOneWidget,
        );
        // Retry is still offered (the error state is the real deal), but
        // crucially the picker sits above it so the user can escape.
        expect(find.byType(FilledButton), findsOneWidget);

        sync.testMachineRPCOverride = null;
      },
    );
  });
}
