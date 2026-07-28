import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/tools/known_tools.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/tools/views/todo_view.dart';

/// The exact wire shape happy-cli-go forwards for a Codex `todo_list`
/// thread item: name is rewritten to `TodoWrite`, and the sanitized input
/// carries `items[{text, completed}]` — not Claude's `todos[{content,
/// status}]`.
Map<String, dynamic> _codexTodoTool({
  required List<Map<String, dynamic>> items,
  String callId = 'msg_1:call_todo',
  int createdAt = 1000,
  String state = 'completed',
}) {
  return <String, dynamic>{
    'name': 'TodoWrite',
    'toolUseId': callId,
    'state': state,
    'createdAt': createdAt,
    'input': <String, dynamic>{'items': items},
  };
}

const List<Map<String, dynamic>> _codexItems = [
  {'completed': false, 'text': 'Verify recovery state and restore boot_b'},
  {'completed': false, 'text': 'Build a valid-header finite-reset control'},
  {'completed': false, 'text': 'Run PID 1/initcall candidate'},
  {'completed': false, 'text': 'Restore stock and document the result'},
];

Widget _wrap(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(TodoView.resetPushGuard);
  tearDown(TodoView.resetPushGuard);

  group('TodoView — Codex todo_list shape', () {
    test('resolveTodos parses items[{text, completed}]', () {
      final todos = TodoView.resolveTodos(
        _codexTodoTool(items: List<Map<String, dynamic>>.from(_codexItems)),
      );

      expect(todos, hasLength(4));
      expect(todos.first.content, 'Verify recovery state and restore boot_b');
      expect(todos.every((t) => t.isPending), isTrue);
    });

    test('resolveTodos maps completed:true to the completed status', () {
      final todos = TodoView.resolveTodos(
        _codexTodoTool(
          items: const [
            {'completed': true, 'text': 'Done step'},
            {'completed': false, 'text': 'Open step'},
          ],
        ),
      );

      expect(todos.first.isCompleted, isTrue);
      expect(todos.last.isPending, isTrue);
    });

    test('resolveTodos still parses the Claude todos[{content}] shape', () {
      final todos = TodoView.resolveTodos({
        'name': 'TodoWrite',
        'input': {
          'todos': [
            {'content': 'Claude step', 'status': 'in_progress'},
          ],
        },
      });

      expect(todos.single.content, 'Claude step');
      expect(todos.single.isInProgress, isTrue);
    });

    testWidgets('renders one row per Codex item', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
          TodoView(
            tool: _codexTodoTool(
              items: List<Map<String, dynamic>>.from(_codexItems),
            ),
            sessionId: 's1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0/4 done'), findsOneWidget);
      expect(
        find.text('Verify recovery state and restore boot_b'),
        findsOneWidget,
      );
    });
  });

  group('TodoWrite — collapsed header description', () {
    test('falls back to input.items for the Codex shape', () {
      final def = KnownTools.get('TodoWrite')!;
      final description = def.extractDescription!(
        _codexTodoTool(items: List<Map<String, dynamic>>.from(_codexItems)),
        null,
      );

      expect(description, '4 items');
    });

    test('still reads input.todos for the Claude shape', () {
      final def = KnownTools.get('TodoWrite')!;
      final description = def.extractDescription!({
        'name': 'TodoWrite',
        'input': {
          'todos': [
            {'content': 'a', 'status': 'pending'},
            {'content': 'b', 'status': 'pending'},
          ],
        },
      }, null);

      expect(description, '2 items');
    });
  });

  group('TodoView — global task state push', () {
    late BuildContext ctx;

    Future<ProviderContainer> pumpHost(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('pushToolToGlobalState fills the session bucket',
        (tester) async {
      final container = await pumpHost(tester);
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(items: List<Map<String, dynamic>>.from(_codexItems)),
        's1',
      );

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items, hasLength(4));
      expect(items.first.content, 'Verify recovery state and restore boot_b');
      expect(items.first.status, TodoState.pending);
      expect(items.first.sessionId, 's1');
      // Ids are tool-stable so a re-render doesn't churn the list.
      expect(items.first.id, startsWith('msg_1:call_todo#'));
    });

    testWidgets('a newer snapshot replaces the previous plan', (tester) async {
      final container = await pumpHost(tester);
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(
          items: const [
            {'completed': false, 'text': 'Step one'},
            {'completed': false, 'text': 'Step two'},
          ],
        ),
        's1',
      );
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(
          callId: 'msg_1:call_todo',
          createdAt: 2000,
          items: const [
            {'completed': true, 'text': 'Step one'},
            {'completed': false, 'text': 'Step two'},
          ],
        ),
        's1',
      );

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items, hasLength(2));
      expect(items.first.status, TodoState.completed);
      expect(items.last.status, TodoState.pending);
    });

    testWidgets('an out-of-order replay cannot clobber a newer plan',
        (tester) async {
      // The chat ListView is reversed: a cold load mounts the newest tool
      // card first, then older ones. The older push must lose.
      final container = await pumpHost(tester);
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(
          createdAt: 2000,
          items: const [
            {'completed': true, 'text': 'Step one'},
            {'completed': true, 'text': 'Step two'},
          ],
        ),
        's1',
      );
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(
          createdAt: 1000,
          items: const [
            {'completed': false, 'text': 'Step one'},
          ],
        ),
        's1',
      );

      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items, hasLength(2));
      expect(items.every((i) => i.status == TodoState.completed), isTrue);
    });

    testWidgets('sessions do not leak into each other', (tester) async {
      final container = await pumpHost(tester);
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(
          items: const [
            {'completed': false, 'text': 'Session one work'},
          ],
        ),
        's1',
      );
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(
          items: const [
            {'completed': false, 'text': 'Session two work'},
          ],
        ),
        's2',
      );

      final state = container.read(todoStateNotifierProvider);
      expect(state.bySession['s1']!.single.content, 'Session one work');
      expect(state.bySession['s2']!.single.content, 'Session two work');
    });

    testWidgets('an empty TodoWrite clears stale tasks', (tester) async {
      final container = await pumpHost(tester);
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(
          items: const [
            {'completed': false, 'text': 'Stale step'},
          ],
        ),
        's1',
      );
      TodoView.pushToolToGlobalState(
        ctx,
        _codexTodoTool(createdAt: 2000, items: const []),
        's1',
      );

      expect(
        container.read(todoStateNotifierProvider).bySession['s1'],
        isEmpty,
      );
    });
  });

  group('ToolView — pushes todo tools while collapsed', () {
    testWidgets('a collapsed Codex TodoWrite still fills the banner state',
        (tester) async {
      // Regression: the push used to live in TodoView.initState, and the
      // body only mounts while the card is expanded — so Codex sessions
      // (whose whole plan arrives as TodoWrite) never populated the
      // session tasks banner or the Zen list.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
          ToolView(
            tool: _codexTodoTool(
              items: List<Map<String, dynamic>>.from(_codexItems),
            ),
            sessionId: 's1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collapsed: no todo rows rendered...
      expect(find.text('0/4 done'), findsNothing);
      // ...but the global state has them.
      final items = container.read(todoStateNotifierProvider).bySession['s1']!;
      expect(items, hasLength(4));
      expect(items.last.content, 'Restore stock and document the result');
    });

    testWidgets('expanding the card renders the rows', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container,
          ToolView(
            tool: _codexTodoTool(
              items: List<Map<String, dynamic>>.from(_codexItems),
            ),
            sessionId: 's1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The header title lives in a Text.rich, so tap the header InkWell.
      expect(
        find.textContaining('Todo List', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('0/4 done'), findsOneWidget);
    });
  });
}
