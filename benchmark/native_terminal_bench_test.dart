import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/native/native_core.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';

import 'bench_runner.dart';

void main() {
  final reporter = BenchReporter(group: 'terminal');
  tearDownAll(() => reporter.finish());

  test('large streaming output: Dart preparation versus native', () async {
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
        'dart_prepare_200kb',
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
        'rust_prepare_200kb',
        () {
          final result = NativeCore.instance.prepareTerminalOutput(
            text: output,
            maxLines: 20,
          )!;
          sink += result.totalLines;
          sink += result.visibleText.length;
          sink += result.strippedOutput.length;
        },
        iterations: 20,
        warmup: 3,
      );
    final prepared = NativeCore.instance.prepareTerminalOutput(
      text: output,
      maxLines: 20,
    )!;
    expect(prepared.totalLines, output.split('\n').length);
    expect(prepared.visibleText, output.split('\n').take(20).join('\n'));
    expect(prepared.strippedOutput, AnsiParser.strip(output));
    expect(sink, greaterThan(0));
  });
}
