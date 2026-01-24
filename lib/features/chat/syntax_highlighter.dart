import 'package:flutter/material.dart';

/// Represents a syntax token with its text, type, and nesting level.
class SyntaxToken {
  final String text;
  final SyntaxTokenType type;
  final int nestLevel;

  const SyntaxToken({
    required this.text,
    required this.type,
    this.nestLevel = 0,
  });

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

  static SyntaxTokenType fromString(String type) {
    return switch (type) {
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

  /// Tokenizes the given code string into syntax tokens.
  static List<SyntaxToken> tokenize(String code, String? language) {
    final tokens = <SyntaxToken>[];

    if (language == null) {
      return [SyntaxToken(text: code, type: SyntaxTokenType.default_)];
    }

    final lang = language.toLowerCase();
    final keywordSets = _getKeywordSets(lang);
    final patterns = _getPatterns(keywordSets);
    final nestingMap = _calculateBracketNesting(code);

    // Split code into lines to preserve line breaks
    final lines = code.split('\n');
    int globalOffset = 0;

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];

      if (lineIndex > 0) {
        tokens.add(const SyntaxToken(text: '\n', type: SyntaxTokenType.default_));
        globalOffset += 1;
      }

      final lineTokens = <_LineToken>[];
      for (final pattern in patterns) {
        final matches = pattern.regex.allMatches(line);
        for (final match in matches) {
          final tokenText = pattern.captureGroup != null
              ? match.group(pattern.captureGroup)!
              : match.group(0)!;
          final tokenStart = pattern.captureGroup != null
              ? match.start + match.group(0)!.indexOf(tokenText)
              : match.start;

          lineTokens.add(_LineToken(
            start: tokenStart,
            end: tokenStart + tokenText.length,
            type: pattern.type,
            text: tokenText,
          ));
        }
      }

      // Sort tokens by position and remove overlaps
      lineTokens.sort((a, b) => a.start - b.start);
      final filteredTokens = <_LineToken>[];
      int lastEnd = 0;
      for (final token in lineTokens) {
        if (token.start >= lastEnd) {
          filteredTokens.add(token);
          lastEnd = token.end;
        }
      }

      // Add tokens with proper nesting levels
      int currentIndex = 0;
      for (final token in filteredTokens) {
        // Add text before this token
        if (token.start > currentIndex) {
          final beforeText = line.substring(currentIndex, token.start);
          if (beforeText.isNotEmpty) {
            tokens.add(SyntaxToken(text: beforeText, type: SyntaxTokenType.default_));
          }
        }

        // Add the token with nesting level if it's a bracket
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

        currentIndex = token.end;
      }

      // Add remaining text
      if (currentIndex < line.length) {
        final remainingText = line.substring(currentIndex);
        if (remainingText.isNotEmpty) {
          tokens.add(SyntaxToken(text: remainingText, type: SyntaxTokenType.default_));
        }
      }

      globalOffset += line.length;
    }

    return tokens;
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

  static List<_TokenPattern> _getPatterns(Map<String, List<String>> keywordSets) {
    final controlFlowPattern = keywordSets['controlFlow']!.join('|');
    final keywordsPattern = keywordSets['keywords']!.join('|');
    final typesPattern = keywordSets['types']!.join('|');
    final modifiersPattern = keywordSets['modifiers']!.join('|');
    final booleanPattern = keywordSets['boolean']!.join('|');
    final importsPattern = keywordSets['imports']!.join('|');

    return [
      // Comments (highest priority)
      _TokenPattern(RegExp(r'/\*[\s\S]*?\*/'), SyntaxTokenType.comment),
      _TokenPattern(RegExp(r'//.*$'), SyntaxTokenType.comment, multiline: true),
      _TokenPattern(RegExp(r'#.*$'), SyntaxTokenType.comment, multiline: true),
      _TokenPattern(RegExp(r'"""[\s\S]*?"""'), SyntaxTokenType.docstring),
      _TokenPattern(RegExp(r"'''[\s\S]*?'''"), SyntaxTokenType.docstring),

      // Strings and regex
      _TokenPattern(
        RegExp(r'(r?["\'`])((?:(?!\1)[^\\]|\\.)*)(\1)'),
        SyntaxTokenType.string,
      ),
      _TokenPattern(
        RegExp(r'/(?:[^\/\\\n]|\\.)+/[gimuy]*'),
        SyntaxTokenType.regex,
      ),

      // Numbers (including hex, binary, floats)
      _TokenPattern(
        RegExp(r'\b(0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\d+\.?\d*(?:[eE][+-]?\d+)?)\b'),
        SyntaxTokenType.number,
      ),

      // Decorators
      _TokenPattern(RegExp(r'@\w+'), SyntaxTokenType.decorator),

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

      // Method calls (object.method)
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

      // Keywords by category
      _TokenPattern(RegExp('\\b($importsPattern)\\b'), SyntaxTokenType.import),
      _TokenPattern(RegExp('\\b($controlFlowPattern)\\b'), SyntaxTokenType.controlFlow),
      _TokenPattern(RegExp('\\b($keywordsPattern)\\b'), SyntaxTokenType.keyword),
      _TokenPattern(RegExp('\\b($typesPattern)\\b'), SyntaxTokenType.type),
      _TokenPattern(RegExp('\\b($modifiersPattern)\\b'), SyntaxTokenType.modifier),
      _TokenPattern(RegExp('\\b($booleanPattern)\\b'), SyntaxTokenType.boolean),

      // Operators by category
      _TokenPattern(RegExp(r'(===|!==|==|!=|<=|>=|<|>)'), SyntaxTokenType.comparison),
      _TokenPattern(RegExp(r'(&&|\|\||!)'), SyntaxTokenType.logical),
      _TokenPattern(RegExp(r'(=|\+=|-=|\*=|/=|%=||=|&=|\^=)'), SyntaxTokenType.assignment),
      _TokenPattern(RegExp(r'(\+|-|\*|/|%|\*\*)'), SyntaxTokenType.operator),
      _TokenPattern(RegExp(r'(\?|:)'), SyntaxTokenType.operator),

      // Brackets and punctuation
      _TokenPattern(RegExp(r'([()[\]{}])'), SyntaxTokenType.bracket),
      _TokenPattern(RegExp(r'([.,;])'), SyntaxTokenType.punctuation),
    ];
  }

  /// Calculates bracket nesting levels for each position in the code.
  static Map<int, int> _calculateBracketNesting(String code) {
    final nestingMap = <int, int>{};
    final stack = <_BracketInfo>[];

    for (int i = 0; i < code.length; i++) {
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
  final int start;
  final int end;
  final SyntaxTokenType type;
  final String text;

  _LineToken({
    required this.start,
    required this.end,
    required this.type,
    required this.text,
  });
}

class _TokenPattern {
  final RegExp regex;
  final SyntaxTokenType type;
  final int? captureGroup;
  final bool multiline;

  _TokenPattern(
    this.regex,
    this.type, {
    this.captureGroup,
    this.multiline = false,
  });
}

class _BracketInfo {
  final String char;
  final int pos;

  _BracketInfo({required this.char, required this.pos});
}

/// Gets syntax colors for the given theme mode.
class SyntaxColors {
  /// Light theme colors (matching React Native light theme).
  static const Map<SyntaxTokenType, Color> light = {
    SyntaxTokenType.keyword: Color(0xFF1d4ed8),
    SyntaxTokenType.controlFlow: Color(0xFF1d4ed8),
    SyntaxTokenType.type: Color(0xFF1d4ed8),
    SyntaxTokenType.modifier: Color(0xFF1d4ed8),
    SyntaxTokenType.string: Color(0xFF059669),
    SyntaxTokenType.number: Color(0xFF0891b2),
    SyntaxTokenType.boolean: Color(0xFF0891b2),
    SyntaxTokenType.regex: Color(0xFF059669),
    SyntaxTokenType.function: Color(0xFF9333ea),
    SyntaxTokenType.method: Color(0xFF9333ea),
    SyntaxTokenType.property: Color(0xFF374151),
    SyntaxTokenType.comment: Color(0xFF6b7280),
    SyntaxTokenType.docstring: Color(0xFF6b7280),
    SyntaxTokenType.operator: Color(0xFF374151),
    SyntaxTokenType.assignment: Color(0xFF1d4ed8),
    SyntaxTokenType.comparison: Color(0xFF1d4ed8),
    SyntaxTokenType.logical: Color(0xFF1d4ed8),
    SyntaxTokenType.decorator: Color(0xFF1d4ed8),
    SyntaxTokenType.import: Color(0xFF1d4ed8),
    SyntaxTokenType.variable: Color(0xFF374151),
    SyntaxTokenType.parameter: Color(0xFF374151),
    SyntaxTokenType.bracket: Color(0xFF374151),
    SyntaxTokenType.punctuation: Color(0xFF374151),
    SyntaxTokenType.default_: Color(0xFF374151),
  };

  /// Dark theme colors (matching React Native dark theme).
  static const Map<SyntaxTokenType, Color> dark = {
    SyntaxTokenType.keyword: Color(0xFF569CD6),
    SyntaxTokenType.controlFlow: Color(0xFF569CD6),
    SyntaxTokenType.type: Color(0xFF569CD6),
    SyntaxTokenType.modifier: Color(0xFF569CD6),
    SyntaxTokenType.string: Color(0xFFCE9178),
    SyntaxTokenType.number: Color(0xFFB5CEA8),
    SyntaxTokenType.boolean: Color(0xFFB5CEA8),
    SyntaxTokenType.regex: Color(0xFFCE9178),
    SyntaxTokenType.function: Color(0xFFDCDCAA),
    SyntaxTokenType.method: Color(0xFFDCDCAA),
    SyntaxTokenType.property: Color(0xFFD4D4D4),
    SyntaxTokenType.comment: Color(0xFF6A9955),
    SyntaxTokenType.docstring: Color(0xFF6A9955),
    SyntaxTokenType.operator: Color(0xFFD4D4D4),
    SyntaxTokenType.assignment: Color(0xFF569CD6),
    SyntaxTokenType.comparison: Color(0xFF569CD6),
    SyntaxTokenType.logical: Color(0xFF569CD6),
    SyntaxTokenType.decorator: Color(0xFF569CD6),
    SyntaxTokenType.import: Color(0xFF569CD6),
    SyntaxTokenType.variable: Color(0xFFD4D4D4),
    SyntaxTokenType.parameter: Color(0xFFD4D4D4),
    SyntaxTokenType.bracket: Color(0xFFD4D4D4),
    SyntaxTokenType.punctuation: Color(0xFFD4D4D4),
    SyntaxTokenType.default_: Color(0xFFD4D4D4),
  };

  /// Bracket nesting colors for light theme.
  static const List<Color> bracketNestingLight = [
    Color(0xFF374151), // default (level 0)
    Color(0xFFff6b6b), // bracket1
    Color(0xFF4ecdc4), // bracket2
    Color(0xFF45b7d1), // bracket3
    Color(0xFFf7b731), // bracket4
    Color(0xFF5f27cd), // bracket5
  ];

  /// Bracket nesting colors for dark theme.
  static const List<Color> bracketNestingDark = [
    Color(0xFFD4D4D4), // default (level 0)
    Color(0xFFFFD700), // bracket1
    Color(0xFFDA70D6), // bracket2
    Color(0xFF179FFF), // bracket3
    Color(0xFFFF8C00), // bracket4
    Color(0xFF00FF00), // bracket5
  ];

  /// Gets the appropriate color for a token type.
  static Color getColor(
    SyntaxTokenType type,
    int nestLevel,
    bool isDarkMode,
  ) {
    final colors = isDarkMode ? dark : light;
    final bracketColors = isDarkMode ? bracketNestingDark : bracketNestingLight;

    if (type == SyntaxTokenType.bracket) {
      final level = nestLevel % 5;
      return bracketColors[level == 0 ? 5 : level];
    }

    return colors[type] ?? colors[SyntaxTokenType.default_]!;
  }
}

/// Widget that displays syntax-highlighted code.
class SyntaxHighlighter extends StatelessWidget {
  final String code;
  final String? language;
  final bool isDarkMode;
  final double fontSize;
  final double lineHeight;
  final FontWeight? keywordFontWeight;

  const SyntaxHighlighter({
    super.key,
    required this.code,
    this.language,
    this.isDarkMode = false,
    this.fontSize = 14,
    this.lineHeight = 20,
    this.keywordFontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = SyntaxTokenizer.tokenize(code, language);
    final textSpans = _buildTextSpans(tokens);

    return RichText(
      text: TextSpan(
        children: textSpans,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          height: lineHeight / fontSize,
        ),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(List<SyntaxToken> tokens) {
    return tokens.map((token) {
      final color = SyntaxColors.getColor(
        token.type,
        token.nestLevel,
        isDarkMode,
      );
      final fontWeight = _getFontWeight(token.type);

      return TextSpan(
        text: token.text,
        style: TextStyle(
          color: color,
          fontWeight: fontWeight,
        ),
      );
    }).toList();
  }

  FontWeight? _getFontWeight(SyntaxTokenType type) {
    return switch (type) {
      SyntaxTokenType.keyword ||
      SyntaxTokenType.controlFlow ||
      SyntaxTokenType.type ||
      SyntaxTokenType.function =>
        keywordFontWeight,
      _ => FontWeight.w400,
    };
  }
}

/// Detects the programming language from a code block.
String? detectLanguage(String? languageHint) {
  if (languageHint == null) {
    return null;
  }

  final normalized = languageHint.toLowerCase().trim();

  // Map common language names
  return switch (normalized) {
    'js' | 'javascript' | 'jsx' => 'javascript',
    'ts' | 'typescript' | 'tsx' => 'typescript',
    'py' | 'python' => 'python',
    'rb' | 'ruby' => 'ruby',
    'java' => 'java',
    'go' | 'golang' => 'go',
    'rs' | 'rust' => 'rust',
    'c' | 'cpp' | 'c++' => 'cpp',
    'cs' | 'csharp' => 'csharp',
    'php' => 'php',
    'swift' => 'swift',
    'kt' | 'kotlin' => 'kotlin',
    'scala' => 'scala',
    'r' => 'r',
    'lua' => 'lua',
    'perl' | 'pl' => 'perl',
    'ex' | 'elixir' => 'elixir',
    'hs' | 'haskell' => 'haskell',
    'ml' | 'ocaml' => 'ocaml',
    'fs' | 'fsharp' => 'fsharp',
    'sh' | 'bash' | 'shell' => 'bash',
    'yml' | 'yaml' => 'yaml',
    'json' => 'json',
    'xml' => 'xml',
    'html' => 'html',
    'css' => 'css',
    'scss' | 'sass' => 'scss',
    'sql' => 'sql',
    'md' | 'markdown' => 'markdown',
    'dockerfile' | 'docker' => 'dockerfile',
    _ => normalized,
  };
}
