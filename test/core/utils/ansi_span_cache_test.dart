import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/ansi_parser.dart';
import 'package:happy_flutter/core/utils/ansi_span_cache.dart';

void main() {
  setUp(() {
    AnsiSpanCache.instance.debugClear();
  });

  tearDown(() {
    AnsiSpanCache.instance.debugClear();
  });

  String colored(int n, {String prefix = ''}) {
    final buf = StringBuffer(prefix);
    for (var i = 0; i < n; i++) {
      buf
        ..write('\x1b[3${i % 7 + 1}m')
        ..write('line $i of output ')
        ..write('\x1b[0m\n');
    }
    return buf.toString();
  }

  List<TextSpan> spansOf(String text) =>
      AnsiSpanCache.instance.parse(text);

  test('hit returns the identical span list without reparsing', () {
    const text = '\x1b[31mred\x1b[0m plain \x1b[32mgreen\x1b[0m';
    final first = spansOf(text);
    expect(AnsiSpanCache.instance.debugMisses, 1);

    final second = spansOf(text);
    expect(AnsiSpanCache.instance.debugHits, 1);
    expect(AnsiSpanCache.instance.debugMisses, 1);
    expect(identical(first, second), isTrue,
        reason: 'a warm hit must reuse the exact cached list');

    // Cached content equals a fresh direct parse.
    expect(
      second.map((s) => (s.text, s.style)).toList(),
      AnsiParser.parse(text)
          .map((s) => (s.text, s.style))
          .toList(),
    );
  });

  test('same length, different content never collides', () {
    final a = StringBuffer();
    final b = StringBuffer();
    // Identical shape and length; only digits inside the payload differ.
    for (var i = 0; i < 200; i++) {
      a.write('\x1b[32mrow-${i.toString().padLeft(4, '0')}-A\x1b[0m\n');
      b.write('\x1b[33mrow-${i.toString().padLeft(4, '0')}-B\x1b[0m\n');
    }
    final textA = a.toString();
    final textB = b.toString();
    expect(textA.length, textB.length);

    final spansA = spansOf(textA);
    final spansB = spansOf(textB);
    final directA = AnsiParser.parse(textA);
    final directB = AnsiParser.parse(textB);

    expect(
      spansA.map((s) => s.text).toList(),
      directA.map((s) => s.text).toList(),
    );
    expect(
      spansB.map((s) => s.text).toList(),
      directB.map((s) => s.text).toList(),
    );
    expect(spansB.first.style?.color, isNot(spansA.first.style?.color));
  });

  test('style participates in identity: same text, different style', () {
    // Leading unstyled run so the first span carries the default style.
    const text = 'plain head \x1b[31merror path\x1b[0m tail';
    const red = TextStyle(color: Colors.red, fontFamily: 'monospace');
    const blue = TextStyle(color: Colors.blue, fontFamily: 'monospace');

    final withRed = AnsiSpanCache.instance.parse(text, defaultStyle: red);
    final withBlue = AnsiSpanCache.instance.parse(text, defaultStyle: blue);
    expect(AnsiSpanCache.instance.debugMisses, 2,
        reason: 'different styles are distinct cache entries');

    expect(
      identical(
        withRed,
        AnsiSpanCache.instance.parse(text, defaultStyle: red),
      ),
      isTrue,
    );
    expect(
      identical(
        withBlue,
        AnsiSpanCache.instance.parse(text, defaultStyle: blue),
      ),
      isTrue,
    );
    expect(withRed.first.style?.color, red.color);
    expect(withBlue.first.style?.color, blue.color);
  });

  test('streaming growth misses then reparses the longer output', () {
    var streamed = colored(5);
    final first = spansOf(streamed);
    streamed += '\x1b[36mtail line\x1b[0m\n';
    final grown = spansOf(streamed);

    expect(grown.length, greaterThan(first.length));
    expect(AnsiSpanCache.instance.debugMisses, 2);
    // The old shorter entry is still valid for its own key.
    expect(identical(first, spansOf(colored(5))), isTrue);
  });

  test('eviction respects the entry cap', () {
    final cap = AnsiSpanCache.maxEntries;
    final texts = List<String>.generate(cap + 8, (i) => colored(2) * (i + 1));
    final firstSpans = spansOf(texts.first);
    for (final t in texts.skip(1)) {
      spansOf(t);
    }

    expect(AnsiSpanCache.instance.debugEntryCount, cap);
    expect(AnsiSpanCache.instance.debugEvictions, greaterThan(0));

    // The oldest entry was evicted: reparsing it is a miss again.
    final hitsBefore = AnsiSpanCache.instance.debugHits;
    final reparsed = spansOf(texts.first);
    expect(AnsiSpanCache.instance.debugHits, hitsBefore);
    expect(identical(reparsed, firstSpans), isFalse);
    expect(
      reparsed.map((s) => s.text).toList(),
      firstSpans.map((s) => s.text).toList(),
    );

    // The most recent entries survive.
    expect(
      identical(spansOf(texts.last), AnsiParser.parse(texts.last)),
      isFalse,
    );
    expect(AnsiSpanCache.instance.debugHits, hitsBefore + 1);
  });

  test('oversize outputs bypass the cache entirely', () {
    final big = StringBuffer();
    while (big.length <= AnsiSpanCache.maxCacheableChars) {
      big.write(colored(64));
    }
    final oversized = big.toString();
    expect(oversized.length, greaterThan(AnsiSpanCache.maxCacheableChars));

    final first = spansOf(oversized);
    final second = spansOf(oversized);

    expect(AnsiSpanCache.instance.debugBypasses, 2);
    expect(AnsiSpanCache.instance.debugHits, 0);
    expect(AnsiSpanCache.instance.debugEntryCount, 0);
    expect(
      second.map((s) => (s.text, s.style)).toList(),
      first.map((s) => (s.text, s.style)).toList(),
    );
  });

  test('empty input stays cheap and parser-shaped', () {
    expect(spansOf(''), isEmpty);
    expect(AnsiSpanCache.instance.debugEntryCount, 0);
  });

  test('strip path is unaffected by the memo', () {
    const text = '\x1b[31mred\x1b[0m plain tail';
    spansOf(text);
    expect(AnsiParser.strip(text), 'red plain tail');
    expect(AnsiParser.strip('no escapes here'), 'no escapes here');
    expect(AnsiParser.strip('\x1b[38;5;196mx\x1b[0m'), 'x');
  });
}
