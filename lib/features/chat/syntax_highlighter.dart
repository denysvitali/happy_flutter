import 'package:flutter/material.dart';

import '../../core/utils/syntax_cache.dart';

/// Global tokenization cache shared across all SyntaxHighlighter instances.
final _tokenCache = SyntaxTokenCache.instance;

/// Represents a syntax token with its text, type, and nesting level.
class SyntaxToken {

  const SyntaxToken({
    required this.text,
    required this.type,
    this.nestLevel = 0,
  });
  /// The raw text of this token.
  final String text;

  /// The semantic type of this token.
  final SyntaxTokenType type;

  /// Bracket nesting depth (used for rainbow brackets).
  final int nestLevel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyntaxToken &&
          text == other.text &&
          type == other.type &&
          nestLevel == other.nestLevel;

  @override
  int get hashCode => Object.hash(text, type, nestLevel);
}

/// Types of syntax tokens matching the React Native implementation.
enum SyntaxTokenType {
  keyword,
  controlFlow,
  type,
  modifier,
  string,
  number,
  boolean,
  regex,
  function,
  method,
  property,
  comment,
  docstring,
  operator,
  assignment,
  comparison,
  logical,
  decorator,
  import,
  variable,
  parameter,
  bracket,
  punctuation,
  default_;

