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

TodoItem _todo(String id, String content) {
  return TodoItem(
    id: id,
    content: content,
    status: TodoState.pending,
    priority: 'medium',
    order: 0,
    createdAt: 1,
    updatedAt: 1,
    sessionId: 'session-1',
  );
}
