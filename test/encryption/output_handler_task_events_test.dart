import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

// Regression coverage for the dynamic-workflow surfacing path.
//
// Background: when the CLI dispatches a `Workflow` tool with
// `run_in_background: true`, it never sends the sub-agent's individual
// `tool_use` blocks across the wire. It only emits
// `task_started` / `task_progress` / `task_notification` `system` meta
// events with optional `last_tool_name`, `transcript_dir`, and `run_id`
// fields. Before the parser was taught to surface those, the chat showed
// only the eventual summary text — users had no way to tell what the
// sub-agent was doing in real time or to audit its tool calls after the
// fact.
//
// These tests pin the wire-shape contract so a CLI field rename cannot
// silently regress us back to "no live signal, no transcript affordance".
void main() {
  Map<String, dynamic> wire({
    required String id,
    required int seq,
    int createdAt = 1000,
    String? localId,
  }) =>
      {
        'id': id,
        'seq': seq,
        'createdAt': createdAt,
        if (localId != null) 'localId': localId,
      };

  Map<String, dynamic> metaSystem(
    Map<String, dynamic> data, {
    bool isSidechain = true,
    String? uuid,
    String? parentUuid,
  }) {
    return {
      'role': 'agent',
      'content': {
        'type': 'output',
        'data': {
          'type': 'system',
          'isMeta': true,
          ...data,
          if (isSidechain) 'isSidechain': true,
          if (uuid != null) 'uuid': uuid,
          if (parentUuid != null) 'parentUuid': parentUuid,
        },
      },
    };
  }

  group('output handler — task_* meta events', () {
    test('task_started with no description surfaces a sane label', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_started',
            'task_type': 'general-purpose',
            'subagent_type': 'Explore',
            'description': 'Reconcile devices on bench',
            'task_id': 'agent-42',
          }, uuid: 't-started-1'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      final msg = result.messages.first;
      expect(msg['kind'], 'agent-event');
      expect(msg['taskEvent'], true);
      expect(msg['agentId'], 'agent-42');
      expect(msg['taskType'], 'general-purpose');
      expect(msg['subagentType'], 'Explore');
      final event = msg['event'] as Map<String, dynamic>;
      expect(event['type'], 'message');
      expect(event['message'], 'Reconcile devices on bench');
    });

    test('task_progress with last_tool_name prepends tool to label', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_progress',
            'description': 'wait for scan completion',
            'last_tool_name': 'Bash',
            'task_id': 'agent-42',
          }, uuid: 't-progress-1'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      final msg = result.messages.first;
      expect(msg['kind'], 'agent-event');
      expect(msg['subAgentLastTool'], 'Bash');
      final event = msg['event'] as Map<String, dynamic>;
      expect(event['message'], 'Bash · wait for scan completion');
    });

    test('task_progress does not double-prefix when description already starts '
        'with the tool name', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_progress',
            'description': 'Bash · wait for scan completion',
            'last_tool_name': 'Bash',
            'task_id': 'agent-42',
          }, uuid: 't-progress-2'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      final event = result.messages.first['event'] as Map<String, dynamic>;
      expect(event['message'], 'Bash · wait for scan completion');
    });

    test('task_progress accepts camelCase lastToolName alias', () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_progress',
            'description': 'reading reference docs',
            'lastToolName': 'Read',
            'task_id': 'agent-7',
          }, uuid: 't-progress-3'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      final msg = result.messages.first;
      expect(msg['subAgentLastTool'], 'Read');
    });

    test('task_progress with no tool name still renders a chip', () {
      // Bare progress events without a last_tool_name are common during
      // early sub-agent warm-up; the chip must still surface so users
      // can see the sub-agent is alive.
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_progress',
            'description': 'spinning up',
            'task_id': 'agent-7',
          }, uuid: 't-progress-4'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      final msg = result.messages.first;
      expect(msg['kind'], 'agent-event');
      expect(msg['subAgentLastTool'], isNull);
      final event = msg['event'] as Map<String, dynamic>;
      expect(event['message'], 'spinning up');
    });

    test('task_notification completed emits a text summary with transcript',
        () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_notification',
            'status': 'completed',
            'summary': 'All branches reconciled.',
            'task_type': 'local_workflow',
            'transcript_dir':
                '/Users/me/.claude/projects/foo/transcripts/x.jsonl',
            'run_id': 'run-2026-06-24-abc',
            'task_id': 'agent-42',
          }, uuid: 't-notification-1'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      expect(result.messages, hasLength(1));
      final msg = result.messages.first;
      expect(msg['kind'], 'text');
      expect(msg['taskEvent'], true);
      expect(msg['content'], 'All branches reconciled.');
      expect(msg['taskStatus'], 'completed');
      expect(msg['taskType'], 'local_workflow');
      expect(msg['transcriptDir'],
          '/Users/me/.claude/projects/foo/transcripts/x.jsonl');
      expect(msg['workflowRunId'], 'run-2026-06-24-abc');
      expect(msg['agentId'], 'agent-42');
    });

    test('task_notification failed emits a text summary with failed status',
        () {
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_notification',
            'status': 'failed',
            'summary': 'Lint step crashed',
            'task_type': 'local_bash',
            'task_id': 'agent-7',
          }, uuid: 't-notification-2'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      final msg = result.messages.first;
      expect(msg['kind'], 'text');
      expect(msg['taskStatus'], 'failed');
      expect(msg['taskType'], 'local_bash');
      expect(msg['content'], 'Lint step crashed');
    });

    test('task_notification running does NOT collapse to text — stays a chip',
        () {
      // Non-terminal task_updated/task_notification is still live; the
      // parser must keep it as an agent-event so the chip sees the
      // in-flight tool.
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_updated',
            'status': 'running',
            'description': 'still churning',
            'last_tool_name': 'Edit',
            'task_id': 'agent-7',
          }, uuid: 't-running-1'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      final msg = result.messages.first;
      expect(msg['kind'], 'agent-event');
      expect(msg['subAgentLastTool'], 'Edit');
      expect(msg['taskStatus'], 'running');
    });

    test('task_progress stamps sidechain metadata for the grouper', () {
      // task_progress emitted from inside a sub-agent must carry the
      // sidechain uuid chain so the sidechain_grouper can nest it under
      // the spawning Agent/Workflow.
      final result = processDecryptedMessages(
        decryptedJsonList: [
          metaSystem({
            'subtype': 'task_progress',
            'description': 'working',
            'last_tool_name': 'Read',
            'tool_use_id': 'parent-tool-use-1',
            'task_id': 'agent-7',
          }, uuid: 'child-uuid-1', parentUuid: 'parent-uuid-1'),
        ],
        wireMessages: [wire(id: 'm1', seq: 1)],
        sessionId: 's1',
      );

      final msg = result.messages.first;
      expect(msg['isSidechain'], true);
      expect(msg['uuid'], 'child-uuid-1');
      expect(msg['parentUuid'], 'parent-uuid-1');
      // parentToolUseId falls back to tool_use_id when no explicit
      // parent_tool_use_id is supplied (see _extractParentToolUseId).
      expect(msg['parentToolUseId'], 'parent-tool-use-1');
    });
  });
}
