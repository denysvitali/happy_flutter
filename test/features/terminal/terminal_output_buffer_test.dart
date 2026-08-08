import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/terminal/terminal_output_buffer.dart';

void main() {
  group('TerminalOutputBuffer', () {
    test(
      'shows daemon truncation metadata without retaining unbounded lines',
      () {
        final buffer = TerminalOutputBuffer(maxRetainedLines: 5)
          ..appendLine('connected')
          ..appendResult(
            const BashResponse(
              success: true,
              stdout: 'one\ntwo\nthree\nfour\nfive',
              stdoutTruncated: true,
              stdoutBytes: 2097152,
            ),
            truncationNotice: 'Output truncated (2 MB total).',
          );

        expect(buffer.lines, hasLength(5));
        expect(buffer.lines.first, 'two');
        expect(buffer.lines.last, 'Output truncated (2 MB total).');
      },
    );

    test('adds one notice when either stream was truncated', () {
      final buffer = TerminalOutputBuffer(maxRetainedLines: 20)
        ..appendResult(
          const BashResponse(
            success: false,
            stdout: 'out',
            stderr: 'err',
            stderrTruncated: true,
            stderrBytes: 1048577,
          ),
          truncationNotice: 'Output truncated.',
        );

      expect(buffer.lines, <String>['out', 'err', 'Output truncated.']);
    });

    test('caps history across repeated commands', () {
      final buffer = TerminalOutputBuffer(maxRetainedLines: 3)
        ..appendLine('first')
        ..appendLine('second')
        ..appendLine('third')
        ..appendLine('fourth');

      expect(buffer.lines, <String>['second', 'third', 'fourth']);
    });
  });
}
