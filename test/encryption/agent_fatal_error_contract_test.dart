import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

/// Contract tests for fatal agent API failures on the Claude wire.
///
/// When an API call fails fatally (unknown model on a third-party
/// gateway, revoked access, ...) Claude CLI emits BOTH:
///
///   1. a synthetic assistant turn — `error: "model_not_found"`,
///      `is_api_error_message: true`, `message.model == "<synthetic>"`,
///      carrying the human-readable failure as its only text block; and
///   2. a terminal result envelope — `is_error: true` (with the CLI's
///      quirky `subtype: "success"`), carrying the same text in
///      `result`.
///
/// Both shapes must render as ONE error card, never as a regular
/// assistant bubble. Shape pinned from claude 2.1.239 against an
/// OpenRouter backend returning 404 for inclusionai/ling-3.0-flash:free.
void main() {
  const failureText =
      "There's an issue with the selected model "
      '(inclusionai/ling-3.0-flash:free). It may not exist or you may not '
      'have access to it. Run --model to pick a different model.';

  Map<String, dynamic> syntheticAssistantEnvelope() => {
    'type': 'assistant',
    'message': {
      'diagnostics': null,
      'id': 'c4883ec9-684a-40bc-9829-db9991210824',
      'container': null,
      'model': '<synthetic>',
      'role': 'assistant',
      'stop_reason': 'stop_sequence',
      'type': 'message',
      'usage': {'input_tokens': 0, 'output_tokens': 0},
      'content': [
        {'type': 'text', 'text': failureText},
      ],
    },
    'parent_tool_use_id': null,
    'session_id': '22d5daba-0c1e-4d77-8ac9-f9e7a43a68fd',
    'uuid': '98ca9f1e-8e85-4d5b-829d-c97ed824bcb0',
    'error': 'model_not_found',
    'request_id': 'req_011CeHnddj4ZnEA6cGQcDkVW',
    'is_api_error_message': true,
  };

  Map<String, dynamic> errorResultEnvelope() => {
    'is_error': true,
    'duration_api_ms': 0,
    'num_turns': 1,
    'session_id': '22d5daba-0c1e-4d77-8ac9-f9e7a43a68fd',
    'subtype': 'success',
    'api_error_status': 404,
    'terminal_reason': 'api_error',
    'result': failureText,
    'type': 'result',
    'uuid': '863dc0eb-a79a-41f1-86a3-b0f26afa7c46',
  };

  ProcessedMessages process(List<Map<String, dynamic>> envelopes) {
    final wireMessages = <Map<String, dynamic>>[];
    final decrypted = <Map<String, dynamic>>[];
    for (var i = 0; i < envelopes.length; i++) {
      decrypted.add({
        'role': 'agent',
        'content': {'type': 'output', 'data': envelopes[i]},
      });
      wireMessages.add({'id': 'm$i', 'seq': i + 1, 'createdAt': 1000 + i});
    }
    return processDecryptedMessages(
      decryptedJsonList: decrypted,
      wireMessages: wireMessages,
      sessionId: 's1',
    );
  }

  group('fatal agent API errors render as error cards', () {
    test('synthetic assistant turn renders one error card, no text bubble', () {
      final result = process([syntheticAssistantEnvelope()]);

      expect(result.messages, hasLength(1));
      final row = result.messages.single;
      expect(row['kind'], 'error');
      expect(row['role'], 'agent');
      expect(row['errorType'], 'model_not_found');
      expect(row['errorMessage'], failureText);
      expect(row['isError'], isTrue);
      expect((row['debugData'] as Map)['requestId'], contains('req_'));
      expect(
        result.messages.where((m) => m['kind'] == 'text'),
        isEmpty,
        reason: 'the failure must not double-render as an assistant bubble',
      );
    });

    test('trailing is_error result envelope does not duplicate the card', () {
      final result = process([
        syntheticAssistantEnvelope(),
        errorResultEnvelope(),
      ]);

      final errorRows = result.messages
          .where((m) => m['kind'] == 'error')
          .toList();
      expect(errorRows, hasLength(1));
      expect(result.messages.where((m) => m['kind'] == 'text'), isEmpty);
    });

    test('lone is_error result envelope renders an error card', () {
      final result = process([errorResultEnvelope()]);

      expect(result.messages, hasLength(1));
      final row = result.messages.single;
      expect(row['kind'], 'error');
      // terminal_reason beats the CLI's misleading subtype:"success".
      expect(row['errorType'], 'api_error');
      expect(row['errorMessage'], failureText);
      expect(
        result.messages.where((m) => m['kind'] == 'agent-event'),
        isEmpty,
        reason: 'must not fall through to the unsupported-dataType chip',
      );
    });

    test('normal assistant text keeps rendering as text', () {
      final result = process([
        {
          'type': 'assistant',
          'message': {
            'role': 'assistant',
            'model': 'claude-sonnet-4-6',
            'content': [
              {'type': 'text', 'text': 'All good, nothing failed.'},
            ],
          },
          'uuid': 'u1',
        },
      ]);

      expect(result.messages, hasLength(1));
      expect(result.messages.single['kind'], 'text');
      expect(result.messages.single['content'], 'All good, nothing failed.');
    });

    test('successful result envelope never produces an error card', () {
      final result = process([
        {
          'type': 'result',
          'subtype': 'success',
          'is_error': false,
          'result': 'Done.',
          'uuid': 'u2',
        },
      ]);

      expect(
        result.messages.where((m) => m['kind'] == 'error'),
        isEmpty,
      );
    });

    test('flagged envelope without extractable text stays silent', () {
      final result = process([
        {'type': 'assistant', 'is_api_error_message': true},
      ]);

      expect(result.messages, isEmpty);
    });

    test('string-message variant of the synthetic turn renders a card', () {
      final result = process([
        {
          'type': 'assistant',
          'error': 'model_not_found',
          'message': failureText,
        },
      ]);

      expect(result.messages, hasLength(1));
      expect(result.messages.single['kind'], 'error');
      expect(result.messages.single['errorMessage'], failureText);
    });
  });
}
