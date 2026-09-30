import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tool_work_summary.dart';

void main() {
  test('a completed command with nonzero exit remains a failure', () {
    final summary = ToolWorkSummary.fromTools([
      {
        'name': 'Bash',
        'state': 'completed',
        'result': {'exit_code': 1},
      },
    ]);
    expect(summary.commands, 0);
    expect(summary.failed, 1);
  });
  test('counts successful file work once per path and preserves failures', () {
    final summary = ToolWorkSummary.fromTools([
      {
        'name': 'Read',
        'state': 'completed',
        'input': {'file_path': 'a.dart'},
      },
      {
        'name': 'read_file',
        'state': 'completed',
        'input': {'target_file': 'a.dart'},
      },
      {
        'name': 'Edit',
        'state': 'completed',
        'input': {'filePath': 'a.dart'},
      },
      {
        'name': 'Write',
        'state': 'error',
        'input': {'file_path': 'b.dart'},
      },
      {'name': 'functions.exec_command', 'state': 'completed'},
      {'name': 'Bash', 'state': 'error'},
      {'name': 'Read', 'state': 'canceled'},
    ]);
    expect(summary.readFiles, 1);
    expect(summary.changedFiles.keys, ['a.dart']);
    expect(summary.commands, 1);
    expect(summary.failed, 2);
    expect(summary.pending, 0);
    expect(summary.canceled, 1);
  });

  test('recognizes patch paths without counting failed patch attempts', () {
    final summary = ToolWorkSummary.fromTools([
      {
        'name': 'functions.apply_patch',
        'state': 'completed',
        'input': {
          'patch':
              '*** Begin Patch\n*** Update File: a.dart\n'
              '*** Add File: b.dart\n*** End Patch',
        },
      },
      {
        'name': 'apply_patch',
        'state': 'error',
        'input': {'patch': '*** Delete File: c.dart'},
      },
    ]);
    expect(summary.changedFiles.keys, ['a.dart', 'b.dart']);
    expect(summary.failed, 1);
  });

  test('unknown, queued, and malformed tools never imply completed work', () {
    final summary = ToolWorkSummary.fromTools([
      {
        'name': 'Edit',
        'state': 'running',
        'input': {'file_path': 42},
      },
      {'name': 'Read', 'state': 'pending'},
      {'name': 'custom', 'state': 'completed'},
    ]);
    expect(summary.changedFiles, isEmpty);
    expect(summary.running, 1);
    expect(summary.pending, 2);
    expect(summary.otherCompleted, 1);
  });

  test('structured Codex result changes populate review files', () {
    final summary = ToolWorkSummary.fromTools([
      {
        'name': 'CodexPatch',
        'state': 'completed',
        'result': {
          'changes': [
            {'path': 'lib/app.dart', 'kind': 'modify'},
          ],
        },
      },
    ]);
    expect(summary.changedFiles.keys, ['lib/app.dart']);
  });

  test('turn review fences earlier turns and ignores sidechain answers', () {
    final turn = ChatTurnWork.fromMessages([
      {'role': 'agent', 'kind': 'tool-call', 'name': 'Bash', 'state': 'error'},
      {'role': 'user', 'createdAt': 100},
      {
        'role': 'agent',
        'kind': 'tool-call',
        'name': 'Bash',
        'state': 'completed',
      },
      {'role': 'agent', 'kind': 'text', 'content': 'Final answer'},
      {'role': 'user', 'isSidechain': true, 'createdAt': 200},
      {
        'role': 'agent',
        'kind': 'text',
        'content': 'Child answer',
        'isSidechain': true,
      },
    ]);
    expect(turn.startedAt, 100);
    expect(turn.answer?['content'], 'Final answer');
    expect(turn.summary.commands, 1);
    expect(turn.summary.failed, 0);
  });

  test('a fresh or failed send cannot review the previous answer', () {
    final turn = ChatTurnWork.fromMessages([
      {'role': 'agent', 'kind': 'text', 'content': 'Old answer'},
      {'role': 'user', 'sendStatus': 'failed'},
    ]);
    expect(turn.answer, isNull);
    expect(turn.hasResult, isFalse);
  });
}
