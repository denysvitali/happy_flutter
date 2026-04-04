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
    required this.code,
    super.key,
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
