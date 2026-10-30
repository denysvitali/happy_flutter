import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/services/tool_result_processor.dart';
import 'package:happy_flutter/features/chat/chat_list_pipeline.dart';
import 'package:happy_flutter/features/chat/message_render_signature.dart';
import 'package:happy_flutter/features/chat/tools/views/background_shell_badge.dart';

const _receipt =
    'Command did not complete within its 600s timeout and was moved to the '
    'background (ID: bit9nvfrb). Output is being written to: '
    '/tmp/claude-0/proj/f31cdd9f/tasks/bit9nvfrb.output. You will be '
    'notified when it completes.';

Map<String, dynamic> _wireOutput(Map<String, dynamic> data) => {
  'role': 'agent',
  'content': {'type': 'output', 'data': data},
};

List<Map<String, dynamic>> _toolResultsFor(Map<String, dynamic> data) {
  return processDecryptedMessages(
    decryptedJsonList: [_wireOutput(data)],
    wireMessages: [
      {'id': 'm1', 'seq': 1, 'createdAt': 1000},
    ],
    sessionId: 's1',
  ).toolResults;
}

Map<String, dynamic> _backgroundedBashResult({
  Map<String, dynamic>? receipt,
  List<Map<String, dynamic>>? extraBlocks,
}) => {
  'type': 'user',
  'message': {
    'role': 'user',
    'content': [
      {'type': 'tool_result', 'tool_use_id': 'toolu_bash', 'content': _receipt},
      ...?extraBlocks,
    ],
  },
  'tool_use_result':
      receipt ??
      {
        'stdout': '',
        'stderr': '',
        'interrupted': false,
        'backgroundTaskId': 'bit9nvfrb',
        'timedOutAfterMs': 600000,
      },
};

List<Map<String, dynamic>?> _items(List<Map<String, dynamic>> messages) =>
    buildChatListItems(
      visibleMessages: messages,
      hideToolCalls: false,
      shouldRenderAgentEvent: (_) => true,
      shouldHideToolCall: (msg, {required hideToolCalls}) => false,
    );

