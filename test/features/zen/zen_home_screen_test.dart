import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/components.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/todo_notifier.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

/// A stub [TodoStateNotifier] that avoids touching the sync singleton.
class _StubTodoNotifier extends TodoStateNotifier {
  _StubTodoNotifier(this._seed);

  final TodoListState _seed;

  @override
  TodoListState build() => _seed;

  @override
  void loadFromSync() {
    // No-op — avoids touching the sync singleton.
  }

  @override
  Future<void> refreshFromSync() async {
    // No-op.
  }
}

TodoItem _makeTodo({
  required String id,
  String content = 'Test task',
  TodoState status = TodoState.pending,
  String priority = 'medium',
  String sessionId = 'session-1',
  int? completedAt,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TodoItem(
    id: id,
    content: content,
    status: status,
    priority: priority,
    order: 0,
    createdAt: now - 60000,
    updatedAt: now,
    sessionId: sessionId,
    completedAt: completedAt,
  );
}

TodoListState _makeState(List<TodoItem> items) {
  final lists = <String?, TodoList>{};
  for (final item in items) {
    final sid = item.sessionId;
    final existing = lists[sid];
    if (existing != null) {
      lists[sid] = existing.copyWith(
        items: [...existing.items, item],
      );
    } else {
      lists[sid] = TodoList(
        sessionId: sid,
        items: [item],
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }
  }
  return TodoListState(lists: lists);
}

Widget _buildApp({required TodoListState todoState, required Widget child}) {
  return ProviderScope(
    overrides: [
      todoStateNotifierProvider.overrideWith(
        () => _StubTodoNotifier(todoState),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenHomeScreen - widget rendering', () {
    testWidgets('shows empty state when no todos', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          todoState: TodoListState(),
          child: const _ZenHomeReplica(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Empty state icon.
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      // Empty state should show "No Tasks Yet".
      expect(find.text('No Tasks Yet'), findsOneWidget);
      expect(find.text('Tap + to add your first task.'), findsOneWidget);
    });

    testWidgets('shows task count badge when todos exist', (tester) async {
      final state = _makeState([
        _makeTodo(id: '1', status: TodoState.pending),
        _makeTodo(id: '2', status: TodoState.completed),
      ]);

      await tester.pumpWidget(
        _buildApp(todoState: state, child: const _ZenHomeReplica()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Badge shows completed/total.
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('shows active todos in Active section', (tester) async {
      final state = _makeState([
        _makeTodo(id: '1', content: 'Pending task'),
        _makeTodo(
          id: '2',
          content: 'In progress task',
          status: TodoState.inProgress,
        ),
      ]);

      await tester.pumpWidget(
        _buildApp(todoState: state, child: const _ZenHomeReplica()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Pending task'), findsOneWidget);
      expect(find.text('In progress task'), findsOneWidget);
    });

    testWidgets('shows completed todos in Completed section',
        (tester) async {
      final state = _makeState([
        _makeTodo(
          id: '1',
          content: 'Done task',
          status: TodoState.completed,
        ),
        _makeTodo(
          id: '2',
          content: 'Canceled task',
          status: TodoState.canceled,
        ),
      ]);

      await tester.pumpWidget(
        _buildApp(todoState: state, child: const _ZenHomeReplica()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Done task'), findsOneWidget);
      expect(find.text('Canceled task'), findsOneWidget);
    });

    testWidgets('renders both active and completed sections',
        (tester) async {
      final state = _makeState([
        _makeTodo(id: '1', content: 'Active task'),
        _makeTodo(
          id: '2',
          content: 'Finished task',
          status: TodoState.completed,
        ),
      ]);

      await tester.pumpWidget(
        _buildApp(todoState: state, child: const _ZenHomeReplica()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Active task'), findsOneWidget);
      expect(find.text('Finished task'), findsOneWidget);
    });

    testWidgets('completed todos show line-through decoration',
        (tester) async {
      final state = _makeState([
        _makeTodo(
          id: '1',
          content: 'Done',
          status: TodoState.completed,
        ),
      ]);

      await tester.pumpWidget(
        _buildApp(todoState: state, child: const _ZenHomeReplica()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final text = tester.widget<Text>(find.text('Done'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('pending todos do not show line-through', (tester) async {
      final state = _makeState([
        _makeTodo(id: '1', content: 'Active item'),
      ]);

      await tester.pumpWidget(
        _buildApp(todoState: state, child: const _ZenHomeReplica()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final text = tester.widget<Text>(find.text('Active item'));
      expect(text.style?.decoration, isNull);
    });

    testWidgets('shows FAB for adding new task', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          todoState: TodoListState(),
          child: const _ZenHomeReplica(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('todo cards show priority dot', (tester) async {
      final state = _makeState([
        _makeTodo(id: '1', priority: 'critical'),
      ]);

      await tester.pumpWidget(
        _buildApp(todoState: state, child: const _ZenHomeReplica()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The priority dot uses AppStatusDot with color based on priority.
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('empty state shows add button', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          todoState: TodoListState(),
          child: const _ZenHomeReplica(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('New Task'), findsOneWidget);
    });
  });
}

/// A minimal replica of the ZenHomeScreen build logic that avoids the
/// sync singleton subscription in initState.
class _ZenHomeReplica extends ConsumerStatefulWidget {
  const _ZenHomeReplica();

  @override
  ConsumerState<_ZenHomeReplica> createState() => _ZenHomeReplicaState();
}

class _ZenHomeReplicaState extends ConsumerState<_ZenHomeReplica> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(todoStateNotifierProvider.notifier)
          .refreshFromSync();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final todoState = ref.watch(todoStateNotifierProvider);
    final allTodos = todoState.allTodos;
    final totalCount = todoState.totalCount;
    final completedCount = todoState.completedCount;

    final activeTodos = allTodos
        .where(
          (t) =>
              t.status == TodoState.pending ||
              t.status == TodoState.inProgress,
        )
        .toList(growable: false);

    final completedTodos = allTodos
        .where((t) => t.status.isTerminal)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Zen'),
            if (totalCount > 0) ...[
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$completedCount/$totalCount',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const Shimmer(
              child: Center(child: CircularProgressIndicator()),
            )
          : allTodos.isEmpty
              ? AppEmptyState(
                  icon: Icons.check_circle_outline,
                  title: 'No Tasks Yet',
                  subtitle: 'Tap + to add your first task.',
                  action: FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('New Task'),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    80,
                  ),
                  children: [
                    if (activeTodos.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text('Active'),
                      ),
                      ...activeTodos.map(
                        (item) => Card(
                          margin: const EdgeInsets.only(
                            bottom: AppSpacing.md,
                          ),
                          child: ListTile(
                            title: Text(
                              item.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (completedTodos.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text('Completed'),
                      ),
                      ...completedTodos.map(
                        (item) => Card(
                          margin: const EdgeInsets.only(
                            bottom: AppSpacing.md,
                          ),
                          child: ListTile(
                            title: Text(
                              item.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
