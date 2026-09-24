import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/native/native_core.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';

void main() {
  setUp(() async {
    NativeCore.instance.debugReset();
    await NativeCore.instance.ensureInitialized();
  });

  tearDown(NativeCore.instance.debugReset);

  test('native preview and copy text match Dart for a long ANSI output', () {
    if (!NativeCore.instance.isAvailable) return;
    final output = List<String>.generate(
      320,
      (i) =>
          '☕ row $i \x1b[38;5;196mred\x1b[0m '
          '\x1b[31K untouched',
    ).join('\n');
    expect(output.length, greaterThan(4096));

    for (final maxLines in [0, 1, 20, 320, 400]) {
      final prepared = NativeCore.instance.prepareTerminalOutput(
        text: output,
        maxLines: maxLines,
      );
      expect(prepared, isNotNull);
      final lines = output.split('\n');
      expect(prepared!.totalLines, lines.length);
      expect(prepared.visibleText, lines.take(maxLines).join('\n'));
      expect(prepared.strippedOutput, AnsiParser.strip(output));
    }
  });

  test('missing native core keeps the Dart fallback available', () {
    NativeCore.instance.debugSetAvailable(available: false);
    expect(
      NativeCore.instance.prepareTerminalOutput(
        text: 'plain \x1b[31mred\x1b[0m',
        maxLines: 2,
      ),
      isNull,
    );
    expect(AnsiParser.strip('plain \x1b[31mred\x1b[0m'), 'plain red');
  });
}
