import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/tool_result_parser.dart';

void main() {
  group('parseExitCode', () {
    test('parses int exitCode', () {
      const result = {'exitCode': 0};
      expect(parseExitCode(result), 0);
    });

    test('parses int exit_code', () {
      const result = {'exit_code': 1};
      expect(parseExitCode(result), 1);
    });

    test('prefers exitCode over exit_code', () {
      const result = {'exitCode': 0, 'exit_code': 1};
      expect(parseExitCode(result), 0);
    });

    test('parses string exit code', () {
      const result = {'exitCode': '42'};
      expect(parseExitCode(result), 42);
    });

    test('returns null for malformed string', () {
      const result = {'exitCode': 'abc'};
      expect(parseExitCode(result), isNull);
    });

    test('returns null for non-map', () {
      expect(parseExitCode('plain string'), isNull);
    });

    test('returns null when absent', () {
      expect(parseExitCode({'stdout': 'ok'}), isNull);
    });
  });

  group('parseStdout', () {
    test('parses stdout from map', () {
      const result = {'stdout': 'hello'};
      expect(parseStdout(result), 'hello');
    });

    test('falls back to output', () {
      const result = {'output': 'hello'};
      expect(parseStdout(result), 'hello');
    });

    test('prefers stdout over output', () {
      const result = {'stdout': 'a', 'output': 'b'};
      expect(parseStdout(result), 'a');
    });

    test('returns plain string as-is', () {
      expect(parseStdout('hello'), 'hello');
    });

    test('returns null when absent', () {
      expect(parseStdout({'stderr': 'err'}), isNull);
    });
  });

  group('parseStderr', () {
    test('parses stderr from map', () {
      const result = {'stderr': 'error'};
      expect(parseStderr(result), 'error');
    });

    test('returns null for plain string', () {
      expect(parseStderr('plain'), isNull);
    });

    test('returns null when absent', () {
      expect(parseStderr({'stdout': 'ok'}), isNull);
    });
  });

  group('parseErrorText', () {
    test('parses stderr first', () {
      const result = {
        'stderr': 'err',
        'stdout': 'out',
        'output': 'output',
      };
      expect(parseErrorText(result), 'err');
    });

    test('falls back through stdout, output, error, summary', () {
      expect(parseErrorText({'stdout': 'out'}), 'out');
      expect(parseErrorText({'output': 'output'}), 'output');
      expect(parseErrorText({'error': 'err'}), 'err');
      expect(parseErrorText({'summary': 'summary'}), 'summary');
    });

    test('returns string as-is', () {
      expect(parseErrorText('plain error'), 'plain error');
    });

    test('returns null when map has no error fields', () {
      expect(parseErrorText({'other': 'value'}), isNull);
    });
  });

  group('isStructuredResult', () {
    test('returns true for stdout', () {
      expect(isStructuredResult({'stdout': 'ok'}), isTrue);
    });

    test('returns true for stderr', () {
      expect(isStructuredResult({'stderr': 'err'}), isTrue);
    });

    test('returns true for exitCode variants', () {
      expect(isStructuredResult({'exitCode': 0}), isTrue);
      expect(isStructuredResult({'exit_code': 0}), isTrue);
    });

    test('returns true for output', () {
      expect(isStructuredResult({'output': 'ok'}), isTrue);
    });

    test('returns true for error', () {
      expect(isStructuredResult({'error': 'err'}), isTrue);
    });

    test('returns true for summary', () {
      expect(isStructuredResult({'summary': 'summary'}), isTrue);
    });

    test('returns false for plain string', () {
      expect(isStructuredResult('plain'), isFalse);
    });

    test('returns false for unrelated map', () {
      expect(isStructuredResult({'other': 'value'}), isFalse);
    });
  });

  group('parseFileEntries', () {
    test('parses list of maps', () {
      const result = [
        {'name': 'a.txt'},
        {'name': 'b.txt'},
      ];
      expect(parseFileEntries(result), [
        {'name': 'a.txt'},
        {'name': 'b.txt'},
      ]);
    });

    test('filters non-map entries from list', () {
      const result = [
        {'name': 'a.txt'},
        'not-a-map',
      ];
      expect(parseFileEntries(result), [
        {'name': 'a.txt'},
      ]);
    });

    test('parses entries key', () {
      const result = {
        'entries': [
          {'name': 'a.txt'},
        ],
      };
      expect(parseFileEntries(result), [
        {'name': 'a.txt'},
      ]);
    });

    test('parses files key', () {
      const result = {
        'files': [
          {'name': 'a.txt'},
        ],
      };
      expect(parseFileEntries(result), [
        {'name': 'a.txt'},
      ]);
    });

    test('parses items key', () {
      const result = {
        'items': [
          {'name': 'a.txt'},
        ],
      };
      expect(parseFileEntries(result), [
        {'name': 'a.txt'},
      ]);
    });

    test('returns empty list for unrelated map', () {
      expect(parseFileEntries({'other': 'value'}), isEmpty);
    });

    test('returns empty list for null', () {
      expect(parseFileEntries(null), isEmpty);
    });
  });
}
