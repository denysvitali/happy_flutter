import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/machine.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/machines_notifier.dart';
import 'package:happy_flutter/core/services/opentelemetry_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/settings/codex_usage_screen.dart';
import 'package:intl/intl.dart';

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
    OpenTelemetryService.debugDurationSink = null;
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

        sync.testMachineRPCOverride = (machineId, method, params) async =>
            <String, dynamic>{
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
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        // Retry is still offered (the error state is the real deal), but
        // crucially the picker sits above it so the user can escape.
        expect(find.byType(FilledButton), findsOneWidget);
      },
    );
  });

  group('CodexUsageScreen reset credits', () {
    testWidgets('does not block usage on slow reset credits', (tester) async {
      final resetCredits = Completer<Map<String, dynamic>>();
      final metrics = <String>[];
      OpenTelemetryService.debugDurationSink = (name, _, attributes) {
        metrics.add(
          '$name:${attributes['operation']}:${attributes['outcome']}',
        );
      };
      sync.testMachineRPCOverride = (machineId, method, params) async {
        if (method == 'get-codex-usage') {
          return <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'email': 'codex@example.com',
              'rate_limit': <String, dynamic>{'allowed': true},
            },
          };
        }
        if (method == 'bash') return resetCredits.future;
        throw StateError('Unexpected method: $method');
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            machinesNotifierProvider.overrideWith(
              () => _StubMachinesNotifier({
                'm-codex': _onlineMachine(id: 'm-codex'),
              }),
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
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('codex@example.com'), findsOneWidget);
      expect(metrics, contains('app.operation:providers.codex_usage.load:ok'));
      expect(
        metrics,
        contains('app.operation.stage:providers.codex_usage.load:timeout'),
      );
      resetCredits.complete(<String, dynamic>{
        'success': false,
        'error': 'late response',
      });
    });

    testWidgets('renders the expiry of every available reset credit', (
      tester,
    ) async {
      final firstExpiry = DateTime.now().toUtc().add(const Duration(days: 18));
      final secondExpiry = DateTime.now().toUtc().add(const Duration(days: 31));
      final machines = {
        'm-codex': _onlineMachine(id: 'm-codex', displayName: 'Codex Box'),
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
                  'expires_at': firstExpiry.toIso8601String(),
                },
                {
                  'status': 'available',
                  'title': 'Full reset two',
                  'expires_at': secondExpiry.toIso8601String(),
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
      final firstDate = DateFormat.MMMd('en').format(firstExpiry.toLocal());
      final secondDate = DateFormat.MMMd('en').format(secondExpiry.toLocal());
      expect(find.text('18 days left · $firstDate'), findsOneWidget);
      expect(find.text('31 days left · $secondDate'), findsOneWidget);
    });
  });
}
