import 'package:flutter/material.dart';

import '../../../core/theme/syntax_theme.dart';

/// Semantic colors for rendering JSON.
///
/// Shared by the collapsible [JsonTreeViewer] and the flat, line-based panes
/// (MCP tool results) so both spell the same payload in the same colors.
class JsonSyntaxColors {
  const JsonSyntaxColors({
    required this.key,
    required this.string,
    required this.number,
    required this.boolean,
    required this.nullValue,
    required this.bracket,
    required this.punctuation,
    required this.muted,
  });

  final Color key;
  final Color string;
  final Color number;
  final Color boolean;
  final Color nullValue;
  final Color bracket;
  final Color punctuation;
  final Color muted;

  static JsonSyntaxColors of(Brightness brightness, Color onSurface) {
    // Map JSON's semantic roles onto the [SyntaxTheme] tokens so a
    // single palette drives both the code-block highlighter and the
    // JSON tree viewer. The ThemeHelper registers both light and dark
    // variants, so the matching one is always present.
    final syntax = brightness == Brightness.dark
        ? SyntaxTheme.dark
        : SyntaxTheme.light;
    return JsonSyntaxColors(
      key: syntax.colorFor('property'),
      string: syntax.colorFor('string'),
      number: syntax.colorFor('number'),
      boolean: syntax.colorFor('boolean'),
      nullValue: syntax.colorFor('default'),
      bracket: syntax.colorFor('bracket'),
      // Punctuation and muted are alpha tints of onSurface so they
      // adapt to whatever surface the JSON sits on.
      punctuation: onSurface.withValues(alpha: 0.5),
      muted: onSurface.withValues(alpha: 0.4),
    );
  }
}

/// Payload size past which highlighting is skipped.
///
/// Mirrors the guard in `code_block_line_spans.dart`: beyond this the scan
/// costs more than the readability it buys, and the pane falls back to plain
/// monospace text.
const int jsonHighlightMaxCodeUnits = 50000;

/// Colors a pretty-printed JSON [text] into styled runs.
///
/// Unlike the generic code tokenizer this distinguishes an object *key* from a
/// string *value* — the single most useful distinction in a deeply nested
/// payload, and the one the tree viewer already makes. Whitespace and indent
/// come back unstyled so the caller's base style applies.
///
/// Returns a single unstyled span when [text] is larger than
/// [jsonHighlightMaxCodeUnits].
List<TextSpan> buildJsonSpans(String text, JsonSyntaxColors colors) {
  if (text.length > jsonHighlightMaxCodeUnits) {
    return <TextSpan>[TextSpan(text: text)];
  }

  final spans = <TextSpan>[];
  var plainStart = 0;

  void emit(int start, int end, Color color) {
    if (start > plainStart) {
      spans.add(TextSpan(text: text.substring(plainStart, start)));
    }
    spans.add(
      TextSpan(
        text: text.substring(start, end),
        style: TextStyle(color: color),
      ),
    );
    plainStart = end;
  }

  var i = 0;
  while (i < text.length) {
    final ch = text.codeUnitAt(i);

    if (ch == _quote) {
      final end = _scanString(text, i);
      if (end > i + 1) {
        emit(i, end, _followedByColon(text, end) ? colors.key : colors.string);
        i = end;
        continue;
      }
      i++;
      continue;
    }

    if (ch == _openBrace ||
        ch == _closeBrace ||
        ch == _openBracket ||
        ch == _closeBracket) {
      emit(i, i + 1, colors.bracket);
      i++;
      continue;
    }

    if (ch == _comma || ch == _colon) {
      emit(i, i + 1, colors.punctuation);
      i++;
      continue;
    }

    if (_startsWord(text, i)) {
      if (text.startsWith('true', i)) {
        emit(i, i + 4, colors.boolean);
        i += 4;
        continue;
      }
      if (text.startsWith('false', i)) {
        emit(i, i + 5, colors.boolean);
        i += 5;
        continue;
      }
      if (text.startsWith('null', i)) {
        emit(i, i + 4, colors.nullValue);
        i += 4;
        continue;
      }
      final end = _scanNumber(text, i);
      if (end > i) {
        emit(i, end, colors.number);
        i = end;
        continue;
      }
    }

    i++;
  }

  if (plainStart < text.length) {
    spans.add(TextSpan(text: text.substring(plainStart)));
  }
  return spans;
}

const int _quote = 0x22;
const int _comma = 0x2C;
const int _colon = 0x3A;
const int _minus = 0x2D;
const int _backslash = 0x5C;
const int _newline = 0x0A;
const int _openBracket = 0x5B;
const int _closeBracket = 0x5D;
const int _openBrace = 0x7B;
const int _closeBrace = 0x7D;
const int _zero = 0x30;
const int _nine = 0x39;

/// Index just past the string literal opening at [start].
///
/// Stops at a newline: a JSON string cannot contain a raw one, so hitting it
/// means the quote was unbalanced and coloring the rest of the payload as a
/// string would be worse than leaving it plain.
int _scanString(String text, int start) {
  var i = start + 1;
  while (i < text.length) {
    final ch = text.codeUnitAt(i);
    if (ch == _backslash) {
      i += 2;
      continue;
    }
    if (ch == _newline) return start + 1;
    if (ch == _quote) return i + 1;
    i++;
  }
  return start + 1;
}

/// Whether the next non-space character at or after [index] is `:`.
bool _followedByColon(String text, int index) {
  for (var i = index; i < text.length; i++) {
    final ch = text.codeUnitAt(i);
    if (ch == _colon) return true;
    if (ch != 0x20 && ch != 0x09) return false;
  }
  return false;
}

/// Whether position [index] can begin a literal — i.e. it is not in the middle
/// of a longer bare word.
bool _startsWord(String text, int index) {
  if (index == 0) return true;
  final prev = text.codeUnitAt(index - 1);
  final isWord =
      (prev >= 0x30 && prev <= 0x39) ||
      (prev >= 0x41 && prev <= 0x5A) ||
      (prev >= 0x61 && prev <= 0x7A) ||
      prev == 0x5F ||
      prev == 0x2E;
  return !isWord;
}

/// Index just past the JSON number starting at [start], or [start] when there
/// is no number there.
int _scanNumber(String text, int start) {
  var i = start;
  if (i < text.length && text.codeUnitAt(i) == _minus) i++;
  final digitsStart = i;
  while (i < text.length && _isDigit(text.codeUnitAt(i))) {
    i++;
  }
  if (i == digitsStart) return start;
  if (i < text.length && text.codeUnitAt(i) == 0x2E) {
    final afterDot = i + 1;
    var j = afterDot;
    while (j < text.length && _isDigit(text.codeUnitAt(j))) {
      j++;
    }
    if (j > afterDot) i = j;
  }
  if (i < text.length &&
      (text.codeUnitAt(i) == 0x65 || text.codeUnitAt(i) == 0x45)) {
    var j = i + 1;
    if (j < text.length &&
        (text.codeUnitAt(j) == _minus || text.codeUnitAt(j) == 0x2B)) {
      j++;
    }
    final expStart = j;
    while (j < text.length && _isDigit(text.codeUnitAt(j))) {
      j++;
    }
    if (j > expStart) i = j;
  }
  return i;
}

bool _isDigit(int ch) => ch >= _zero && ch <= _nine;
