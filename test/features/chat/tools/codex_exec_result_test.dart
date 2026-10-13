import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/tools/codex_exec_result.dart';

Map<String, dynamic> _record() => {
  'elapsed_ms': 54661,
  'exit_code': 0,
  'final_message':
      '[build-brief.md](/var/tmp/spx-codex/build-brief.md) contains **the plan**.',
  'raw_event_count': 23,
  'thread_id': 'codex-thread',
  'usage': {
    'cached_input_tokens': 351744,
    'input_tokens': 409557,
    'output_tokens': 4146,
  },
};

void main() {
  test('matches only the agreed Codex execution tool names', () {
    for (final name in codexExecToolNames) {
      expect(isCodexExecTool(name), isTrue);
    }
    for (final name in [
      'exec_command',
      'mcp__ssh__ssh_execute',
      'mcp__other__codex_exec',
      'mcp__codex__codex',
      'codex_exec_extra',
    ]) {
      expect(isCodexExecTool(name), isFalse, reason: name);
    }
  });

  test('keeps the answer and execution metadata separate', () {
    final record = _record();
    final before = jsonEncode(record);
    final result = CodexExecResult.tryParse(record)!;
    expect(result.finalMessage, record['final_message']);
    expect(result.hasAnswer, isTrue);
    expect(result.exitCode, 0);
    expect(result.elapsedMs, 54661);
    expect(result.threadId, 'codex-thread');
    expect(result.rawEventCount, 23);
    expect(result.inputTokens, 409557);
    expect(result.cachedInputTokens, 351744);
    expect(result.outputTokens, 4146);
    expect(jsonEncode(record), before);
  });

  test('accepts JSON and map/string MCP text-content envelopes', () {
    final record = _record();
    for (final envelope in <dynamic>[
      jsonEncode(record),
      {'structuredContent': record},
      {
        'content': [
          {'type': 'text', 'text': record},
        ],
      },
      [
        {'type': 'text', 'text': jsonEncode(record)},
      ],
      {
        'result': {
          'output': {
            'content': [
              {'type': 'text', 'text': jsonEncode(record)},
            ],
          },
        },
      },
    ]) {
      expect(
        CodexExecResult.tryParse(envelope)?.finalMessage,
        record['final_message'],
      );
    }
  });

  test('structuredContent takes precedence over a text copy', () {
    final result = CodexExecResult.tryParse({
      'structuredContent': _record(),
      'content': [
        {
          'type': 'text',
          'text': jsonEncode({'final_message': 'abbreviated'}),
        },
      ],
    });
    expect(result?.finalMessage, _record()['final_message']);
  });

  test('empty and absent answers preserve execution metadata', () {
    for (final answer in ['', ' \n ', null]) {
      final record = _record()..['final_message'] = answer;
      final result = CodexExecResult.tryParse(record)!;
      expect(result.finalMessage, answer);
      expect(result.hasAnswer, isFalse);
      expect(result.exitCode, 0);
    }
    final record = _record()..remove('final_message');
    expect(CodexExecResult.tryParse(record)?.hasAnswer, isFalse);
  });

  test('normalizes integer strings without truncating malformed values', () {
    final result = CodexExecResult.tryParse({
      'final_message': 'done',
      'exit_code': '0',
      'elapsed_ms': 23.0,
      'usage': {'input_tokens': '400'},
    });
    expect(result?.exitCode, 0);
    expect(result?.elapsedMs, 23);
    expect(result?.inputTokens, 400);
    for (final value in [false, 1.5, double.infinity, double.nan, 'oops']) {
      expect(
        CodexExecResult.tryParse({'thread_id': 'thread', 'exit_code': value}),
        isNull,
      );
    }
  });

  test('invalid optional metadata does not hide a valid answer', () {
    final result = CodexExecResult.tryParse({
      'final_message': '**Done**',
      'exit_code': false,
      'elapsed_ms': -1,
      'thread_id': {},
      'usage': {'output_tokens': 'oops', 'input_tokens': 42},
    })!;
    expect(result.finalMessage, '**Done**');
    expect(result.exitCode, isNull);
    expect(result.elapsedMs, isNull);
    expect(result.threadId, isNull);
    expect(result.outputTokens, isNull);
    expect(result.inputTokens, 42);
  });

  test('rejects malformed records and unrelated executor results', () {
    for (final value in <dynamic>[
      null,
      'plain answer',
      '{invalid json',
      {'exit_code': 0, 'stdout': 'hello'},
      {'final_message': 42, 'thread_id': 'thread', 'exit_code': 0},
      {'thread_id': {}, 'exit_code': 0},
      {'thread_id': 'thread', 'usage': []},
      {
        'thread_id': 'thread',
        'usage': {'output_tokens': 'oops'},
      },
      {'thread_id': 'thread'},
      {'type': 'image', 'text': _record()},
    ]) {
      expect(CodexExecResult.tryParse(value), isNull);
    }
  });

  test('bounds deeply nested, broad, and cyclic envelopes', () {
    dynamic nested = _record();
    for (var i = 0; i < 20; i++) {
      nested = {'result': nested};
    }
    expect(CodexExecResult.tryParse(nested), isNull);
    final cyclic = <String, dynamic>{};
    cyclic['result'] = cyclic;
    expect(CodexExecResult.tryParse(cyclic), isNull);
    expect(
      CodexExecResult.tryParse([...List<dynamic>.filled(200, null), _record()]),
      isNull,
    );
  });
}
