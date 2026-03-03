import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';

Widget _wrapToolView({
  required Map<String, dynamic> tool,
  String? sessionId = 's1',
  Map<String, dynamic>? metadata,
  PermissionActionDelegate? permissionActionDelegate,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ToolView(
        tool: tool,
        sessionId: sessionId,
        metadata: metadata,
        permissionActionDelegate: permissionActionDelegate,
      ),
    ),
  );
}

Map<String, dynamic> _planTool({Map<String, dynamic>? permission}) {
  return <String, dynamic>{
    'name': 'ExitPlanMode',
    'state': 'pending',
    'input': <String, dynamic>{'plan': '## Plan'},
    'permission':
        permission ?? <String, dynamic>{'id': 'perm-1', 'status': 'pending'},
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolView permission integration', () {
    testWidgets('Allow emits allow action', (tester) async {
      final actions = <PermissionAction>[];

      await tester.pumpWidget(
        _wrapToolView(
          tool: _planTool(),
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('Allow'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.kind, PermissionActionKind.allow);
      expect(actions.single.sessionId, 's1');
      expect(actions.single.permissionId, 'perm-1');
      expect(actions.single.toolName, 'ExitPlanMode');
    });

    testWidgets('All edits emits allow-all-edits action', (tester) async {
      final actions = <PermissionAction>[];

      await tester.pumpWidget(
        _wrapToolView(
          tool: _planTool(),
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('All edits'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.kind, PermissionActionKind.allowAllEdits);
    });

    testWidgets('Deny emits deny action', (tester) async {
      final actions = <PermissionAction>[];

      await tester.pumpWidget(
        _wrapToolView(
          tool: _planTool(),
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('Deny'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.kind, PermissionActionKind.deny);
    });

    testWidgets('codex Yes emits codex-approve action', (tester) async {
      final actions = <PermissionAction>[];

      await tester.pumpWidget(
        _wrapToolView(
          tool: _planTool(),
          metadata: <String, dynamic>{'flavor': 'codex'},
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('Yes'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.kind, PermissionActionKind.codexApprove);
    });

    testWidgets('codex For session emits codex-approve-for-session action', (
      tester,
    ) async {
      final actions = <PermissionAction>[];

      await tester.pumpWidget(
        _wrapToolView(
          tool: _planTool(),
          metadata: <String, dynamic>{'flavor': 'codex'},
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('For session'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.kind, PermissionActionKind.codexApproveForSession);
    });

    testWidgets('codex Stop emits codex-abort action', (tester) async {
      final actions = <PermissionAction>[];

      await tester.pumpWidget(
        _wrapToolView(
          tool: _planTool(),
          metadata: <String, dynamic>{'flavor': 'codex'},
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('Stop'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.kind, PermissionActionKind.codexAbort);
    });

    testWidgets('For session on Bash emits allow-for-session action', (
      tester,
    ) async {
      final actions = <PermissionAction>[];
      final tool = <String, dynamic>{
        'name': 'Bash',
        'state': 'pending',
        'input': <String, dynamic>{'command': 'ls -la'},
        'permission': <String, dynamic>{'id': 'perm-2', 'status': 'pending'},
      };

      await tester.pumpWidget(
        _wrapToolView(
          tool: tool,
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('For session'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.kind, PermissionActionKind.allowForSession);
      expect(actions.single.permissionId, 'perm-2');
      expect(actions.single.toolName, 'Bash');
      expect(actions.single.toolInput?['command'], 'ls -la');
    });

    testWidgets('missing permission id makes Allow a no-op', (tester) async {
      final actions = <PermissionAction>[];
      final tool = _planTool(
        permission: <String, dynamic>{'status': 'pending'},
      );

      await tester.pumpWidget(
        _wrapToolView(
          tool: tool,
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('Allow'));
      await tester.pump();

      expect(actions, isEmpty);
    });

    testWidgets('missing permission.id falls back to toolUseId', (
      tester,
    ) async {
      final actions = <PermissionAction>[];
      final tool = <String, dynamic>{
        'name': 'ExitPlanMode',
        'state': 'pending',
        'toolUseId': 'tool-use-123',
        'input': <String, dynamic>{'plan': '## Plan'},
        'permission': <String, dynamic>{'status': 'pending'},
      };

      await tester.pumpWidget(
        _wrapToolView(
          tool: tool,
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('Allow'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.permissionId, 'tool-use-123');
    });

    testWidgets('missing sessionId hides permission footer', (tester) async {
      final actions = <PermissionAction>[];

      await tester.pumpWidget(
        _wrapToolView(
          tool: _planTool(),
          sessionId: null,
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      expect(find.text('Allow'), findsNothing);
      expect(find.text('Deny'), findsNothing);
      expect(actions, isEmpty);
    });
  });
}
