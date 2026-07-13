import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

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
      },
    );
  });

  group('CodexUsageScreen reset credits', () {
    testWidgets('renders the expiry of every available reset credit', (
      tester,
    ) async {
      final machines = {
        'm-codex': _onlineMachine(
          id: 'm-codex',
          displayName: 'Codex Box',
        ),
      };

      sync.testMachineRPCOverride = (machineId, method, params) async {
        if (method == 'get-codex-usage') {
          return <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'email': 'codex@example.com',
              'rate_limit': <String, dynamic>{
                'allowed': true,
                'limit_reached': false,
              },
              'rate_limit_reset_credits': <String, dynamic>{
                'available_count': 2,
              },
            },
          };
        }
        if (method == 'bash') {
          return <String, dynamic>{
            'success': true,
            'stdout': jsonEncode({
              'available_count': 2,
              'credits': [
                {
                  'status': 'available',
                  'title': 'Full reset one',
                  'expires_at': '2026-07-31T19:49:00Z',
                },
                {
                  'status': 'available',
                  'title': 'Full reset two',
                  'expires_at': '2026-08-12T17:26:00Z',
                },
              ],
            }),
            'exitCode': 0,
          };
        }
        return <String, dynamic>{
          'success': false,
          'error': 'Unexpected method: $method',
        };
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

      expect(find.text('Available resets'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Full reset one'), findsOneWidget);
      expect(find.text('Full reset two'), findsOneWidget);
      expect(find.textContaining('Jul 31, 2026'), findsOneWidget);
      expect(find.textContaining('Aug 12, 2026'), findsOneWidget);
    });
  });
}