  /// Parses a token type from its string name.
  static SyntaxTokenType fromString(String str) {
    return switch (str) {
      'keyword' => keyword,
      'controlFlow' => controlFlow,
      'type' => type,
      'modifier' => modifier,
      'string' => string,
      'number' => number,
      'boolean' => boolean,
      'regex' => regex,
      'function' => function,
      'method' => method,
      'property' => property,
      'comment' => comment,
      'docstring' => docstring,
      'operator' => operator,
      'assignment' => assignment,
      'comparison' => comparison,
      'logical' => logical,
      'decorator' => decorator,
      'import' => import,
      'variable' => variable,
      'parameter' => parameter,
      'bracket' => bracket,
      'punctuation' => punctuation,
      _ => default_,
    };
  }
}

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
    // multiple lines. We record their byte ranges so that per-line tokenization
    // can skip them and we can emit them as single tokens instead.
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
      // blockCovered[i] == true means absolute offset (globalOffset + i) is
      // inside a block span that was already emitted (or will be emitted at
      // its start offset on a previous/same line).
      final lineEnd = globalOffset + line.length;

      // Emit the block-span tokens that START on this line (and may end on a
      // later line).  Track which character ranges in this line are covered.
      final coveredRanges = <_Range>[];
      for (final span in blockSpans) {
        if (span.start >= globalOffset && span.start < lineEnd) {
          // Span starts on this line; emit the full multi-line token now.
          final spanText = code.substring(span.start, span.end);
          tokens.add(SyntaxToken(text: spanText, type: span.type));
          // Mark covered range relative to line start.
          coveredRanges.add(_Range(
            span.start - globalOffset,
            // Clamp to end of this line; the rest is on following lines.
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
      // We walk through the line emitting default-text for gaps, skipping
      // covered ranges, and emitting recognised tokens.
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

  /// Returns a list of [_BlockSpan]s covering block comments and docstrings in
  /// [code].  Spans are sorted by start position and non-overlapping.
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
    // Use the default (language-independent) keyword sets for the cache.
    final keywordSets = _getKeywordSets('');
    return _buildPatternsFromSets(keywordSets);
  }

  static List<_TokenPattern> _getPatterns(
    Map<String, List<String>> keywordSets,
  ) {
    // Return the cached list; the keyword sets are language-independent so
    // the same compiled RegExp objects work for every language.
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
          r'\b(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\d+\.?\d*(?:[eE][+-]?\d+)?)\b',
        ),
        SyntaxTokenType.number,
      ),

      // Decorators / annotations
      _TokenPattern(RegExp(r'@\w+'), SyntaxTokenType.decorator),

      // Keywords by category — must come before function-call patterns so that
      // keywords like 'import', 'return', 'if' are not mis-classified as
      // function calls when followed by '('.
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
        RegExp(r'(function|def|async function)\s+([a-zA-Z_$][a-zA-Z0-9_$]*)'),
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
      // Note: |= uses \| to avoid an empty alternative that would match ''.
      _TokenPattern(
        RegExp(r'(=|\+=|-=|\*=|/=|%=|\|=|&=|\^=)'),
        SyntaxTokenType.assignment,
      ),
      _TokenPattern(RegExp(r'(\+|-|\*|/|%|\*\*)'), SyntaxTokenType.operator),
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

/// Syntax color palettes for light and dark themes.
///
/// Dark theme uses Catppuccin Mocha; light theme mirrors the previous
/// palette which was already well-tuned.
class SyntaxColors {
  /// Light theme colors.
  static const Map<SyntaxTokenType, Color> light = {
    SyntaxTokenType.keyword: Color(0xFF1d4ed8),
    SyntaxTokenType.controlFlow: Color(0xFF6d28d9),
    SyntaxTokenType.type: Color(0xFF0f766e),
    SyntaxTokenType.modifier: Color(0xFF1d4ed8),
    SyntaxTokenType.string: Color(0xFF059669),
    SyntaxTokenType.number: Color(0xFF0891b2),
    SyntaxTokenType.boolean: Color(0xFF0891b2),
    SyntaxTokenType.regex: Color(0xFF059669),
    SyntaxTokenType.function: Color(0xFF7c3aed),
    SyntaxTokenType.method: Color(0xFF9333ea),
    SyntaxTokenType.property: Color(0xFF374151),
    SyntaxTokenType.comment: Color(0xFF6b7280),
    SyntaxTokenType.docstring: Color(0xFF6b7280),
    SyntaxTokenType.operator: Color(0xFF374151),
    SyntaxTokenType.assignment: Color(0xFF1d4ed8),
    SyntaxTokenType.comparison: Color(0xFF1d4ed8),
    SyntaxTokenType.logical: Color(0xFF1d4ed8),
    SyntaxTokenType.decorator: Color(0xFFca8a04),
    SyntaxTokenType.import: Color(0xFF1d4ed8),
    SyntaxTokenType.variable: Color(0xFF374151),
    SyntaxTokenType.parameter: Color(0xFF374151),
    SyntaxTokenType.bracket: Color(0xFF374151),
    SyntaxTokenType.punctuation: Color(0xFF374151),
    SyntaxTokenType.default_: Color(0xFF374151),
  };

  // ---------------------------------------------------------------------------
  // Catppuccin Mocha dark theme
  // https://github.com/catppuccin/catppuccin
  // ---------------------------------------------------------------------------
  // Colour reference:
  //   text     #CDD6F4  subtext0 #A6ADC8  overlay0 #6C7086
  //   red      #F38BA8  peach    #FAB387  yellow   #F9E2AF
  //   green    #A6E3A1  teal     #94E2D5  sky      #89DCEB
  //   sapphire #74C7EC  blue     #89B4FA  lavender #B4BEFE
  //   mauve    #CBA6F7  pink     #F5C2E7  flamingo #F2CDCD
  // ---------------------------------------------------------------------------

  /// Dark theme colors (Catppuccin Mocha).
  static const Map<SyntaxTokenType, Color> dark = {
    // Keywords – blue (VSCode dark+ compatible)
    SyntaxTokenType.keyword: Color(0xFF569CD6),
    // Control flow (if/else/for/return) – mauve/purple
    SyntaxTokenType.controlFlow: Color(0xFFCBA6F7),
    // Types – teal
    SyntaxTokenType.type: Color(0xFF94E2D5),
    // Modifiers (public/static/async) – blue
    SyntaxTokenType.modifier: Color(0xFF89B4FA),
    // Strings – green
    SyntaxTokenType.string: Color(0xFFA6E3A1),
    // Numbers – peach
    SyntaxTokenType.number: Color(0xFFFAB387),
    // Booleans / null – peach
    SyntaxTokenType.boolean: Color(0xFFFAB387),
    // Regex literals – green (like strings)
    SyntaxTokenType.regex: Color(0xFFA6E3A1),
    // Function names – yellow
    SyntaxTokenType.function: Color(0xFFF9E2AF),
    // Method calls – sky
    SyntaxTokenType.method: Color(0xFF89DCEB),
    // Property access – subtext0
    SyntaxTokenType.property: Color(0xFFA6ADC8),
    // Comments – overlay0 (muted)
    SyntaxTokenType.comment: Color(0xFF6C7086),
    // Docstrings – overlay0
    SyntaxTokenType.docstring: Color(0xFF6C7086),
    // Arithmetic operators – text
    SyntaxTokenType.operator: Color(0xFFCDD6F4),
    // Assignment operators – blue
    SyntaxTokenType.assignment: Color(0xFF89B4FA),
    // Comparison operators – sapphire
    SyntaxTokenType.comparison: Color(0xFF74C7EC),
    // Logical operators (&&/||) – mauve
    SyntaxTokenType.logical: Color(0xFFCBA6F7),
    // Decorators / annotations – yellow
    SyntaxTokenType.decorator: Color(0xFFF9E2AF),
    // Import statements – blue
    SyntaxTokenType.import: Color(0xFF89B4FA),
    // Variables – text
    SyntaxTokenType.variable: Color(0xFFCDD6F4),
    // Parameters – text
    SyntaxTokenType.parameter: Color(0xFFCDD6F4),
    // Brackets – handled by nesting colours below
    SyntaxTokenType.bracket: Color(0xFFCDD6F4),
    // Punctuation (.,;) – overlay0
    SyntaxTokenType.punctuation: Color(0xFF6C7086),
    // Default / plain text
    SyntaxTokenType.default_: Color(0xFFCDD6F4),
  };

  // Rainbow bracket colours – light theme
  static const List<Color> bracketNestingLight = [
    Color(0xFF374151), // level 0 (unused sentinel)
    Color(0xFFE05252), // 1 – red
    Color(0xFF00897B), // 2 – teal
    Color(0xFF1976D2), // 3 – blue
    Color(0xFFF57F17), // 4 – amber
    Color(0xFF6A1B9A), // 5 – purple
  ];

  // Rainbow bracket colours – Catppuccin Mocha
  static const List<Color> bracketNestingDark = [
    Color(0xFFCDD6F4), // level 0 (unused sentinel) – text
    Color(0xFFF9E2AF), // 1 – yellow
    Color(0xFFCBA6F7), // 2 – mauve
    Color(0xFF89DCEB), // 3 – sky
    Color(0xFFFAB387), // 4 – peach
    Color(0xFF74C7EC), // 5 – sapphire
  ];

  /// Returns the appropriate color for [type] at [nestLevel].
  static Color getColor(
    SyntaxTokenType type,
    int nestLevel,
    bool isDarkMode,
  ) {
    final colors = isDarkMode ? dark : light;
    final bracketColors =
        isDarkMode ? bracketNestingDark : bracketNestingLight;

    if (type == SyntaxTokenType.bracket) {
      final level = nestLevel % 5;
      return bracketColors[level == 0 ? 5 : level];
    }

    return colors[type] ?? colors[SyntaxTokenType.default_]!;
  }
}

/// Widget that displays syntax-highlighted code using [RichText].
///
/// Tokenization and span building are performed once in [initState] and
/// only recomputed in [didUpdateWidget] when the relevant inputs change,
/// avoiding expensive regex work on every rebuild.
class SyntaxHighlighter extends StatefulWidget {

  const SyntaxHighlighter({
    required this.code, super.key,
    this.language,
    this.isDarkMode = false,
    this.fontSize = 14,
    this.lineHeight = 20,
    this.keywordFontWeight = FontWeight.w600,
  });
  /// Raw source code.
  final String code;

  /// Language identifier (e.g., 'dart', 'python').
  final String? language;

  /// Whether to use the dark colour palette.
  final bool isDarkMode;

  /// Base font size in logical pixels.
  final double fontSize;

  /// Absolute line height in logical pixels.
  final double lineHeight;

  /// Font weight applied to keywords and control-flow tokens.
  final FontWeight? keywordFontWeight;

  @override
  State<SyntaxHighlighter> createState() => _SyntaxHighlighterState();
}

class _SyntaxHighlighterState extends State<SyntaxHighlighter> {
  late List<TextSpan> _textSpans;

  @override
  void initState() {
    super.initState();
    _textSpans = _computeSpans();
  }

  @override
  void didUpdateWidget(SyntaxHighlighter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.language != widget.language ||
        oldWidget.isDarkMode != widget.isDarkMode ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.lineHeight != widget.lineHeight ||
        oldWidget.keywordFontWeight != widget.keywordFontWeight) {
      _textSpans = _computeSpans();
    }
  }

  List<TextSpan> _computeSpans() {
    // Use global tokenization cache for instant re-renders of identical code.
    final tokens = _tokenCache.get(widget.code, widget.language);
    return tokens.map((token) {
      final color = SyntaxColors.getColor(
        token.type,
        token.nestLevel,
        widget.isDarkMode,
      );
      final fontWeight = _getFontWeight(token.type);
      return TextSpan(
        text: token.text,
        style: TextStyle(color: color, fontWeight: fontWeight),
      );
    }).toList();
  }

  FontWeight? _getFontWeight(SyntaxTokenType type) {
    return switch (type) {
      SyntaxTokenType.keyword ||
      SyntaxTokenType.controlFlow ||
      SyntaxTokenType.type ||
      SyntaxTokenType.function =>
        widget.keywordFontWeight,
      _ => FontWeight.w400,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: _textSpans,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: widget.fontSize,
          height: widget.lineHeight / widget.fontSize,
        ),
      ),
    );
  }
}

