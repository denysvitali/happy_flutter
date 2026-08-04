import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/agent_steps.dart';
import 'package:happy_flutter/features/chat/tools/known_tools.dart';

Map<String, dynamic> _chip(String label, {String? tool}) => {
  'kind': 'agent-event',
  'taskEvent': true,
  'event': {'type': 'task_progress', 'message': label},
  if (tool != null) 'subAgentLastTool': tool,
};

Map<String, dynamic> _text(String content) => {
  'kind': 'text',
  'content': content,
};

Map<String, dynamic> _toolCall(String name) => {
  'kind': 'tool-call',
  'name': name,
  'input': <String, dynamic>{},
};

void main() {
  group('buildAgentDisplayChildren', () {
    test('keeps progress chips when the transcript is thinner', () {
      final children = <Map<String, dynamic>>[
        _text('starting'),
        _toolCall('Bash'),
        for (var i = 0; i < 18; i++) _chip('step $i', tool: 'Bash'),
      ];

      final rows = buildAgentDisplayChildren(children, false);

      expect(rows.length, 20);
    });

    test('drops chips when the durable transcript is at least as rich', () {
      final children = <Map<String, dynamic>>[
        for (var i = 0; i < 6; i++) _text('prose $i'),
        for (var i = 0; i < 3; i++) _chip('step $i', tool: 'Bash'),
      ];

      final rows = buildAgentDisplayChildren(children, false);

      expect(rows.length, 6);
      expect(rows.every((r) => r['taskEvent'] != true), isTrue);
    });

    test('drops thinking placeholders once finished', () {
      final children = <Map<String, dynamic>>[
        _text('done'),
        {'kind': 'text', 'isThinking': true},
      ];

      expect(buildAgentDisplayChildren(children, false).length, 1);
    });

    test('collapses a repeated chip for the same step and tool', () {
      final children = <Map<String, dynamic>>[
        _chip('Read file', tool: 'Read'),
        _chip('Read file', tool: 'Read'),
        _chip('Write file', tool: 'Write'),
      ];

      expect(buildAgentDisplayChildren(children, true).length, 2);
    });
  });

  group('Agent step chip', () {
    test('advertises exactly the rows the detail feed renders', () {
      final tool = <String, dynamic>{
        'name': 'Agent',
        'state': 'completed',
        'input': <String, dynamic>{'subagent_type': 'general-purpose'},
        'children': <dynamic>[
          for (var i = 0; i < 6; i++) _text('prose $i'),
          for (var i = 0; i < 3; i++) _chip('step $i', tool: 'Bash'),
        ],
      };

      final status = KnownTools.tools['Agent']!.extractStatus!(tool, null);

      expect(status, '6 steps');
      expect(agentStepCount(tool), 6);
    });

    test('counts chips for a background agent with no streamed transcript', () {
      final tool = <String, dynamic>{
        'name': 'Agent',
        'state': 'completed',
        'input': <String, dynamic>{'subagent_type': 'general-purpose'},
        'children': <dynamic>[
          for (var i = 0; i < 12; i++) _chip('step $i', tool: 'Bash'),
        ],
      };

      expect(KnownTools.tools['Agent']!.extractStatus!(tool, null), '12 steps');
    });
  });
}