void main() {
  group('BackgroundShell receipt', () {
    test('timed-out Bash result carries the background shell receipt', () {
      final results = _toolResultsFor(_backgroundedBashResult());

      expect(results.single['backgroundShell'], {
        'taskId': 'bit9nvfrb',
        'reason': 'timeout',
        'timedOutAfterMs': 600000,
        'outputPath': '/tmp/claude-0/proj/f31cdd9f/tasks/bit9nvfrb.output',
      });
    });

    test('names the user, message and launch origins', () {
      String? reason(Map<String, dynamic> extra) =>
          (_toolResultsFor(
                    _backgroundedBashResult(
                      receipt: {'backgroundTaskId': 'b1', ...extra},
                    ),
                  ).single['backgroundShell']
                  as Map)['reason']
              as String?;

      expect(reason({'backgroundedByUser': true}), 'user');
      expect(reason({'backgroundedByTurnAbort': true}), 'abort');
      expect(reason({'backgroundedToDeliverMessage': true}), 'message');
      expect(reason({}), 'launched');
    });

    test('output paths with spaces are not truncated', () {
      final data = _backgroundedBashResult();
      data['message'] = {
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': 'toolu_bash',
            'content':
                'Output is being written to: /tmp/my project/b1.output. You will be notified.',
          },
        ],
      };
      expect(
        _toolResultsFor(data).single['backgroundShell']['outputPath'],
        '/tmp/my project/b1.output',
      );
    });

    test('foreground results and multi-result messages carry no receipt', () {
      expect(
        _toolResultsFor(
          _backgroundedBashResult(receipt: {'stdout': 'ok'}),
        ).single.containsKey('backgroundShell'),
        isFalse,
      );
      final multi = _toolResultsFor(
        _backgroundedBashResult(
          extraBlocks: [
            {'type': 'tool_result', 'tool_use_id': 'other', 'content': 'x'},
          ],
        ),
      );
      expect(multi, hasLength(2));
      expect(multi.every((r) => !r.containsKey('backgroundShell')), isTrue);
    });

    test('tool result processor stamps the receipt on the tool call', () {
      final applied = ToolResultProcessor().applyToolResults([
        {
          'id': 'call',
          'kind': 'tool-call',
          'name': 'Bash',
          'toolUseId': 'toolu_bash',
          'state': 'running',
        },
      ], _toolResultsFor(_backgroundedBashResult()));

      final call = applied.messages.single;
      expect(call['state'], 'completed');
      expect((call['backgroundShell'] as Map)['taskId'], 'bit9nvfrb');
    });
  });

  group('BackgroundShell status', () {
    final bashCall = <String, dynamic>{
      'id': 'call',
      'kind': 'tool-call',
      'name': 'Bash',
      'toolUseId': 'toolu_bash',
      'state': 'completed',
      'input': {'command': 'mise run test'},
      'backgroundShell': {'taskId': 'bit9nvfrb', 'reason': 'timeout'},
    };

    Map<String, dynamic> shellOf(List<Map<String, dynamic>?> items) =>
        items.firstWhere((m) => m?['id'] == 'call')!['backgroundShell']
            as Map<String, dynamic>;

    test('stays running until the task reports a terminal status', () {
      final items = _items([
        bashCall,
        {
          'id': 'start',
          'kind': 'agent-event',
          'taskEvent': true,
          'agentId': 'bit9nvfrb',
          'taskType': 'local_bash',
          'taskPhase': 'task_started',
          'event': {'type': 'message', 'message': 'Run tests'},
        },
      ]);

      expect(shellOf(items)['status'], 'running');
      // The pipeline copies the row; the source message is untouched.
      expect((bashCall['backgroundShell'] as Map).containsKey('status'), false);
    });

    for (final (wire, shown) in [
      ('completed', 'completed'),
      ('failed', 'failed'),
      ('stopped', 'stopped'),
      ('killed', 'stopped'),
    ]) {
      test('task notification $wire marks the shell $shown', () {
        final items = _items([
          bashCall,
          {
            'id': 'done',
            'role': 'agent',
            'kind': wire == 'completed' || wire == 'failed'
                ? 'text'
                : 'agent-event',
            'taskEvent': true,
            'agentId': 'bit9nvfrb',
            'taskStatus': wire,
            'taskType': 'local_bash',
            'content': 'Background command finished',
            'event': {'type': 'message', 'message': 'Run tests'},
          },
        ]);

        expect(shellOf(items)['status'], shown);
      });
    }

    test('legacy user task notification settles the shell', () {
      final items = _items([
        bashCall,
        {
          'id': 'legacy',
          'role': 'user',
          'kind': 'text',
          'content':
              '<task-notification>\n<task-id>bit9nvfrb</task-id>\n'
              '<status>failed</status>\n</task-notification>',
        },
      ]);

      expect(shellOf(items)['status'], 'failed');
    });

    test('another task id does not settle the shell', () {
      expect(
        withBackgroundShellStatus(bashCall, {'other': 'completed'}),
        containsPair('backgroundShell', {
          'taskId': 'bit9nvfrb',
          'reason': 'timeout',
          'status': 'running',
        }),
      );
    });
  });

  group('background shell lifecycle projection', () {
    final call = <String, dynamic>{
      'id': 'shell',
      'kind': 'tool-call',
      'name': 'Bash',
      'state': 'completed',
      'backgroundShell': {'taskId': 'b1', 'reason': 'launched'},
    };
    final done = <String, dynamic>{
      'id': 'done',
      'taskEvent': true,
      'agentId': 'b1',
      'taskStatus': 'completed',
    };

    test('matches outcomes across scrollback gaps and grouped children', () {
      final source = <Map<String, dynamic>>[
        {
          'id': 'agent',
          'children': [done],
        },
        call,
      ];
      final items = buildChatListItems(
        visibleMessages: [call],
        taskMessages: source,
        hideToolCalls: false,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (_, {required hideToolCalls}) => false,
      );
      expect(items.single!['backgroundShell']['status'], 'completed');
      expect(call['backgroundShell'], isNot(contains('status')));
    });

    test('active shells remain visible when completed tools are hidden', () {
      final items = buildChatListItems(
        visibleMessages: [call],
        hideToolCalls: true,
        shouldRenderAgentEvent: (_) => true,
        shouldHideToolCall: (_, {required hideToolCalls}) => true,
      );
      expect(items.single!['id'], 'shell');
    });

    test('nested shells settle without mutating source children', () {
      final parent = <String, dynamic>{
        'id': 'parent',
        'children': [call],
      };
      final projected = withBackgroundShellStatus(parent, {'b1': 'failed'});
      expect(projected['children'][0]['backgroundShell']['status'], 'failed');
      expect(call['backgroundShell'], isNot(contains('status')));
    });

    test('terminal state survives delayed start and invalid fields', () {
      expect(
        backgroundShellOutcomes([
          done,
          {'taskEvent': true, 'agentId': 'b1', 'taskStatus': 'running'},
          {'taskEvent': true, 'agentId': 42, 'taskStatus': []},
        ]),
        {'b1': 'completed'},
      );
    });

    test('render cache invalidates on shell completion', () {
      final running = withBackgroundShellStatus(call, {});
      final completed = withBackgroundShellStatus(call, {'b1': 'completed'});
      expect(
        messageRenderSignature(running),
        isNot(messageRenderSignature(completed)),
      );
    });
  });

  group('BackgroundShellBadge', () {
    test('describes origin and status', () {
      expect(
        BackgroundShellBadge.describe({
          'reason': 'timeout',
          'timedOutAfterMs': 600000,
          'status': 'running',
        }),
        'Moved to background after 600s · still running',
      );
      expect(
        BackgroundShellBadge.describe({'reason': 'user', 'status': 'stopped'}),
        'Moved to background by you · stopped',
      );
      expect(
        BackgroundShellBadge.describe({
          'reason': 'launched',
          'status': 'completed',
        }),
        'Background command · finished',
      );
    });
  });
}
