import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';
import 'package:happy_flutter/core/services/sidechain_grouper.dart';
import 'package:happy_flutter/core/services/tool_result_processor.dart';
import 'package:happy_flutter/features/chat/agent_presentation.dart';

const _childIdentity = <String, dynamic>{
  'isSidechain': true,
  'parentToolUseId': 'prime-child',
  'agentId': 'prime-child',
};
const _metadata = <String, dynamic>{
  'model': 'gpt-6-luna',
  'provider': 'openai-codex',
  'reasoningEffort': 'high',
  'source': 'acp',
  'futureField': 'retained',
};

ProcessedMessages _process(List<Map<String, dynamic>> bodies) =>
    processDecryptedMessages(
      decryptedJsonList: [
        for (final body in bodies)
          {
            'role': 'agent',
            'content': {'type': 'acp', 'data': body},
            'meta': {
              'model': 'parent-model',
              'permissionMode': 'bypassPermissions',
            },
          },
      ],
      wireMessages: [
        for (var i = 0; i < bodies.length; i++)
          {'id': 'prime-$i', 'seq': i + 1, 'createdAt': 1000 + i},
      ],
      sessionId: 'prime-session',
    );

void main() {
  for (final type in [
    'message',
    'reasoning',
    'agent_message_chunk',
    'thinking',
    'agent_thought_chunk',
    'tool-call',
    'file-edit',
    'tool-result',
  ]) {
    for (final snapshot in [_metadata, <String, dynamic>{}]) {
      test('Prime ACP $type retains metadata snapshot $snapshot', () {
        final processed = _process([
          {
            ..._childIdentity,
            'type': type,
            'callId': 'child-tool',
            'id': 'child-tool',
            'name': 'Read',
            'input': {'file_path': 'go.mod'},
            'text': 'Child thought',
            'message': 'Child reply',
            'result': 'Contents',
            'agentMetadata': snapshot,
          },
        ]);
        final row = type == 'tool-result'
            ? processed.toolResults.single
            : processed.messages.single;
        expect(row['agentMetadata'], snapshot);
        expect(row.containsKey('agentMetadata'), isTrue);
        expect(row['isSidechain'], isTrue);
        expect(row['parentToolUseId'], 'prime-child');
        expect(row['agentId'], 'prime-child');
        expect(processed.droppedReasons, isEmpty);
      });
    }
  }

  test('missing child metadata never inherits envelope defaults', () {
    final processed = _process([
      {..._childIdentity, 'type': 'message', 'message': 'Unknown child'},
      {
        ..._childIdentity,
        'type': 'tool-result',
        'callId': 'child-tool',
        'result': 'Done',
      },
    ]);
    for (final row in [...processed.messages, ...processed.toolResults]) {
      expect(row.containsKey('agentMetadata'), isFalse);
      expect(row.containsKey('model'), isFalse);
      expect(row.containsKey('permissionMode'), isFalse);
    }
  });

  test(
    'interleaved Prime steps stay with their sibling and retain wire input',
    () {
      Map<String, dynamic> child(String id, Map<String, dynamic> body) => {
        ...body,
        'isSidechain': true,
        'parentToolUseId': 'prime-agent:$id',
        'agentId': id,
      };
      final parsed = _process([
        for (final id in ['alpha', 'beta'])
          {
            'type': 'tool-call',
            'callId': 'prime-agent:$id',
            'name': 'Agent',
            'agentId': id,
            'input': {'description': id, 'subagent_type': 'prime-agent'},
          },
        child('alpha', {'type': 'message', 'message': 'Alpha first step'}),
        child('beta', {'type': 'message', 'message': 'Beta first step'}),
        child('alpha', {'type': 'thinking', 'text': 'Alpha inspects source'}),
        child('beta', {
          'type': 'tool-call',
          'callId': 'prime-agent:beta:read',
          'name': 'Read',
          'input': {'path': 'beta.dart', 'limit': 10},
        }),
        child('alpha', {
          'type': 'tool-call',
          'callId': 'prime-agent:alpha:read',
          'name': 'Read',
          'input': {'path': 'alpha.dart', 'limit': 5},
        }),
        child('alpha', {
          'type': 'tool-result',
          'callId': 'prime-agent:alpha:read',
          'result': 'Alpha source contents',
        }),
        child('beta', {
          'type': 'tool-result',
          'callId': 'prime-agent:beta:read',
          'result': 'Beta source contents',
        }),
        child('alpha', {'type': 'message', 'message': 'Alpha final step'}),
        {'type': 'message', 'message': 'Parent answer'},
      ]);
      expect(parsed.droppedReasons, isEmpty);
      final grouped = SidechainGrouper().groupMessages(parsed.messages)!;
      expect(grouped.hasOrphans, isFalse);
      final updated = ToolResultProcessor().applyToolResults(
        grouped.messages,
        parsed.toolResults,
      );
      expect(updated.matchedIds, {
        'prime-agent:alpha:read',
        'prime-agent:beta:read',
      });
      expect(updated.messages, hasLength(3));
      expect(updated.messages.last['content'], 'Parent answer');
      expect(
        updated.messages.any((row) => row['isSidechain'] == true),
        isFalse,
      );
      for (final id in ['alpha', 'beta']) {
        final anchor = updated.messages.singleWhere(
          (row) => row['toolUseId'] == 'prime-agent:$id',
        );
        final children = (anchor['children'] as List)
            .cast<Map<String, dynamic>>();
        expect(children, hasLength(id == 'alpha' ? 4 : 2));
        for (final row in children) {
          expect(row['agentId'], id);
          expect(row['parentToolUseId'], 'prime-agent:$id');
          expect(row['isSidechain'], isTrue);
        }
        final tool = children.singleWhere((row) => row['kind'] == 'tool-call');
        final wireInput = {'path': '$id.dart', 'limit': id == 'alpha' ? 5 : 10};
        expect(tool['wireInput'], wireInput);
        expect(tool['input']['file_path'], '$id.dart');
        expect(tool['wireInput'].containsKey('file_path'), isFalse);
        expect(tool['state'], 'completed');
        expect(
          tool['result'],
          id == 'alpha' ? 'Alpha source contents' : 'Beta source contents',
        );
        if (id == 'alpha') {
          final thinking = children.singleWhere(
            (row) => row['isThinking'] == true,
          );
          expect(thinking['content'], contains('Alpha inspects source'));
          expect(children.last['content'], 'Alpha final step');
        }
      }
    },
  );

  test(
    'Prime children group under Agent and result clears replace metadata',
    () {
      final parsed = _process([
        {
          'type': 'tool-call',
          'callId': 'prime-child',
          'name': 'Agent',
          'input': {
            'subagent_type': 'prime-agent',
            'description': 'Inspect Go module',
          },
          'agentMetadata': _metadata,
        },
        {..._childIdentity, 'type': 'message', 'message': 'Inspecting module'},
        {
          ..._childIdentity,
          'type': 'thinking',
          'text': 'Checking dependencies',
        },
        {
          ..._childIdentity,
          'type': 'tool-call',
          'callId': 'child-tool',
          'name': 'Read',
          'input': {'file_path': 'go.mod'},
          'agentMetadata': _metadata,
        },
        {'type': 'message', 'message': 'Parent answer'},
        {
          ..._childIdentity,
          'type': 'tool-result',
          'callId': 'child-tool',
          'result': 'module example',
          'agentMetadata': {'model': 'gpt-6-luna', 'source': 'acp'},
        },
      ]);
      final grouped = SidechainGrouper().groupMessages(parsed.messages)!;
      expect(grouped.hasOrphans, isFalse);
      expect(grouped.messages, hasLength(2));
      expect(grouped.messages.last['content'], 'Parent answer');
      final updated = ToolResultProcessor().applyToolResults(
        grouped.messages,
        parsed.toolResults,
      );
      expect(updated.matchedIds, {'child-tool'});
      final anchor = updated.messages.first;
      expect(anchor['name'], 'Agent');
      expect(anchor['isSidechain'], isNot(true));
      final children = (anchor['children'] as List)
          .cast<Map<String, dynamic>>();
      expect(children, hasLength(3));
      expect(children[1]['isThinking'], isTrue);
      expect(children.last['state'], 'completed');
      expect(children.last['result'], 'module example');
      expect(children.last['agentMetadata'], {
        'model': 'gpt-6-luna',
        'source': 'acp',
      });
      final presentation = AgentPresentation.fromMessage(anchor);
      expect(presentation.model, 'gpt-6-luna');
      expect(presentation.effort, isNull);
      expect(presentation.sandboxLabel, 'Not reported');
      expect(presentation.approvalLabel, 'Not reported');

      final clear = _process([
        {
          'type': 'tool-result',
          'callId': 'prime-child',
          'result': 'Finished',
          'agentMetadata': <String, dynamic>{},
        },
      ]);
      clear.toolResults.single['createdAt'] = 2000;
      final completed = ToolResultProcessor().applyToolResults(
        updated.messages,
        clear.toolResults,
      );
      final cleared = AgentPresentation.fromMessage(completed.messages.first);
      expect(cleared.metadata, isEmpty);
      expect(cleared.model, isNull);
      expect(cleared.parentModel, isNull);
    },
  );
}
