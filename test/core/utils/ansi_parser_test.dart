import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';

String _plain(List<TextSpan> spans) => spans.map((s) => s.text).join();

void main() {
  group('AnsiParser', () {
    test('parse colours SGR runs and hides the escapes', () {
      final spans = AnsiParser.parse('ok \x1b[31merror\x1b[0m done');
      expect(_plain(spans), 'ok error done');
      expect(spans[1].text, 'error');
      expect(spans[1].style?.color, const Color(0xFFCC0000));
      expect(spans[2].style?.color, isNull);
    });

    test('parse drops non-SGR escape sequences', () {
      const raw =
          '\x1b[2K\x1b[1G\x1b[?25lstep\x1b(B\x1b[m '
          '\x1b]8;;https://example.com\x07link\x1b]8;;\x1b\\ '
          '\x1b]0;title\x07end\x1b=';
      expect(_plain(AnsiParser.parse(raw)), 'step link end');
      expect(AnsiParser.strip(raw), 'step link end');
    });

    test('attribute resets remove earlier attributes', () {
      final spans = AnsiParser.parse(
        '\x1b[1;32mbold green\x1b[22mgreen\x1b[39mplain',
        defaultStyle: const TextStyle(fontSize: 12),
      );
      expect(spans[0].style?.fontWeight, FontWeight.bold);
      expect(spans[1].style?.fontWeight, isNot(FontWeight.bold));
      expect(spans[1].style?.color, const Color(0xFF00CC00));
      expect(spans[2].style?.color, isNull);
      expect(spans[2].style?.fontSize, 12);
    });

    test('text made only of escapes yields no visible text', () {
      expect(_plain(AnsiParser.parse('\x1b[0m\x1b[K')), '');
    });

    test('an unterminated OSC stops at the line break', () {
      expect(AnsiParser.strip('\x1b]0;cut off\nnext line'), '\nnext line');
    });
  });
}
