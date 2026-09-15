import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/task_label.dart';
import 'package:happy_flutter/core/utils/text_truncate.dart';

/// True when [text] is not well-formed UTF-16, i.e. it contains a high
/// surrogate with no following low surrogate, or a low surrogate with no
/// preceding high one.
///
/// This is the exact condition the text layout rejects with
/// `ArgumentError: Invalid argument(s): string is not well-formed UTF-16`,
/// which is what crashed the home route on build 279300 (GlitchTip
/// 8777/8779). A plain `substring` cut through an emoji produces it.
bool hasLoneSurrogate(String text) {
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (i + 1 >= text.length) return true;
      final next = text.codeUnitAt(i + 1);
      if (next < 0xDC00 || next > 0xDFFF) return true;
      i++; // consume the pair
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return true; // low surrogate with no high surrogate before it
    }
  }
  return false;
}

void main() {
  // U+1F600 GRINNING FACE: one grapheme, two UTF-16 code units.
  const emoji = '\u{1F600}';
  // 'e' + U+0301 COMBINING ACUTE ACCENT: one grapheme, two code units.
  const combining = 'é';

  group('hasLoneSurrogate oracle', () {
    test('detects the malformation a raw substring produces', () {
      expect(emoji.length, 2);
      expect(hasLoneSurrogate(emoji.substring(0, 1)), isTrue);
      expect(hasLoneSurrogate(emoji.substring(1)), isTrue);
    });

    test('accepts intact text', () {
      expect(hasLoneSurrogate(''), isFalse);
      expect(hasLoneSurrogate('plain ascii'), isFalse);
      expect(hasLoneSurrogate(emoji), isFalse);
      expect(hasLoneSurrogate(combining), isFalse);
    });
  });

  group('truncateGraphemes', () {
    test('never splits a surrogate pair', () {
      // The exact crash shape: cut just past the first half of an emoji.
      expect(hasLoneSurrogate(truncateGraphemes('$emoji$emoji', 1)), isFalse);
      expect(truncateGraphemes('$emoji$emoji', 1), '$emoji…');
    });

    test('keeps a combining mark with its base character', () {
      expect(truncateGraphemes('${combining}x', 1), '$combining…');
      expect(hasLoneSurrogate(truncateGraphemes('${combining}x', 1)), isFalse);
    });

    test('returns the input untouched when it fits', () {
      expect(truncateGraphemes('abc', 5), 'abc');
      expect(truncateGraphemes('abc', 3), 'abc');
      expect(truncateGraphemes('$emoji$emoji', 2), '$emoji$emoji');
    });

    test('appends the ellipsis only when it cuts', () {
      expect(truncateGraphemes('abcdef', 3), 'abc…');
      expect(truncateGraphemes('abcdef', 3, ellipsis: '...'), 'abc...');
    });

    test('handles empty and non-positive budgets', () {
      expect(truncateGraphemes('', 5), '');
      expect(truncateGraphemes('abc', 0), '');
      expect(truncateGraphemes('abc', -1), '');
    });

    // The property that matters: whatever the input, no cut may leave a
    // dangling half of a surrogate pair.
    test('every prefix length yields well-formed UTF-16', () {
      final input = 'a$emoji${combining}b\u{1F1EE}\u{1F1F9}c'; // incl. a flag
      for (var budget = 0; budget <= input.characters.length + 2; budget++) {
        expect(
          hasLoneSurrogate(truncateGraphemes(input, budget)),
          isFalse,
          reason: 'budget=$budget',
        );
      }
    });
  });

  group('tailGraphemes', () {
    test('never leaves a low surrogate at the start of the tail', () {
      expect(hasLoneSurrogate(tailGraphemes('x$emoji', 1)), isFalse);
      expect(tailGraphemes('x$emoji', 1), emoji);
    });

    test('returns the input untouched when it fits', () {
      expect(tailGraphemes('abc', 5), 'abc');
      expect(tailGraphemes('abc', 0), '');
    });

    test('every suffix length yields well-formed UTF-16', () {
      final input = 'a$emoji${combining}b\u{1F1EE}\u{1F1F9}c';
      for (var budget = 0; budget <= input.characters.length + 2; budget++) {
        expect(
          hasLoneSurrogate(tailGraphemes(input, budget)),
          isFalse,
          reason: 'budget=$budget',
        );
      }
    });
  });

  group('call sites that slice wire text', () {
    test('compactTaskLabel clamps a shell command on grapheme boundaries', () {
      // local_bash puts the entire command in this field, emoji included.
      final command = 'echo ${List.filled(200, emoji).join()}';
      final label = compactTaskLabel(command, maxChars: 40);
      expect(hasLoneSurrogate(label), isFalse);
      expect(label.endsWith('…'), isTrue);
    });
  });
}
