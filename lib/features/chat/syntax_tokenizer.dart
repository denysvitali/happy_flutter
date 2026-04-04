import 'syntax_highlighter.dart';

/// Tokenizes code into syntax tokens.
class SyntaxTokenizer {
  /// Bracket pairs for nesting detection.
  static const Map<String, String> bracketPairs = {
    '(': ')',
    '[': ']',
    '{': '}',
    '<': '>',
  };

  static final Set<String> openBrackets = bracketPairs.keys.toSet();
  static final Set<String> closeBrackets = bracketPairs.values.toSet();

  /// Tokenizes the given [code] string into syntax tokens for [language].
  static List<SyntaxToken> tokenize(String code, String? language) {
    final tokens = <SyntaxToken>[];

    if (language == null) {
      return [SyntaxToken(text: code, type: SyntaxTokenType.default_)];
    }

    if (code.isEmpty) return tokens;

    final lang = language.toLowerCase();
    final keywordSets = _getKeywordSets(lang);
    final patterns = _getPatterns(keywordSets);
    final nestingMap = _calculateBracketNesting(code);

    // Pre-scan for block comments (/* ... */) and docstrings that may span
    // multiple lines. We record their byte ranges so that per-line
    // tokenization can skip them and emit them as single tokens instead.
    final blockSpans = _findBlockSpans(code);

    final lines = code.split('\n');
    var globalOffset = 0;

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];

      if (lineIndex > 0) {
        tokens.add(
          const SyntaxToken(text: '\n', type: SyntaxTokenType.default_),
        );
        globalOffset += 1;
      }

      // Determine which portions of this line are covered by a block span.
      final lineEnd = globalOffset + line.length;

      // Emit the block-span tokens that START on this line (may end later).
      // Track which character ranges in this line are covered.
      final coveredRanges = <_Range>[];
      for (final span in blockSpans) {
        if (span.start >= globalOffset && span.start < lineEnd) {
          // Span starts on this line; emit the full multi-line token now.
          final spanText = code.substring(span.start, span.end);
          tokens.add(SyntaxToken(text: spanText, type: span.type));
          // Mark covered range relative to line start.
          coveredRanges.add(_Range(
            span.start - globalOffset,
            // Clamp to end of this line; rest is on following lines.
            (span.end - globalOffset).clamp(0, line.length),
          ));
        } else if (span.start < globalOffset && span.end > globalOffset) {
          // Span started on a previous line and continues through this one.
          coveredRanges.add(_Range(
            0,
            (span.end - globalOffset).clamp(0, line.length),
          ));
        }
      }

      // Build a per-line token list, excluding covered ranges.
      final lineTokens = <_LineToken>[];
      for (final pattern in patterns) {
        final matches = pattern.regex.allMatches(line);
        for (final match in matches) {
          final tokenText = pattern.captureGroup != null
              ? match.group(pattern.captureGroup!)!
              : match.group(0)!;
          if (tokenText.isEmpty) continue;
          final tokenStart = pattern.captureGroup != null
              ? match.start + match.group(0)!.indexOf(tokenText)
              : match.start;
          final tokenEnd = tokenStart + tokenText.length;

          // Skip if this position is already covered by a block span.
          if (_isCovered(tokenStart, coveredRanges)) continue;

          lineTokens.add(_LineToken(
            start: tokenStart,
            end: tokenEnd,
            type: pattern.type,
            text: tokenText,
          ));
        }
      }

      // Sort tokens by position and remove overlaps.
      lineTokens.sort((a, b) => a.start - b.start);
      final filteredTokens = <_LineToken>[];
      var lastEnd = 0;
      for (final token in lineTokens) {
        if (token.start >= lastEnd) {
          filteredTokens.add(token);
          lastEnd = token.end;
        }
      }

      // Emit line characters, skipping covered ranges and inserting tokens.
      var currentIndex = 0;

      // Merge covered ranges and filtered tokens into a sorted event list.
      final events = <_LineEvent>[];
      for (final r in coveredRanges) {
        if (r.start < r.end) {
          events.add(_LineEvent(r.start, r.end, null));
        }
      }
      for (final t in filteredTokens) {
        events.add(_LineEvent(t.start, t.end, t));
      }
      events.sort((a, b) => a.start - b.start);

      for (final event in events) {
        if (event.start < currentIndex) continue; // overlapping — skip
        if (event.start > currentIndex) {
          final beforeText = line.substring(currentIndex, event.start);
          if (beforeText.isNotEmpty) {
            tokens.add(SyntaxToken(
              text: beforeText,
              type: SyntaxTokenType.default_,
            ));
          }
        }

        if (event.token != null) {
          final token = event.token!;
          if (token.type == SyntaxTokenType.bracket) {
            final globalPos = globalOffset + token.start;
            final nestLevel = nestingMap[globalPos] ?? 1;
            tokens.add(SyntaxToken(
              text: token.text,
              type: token.type,
              nestLevel: nestLevel,
            ));
          } else {
            tokens.add(SyntaxToken(text: token.text, type: token.type));
          }
        }
        // If event.token is null it's a covered range — just advance.

        currentIndex = event.end;
      }

