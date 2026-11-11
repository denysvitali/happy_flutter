import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/settings_section.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/machine/widgets/machine_git_identity.dart';

Widget _app({bool online = true, String machineId = 'machine-1'}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MachineGitIdentity(machineId: machineId, isOnline: online),
        ),
      ),
    );

Map<String, dynamic> _identity({
  String name = 'Ada Lovelace',
  String email = 'ada@example.com',
  String source = 'settings',
}) => {
  'success': true,
  'name': name,
  'email': email,
  'source': source,
  if (source == 'settings') 'updatedAt': 1700000000000,
};

const _unset = {'success': true, 'name': '', 'email': '', 'source': 'none'};

final _row = find.byKey(const ValueKey('machine-git-identity'));
final _nameField = find.byKey(const ValueKey('git-identity-name'));
final _emailField = find.byKey(const ValueKey('git-identity-email'));

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

  test('a half identity is never reported as configured', () {
    final response = GitIdentityResponse.fromJson({
      'success': true,
      'name': 'Ada',
      'email': '',
      'source': 'settings',
    });
    expect(response.isConfigured, isFalse);
    expect(response.source, GitIdentitySource.none);
  });

  test('field validation mirrors the daemon rules', () {
    expect(validateGitIdentityName('  '), GitIdentityFieldError.required);
    expect(validateGitIdentityName('Ada <x>'), GitIdentityFieldError.invalid);
    expect(validateGitIdentityName('Ada\nL'), GitIdentityFieldError.invalid);
    expect(validateGitIdentityName(' Ada Lovelace '), isNull);
    expect(validateGitIdentityEmail(''), GitIdentityFieldError.required);
    expect(validateGitIdentityEmail('ada'), GitIdentityFieldError.invalid);
    expect(validateGitIdentityEmail('a b@c.d'), GitIdentityFieldError.invalid);
    expect(validateGitIdentityEmail('<a@c.d>'), GitIdentityFieldError.invalid);
    expect(validateGitIdentityEmail(' ada@example.com '), isNull);
  });

  testWidgets('offline machines neither load nor edit', (tester) async {
    var calls = 0;
    sync.testMachineRPCOverride = (_, _, _) async {
      calls++;
      return _identity();
    };
    await tester.pumpWidget(_app(online: false));
    await tester.pump();

    expect(calls, 0);
    expect(
      find.text('Connect this machine to view or change it.'),
      findsOneWidget,
    );
    expect(tester.widget<SettingsNavRow>(_row).onTap, isNull);
  });

  testWidgets('shows the identity the machine commits with', (tester) async {
    final methods = <String>[];
    sync.testMachineRPCOverride = (machineId, method, params) async {
      expect(machineId, 'machine-1');
      expect(params, isEmpty);
      methods.add(method);
      return _identity();
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(methods, ['git-identity-get']);
    expect(find.text('Ada Lovelace <ada@example.com>'), findsOneWidget);
  });

  testWidgets('labels an identity inherited from daemon configuration', (
    tester,
  ) async {
    sync.testMachineRPCOverride = (_, _, _) async =>
        _identity(source: 'config');
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ada Lovelace <ada@example.com> · from the daemon configuration',
      ),
      findsOneWidget,
    );
    await tester.tap(_row);
    await tester.pumpAndSettle();
    // Nothing app-owned to remove; saving overrides the fallback.
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('saves a trimmed identity and shows the confirmed value', (
    tester,
  ) async {
    final sets = <Map<String, dynamic>>[];
    sync.testMachineRPCOverride = (_, method, params) async {
      if (method == 'git-identity-get') return _unset;
      expect(method, 'git-identity-set');
      sets.add(Map<String, dynamic>.from(params));
      return _identity(name: 'Grace Hopper', email: 'grace@example.com');
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      find.text('Not set. New sessions cannot commit until you add one.'),
      findsOneWidget,
    );

    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.enterText(_nameField, '  Grace Hopper ');
    await tester.enterText(_emailField, ' grace@example.com ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(sets, [
      {'name': 'Grace Hopper', 'email': 'grace@example.com'},
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Grace Hopper <grace@example.com>'), findsOneWidget);
    expect(find.text('Git identity saved'), findsOneWidget);
  });

  testWidgets('invalid input never reaches the daemon', (tester) async {
    var sets = 0;
    sync.testMachineRPCOverride = (_, method, _) async {
      if (method == 'git-identity-set') sets++;
      return _unset;
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_row);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Enter an email'), findsOneWidget);

    await tester.enterText(_nameField, 'Ada');
    await tester.enterText(_emailField, 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(sets, 0);
  });

  testWidgets('a daemon rejection keeps the dialog and the old identity', (
    tester,
  ) async {
    sync.testMachineRPCOverride = (_, method, _) async {
      if (method == 'git-identity-get') return _identity();
      return {'success': false, 'error': 'email "x@y" is not a valid address'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.enterText(_emailField, 'x@y');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('email "x@y" is not a valid address'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Ada Lovelace <ada@example.com>'), findsOneWidget);
  });

  testWidgets('removing clears the app identity', (tester) async {
    final sets = <Map<String, dynamic>>[];
    sync.testMachineRPCOverride = (_, method, params) async {
      if (method == 'git-identity-get') return _identity();
      sets.add(Map<String, dynamic>.from(params));
      return _unset;
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(sets, [
      {'name': '', 'email': ''},
    ]);
    expect(
      find.text('Not set. New sessions cannot commit until you add one.'),
      findsOneWidget,
    );
    expect(find.text('Git identity removed'), findsOneWidget);
  });

  testWidgets('an old daemon asks for an update instead of editing', (
    tester,
  ) async {
    sync.testMachineRPCOverride = (_, _, _) async {
      throw const RpcException(
        code: RpcErrorCode.methodUnsupported,
        message: 'method not found',
        retryable: false,
      );
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.text('Update Happy CLI on this machine to set a git identity.'),
      findsOneWidget,
    );
    expect(tester.widget<SettingsNavRow>(_row).onTap, isNull);
  });

  testWidgets('a failed load can be retried from the row', (tester) async {
    var calls = 0;
    sync.testMachineRPCOverride = (_, _, _) async {
      calls++;
      if (calls == 1) throw TimeoutException('slow');
      return _identity();
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load the git identity. Tap to retry.'),
      findsOneWidget,
    );

    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Ada Lovelace <ada@example.com>'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a late answer for another machine is dropped', (tester) async {
    final first = Completer<Map<String, dynamic>>();
    sync.testMachineRPCOverride = (machineId, _, _) =>
        machineId == 'machine-1' ? first.future : Future.value(_unset);
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pumpWidget(_app(machineId: 'machine-2'));
    await tester.pumpAndSettle();
    first.complete(_identity());
    await tester.pumpAndSettle();

    expect(find.text('Ada Lovelace <ada@example.com>'), findsNothing);
    expect(
      find.text('Not set. New sessions cannot commit until you add one.'),
      findsOneWidget,
    );
  });
}
