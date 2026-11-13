import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/settings_section.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/features/machine/widgets/machine_kubernetes_claude_md.dart';

Widget _app({bool online = true, String machineId = 'machine-1'}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MachineKubernetesClaudeMd(
            machineId: machineId,
            isOnline: online,
          ),
        ),
      ),
    );

Map<String, dynamic> _instructions([String content = '']) => {
  'success': true,
  'content': content,
  'updatedAt': 1700000000000,
};

final _row = find.byKey(const ValueKey('machine-kubernetes-claude-md'));
final _content = find.byKey(const ValueKey('kubernetes-claude-md-content'));

void main() {
  final sync = Sync();

  tearDown(() {
    sync.testMachineRPCOverride = null;
  });

  test('response preserves Markdown and validates UTF-8 byte length', () {
    const content = '  # Instructions\n\n    code\n';
    final response = KubernetesClaudeMdResponse.fromJson(
      _instructions(content),
    );
    expect(response.content, content);
    expect(response.isConfigured, isTrue);
    expect(
      KubernetesClaudeMdResponse.fromJson(_instructions()).isConfigured,
      isFalse,
    );
    expect(kubernetesClaudeMdContentTooLarge('x' * 65536), isFalse);
    expect(kubernetesClaudeMdContentTooLarge('x' * 65537), isTrue);
    expect(kubernetesClaudeMdContentTooLarge('😀' * 16384), isFalse);
    expect(kubernetesClaudeMdContentTooLarge('😀' * 16385), isTrue);
  });

  testWidgets('offline machines neither load nor edit', (tester) async {
    var calls = 0;
    sync.testMachineRPCOverride = (_, _, _) async {
      calls++;
      return _instructions();
    };
    await tester.pumpWidget(_app(online: false));
    await tester.pump();
    expect(calls, 0);
    expect(tester.widget<SettingsNavRow>(_row).onTap, isNull);
    expect(
      find.text('Connect this machine to view or edit Pod instructions.'),
      findsOneWidget,
    );
  });

  testWidgets('loads and saves exact Markdown through machine RPC', (
    tester,
  ) async {
    const draft = '  # Team instructions\n\nUse tests.\n';
    final sets = <Map<String, dynamic>>[];
    sync.testMachineRPCOverride = (machineId, method, params) async {
      expect(machineId, 'machine-1');
      if (method == 'kubernetes-claude-md-get') {
        expect(params, isEmpty);
        return _instructions();
      }
      expect(method, 'kubernetes-claude-md-set');
      sets.add(Map<String, dynamic>.from(params));
      return _instructions(draft);
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      find.text('No machine-level instructions. Tap to add them.'),
      findsOneWidget,
    );
    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.enterText(_content, draft);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(sets, [
      {'content': draft},
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Configured · tap to edit'), findsOneWidget);
    expect(find.text('Kubernetes instructions saved'), findsOneWidget);
  });

  testWidgets('clear sends an empty string for future Pods', (tester) async {
    final sets = <Map<String, dynamic>>[];
    sync.testMachineRPCOverride = (_, method, params) async {
      if (method == 'kubernetes-claude-md-get') {
        return _instructions('# Old instructions\n');
      }
      sets.add(Map<String, dynamic>.from(params));
      return _instructions();
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Clear'));
    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(sets, [
      {'content': ''},
    ]);
    expect(find.text('Kubernetes instructions cleared'), findsOneWidget);
  });

  testWidgets('oversized Unicode content is rejected before saving', (
    tester,
  ) async {
    var sets = 0;
    sync.testMachineRPCOverride = (_, method, _) async {
      if (method == 'kubernetes-claude-md-set') sets++;
      return _instructions();
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.enterText(_content, '😀' * 16385);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Instructions must be no larger than 64 KiB in UTF-8.'),
      findsOneWidget,
    );
    expect(sets, 0);
  });

  testWidgets('NUL content is rejected before saving', (tester) async {
    var sets = 0;
    sync.testMachineRPCOverride = (_, method, _) async {
      if (method == 'kubernetes-claude-md-set') sets++;
      return _instructions();
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.enterText(_content, '# Invalid\u0000text');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Instructions cannot contain NUL characters.'),
      findsOneWidget,
    );
    expect(sets, 0);
  });

  testWidgets('failed save retains draft and confirmed old setting', (
    tester,
  ) async {
    sync.testMachineRPCOverride = (_, method, _) async {
      if (method == 'kubernetes-claude-md-get') {
        return _instructions('# Original\n');
      }
      return {'success': false, 'error': 'Could not persist instructions'};
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.enterText(_content, '# Unsaved draft\n');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Could not persist instructions'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(_content).controller!.text,
      '# Unsaved draft\n',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(_content).controller!.text,
      '# Original\n',
    );
  });

  testWidgets('old daemon displays an upgrade requirement without editing', (
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
    expect(tester.widget<SettingsNavRow>(_row).onTap, isNull);
    expect(
      find.text(
        'Update Happy CLI on this machine to manage Kubernetes '
        'instructions.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('load failure can retry without opening an empty editor', (
    tester,
  ) async {
    var calls = 0;
    sync.testMachineRPCOverride = (_, _, _) async {
      if (++calls == 1) throw TimeoutException('slow');
      return _instructions('# Loaded\n');
    };
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load Pod instructions. Tap to retry.'),
      findsOneWidget,
    );
    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Configured · tap to edit'), findsOneWidget);
  });

  testWidgets('late load from a different machine is ignored', (tester) async {
    final first = Completer<Map<String, dynamic>>();
    sync.testMachineRPCOverride = (machineId, _, _) =>
        machineId == 'machine-1' ? first.future : Future.value(_instructions());
    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pumpWidget(_app(machineId: 'machine-2'));
    await tester.pumpAndSettle();
    first.complete(_instructions('# Wrong machine\n'));
    await tester.pumpAndSettle();
    expect(find.text('Configured · tap to edit'), findsNothing);
    expect(
      find.text('No machine-level instructions. Tap to add them.'),
      findsOneWidget,
    );
  });
}
