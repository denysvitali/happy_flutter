import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/tool_status_indicator.dart';
import 'package:happy_flutter/features/chat/tools/tool_view.dart';
import 'package:happy_flutter/features/chat/widgets/agent_conversation_info.dart';
import 'package:happy_flutter/features/chat/widgets/agent_conversation_row.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('expanded prompt survives content and theme updates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(const AgentConversationPrompt(prompt: 'Original instructions')),
    );
    expect(
      find.text('Original instructions', findRichText: true),
      findsNothing,
    );

    await tester.tap(find.text('Prompt'));
    await tester.pumpAndSettle();
    expect(
      find.text('Original instructions', findRichText: true),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _app(
        const AgentConversationPrompt(prompt: 'Updated instructions'),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Original instructions', findRichText: true),
      findsNothing,
    );
    expect(
      find.text('Updated instructions', findRichText: true),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.expand_less_rounded), findsOneWidget);

    await tester.tap(find.text('Prompt'));
    await tester.pumpAndSettle();
    expect(find.text('Updated instructions', findRichText: true), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('model fallback remains explicit in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _app(
          const AgentConversationDebugCard(
            state: 'running',
            messageId: 'task-id',
            parentModel: 'orchestrator',
          ),
          brightness: brightness,
        ),
      );
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Parent model'), findsOneWidget);
      expect(find.text('orchestrator'), findsOneWidget);

      await tester.pumpWidget(
        _app(
          const AgentConversationDebugCard(
            state: 'completed',
            messageId: 'task-id',
            subagentModel: 'worker-model',
            parentModel: 'orchestrator',
          ),
          brightness: brightness,
        ),
      );
      expect(find.text('worker-model'), findsOneWidget);
      expect(find.text('Parent model'), findsNothing);
      expect(find.text('orchestrator'), findsNothing);
      expect(find.text('completed'), findsOneWidget);
      expect(find.text('task-id'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final name in ['Task', 'Agent', 'Workflow']) {
    testWidgets('$name rows open the nested conversation with original data', (
      tester,
    ) async {
      final message = <String, dynamic>{
        'id': 'nested-id',
        'kind': 'tool-call',
        'name': name,
        'state': 'completed',
        'input': <String, dynamic>{
          'description': 'Nested investigation',
          'prompt': 'Full prompt',
          'subagent_type': 'explore',
        },
        'children': <Map<String, dynamic>>[
          {'id': 'nested-child', 'kind': 'text', 'content': 'Found details'},
        ],
      };
      Object? routedExtra;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: AgentConversationMessage(
                message: message,
                sessionId: 'session-id',
                isSessionOnline: true,
              ),
            ),
          ),
          GoRoute(
            path: '/chat/:sessionId/agent/:messageId',
            builder: (context, state) {
              routedExtra = state.extra;
              return Scaffold(body: Text(state.uri.path));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

      expect(find.text('Nested investigation'), findsOneWidget);
      expect(find.text('Full prompt'), findsNothing);
      expect(find.text('explore'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(
        tester
            .widget<ToolStatusIndicator>(find.byType(ToolStatusIndicator))
            .state,
        ToolState.completed,
      );

      await tester.tap(find.text('Nested investigation'));
      await tester.pumpAndSettle();
      expect(find.text('/chat/session-id/agent/nested-id'), findsOneWidget);
      expect(routedExtra, same(message));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tool details retain session, metadata and original message', (
    tester,
  ) async {
    final message = <String, dynamic>{
      'id': 'read-id',
      'kind': 'tool-call',
      'name': 'Read',
      'state': 'completed',
      'input': <String, dynamic>{'file_path': '/project/file.txt'},
      'result': 'File content',
    };
    final metadata = <String, dynamic>{'path': '/project'};
    Object? routedExtra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: AgentConversationMessage(
              message: message,
              sessionId: 'offline-session',
              isSessionOnline: false,
              metadata: metadata,
            ),
          ),
        ),
        GoRoute(
          path: '/chat/:sessionId/message/:messageId',
          builder: (context, state) {
            routedExtra = state.extra;
            return Scaffold(body: Text(state.uri.path));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    final tool = tester.widget<ToolView>(find.byType(ToolView));
    expect(tool.tool, same(message));
    expect(tool.metadata, same(metadata));
    expect(tool.sessionId, 'offline-session');
    expect(tool.isSessionOnline, isFalse);

    tool.onPress!();
    await tester.pumpAndSettle();
    expect(find.text('/chat/offline-session/message/read-id'), findsOneWidget);
    expect(routedExtra, same(message));
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline errors keep their detail dialog and debug data', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AgentConversationMessage(
          sessionId: 'session-id',
          isSessionOnline: true,
          message: {
            'kind': 'error',
            'errorType': 'Gateway',
            'errorMessage': 'Model unavailable',
            'debugData': {'code': 400},
          },
        ),
      ),
    );

    await tester.tap(find.text('Gateway: Model unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Gateway'), findsOneWidget);
    expect(find.text('Model unavailable'), findsOneWidget);
    expect(find.text('Debug data:'), findsOneWidget);
    expect(find.text('{code: 400}'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Gateway: Model unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