      if (currentIndex < line.length) {
        final remainingText = line.substring(currentIndex);
        if (remainingText.isNotEmpty) {
          tokens.add(SyntaxToken(
            text: remainingText,
            type: SyntaxTokenType.default_,
          ));
        }
      }

      globalOffset += line.length;
    }

    return tokens;
  }

  static bool _isCovered(int pos, List<_Range> ranges) {
    for (final r in ranges) {
      if (pos >= r.start && pos < r.end) return true;
    }
    return false;
  }

  static final RegExp _blockCommentRe =
      RegExp(r'/\*[\s\S]*?\*/', multiLine: true);
  static final RegExp _docstringDoubleRe =
      RegExp(r'"""[\s\S]*?"""', multiLine: true);
  static final RegExp _docstringSingleRe =
      RegExp(r"'''[\s\S]*?'''", multiLine: true);

  /// Returns a list of [_BlockSpan]s covering block comments and docstrings
  /// in [code]. Spans are sorted by start position and non-overlapping.
  static List<_BlockSpan> _findBlockSpans(String code) {
    final spans = <_BlockSpan>[];
    for (final m in _blockCommentRe.allMatches(code)) {
      spans.add(_BlockSpan(m.start, m.end, SyntaxTokenType.comment));
    }
    for (final m in _docstringDoubleRe.allMatches(code)) {
      spans.add(_BlockSpan(m.start, m.end, SyntaxTokenType.docstring));
    }
    for (final m in _docstringSingleRe.allMatches(code)) {
      spans.add(_BlockSpan(m.start, m.end, SyntaxTokenType.docstring));
    }
    spans.sort((a, b) => a.start - b.start);
    // Remove overlaps (keep the first).
    final result = <_BlockSpan>[];
    var lastEnd = 0;
    for (final s in spans) {
      if (s.start >= lastEnd) {
        result.add(s);
        lastEnd = s.end;
      }
    }
    return result;
  }

  static Map<String, List<String>> _getKeywordSets(String lang) {
    return {
      'controlFlow': [
        'if', 'else', 'elif', 'for', 'while', 'do', 'switch', 'case',
        'break', 'continue', 'return', 'yield', 'try', 'catch', 'finally',
        'throw', 'with',
      ],
      'keywords': [
        'function', 'const', 'let', 'var', 'def', 'class', 'interface',
        'enum', 'struct', 'union', 'namespace', 'module',
      ],
      'types': [
        'int', 'string', 'bool', 'float', 'double', 'char', 'void', 'any',
        'unknown', 'never', 'object', 'array', 'number', 'boolean',
      ],
      'modifiers': [
        'public', 'private', 'protected', 'static', 'final', 'abstract',
        'virtual', 'override', 'async', 'await', 'export', 'default',
      ],
      'boolean': [
        'true', 'false', 'null', 'undefined', 'None', 'True', 'False', 'nil',
      ],
      'imports': [
        'import', 'from', 'export', 'require', 'include', 'using', 'package',
      ],
    };
  }

  // Cached compiled patterns — built once and reused across all tokenize calls.
  static final List<_TokenPattern> _cachedPatterns = _buildPatterns();

  static List<_TokenPattern> _buildPatterns() {
    final keywordSets = _getKeywordSets('');
    return _buildPatternsFromSets(keywordSets);
  }

  static List<_TokenPattern> _getPatterns(
    Map<String, List<String>> keywordSets,
  ) {
    return _cachedPatterns;
  }

  static List<_TokenPattern> _buildPatternsFromSets(
    Map<String, List<String>> keywordSets,
  ) {
    final controlFlowPattern = keywordSets['controlFlow']!.join('|');
    final keywordsPattern = keywordSets['keywords']!.join('|');
    final typesPattern = keywordSets['types']!.join('|');
    final modifiersPattern = keywordSets['modifiers']!.join('|');
    final booleanPattern = keywordSets['boolean']!.join('|');
    final importsPattern = keywordSets['imports']!.join('|');

    return [
      // Single-line comments (block comments handled via _findBlockSpans)
      _TokenPattern(
        RegExp(r'//.*$'),
        SyntaxTokenType.comment,
        multiline: true,
      ),
      _TokenPattern(
        RegExp(r'#.*$'),
        SyntaxTokenType.comment,
        multiline: true,
      ),

      // Strings
      _TokenPattern(
        RegExp(r'''(r?["'`])((?:(?!\1)[^\\]|\\.)*)(\1)'''),
        SyntaxTokenType.string,
      ),
      // Regex literals
      _TokenPattern(
        RegExp(r'/(?:[^\/\\\n]|\\.)+/[gimuy]*'),
        SyntaxTokenType.regex,
      ),

      // Numbers (hex, binary, octal, floats)
      _TokenPattern(
        RegExp(
          r'\b(0x[0-9a-fA-F]+'
          r'|0b[01]+'
          r'|0o[0-7]+'
          r'|\d+\.?\d*(?:[eE][+-]?\d+)?)\b',
        ),
        SyntaxTokenType.number,
      ),

      // Decorators / annotations
      _TokenPattern(RegExp(r'@\w+'), SyntaxTokenType.decorator),

      // Keywords by category — must come before function-call patterns so
      // that keywords like 'import', 'return', 'if' are not mis-classified
      // as function calls when followed by '('.
      _TokenPattern(
        RegExp('\\b($importsPattern)\\b'),
        SyntaxTokenType.import,
      ),
      _TokenPattern(
        RegExp('\\b($controlFlowPattern)\\b'),
        SyntaxTokenType.controlFlow,
      ),
      _TokenPattern(
        RegExp('\\b($keywordsPattern)\\b'),
        SyntaxTokenType.keyword,
      ),
      _TokenPattern(
        RegExp('\\b($typesPattern)\\b'),
        SyntaxTokenType.type,
      ),
      _TokenPattern(
        RegExp('\\b($modifiersPattern)\\b'),
        SyntaxTokenType.modifier,
      ),
      _TokenPattern(
        RegExp('\\b($booleanPattern)\\b'),
        SyntaxTokenType.boolean,
      ),

      // Function definitions
      _TokenPattern(
        RegExp(
          r'(function|def|async function)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)',
        ),
        SyntaxTokenType.function,
        captureGroup: 2,
      ),
      _TokenPattern(
        RegExp(r'\b([a-zA-Z_$][a-zA-Z0-9_$]*)\s*(?=\()'),
        SyntaxTokenType.function,
      ),

      // Method calls and property access
      _TokenPattern(
        RegExp(r'\.([a-zA-Z_$][a-zA-Z0-9_$]*)\s*(?=\()'),
        SyntaxTokenType.method,
        captureGroup: 1,
      ),
      _TokenPattern(
        RegExp(r'\.([a-zA-Z_$][a-zA-Z0-9_$]*)'),
        SyntaxTokenType.property,
        captureGroup: 1,
      ),

      // Operators
      _TokenPattern(
        RegExp(r'(===|!==|==|!=|<=|>=|<|>)'),
        SyntaxTokenType.comparison,
      ),
      _TokenPattern(RegExp(r'(&&|\|\||!)'), SyntaxTokenType.logical),
      // Note: |= uses \| to avoid an empty alternative that matches ''.
      _TokenPattern(
        RegExp(r'(=|\+=|-=|\*=|/=|%=|\|=|&=|\^=)'),
        SyntaxTokenType.assignment,
      ),
      _TokenPattern(
        RegExp(r'(\+|-|\*|/|%|\*\*)'),
        SyntaxTokenType.operator,
      ),
      _TokenPattern(RegExp(r'(\?|:)'), SyntaxTokenType.operator),

      // Brackets and punctuation
      _TokenPattern(RegExp(r'([()[\]{}])'), SyntaxTokenType.bracket),
      _TokenPattern(RegExp(r'([.,;])'), SyntaxTokenType.punctuation),
    ];
  }

  /// Calculates bracket nesting levels for each position in [code].
  static Map<int, int> _calculateBracketNesting(String code) {
    final nestingMap = <int, int>{};
    final stack = <_BracketInfo>[];

    for (var i = 0; i < code.length; i++) {
      final char = code[i];

      if (openBrackets.contains(char)) {
        stack.add(_BracketInfo(char: char, pos: i));
        nestingMap[i] = stack.length;
      } else if (closeBrackets.contains(char)) {
        if (stack.isNotEmpty) {
          final lastOpen = stack.removeLast();
          if (bracketPairs[lastOpen.char] == char) {
            nestingMap[i] = stack.length + 1;
          }
        }
      }
    }

    return nestingMap;
  }
}

class _LineToken {
  _LineToken({
    required this.start,
    required this.end,
    required this.type,
    required this.text,
  });

  final int start;
  final int end;
  final SyntaxTokenType type;
  final String text;
}

class _TokenPattern {
  _TokenPattern(
    this.regex,
    this.type, {
    this.captureGroup,
    this.multiline = false,
  });

  final RegExp regex;
  final SyntaxTokenType type;
  final int? captureGroup;
  final bool multiline;
}

class _BracketInfo {
  _BracketInfo({required this.char, required this.pos});

  final String char;
  final int pos;
}

/// A half-open byte range [start, end) within the source code.
class _Range {
  _Range(this.start, this.end);

  final int start;
  final int end;
}

/// A multi-line block span (block comment or docstring) with its absolute
/// start/end offsets in the source code.
class _BlockSpan {
  _BlockSpan(this.start, this.end, this.type);

  final int start;
  final int end;
  final SyntaxTokenType type;
}

/// Represents either a recognised token or a covered (skipped) range when
/// walking through the characters of a single line.
class _LineEvent {
  _LineEvent(this.start, this.end, this.token);

  final int start;
  final int end;

  /// Non-null for a matched token; null for a covered/skipped range.
  final _LineToken? token;
}
