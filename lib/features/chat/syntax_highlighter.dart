import 'package:flutter/material.dart';

import '../../core/theme/syntax_theme.dart';
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
/// **Deprecated** — kept as a thin shim that delegates to the
/// [SyntaxTheme] `ThemeExtension`. New code should resolve the theme
/// via `Theme.of(context).extension<SyntaxTheme>()` (or the
/// `context.syntaxTheme` convenience). The class still exposes the
/// original `light` / `dark` map fields and `bracketNestingLight` /
/// `bracketNestingDark` lists so existing in-tree callers compile, but
/// the data is now derived from [SyntaxTheme.light] and [SyntaxTheme.dark].
class SyntaxColors {
  /// Light theme colors (alias of [SyntaxTheme.light] tokens).
  static Map<SyntaxTokenType, Color> get light => _enumMap(SyntaxTheme.light);

  /// Dark theme colors (alias of [SyntaxTheme.dark] tokens).
  static Map<SyntaxTokenType, Color> get dark => _enumMap(SyntaxTheme.dark);

  /// Light rainbow brackets (alias of [SyntaxTheme.light] bracketNesting).
  static List<Color> get bracketNestingLight => SyntaxTheme.light.bracketNesting;

  /// Dark rainbow brackets (alias of [SyntaxTheme.dark] bracketNesting).
  static List<Color> get bracketNestingDark => SyntaxTheme.dark.bracketNesting;

  /// Resolves a token colour from the appropriate [SyntaxTheme] palette.
  ///
  /// Falls back to [SyntaxTheme.defaultText] when the token has no entry
  /// or when the enum value is the unknown-string sentinel `default_`.
  static Color getColor(
    SyntaxTokenType type,
    int nestLevel,
    bool isDarkMode,
  ) {
    final theme = isDarkMode ? SyntaxTheme.dark : SyntaxTheme.light;
    if (type == SyntaxTokenType.bracket) {
      return theme.bracketFor(nestLevel);
    }
    return theme.colorFor(_tokenName(type));
  }

  static String _tokenName(SyntaxTokenType type) {
    final name = type.name;
    // The enum member is `default_` (Dart forbids the bare keyword) but
    // the token key in the map is `default` — strip the trailing
    // underscore to match.
    return name.endsWith('_') ? name.substring(0, name.length - 1) : name;
  }

  static Map<SyntaxTokenType, Color> _enumMap(SyntaxTheme theme) {
    return <SyntaxTokenType, Color>{
      for (final type in SyntaxTokenType.values)
        type: theme.colorFor(_tokenName(type)),
    };
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
  static const int _maxHighlightedCodeUnits = 50000;
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
    if (widget.code.length > _maxHighlightedCodeUnits) {
      return [TextSpan(text: widget.code)];
    }

    // Fast path: empty code skips cache lookup entirely.
    if (widget.code.isEmpty) {
      return const <TextSpan>[];
    }

    // Use global tokenization cache for instant re-renders of identical
    // code. `_tokenCache.get` is cache-first: it only invokes the
    // tokenizer on a cache miss, so repeated identical (code, language)
    // pairs across all SyntaxHighlighter instances return instantly.
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
          // Pinned, not inherited: code is rendered in overlays and routes
          // that may lack a Material ancestor, whose fallback text style
          // carries a yellow double underline.
          decoration: TextDecoration.none,
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
