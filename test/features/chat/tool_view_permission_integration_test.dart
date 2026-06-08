import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/json_viewer.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';

Widget _wrapToolView({
  required Map<String, dynamic> tool,
  String? sessionId = 's1',
  Map<String, dynamic>? metadata,
  PermissionActionDelegate? permissionActionDelegate,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ToolView(
          tool: tool,
          sessionId: sessionId,
          metadata: metadata,
          permissionActionDelegate: permissionActionDelegate,
        ),
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

String _richTextContent(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((widget) => widget.text.toPlainText())
      .join('\n');
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

    testWidgets('YOLO emits yolo action', (tester) async {
      final actions = <PermissionAction>[];

      await tester.pumpWidget(
        _wrapToolView(
          tool: _planTool(),
          permissionActionDelegate: (action) async {
            actions.add(action);
          },
        ),
      );

      await tester.tap(find.text('YOLO'));
      await tester.pump();

      expect(actions, hasLength(1));
      expect(actions.single.kind, PermissionActionKind.yolo);
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

    testWidgets('unknown Codex MCP tool calls onPress on tap (minimal mode)', (
      tester,
    ) async {
      var onPressCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ToolView(
                tool: <String, dynamic>{
                  'name': 'list_mcp_resources',
                'state': 'completed',
                'toolUseId': 'mcp-1',
                'input': <String, dynamic>{
                  'server': 'codex',
                  'arguments': <String, dynamic>{},
                },
                'result': <String, dynamic>{
                  'structuredContent': <String, dynamic>{
                    'resources': <dynamic>[],
                  },
                },
              },
              sessionId: 's1',
              metadata: <String, dynamic>{'flavor': 'codex'},
              onPress: () => onPressCalled = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('list_mcp_resources'), findsOneWidget);
      expect(find.text('INPUT'), findsNothing);
      expect(find.text('OUTPUT'), findsNothing);

      await tester.tap(find.byType(ToolView));
      await tester.pump();

      expect(onPressCalled, isTrue);
    });

    testWidgets('mcp text result renders as text with raw JSON toggle', (
      tester,
    ) async {
      const statusText =
          'Workflow Status for bda45616\n'
          'Overall: pending\n'
          'Workflows: 1\n'
          'Filter Mode: latest\n'
          'By Conclusion:\n'
          '  in_progress: 1\n'
          'Workflow Details:\n'
          '  - Happy Flutter CI/CD: in_progress/- (id: 27120557489)\n';

      await tester.pumpWidget(
        _wrapToolView(
          tool: <String, dynamic>{
            'name': 'mcp__gh_actions__get_check_status',
            'state': 'completed',
            'toolUseId': 'mcp-2',
            'input': <String, dynamic>{},
            'result': <String, dynamic>{
              'content': <Map<String, dynamic>>[
                <String, dynamic>{'text': statusText, 'type': 'text'},
              ],
              'result': <String, dynamic>{
                'content': <Map<String, dynamic>>[
                  <String, dynamic>{'text': statusText, 'type': 'text'},
                ],
                'structured_content': null,
              },
              'status': 'completed',
            },
          },
        ),
      );

      await tester.tap(find.text('Gh Actions: Get Check Status'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Workflow Status for bda45616'),
        findsOneWidget,
      );
      expect(find.textContaining('Happy Flutter CI/CD'), findsOneWidget);
      expect(find.text('Show JSON'), findsOneWidget);
      expect(find.textContaining('"structured_content"'), findsNothing);

      final showJsonButton = find.widgetWithText(TextButton, 'Show JSON');
      await tester.ensureVisible(showJsonButton);
      await tester.tap(showJsonButton);
      await tester.pumpAndSettle();

      expect(find.text('Hide JSON'), findsOneWidget);
      expect(_richTextContent(tester), contains('"structured_content"'));
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
