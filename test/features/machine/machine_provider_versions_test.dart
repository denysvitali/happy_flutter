import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/socket_io_client.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/machine/widgets/machine_provider_versions.dart';

Map<String, dynamic> _provider({
  String provider = 'codex',
  String version = '1.0.0',
  String latestVersion = '1.1.0',
  bool installed = true,
  bool canUpdate = true,
  bool updateAvailable = true,
  String updateStatus = 'idle',
  String? updateError,
  String? updateMessage,
  String? error,
}) => {
  'provider': provider,
  'installed': installed,
  'version': version,
  'latestVersion': latestVersion,
  'canUpdate': canUpdate,
  'updateAvailable': updateAvailable,
  'updateStatus': updateStatus,
  if (updateError != null) 'updateError': updateError,
  if (updateMessage != null) 'updateMessage': updateMessage,
  if (error != null) 'error': error,
};

Map<String, dynamic> _versions(Map<String, dynamic> codex) => {
  'success': true,
  'providers': [
    codex,
    _provider(
      provider: 'claude',
      version: '2.0.0',
      latestVersion: '2.0.0',
      updateAvailable: false,
    ),
  ],
};

Widget _app({bool online = true, String machineId = 'machine-1'}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MachineProviderVersions(
            machineId: machineId,
            machineName: 'My workstation',
            isOnline: online,
          ),
        ),
      ),
    );

final _checkButton = find.byKey(const ValueKey('check-provider-versions'));
final _updateCodex = find.byKey(const ValueKey('update-provider-codex'));

Future<void> _check(WidgetTester tester) async {
  await tester.ensureVisible(_checkButton);
  await tester.tap(_checkButton);
  await tester.pump();
}

