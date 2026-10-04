import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/agent_presentation.dart';
import 'package:happy_flutter/features/chat/widgets/agent_conversation_info.dart';
import 'package:happy_flutter/features/chat/widgets/agents_list_sheet.dart';

Map<String, dynamic> _native({
  Map<String, dynamic>? metadata,
  List<Map<String, dynamic>> children = const [],
  Map<String, dynamic>? result,
}) => {
  'name': 'Agent',
  'model': 'gpt-6-sol',
  'input': {'subagent_type': 'codex', 'agentMetadata': ?metadata},
  'children': children,
  'result': ?result,
};

void main() {
  for (final model in <String?>['gpt-6-luna', null]) {
    testWidgets('native list shows reported child model $model at 320px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final role = model == null
          ? 'explorer-with-a-long-custom-role-that-wraps-on-small-screens'
          : 'explorer';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AgentsListSheet(
              sessionId: 'native-list',
              initialProjection: AgentSessionProjection(
                agents: [
                  {
                    ..._native(metadata: {'role': role, 'model': ?model}),
                    'id': 'native',
                    'state': 'completed',
                  },
                ],
                progress: const TaskProgress(
                  total: 1,
                  running: 0,
                  completed: 1,
                  error: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text(role), findsOneWidget);
      expect(find.text(model ?? 'Model not reported'), findsOneWidget);
      expect(find.text('gpt-6-sol'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('native child Luna overrides parent Sol and anchor model', () {
    final details = AgentPresentation.fromMessage(
      _native(
        metadata: {'model': 'stale-model', 'role': 'explorer'},
        children: [
          {
            'agentMetadata': {
              'role': 'explorer',
              'model': 'gpt-6-luna',
              'source': 'thread',
            },
          },
        ],
      ),
    );
    expect(details.model, 'gpt-6-luna');
    expect(details.parentModel, isNull);
    expect(details.overview, 'explorer · gpt-6-luna');
    expect(details.source, 'thread');
  });

  test('native missing child model and permissions stay unknown', () {
    final message = _native(metadata: {'role': 'read-only'});
    message['input']['model'] = 'parent-default';
    message['metadata'] = {'model': 'parent-default', 'mode': 'bypass'};
    final details = AgentPresentation.fromMessage(message);
    expect(details.model, isNull);
    expect(details.parentModel, isNull);
    expect(details.sandboxLabel, 'Not reported');
    expect(details.approvalLabel, 'Not reported');
  });

  test('late child and terminal snapshots enrich initially unknown anchor', () {
    final initial = _native();
    expect(AgentPresentation.fromMessage(initial).model, isNull);
    final enriched = {
      ...initial,
      'children': [
        {
          'agentMetadata': {'role': 'worker', 'model': 'gpt-6-luna'},
        },
      ],
      'result': {
        'agentMetadata': {
          'role': 'worker',
          'model': 'gpt-6-sol',
          'reasoningEffort': 'high',
          'source': 'thread',
        },
      },
    };
    final details = AgentPresentation.fromMessage(enriched);
    expect(details.model, 'gpt-6-sol');
    expect(details.role, 'worker');
    expect(details.effort, 'high');
  });

  test('nested grandchild metadata never becomes child configuration', () {
    final details = AgentPresentation.fromMessage(
      _native(
        children: [
          {
            'name': 'Agent',
            'agentMetadata': {'model': 'grandchild'},
            'children': [
              {
                'agentMetadata': {'model': 'grandchild'},
              },
            ],
          },
        ],
      ),
    );
    expect(details.model, isNull);
  });

  test('present snapshot clears omitted fields and empty map clears all', () {
    final message = _native(
      metadata: {
        'model': 'old',
        'reasoningEffort': 'high',
        'effectiveSandbox': 'read-only',
        'approvalPolicy': 'never',
      },
      children: [
        {
          'agentMetadata': {'model': 'new', 'source': 'thread'},
        },
        {'content': 'No snapshot update'},
      ],
    );
    final updated = AgentPresentation.fromMessage(message);
    expect(updated.model, 'new');
    expect(updated.effort, isNull);
    expect(updated.sandboxLabel, 'Not reported');
    expect(updated.approvalLabel, 'Not reported');
    message['children'].add({'agentMetadata': <String, dynamic>{}});
    final cleared = AgentPresentation.fromMessage(message);
    expect(cleared.model, isNull);
    expect(cleared.metadata, isEmpty);
  });

  test('result observation time wins over intervening text metadata', () {
    final details = AgentPresentation.fromMessage(
      _native(
        children: [
          {
            'kind': 'tool-call',
            'name': 'Read',
            'createdAt': 1000,
            '_agentMetadataObservedAt': 3000,
            'agentMetadata': {'model': 'result-new'},
          },
          {
            'kind': 'text',
            'createdAt': 2000,
            'agentMetadata': {'model': 'intervening-old'},
          },
        ],
      ),
    );
    expect(details.model, 'result-new');
  });

  test('resumed child snapshot wins over earlier terminal result', () {
    final message = _native(
      children: [
        {
          'createdAt': 3000,
          'agentMetadata': {'model': 'resumed'},
        },
      ],
      result: {
        'agentMetadata': {'model': 'terminal-old'},
      },
    );
    message['completedAt'] = 2000;
    expect(AgentPresentation.fromMessage(message).model, 'resumed');
  });

  test('legacy input and parent model behavior remains unchanged', () {
    final details = AgentPresentation.fromMessage({
      'model': 'parent',
      'input': {'subagent_type': 'Explore', 'model': 'explicit'},
      'metadata': {'model': 'metadata'},
      'children': [
        {'model': 'first'},
        {'model': 'last'},
      ],
    });
    expect(details.isNativeCodex, false);
    expect(details.model, 'explicit');
    expect(details.parentModel, 'parent');
    expect(
      AgentPresentation.fromMessage({
        'children': [
          {'model': 'first'},
          {'model': 'last'},
        ],
      }).model,
      'first',
    );
  });

  for (final sandbox in {
    'read-only': 'Read only',
    'workspace-write': 'Workspace writes',
    'danger-full-access': 'Full access',
  }.entries) {
    test('reported ${sandbox.key} permission gets clear label', () {
      final details = AgentPresentation.fromMessage(
        _native(
          metadata: {
            'effectiveSandbox': sandbox.key,
            'approvalPolicy': 'on-request',
          },
        ),
      );
      expect(details.sandboxLabel, sandbox.value);
      expect(details.approvalLabel, 'When requested');
    });
  }

  testWidgets('native details wrap and expand without parent fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final details = AgentPresentation.fromMessage(
      _native(
        metadata: {
          'role': 'read-only',
          'reasoningEffort': 'high',
          'source': 'thread',
          'status': 'idle',
        },
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentConversationDebugCard(
            state: 'running',
            messageId: 'native-id',
            presentation: details,
          ),
        ),
      ),
    );
    expect(find.text('Model not reported · running'), findsOneWidget);
    expect(find.text('gpt-6-sol'), findsNothing);
    await tester.tap(find.text('Agent details'));
    await tester.pumpAndSettle();
    expect(find.text('read-only'), findsOneWidget);
    expect(find.text('Not reported'), findsNWidgets(2));
    expect(find.text('high'), findsOneWidget);
    expect(find.text('Thread configuration'), findsOneWidget);
    expect(find.text('Thread status'), findsOneWidget);
    expect(find.text('idle'), findsOneWidget);
    expect(find.textContaining('enforced'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