/// Normalises a language identifier to a canonical name.
///
/// Returns the canonical name if known, otherwise returns [languageHint]
/// as-is (lowercased). Returns `null` when [languageHint] is `null`.
String? detectLanguage(String? languageHint) {
  if (languageHint == null) return null;

  final normalized = languageHint.toLowerCase().trim();

  const languageMap = {
    'js': 'javascript',
    'javascript': 'javascript',
    'jsx': 'javascript',
    'ts': 'typescript',
    'typescript': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'python': 'python',
    'rb': 'ruby',
    'ruby': 'ruby',
    'java': 'java',
    'go': 'go',
    'golang': 'go',
    'rs': 'rust',
    'rust': 'rust',
    'c': 'cpp',
    'cpp': 'cpp',
    'c++': 'cpp',
    'cs': 'csharp',
    'csharp': 'csharp',
    'php': 'php',
    'swift': 'swift',
    'kt': 'kotlin',
    'kotlin': 'kotlin',
    'scala': 'scala',
    'r': 'r',
    'lua': 'lua',
    'perl': 'perl',
    'pl': 'perl',
    'ex': 'elixir',
    'elixir': 'elixir',
    'hs': 'haskell',
    'haskell': 'haskell',
    'ml': 'ocaml',
    'ocaml': 'ocaml',
    'fs': 'fsharp',
    'fsharp': 'fsharp',
    'sh': 'bash',
    'bash': 'bash',
    'shell': 'bash',
    'yml': 'yaml',
    'yaml': 'yaml',
    'json': 'json',
    'xml': 'xml',
    'html': 'html',
    'css': 'css',
    'scss': 'scss',
    'sass': 'scss',
    'sql': 'sql',
    'md': 'markdown',
    'markdown': 'markdown',
    'dockerfile': 'dockerfile',
    'docker': 'dockerfile',
    'dart': 'dart',
    'flutter': 'dart',
  };

  return languageMap[normalized] ?? normalized;
}
