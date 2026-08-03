import 'package:flutter/material.dart';

import '../../core/utils/syntax_cache.dart';
import 'syntax_highlighter.dart';

/// Maximum code size that is tokenised for wrapped rendering.
///
/// Mirrors the guard inside [SyntaxHighlighter]: past this size the cost of
/// tokenising outweighs the benefit and the code renders unstyled.
const int _maxHighlightedCodeUnits = 50000;

/// Splits [code] into per-logical-line [TextSpan] lists using a **single**
/// tokenisation pass over the whole block.
///
/// Wrapped mode renders one widget per logical line so that each line gets
/// exactly one line number. Highlighting each line in isolation would break
/// multi-line constructs (block comments, multi-line strings, heredocs), so
/// the block is tokenised as a whole and the resulting tokens are then cut on
/// newlines. A token that spans lines keeps its style on every line it
/// covers.
///
/// The returned list always has `code.split('\n').length` entries.
List<List<TextSpan>> buildCodeLineSpans({
  required String code,
  required bool isDarkMode,
  String? language,
}) {
  if (code.length > _maxHighlightedCodeUnits) {
    return [
      for (final line in code.split('\n')) <TextSpan>[TextSpan(text: line)],
    ];
  }

  final tokens = SyntaxTokenCache.instance.get(code, language);
  final lines = <List<TextSpan>>[<TextSpan>[]];
  for (final token in tokens) {
    final style = TextStyle(
      color: SyntaxColors.getColor(token.type, token.nestLevel, isDarkMode),
      fontWeight: _fontWeightFor(token.type),
    );
    final parts = token.text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) lines.add(<TextSpan>[]);
      if (parts[i].isEmpty) continue;
      lines.last.add(TextSpan(text: parts[i], style: style));
    }
  }
  return lines;
}

/// Mirrors `_SyntaxHighlighterState._getFontWeight` so wrapped and
/// horizontal-scroll modes render identical weights.
FontWeight _fontWeightFor(SyntaxTokenType type) {
  return switch (type) {
    SyntaxTokenType.keyword ||
    SyntaxTokenType.controlFlow ||
    SyntaxTokenType.type ||
    SyntaxTokenType.function => FontWeight.w600,
    _ => FontWeight.w400,
  };
}
