import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/tool_result_processor.dart';

void main() {
  late ToolResultProcessor processor;

  setUp(() {
    processor = ToolResultProcessor();
  });

  // ── Helpers ────────────────────────────────────────────

  Map<String, dynamic> _toolCallMsg({
    required String id,
    String? toolUseId,
    String? state,
    Map<String, dynamic>? permission,
    List<Map<String, dynamic>>? children,
  }) =>
      <String, dynamic>{
        'id': id,
        'kind': 'tool-call',
        if (toolUseId != null) 'toolUseId': toolUseId,
        if (state != null) 'state': state,
        if (permission != null) 'permission': permission,
        if (children != null) 'children': children,
      };

  Map<String, dynamic> _toolResult({
    required String toolUseId,
    String? result,
    bool isError = false,
    int? createdAt,
    Map<String, dynamic>? permissions,
  }) =>
      <String, dynamic>{
        'toolUseId': toolUseId,
        if (result != null) 'result': result,
        'isError': isError,
        if (createdAt != null) 'createdAt': createdAt,
        if (permissions != null)
          'permissions': permissions,
      };

  Map<String, dynamic> _textMsg({required String id}) =>
      <String, dynamic>{
        'id': id,
        'kind': 'text',
        'role': 'assistant',
        'content': 'hello',
      };

  // ── applyToolResults ──────────────────────────────────

  group('applyToolResults', () {
    test('returns unchanged when no tool results', () {
      final messages = [_toolCallMsg(id: 'm1')];
      final (result, changed) =
          processor.applyToolResults(messages, []);
      expect(changed, isFalse);
      expect(identical(result, messages), isTrue);
    });

    test('matches tool result by toolUseId', () {
      final messages = [
        _toolCallMsg(
          id: 'm1',
          toolUseId: 'tu-1',
          state: 'running',
        ),
      ];

      final (result, changed) =
          processor.applyToolResults(messages, [
        _toolResult(
          toolUseId: 'tu-1',
          result: 'done',
          createdAt: 1000,
        ),
      ]);

      expect(changed, isTrue);
      expect(result[0]['state'], 'completed');
      expect(result[0]['result'], 'done');
      expect(result[0]['completedAt'], 1000);
    });

    test('sets state to error when isError is true', () {
      final messages = [
        _toolCallMsg(id: 'm1', toolUseId: 'tu-1'),
      ];

      final (result, changed) =
          processor.applyToolResults(messages, [
        _toolResult(
          toolUseId: 'tu-1',
          result: 'failed',
          isError: true,
        ),
      ]);

      expect(changed, isTrue);
      expect(result[0]['state'], 'error');
    });

    test('applies permission from tool result', () {
      final messages = [
        _toolCallMsg(id: 'm1', toolUseId: 'tu-1'),
      ];

      final (result, changed) =
          processor.applyToolResults(messages, [
        _toolResult(
          toolUseId: 'tu-1',
          permissions: <String, dynamic>{
            'result': 'approved',
            'mode': 'yolo',
          },
        ),
      ]);

      expect(changed, isTrue);
      final perm =
          result[0]['permission'] as Map<String, dynamic>;
      expect(perm['status'], 'approved');
      expect(perm['mode'], 'yolo');
    });

    test('applies denied permission', () {
      final messages = [
        _toolCallMsg(id: 'm1', toolUseId: 'tu-1'),
      ];

      final (result, _) =
          processor.applyToolResults(messages, [
        _toolResult(
          toolUseId: 'tu-1',
          permissions: <String, dynamic>{
            'result': 'denied',
          },
        ),
      ]);

      final perm =
          result[0]['permission'] as Map<String, dynamic>;
      expect(perm['status'], 'denied');
    });

    test('recurses into children', () {
      final messages = [
        _toolCallMsg(
          id: 'parent',
          toolUseId: 'tu-parent',
          children: [
            _toolCallMsg(
              id: 'child',
              toolUseId: 'tu-child',
            ),
          ],
        ),
      ];

      final (result, changed) =
          processor.applyToolResults(messages, [
        _toolResult(
          toolUseId: 'tu-child',
          result: 'child-done',
        ),
      ]);

      expect(changed, isTrue);
      final children = result[0]['children']
          as List<Map<String, dynamic>>;
      expect(children[0]['state'], 'completed');
      expect(children[0]['result'], 'child-done');
    });

    test('ignores results with unknown toolUseId', () {
      final messages = [
        _toolCallMsg(id: 'm1', toolUseId: 'tu-1'),
      ];

      final (result, changed) =
          processor.applyToolResults(messages, [
        _toolResult(
          toolUseId: 'tu-unknown',
          result: 'nope',
        ),
      ]);

      expect(changed, isFalse);
      expect(result[0]['state'], isNull);
    });

    test('ignores results with empty toolUseId', () {
      final messages = [
        _toolCallMsg(id: 'm1', toolUseId: 'tu-1'),
      ];

      final (_, changed) =
          processor.applyToolResults(messages, [
        <String, dynamic>{
          'toolUseId': '',
          'result': 'nope',
        },
      ]);

      expect(changed, isFalse);
    });

    test('skips non-tool-call messages', () {
      final messages = [
        _textMsg(id: 'm1'),
        _toolCallMsg(id: 'm2', toolUseId: 'tu-2'),
      ];

      final (result, changed) =
          processor.applyToolResults(messages, [
        _toolResult(toolUseId: 'tu-2', result: 'ok'),
      ]);

      expect(changed, isTrue);
      expect(result[0]['kind'], 'text');
      expect(result[1]['state'], 'completed');
    });
  });

  // ── applyPermissionRequests ───────────────────────────

  group('applyPermissionRequests', () {
    test('stamps pending permission on tool-call', () {
      final messages = [
        _toolCallMsg(id: 'm1', toolUseId: 'perm-1'),
      ];

      final agentState = AgentState(
        requests: {
          'perm-1': RequestInfo.fromJson(<String, dynamic>{
            'tool': 'bash',
            'arguments': <String, dynamic>{
              'command': 'rm -rf /',
            },
          }),
        },
      );

      final result = processor.applyPermissionRequests(
        messages,
        agentState,
        <String>{},
      );

      expect(result.changed, isTrue);
      final perm = result.messages[0]['permission']
          as Map<String, dynamic>;
      expect(perm['id'], 'perm-1');
      expect(perm['status'], 'pending');
    });

    test('stamps completed permission', () {
      final messages = [
        _toolCallMsg(
          id: 'm1',
          toolUseId: 'perm-1',
          permission: <String, dynamic>{
            'id': 'perm-1',
            'status': 'pending',
          },
        ),
      ];

      final agentState = AgentState(
        completedRequests: {
          'perm-1': CompletedRequestInfo(
            tool: 'bash',
            status: 'approved',
            mode: 'yolo',
          ),
        },
      );

      final result = processor.applyPermissionRequests(
        messages,
        agentState,
        <String>{},
      );

      expect(result.changed, isTrue);
      final perm = result.messages[0]['permission']
          as Map<String, dynamic>;
      expect(perm['status'], 'approved');
      expect(perm['mode'], 'yolo');
    });

    test('reports resolvedPermIds for notified permissions',
        () {
      final messages = [
        _toolCallMsg(id: 'm1', toolUseId: 'perm-1'),
      ];

      final notified = <String>{'perm-1'};
      final agentState = AgentState(
        completedRequests: {
          'perm-1': CompletedRequestInfo(
            tool: 'bash',
            status: 'denied',
          ),
        },
      );

      final result = processor.applyPermissionRequests(
        messages,
        agentState,
        notified,
      );

      expect(result.resolvedPermIds, contains('perm-1'));
    });

    test('skips already-resolved permissions', () {
      final messages = [
        _toolCallMsg(
          id: 'm1',
          toolUseId: 'perm-1',
          permission: <String, dynamic>{
            'id': 'perm-1',
            'status': 'approved',
          },
        ),
      ];

      final agentState = AgentState(
        completedRequests: {
          'perm-1': CompletedRequestInfo(
            tool: 'bash',
            status: 'denied',
          ),
        },
      );

      final result = processor.applyPermissionRequests(
        messages,
        agentState,
        <String>{},
      );

      // Should not change — existing is already resolved.
      expect(result.changed, isFalse);
    });

    test('clears stale pending permission', () {
      final messages = [
        _toolCallMsg(
          id: 'm1',
          toolUseId: 'perm-1',
          permission: <String, dynamic>{
            'id': 'perm-1',
            'status': 'pending',
          },
        ),
        _toolCallMsg(id: 'm2', toolUseId: 'perm-2'),
      ];

      // requests has perm-2 but NOT perm-1 → perm-1 stale
      final agentState = AgentState(
        requests: {
          'perm-2': RequestInfo.fromJson(<String, dynamic>{
            'tool': 'bash',
            'arguments': <String, dynamic>{},
          }),
        },
      );

      final result = processor.applyPermissionRequests(
        messages,
        agentState,
        <String>{},
      );

      expect(result.changed, isTrue);
      final perm = result.messages[0]['permission']
          as Map<String, dynamic>;
      expect(perm['status'], 'canceled');
    });

    test('returns unchanged when no requests', () {
      final messages = [
        _toolCallMsg(id: 'm1', toolUseId: 'tu-1'),
      ];

      final agentState = AgentState();

      final result = processor.applyPermissionRequests(
        messages,
        agentState,
        <String>{},
      );

      expect(result.changed, isFalse);
    });

    test('backfills missing permission id', () {
      final messages = [
        _toolCallMsg(
          id: 'm1',
          toolUseId: 'perm-1',
          permission: <String, dynamic>{
            'status': 'pending',
            // Note: no 'id' key
          },
        ),
      ];

      final agentState = AgentState(
        requests: {
          'perm-1': RequestInfo.fromJson(<String, dynamic>{
            'tool': 'bash',
            'arguments': <String, dynamic>{},
          }),
        },
      );

      final result = processor.applyPermissionRequests(
        messages,
        agentState,
        <String>{},
      );

      expect(result.changed, isTrue);
      final perm = result.messages[0]['permission']
          as Map<String, dynamic>;
      expect(perm['id'], 'perm-1');
    });
  });
}
