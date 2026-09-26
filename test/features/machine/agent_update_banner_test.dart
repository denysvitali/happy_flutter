import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/machine/widgets/agent_update_banner.dart';

Map<String, dynamic> _provider({
  String provider = 'codex',
  String version = '1.0.0',
  String latestVersion = '1.1.0',
  bool installed = true,
  bool canUpdate = true,
  bool updateAvailable = true,
}) => {
  'provider': provider,
  'installed': installed,
  'version': version,
  'latestVersion': latestVersion,
  'canUpdate': canUpdate,
  'updateAvailable': updateAvailable,
  'updateStatus': 'idle',
};

Widget _app({bool online = true, String machineId = 'machine-1'}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: SingleChildScrollView(
        child: AgentUpdateBanner(
          machineId: machineId,
          machineName: 'My workstation',
          isOnline: online,
        ),
      ),
    ),
  );
}

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

  testWidgets('shows banner when update is available', (tester) async {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      if (method == 'get-provider-versions') {
        return <String, dynamic>{
          'success': true,
          'providers': [
            _provider(),
            _provider(provider: 'claude', updateAvailable: false),
          ],
        };
      }
      return <String, dynamic>{'success': false, 'error': 'unexpected'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Codex update available'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('hides banner when no updates available', (tester) async {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      if (method == 'get-provider-versions') {
        return <String, dynamic>{
          'success': true,
          'providers': [
            _provider(updateAvailable: false),
            _provider(provider: 'claude', updateAvailable: false),
          ],
        };
      }
      return <String, dynamic>{'success': false, 'error': 'unexpected'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Codex update available'), findsNothing);
  });

  testWidgets('hides banner when not installed', (tester) async {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      if (method == 'get-provider-versions') {
        return <String, dynamic>{
          'success': true,
          'providers': [_provider(installed: false)],
        };
      }
      return <String, dynamic>{'success': false, 'error': 'unexpected'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Codex update available'), findsNothing);
  });

  testWidgets('hides banner when cannot update', (tester) async {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      if (method == 'get-provider-versions') {
        return <String, dynamic>{
          'success': true,
          'providers': [_provider(canUpdate: false)],
        };
      }
      return <String, dynamic>{'success': false, 'error': 'unexpected'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Codex update available'), findsNothing);
  });

  testWidgets('dismiss button hides banner', (tester) async {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      if (method == 'get-provider-versions') {
        return <String, dynamic>{
          'success': true,
          'providers': [_provider()],
        };
      }
      return <String, dynamic>{'success': false, 'error': 'unexpected'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Codex update available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('Codex update available'), findsNothing);
  });

  testWidgets('update button triggers update RPC', (tester) async {
    final calls = <String>[];
    sync.testMachineRPCOverride = (machineId, method, params) async {
      calls.add(method);
      if (method == 'get-provider-versions') {
        return <String, dynamic>{
          'success': true,
          'providers': [_provider()],
        };
      }
      if (method == 'update-provider') {
        return <String, dynamic>{
          'success': true,
          'provider': _provider(version: '1.1.0'),
        };
      }
      return <String, dynamic>{'success': false, 'error': 'unexpected'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(calls, contains('update-provider'));
  });

  testWidgets('shows restart dialog after successful update', (tester) async {
    sync.testMachineRPCOverride = (machineId, method, params) async {
      if (method == 'get-provider-versions') {
        return <String, dynamic>{
          'success': true,
          'providers': [_provider()],
        };
      }
      if (method == 'update-provider') {
        return <String, dynamic>{
          'success': true,
          'provider': _provider(version: '1.1.0'),
        };
      }
      return <String, dynamic>{'success': false, 'error': 'unexpected'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(
      find.text('Restart sessions to finish the update?'),
      findsOneWidget,
    );
    expect(find.text('Restart sessions'), findsOneWidget);
    expect(find.text('Later'), findsWidgets);
  });

  testWidgets('hides banner when machine offline', (tester) async {
    await tester.pumpWidget(_app(online: false));
    await tester.pumpAndSettle();
    expect(find.text('Codex update available'), findsNothing);
  });
}