Future<void> _confirmUpdate(WidgetTester tester) async {
  await tester.ensureVisible(_updateCodex);
  await tester.tap(_updateCodex);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Update'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

  testWidgets('offline machines cannot check or update', (tester) async {
    var calls = 0;
    sync.testMachineRPCOverride = (_, _, _) async {
      calls++;
      return _versions(_provider());
    };
    await tester.pumpWidget(_app(online: false));

    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Claude Code'), findsOneWidget);
    expect(
      find.text('Connect this machine to check and update coding agents.'),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(_checkButton).onPressed, isNull);
    expect(calls, 0);
  });

  testWidgets('explicit check shows installed and latest versions', (
    tester,
  ) async {
    var calls = 0;
    sync.testMachineRPCOverride = (machineId, method, params) async {
      calls++;
      expect(machineId, 'machine-1');
      expect(method, 'get-provider-versions');
      expect(params, {'refresh': true});
      return _versions(_provider());
    };
    await tester.pumpWidget(_app());
    expect(calls, 0);

    await _check(tester);

    expect(calls, 1);
    expect(find.text('Installed: 1.0.0'), findsOneWidget);
    expect(find.text('Latest: 1.1.0'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Up to date'), findsOneWidget);
    expect(_updateCodex, findsOneWidget);
    expect(find.byKey(const ValueKey('update-provider-claude')), findsNothing);
  });

  testWidgets('a pending version check disables duplicate requests', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    sync.testMachineRPCOverride = (_, _, _) {
      calls++;
      return pending.future;
    };
    await tester.pumpWidget(_app());
    await _check(tester);

    expect(find.text('Checking versions…'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(_checkButton).onPressed, isNull);
    expect(calls, 1);
    pending.complete(_versions(_provider()));
    await tester.pump();
    expect(find.text('Checking versions…'), findsNothing);
  });

  testWidgets('canceling update confirmation makes no update request', (
    tester,
  ) async {
    var updates = 0;
    sync.testMachineRPCOverride = (_, method, _) async {
      if (method == 'update-provider') updates++;
      return _versions(_provider());
    };
    await tester.pumpWidget(_app());
    await _check(tester);
    await tester.tap(_updateCodex);
    await tester.pumpAndSettle();

    expect(find.text('Update Codex?'), findsOneWidget);
    expect(find.text('Update Codex on My workstation?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(updates, 0);
  });

  testWidgets('confirmed update polls cached state until success', (
    tester,
  ) async {
    var updates = 0;
    var polls = 0;
    sync.testMachineRPCOverride = (machineId, method, params) async {
      expect(machineId, 'machine-1');
      if (method == 'update-provider') {
        updates++;
        expect(params, {'provider': 'codex'});
        return {
          'success': true,
          'provider': _provider(updateStatus: 'running'),
        };
      }
      if (params['refresh'] == false) {
        polls++;
        return _versions(
          _provider(
            version: '1.1.0',
            updateAvailable: false,
            updateStatus: 'succeeded',
          ),
        );
      }
      return _versions(_provider());
    };
    await tester.pumpWidget(_app());
    await _check(tester);
    await _confirmUpdate(tester);

    expect(updates, 1);
    expect(find.text('Updating…'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(_checkButton).onPressed, isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(polls, 1);
    expect(find.text('Installed: 1.1.0'), findsOneWidget);
    expect(find.text('Update completed'), findsOneWidget);
    expect(find.text('Updating…'), findsNothing);
    expect(_updateCodex, findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(polls, 1);
  });

  testWidgets('a newer version supersedes a previous successful update', (
    tester,
  ) async {
    sync.testMachineRPCOverride = (_, _, _) async =>
        _versions(_provider(updateStatus: 'succeeded'));
    await tester.pumpWidget(_app());
    await _check(tester);

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Update completed'), findsNothing);
    expect(_updateCodex, findsOneWidget);
  });

  testWidgets('unsupported daemon shows upgrade guidance', (tester) async {
    sync.testMachineRPCOverride = (_, _, _) async {
      throw const RpcException(
        code: RpcErrorCode.methodUnsupported,
        message: 'No such method',
        retryable: false,
      );
    };
    await tester.pumpWidget(_app());
    await _check(tester);

    expect(
      find.text(
        'Update Happy on this machine to manage coding agent versions.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(_checkButton).onPressed, isNotNull);
  });

  testWidgets('uncertain update requires another check before retrying', (
    tester,
  ) async {
    var updates = 0;
    sync.testMachineRPCOverride = (_, method, _) async {
      if (method == 'update-provider') {
        updates++;
        throw const SocketAckTimeoutException('rpc-call');
      }
      return _versions(_provider());
    };
    await tester.pumpWidget(_app());
    await _check(tester);
    await _confirmUpdate(tester);

    expect(updates, 1);
    expect(find.textContaining('It may still be running'), findsOneWidget);
    expect(tester.widget<FilledButton>(_updateCodex).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(_checkButton).onPressed, isNotNull);
    await _check(tester);
    expect(tester.widget<FilledButton>(_updateCodex).onPressed, isNotNull);
    expect(updates, 1);
  });

  testWidgets('failed background update shows the daemon error', (
    tester,
  ) async {
    sync.testMachineRPCOverride = (_, _, params) async => _versions(
      params['refresh'] == true
          ? _provider(updateStatus: 'running')
          : _provider(
              updateStatus: 'failed',
              updateError: 'Installation directory is not writable',
            ),
    );
    await tester.pumpWidget(_app());
    await _check(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Installation directory is not writable'), findsOneWidget);
    expect(find.text('Updating…'), findsNothing);
    expect(tester.widget<OutlinedButton>(_checkButton).onPressed, isNotNull);
  });

  testWidgets('poll failure permits checking status without repeating update', (
    tester,
  ) async {
    var calls = 0;
    sync.testMachineRPCOverride = (_, method, params) async {
      calls++;
      expect(method, 'get-provider-versions');
      if (params['refresh'] == false) {
        throw const SocketNotConnectedException('rpc-call');
      }
      return _versions(_provider(updateStatus: 'running'));
    };
    await tester.pumpWidget(_app());
    await _check(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.textContaining('It may still be running'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(_checkButton).onPressed, isNotNull);
    await tester.pump(const Duration(seconds: 5));
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline stops polling and reconnect resumes it', (tester) async {
    var polls = 0;
    sync.testMachineRPCOverride = (_, _, params) async {
      if (params['refresh'] == false) polls++;
      return _versions(_provider(updateStatus: 'running'));
    };
    await tester.pumpWidget(_app());
    await _check(tester);
    await tester.pumpWidget(_app(online: false));
    await tester.pump(const Duration(seconds: 5));
    expect(polls, 0);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(polls, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(polls, 1);
  });

  testWidgets('old poll cannot overwrite newer result after reconnect', (
    tester,
  ) async {
    final oldPoll = Completer<Map<String, dynamic>>();
    var polls = 0;
    sync.testMachineRPCOverride = (_, _, params) async {
      if (params['refresh'] == true) {
        return _versions(_provider(updateStatus: 'running'));
      }
      polls++;
      if (polls == 1) return oldPoll.future;
      return _versions(
        _provider(
          version: '1.1.0',
          updateAvailable: false,
          updateStatus: 'succeeded',
        ),
      );
    };
    await tester.pumpWidget(_app());
    await _check(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(_app(online: false));
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Update completed'), findsOneWidget);

    oldPoll.complete(_versions(_provider(updateStatus: 'running')));
    await tester.pump();
    expect(find.text('Update completed'), findsOneWidget);
    expect(find.text('Updating…'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(polls, 2);
  });

  testWidgets('switching machines ignores the old machine response', (
    tester,
  ) async {
    final oldCheck = Completer<Map<String, dynamic>>();
    sync.testMachineRPCOverride = (_, _, _) => oldCheck.future;
    await tester.pumpWidget(_app());
    await _check(tester);
    await tester.pumpWidget(_app(machineId: 'machine-2'));
    oldCheck.complete(_versions(_provider()));
    await tester.pump();

    expect(find.text('Installed: 1.0.0'), findsNothing);
    expect(tester.widget<OutlinedButton>(_checkButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported installations show package manager guidance', (
    tester,
  ) async {
    sync.testMachineRPCOverride = (_, _, _) async => _versions(
      _provider(
        canUpdate: false,
        updateMessage: 'Update Codex using Homebrew on the machine.',
      ),
    );
    await tester.pumpWidget(_app());
    await _check(tester);

    expect(
      find.text('Update Codex using Homebrew on the machine.'),
      findsOneWidget,
    );
    expect(_updateCodex, findsNothing);
  });
}
