import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/zen/views/zen_home.dart';

class _StubSessionsNotifier extends SessionsNotifier {
  @override
  Map<String, Session> build() => {'session-1': _session()};

  void replace(Session session) {
    state = {session.id: session};
  }

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ZenHomeScreen', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          sessionsNotifierProvider.overrideWith(_StubSessionsNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Widget buildApp() {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ZenHomeScreen(),
        ),
      );
    }

    testWidgets('shows live chat tasks when session metadata has none', (
      tester,
    ) async {
      container.read(todoStateNotifierProvider.notifier).setItemsForSession(
        'session-1',
        [_todo('live-task', 'Implement the telemetry driver')],
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Implement the telemetry driver'), findsOneWidget);
      expect(find.text('No active tasks'), findsNothing);
    });

    testWidgets('live empty snapshot clears stale session tasks', (
      tester,
    ) async {
      final notifier = container.read(sessionsNotifierProvider.notifier);
      (notifier as _StubSessionsNotifier).replace(
        _session(todos: [_todo('stale-task', 'Stale server task')]),
      );
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('session-1', const []);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Stale server task'), findsNothing);
      expect(find.text('No active tasks'), findsOneWidget);
    });

    testWidgets('completed rows hide immediately and retained rows reopen', (
      tester,
    ) async {
      final notifier = container.read(todoStateNotifierProvider.notifier);
      notifier.setItemsForSession('session-1', [
        _todo('task', 'Finish this task'),
        _todo('canceled', 'Canceled task', status: TodoState.canceled),
      ]);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Finish this task'), findsOneWidget);
      expect(find.text('Canceled task'), findsNothing);

      notifier.markComplete('task');
      await tester.pumpAndSettle();
      expect(find.text('Finish this task'), findsNothing);
      expect(find.text('No active tasks'), findsOneWidget);
      expect(
        container.read(todoStateNotifierProvider).bySession['session-1'],
        hasLength(2),
      );

      notifier.toggleComplete('task');
      await tester.pumpAndSettle();
      expect(find.text('Finish this task'), findsOneWidget);
      expect(find.text('No active tasks'), findsNothing);
    });

    testWidgets('persisted terminal rows hydrate into an empty task view', (
      tester,
    ) async {
      final notifier =
          container.read(sessionsNotifierProvider.notifier)
              as _StubSessionsNotifier;
      notifier.replace(
        _session(
          todos: TodoItem.listFromJson([
            {'id': 'done', 'content': 'Finished task', 'status': 'completed'},
            {
              'id': 'canceled',
              'content': 'Canceled task',
              'status': 'cancelled',
            },
          ]),
        ),
      );

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.text('Finished task'), findsNothing);
      expect(find.text('Canceled task'), findsNothing);
      expect(find.text('No active tasks'), findsOneWidget);
      expect(find.byTooltip('Filter tasks by agent'), findsNothing);
    });

    testWidgets('filters sub-items by inherited assigned agent', (
      tester,
    ) async {
      container
          .read(todoStateNotifierProvider.notifier)
          .setItemsForSession('session-1', [
            _todo('parent', 'Agent A parent', agentId: 'agent-a'),
            _todo('child', 'Agent A child', parentId: 'parent'),
            _todo('other', 'Agent B task', agentId: 'agent-b'),
          ]);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter tasks by agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('agent-a').last);
      await tester.pumpAndSettle();
      expect(find.text('Agent A parent'), findsOneWidget);
      expect(find.text('Agent A child'), findsOneWidget);
      expect(find.text('Agent B task'), findsNothing);
      expect(find.text('Sub-item of #parent'), findsOneWidget);
    });

    testWidgets(
      'persisted child inherits agent from a hidden completed parent',
      (tester) async {
        final notifier =
            container.read(sessionsNotifierProvider.notifier)
                as _StubSessionsNotifier;
        notifier.replace(
          _session(
            todos: TodoItem.listFromJson([
              {
                'id': 'parent',
                'content': 'Completed parent',
                'status': 'completed',
                'agentId': 'agent-a',
              },
              {
                'id': 'child',
                'content': 'Agent A child',
                'status': 'pending',
                'parentId': 'parent',
              },
              {
                'id': 'other',
                'content': 'Agent B task',
                'status': 'pending',
                'agentId': 'agent-b',
              },
            ]),
          ),
        );
        await tester.pumpWidget(buildApp());
        await tester.pumpAndSettle();
        expect(find.text('Completed parent'), findsNothing);
        await tester.tap(find.byTooltip('Filter tasks by agent'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('agent-a').last);
        await tester.pumpAndSettle();

        expect(find.text('Agent A child'), findsOneWidget);
        expect(find.text('Agent B task'), findsNothing);
        expect(find.text('Completed parent'), findsNothing);
        expect(find.text('Sub-item of #parent'), findsOneWidget);
      },
    );
  });
}

Session _session({List<TodoItem>? todos}) {
  return Session(
    id: 'session-1',
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: 1,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: true,
    presence: 'online',
    todos: todos,
    metadata: const Metadata(host: 'localhost', path: '/workspace/project'),
  );
}

TodoItem _todo(
  String id,
  String content, {
  TodoState status = TodoState.pending,
  String? parentId,
  String? agentId,
}) {
  return TodoItem(
    id: id,
    content: content,
    status: status,
    priority: 'medium',
    order: 0,
    parentId: parentId,
    agentId: agentId,
    createdAt: 1,
    updatedAt: 1,
    sessionId: 'session-1',
  );
}
