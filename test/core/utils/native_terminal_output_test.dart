import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/native/native_core.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/terminal_output_preview.dart';

void main() {
  setUp(() async {
    NativeCore.instance.debugReset();
    await NativeCore.instance.ensureInitialized();
  });

  tearDown(NativeCore.instance.debugReset);

  test('preview matches split-and-join across line limits', () {
    final output = List<String>.generate(
      320,
      (i) =>
          '☕ row $i \x1b[38;5;196mred\x1b[0m '
          '\x1b[31K untouched',
    ).join('\n');
    expect(output.length, greaterThan(4096));

    for (final maxLines in [0, 1, 20, 320, 400]) {
      final prepared = prepareTerminalOutputPreview(output, maxLines);
      final lines = output.split('\n');
      expect(prepared.totalLines, lines.length);
      expect(prepared.needsTruncation, lines.length > maxLines);
      expect(prepared.visibleText, lines.take(maxLines).join('\n'));
    }
    expect(prepareTerminalOutputPreview('a\n', 1).totalLines, 2);
    expect(prepareTerminalOutputPreview('', 1).totalLines, 1);
  });

  test('native copy strip matches Dart for long Unicode ANSI text', () async {
    if (!NativeCore.instance.isAvailable) return;
    final output = '☕ \x1b[38;5;196mred\x1b[0m\x1b[31K 日本\n' * 320;
    expect(
      await NativeCore.instance.stripTerminalAnsi(output),
      AnsiParser.strip(output),
    );
  });

  test('missing native core keeps the Dart fallback available', () async {
    NativeCore.instance.debugSetAvailable(available: false);
    expect(
      await NativeCore.instance.stripTerminalAnsi('plain \x1b[31mred\x1b[0m'),
      isNull,
    );
    expect(AnsiParser.strip('plain \x1b[31mred\x1b[0m'), 'plain red');
  });
}
