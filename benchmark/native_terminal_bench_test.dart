import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/native/native_core.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/terminal_output_preview.dart';

import 'bench_runner.dart';

void main() {
  final reporter = BenchReporter(group: 'terminal');
  tearDownAll(() => reporter.finish());

  test('large streaming output: old update versus lazy preview', () async {
    await NativeCore.instance.ensureInitialized();
    expect(
      NativeCore.instance.isAvailable,
      isTrue,
      reason: 'CI builds the native core before benchmarking it',
    );
    final line = '☕ \x1b[38;5;196mcolored command output\x1b[0m\n';
    final output = line * 5000;
    var sink = 0;

    reporter
      ..measureSync(
        'old_eager_update_200kb',
        () {
          final lines = output.split('\n');
          sink += lines.length;
          sink += lines.take(20).join('\n').length;
          sink += AnsiParser.strip(output).length;
        },
        iterations: 20,
        warmup: 3,
      )
      ..measureSync(
        'lazy_preview_update_200kb',
        () {
          final result = prepareTerminalOutputPreview(output, 20);
          sink += result.totalLines;
          sink += result.visibleText.length;
        },
        iterations: 20,
        warmup: 3,
      );
    final prepared = prepareTerminalOutputPreview(output, 20);
    expect(prepared.totalLines, output.split('\n').length);
    expect(prepared.visibleText, output.split('\n').take(20).join('\n'));
    expect(
      await NativeCore.instance.stripTerminalAnsi(output),
      AnsiParser.strip(output),
    );
    expect(sink, greaterThan(0));
  });
}
