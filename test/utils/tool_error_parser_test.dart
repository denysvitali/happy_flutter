import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/tool_error_parser.dart';

void main() {
  group('ToolErrorParser.parse', () {
    test('returns null for non-tool-error strings', () {
      expect(ToolErrorParser.parse('regular error message'), isNull);
      expect(ToolErrorParser.parse(''), isNull);
      expect(ToolErrorParser.parse('no tags here'), isNull);
    });

    test('parses basic tool error with type and body', () {
      const error =
          '<tool_use_error>'
          '<error_type>file_not_found</error_type>'
          '<body>File does not exist</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.errorType, 'file_not_found');
      expect(result.message, isNotEmpty);
    });

    test('parses tool error with only error_type', () {
      const error =
          '<tool_use_error>'
          '<error_type>timeout</error_type>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.errorType, 'timeout');
    });

    test('parses tool error with only body', () {
      const error =
          '<tool_use_error>'
          '<body>Something went wrong</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.errorType, 'Unknown');
      expect(result.message, isNotEmpty);
    });

    test('parses empty tool error tag', () {
      const error = '<tool_use_error></tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.errorType, 'Unknown');
    });

    test('extracts suggestion from body', () {
      const error =
          '<tool_use_error>'
          '<error_type>permission_denied</error_type>'
          '<body>'
          'Access denied'
          '<suggestion>Try running with sudo</suggestion>'
          '</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.suggestion, 'Try running with sudo');
    });

    test('extracts context from body', () {
      const error =
          '<tool_use_error>'
          '<error_type>validation</error_type>'
          '<body>'
          'Invalid input'
          '<context>Field x must be a string</context>'
          '</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.context, 'Field x must be a string');
    });

    test('extracts both suggestion and context', () {
      const error =
          '<tool_use_error>'
          '<error_type>invalid_input</error_type>'
          '<body>'
          'Bad request'
          '<context>Missing required field</context>'
          '<suggestion>Add the field to your request</suggestion>'
          '</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.context, 'Missing required field');
      expect(result.suggestion, 'Add the field to your request');
    });

    test('extracts error_name from body', () {
      const error =
          '<tool_use_error>'
          '<error_type>execution</error_type>'
          '<body>'
          '<error_name>CommandFailed</error_name>'
          'The command failed with exit code 1'
          '</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.errorName, 'CommandFailed');
    });

    test('uses error_type as error_name when error_name missing', () {
      const error =
          '<tool_use_error>'
          '<error_type>network</error_type>'
          '<body>Connection refused</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.errorName, 'network');
    });

    test('preserves raw message', () {
      const raw =
          '<tool_use_error>'
          '<error_type>test</error_type>'
          '<body>Test error</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(raw);
      expect(result, isNotNull);
      expect(result!.rawMessage, raw);
    });

    test('handles multiline content in body', () {
      const error =
          '<tool_use_error>'
          '<error_type>execution</error_type>'
          '<body>'
          'Line 1\n'
          'Line 2\n'
          'Line 3'
          '</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
      expect(result!.message, contains('Line 1'));
    });

    test('handles nested XML-like content', () {
      const error =
          '<tool_use_error>'
          '<error_type>parsing</error_type>'
          '<body>'
          'Failed to parse <tag>content</tag>'
          '</body>'
          '</tool_use_error>';
      final result = ToolErrorParser.parse(error);
      expect(result, isNotNull);
    });
  });

  group('ToolErrorParser.isToolError', () {
    test('returns true for tool error strings', () {
      const error =
          '<tool_use_error>'
          '<error_type>test</error_type>'
          '</tool_use_error>';
      expect(ToolErrorParser.isToolError(error), isTrue);
    });

    test('returns false for non-tool-error strings', () {
      expect(ToolErrorParser.isToolError('regular error'), isFalse);
      expect(ToolErrorParser.isToolError(''), isFalse);
      expect(ToolErrorParser.isToolError('<error>test</error>'), isFalse);
    });
  });

  group('ToolErrorParser.formatForDisplay', () {
    test('formats error with name and message', () {
      final error = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'TestError',
        message: 'Something failed',
      );
      final formatted = ToolErrorParser.formatForDisplay(error);
      expect(formatted, contains('TestError'));
      expect(formatted, contains('Something failed'));
    });

    test('includes context when present', () {
      final error = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'TestError',
        message: 'Failed',
        context: 'Some context',
      );
      final formatted = ToolErrorParser.formatForDisplay(error);
      expect(formatted, contains('Context:'));
      expect(formatted, contains('Some context'));
    });

    test('includes suggestion when present', () {
      final error = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'TestError',
        message: 'Failed',
        suggestion: 'Try this',
      );
      final formatted = ToolErrorParser.formatForDisplay(error);
      expect(formatted, contains('Suggestion:'));
      expect(formatted, contains('Try this'));
    });

    test('excludes context and suggestion when absent', () {
      final error = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'TestError',
        message: 'Failed',
      );
      final formatted = ToolErrorParser.formatForDisplay(error);
      expect(formatted, isNot(contains('Context:')));
      expect(formatted, isNot(contains('Suggestion:')));
    });
  });

  group('ToolErrorParser.extractAll', () {
    test('returns empty list for non-tool-error strings', () {
      expect(ToolErrorParser.extractAll('no errors here'), isEmpty);
      expect(ToolErrorParser.extractAll(''), isEmpty);
    });

    test('extracts single error', () {
      const error =
          '<tool_use_error>'
          '<error_type>test</error_type>'
          '</tool_use_error>';
      final errors = ToolErrorParser.extractAll(error);
      expect(errors.length, 1);
      expect(errors[0].errorType, 'test');
    });

    test('extracts multiple errors', () {
      const error =
          'Some text '
          '<tool_use_error>'
          '<error_type>first</error_type>'
          '</tool_use_error>'
          ' more text '
          '<tool_use_error>'
          '<error_type>second</error_type>'
          '</tool_use_error>';
      final errors = ToolErrorParser.extractAll(error);
      expect(errors.length, 2);
      expect(errors[0].errorType, 'first');
      expect(errors[1].errorType, 'second');
    });
  });

  group('ParsedToolError', () {
    test('toString returns descriptive string', () {
      final error = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'TestError',
        message: 'Something failed',
      );
      final str = error.toString();
      expect(str, contains('test'));
      expect(str, contains('TestError'));
    });

    test('isToolUseError returns true', () {
      final error = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'Test',
        message: 'msg',
      );
      expect(error.isToolUseError, isTrue);
    });

    test('displayMessage returns message', () {
      final error = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'Test',
        message: 'display this',
      );
      expect(error.displayMessage, 'display this');
    });

    test('copyWith replaces specified fields', () {
      final original = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'Test',
        message: 'msg',
        suggestion: 'suggest',
        context: 'ctx',
      );
      final copy = original.copyWith(
        errorName: 'NewName',
        message: 'new message',
      );
      expect(copy.errorName, 'NewName');
      expect(copy.message, 'new message');
      // Unchanged fields
      expect(copy.rawMessage, 'raw');
      expect(copy.errorType, 'test');
      expect(copy.suggestion, 'suggest');
      expect(copy.context, 'ctx');
    });

    test('copyWith preserves all fields when none specified', () {
      final original = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'Test',
        message: 'msg',
        suggestion: 'suggest',
        context: 'ctx',
      );
      final copy = original.copyWith();
      expect(copy.rawMessage, original.rawMessage);
      expect(copy.errorType, original.errorType);
      expect(copy.errorName, original.errorName);
      expect(copy.message, original.message);
      expect(copy.suggestion, original.suggestion);
      expect(copy.context, original.context);
    });

    test('toDisplayString returns formatted output', () {
      final error = ParsedToolError(
        rawMessage: 'raw',
        errorType: 'test',
        errorName: 'Test',
        message: 'msg',
      );
      final display = error.toDisplayString();
      expect(display, contains('Test'));
      expect(display, contains('msg'));
    });
  });

  group('ToolErrorStringExtension', () {
    test('asToolError returns parsed error for tool error strings', () {
      const error =
          '<tool_use_error>'
          '<error_type>test</error_type>'
          '</tool_use_error>';
      final parsed = error.asToolError;
      expect(parsed, isNotNull);
      expect(parsed!.errorType, 'test');
    });

    test('asToolError returns null for non-tool-error strings', () {
      expect('regular string'.asToolError, isNull);
    });

    test('isToolError returns true for tool error strings', () {
      const error =
          '<tool_use_error>'
          '<error_type>test</error_type>'
          '</tool_use_error>';
      expect(error.isToolError, isTrue);
    });

    test('isToolError returns false for regular strings', () {
      expect('regular string'.isToolError, isFalse);
    });
  });

  group('ToolErrorTypes constants', () {
    test('all expected error type constants exist', () {
      expect(ToolErrorTypes.invalidInput, 'invalid_input');
      expect(ToolErrorTypes.fileNotFound, 'file_not_found');
      expect(ToolErrorTypes.permissionDenied, 'permission_denied');
      expect(ToolErrorTypes.timeout, 'timeout');
      expect(ToolErrorTypes.rateLimit, 'rate_limit');
      expect(ToolErrorTypes.validation, 'validation');
      expect(ToolErrorTypes.parsing, 'parsing');
      expect(ToolErrorTypes.execution, 'execution');
      expect(ToolErrorTypes.network, 'network');
      expect(ToolErrorTypes.unknown, 'unknown');
    });
  });
}
