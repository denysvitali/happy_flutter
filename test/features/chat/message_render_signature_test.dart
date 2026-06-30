import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/message_render_signature.dart';

void main() {
  group('messageRenderSignature', () {
    test('changes when tool result or permission changes', () {
      final message = <String, dynamic>{
        'id': 'tool-1',
        'kind': 'tool-call',
        'name': 'Bash',
        'state': 'running',
        'input': <String, dynamic>{'command': 'echo hi'},
        'result': null,
        'permission': <String, dynamic>{'status': 'pending'},
      };

      final pending = messageRenderSignature(message);
      message['result'] = <String, dynamic>{'output': 'hi'};
      final withResult = messageRenderSignature(message);
      message['permission'] = <String, dynamic>{'status': 'approved'};
      final approved = messageRenderSignature(message);

      expect(withResult, isNot(pending));
      expect(approved, isNot(withResult));
    });

    test('changes when grouped sidechain children change', () {
      final message = <String, dynamic>{
        'id': 'task-1',
        'kind': 'tool-call',
        'name': 'Task',
        'children': <Map<String, dynamic>>[
          {'id': 'child-1', 'kind': 'text', 'content': 'one'},
        ],
      };

      final oneChild = messageRenderSignature(message);
      (message['children'] as List<Map<String, dynamic>>).add({
        'id': 'child-2',
        'kind': 'tool-call',
        'state': 'completed',
      });

      expect(messageRenderSignature(message), isNot(oneChild));
    });

    test('changes when hidden tool summary tool states change', () {
      final summary = <String, dynamic>{
        'id': 'hidden-summary',
        'kind': 'hidden-tool-summary',
        'tools': <Map<String, dynamic>>[
          {'id': 'tool-1', 'state': 'running'},
        ],
      };

      final running = messageRenderSignature(summary);
      (summary['tools'] as List<Map<String, dynamic>>).first['state'] =
          'completed';

      expect(messageRenderSignature(summary), isNot(running));
    });
  });
}
