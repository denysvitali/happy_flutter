import 'package:flutter/material.dart';

/// Parses ANSI escape sequences in a string and returns [TextSpan]s
/// with appropriate colors and styles.
///
/// Supports SGR (Select Graphic Rendition) sequences:
/// - 0: Reset
/// - 1: Bold
/// - 3: Italic
/// - 4: Underline
/// - 30-37: Standard foreground colors
/// - 40-47: Standard background colors
/// - 90-97: Bright foreground colors
/// - 100-107: Bright background colors
/// - 38;5;N: 256-color foreground
/// - 38;2;R;G;B: RGB foreground
/// - 48;5;N: 256-color background
/// - 48;2;R;G;B: RGB background
class AnsiParser {
  AnsiParser._();

  static final RegExp _ansiRegex = RegExp(
    r'\x1b\[([0-9;]*)m',
  );

  /// Standard ANSI foreground colors (30-37).
  static const List<Color> _fgColors = [
    Color(0xFF000000), // 30: Black
    Color(0xFFCC0000), // 31: Red
    Color(0xFF00CC00), // 32: Green
    Color(0xFFCCCC00), // 33: Yellow
    Color(0xFF0000CC), // 34: Blue
    Color(0xFFCC00CC), // 35: Magenta
    Color(0xFF00CCCC), // 36: Cyan
    Color(0xFFCCCCCC), // 37: White
  ];

  /// Bright ANSI foreground colors (90-97).
  static const List<Color> _brightFgColors = [
    Color(0xFF555555), // 90: Bright Black
    Color(0xFFFF5555), // 91: Bright Red
    Color(0xFF55FF55), // 92: Bright Green
    Color(0xFFFFFF55), // 93: Bright Yellow
    Color(0xFF5555FF), // 94: Bright Blue
    Color(0xFFFF55FF), // 95: Bright Magenta
    Color(0xFF55FFFF), // 96: Bright Cyan
    Color(0xFFFFFFFF), // 97: Bright White
  ];

  /// Parses [text] containing ANSI escape sequences and returns a
  /// [List<TextSpan>] that can be used in a [RichText] or
  /// [SelectableText.rich] widget.
  ///
  /// [defaultStyle] is applied to text without ANSI styling.
  static List<TextSpan> parse(String text, {TextStyle? defaultStyle}) {
    final spans = <TextSpan>[];
    var currentStyle = defaultStyle ?? const TextStyle();
    var bold = false;
    var italic = false;
    var underline = false;
    Color? fgColor;
    Color? bgColor;

    void applyStyle() {
      var style = currentStyle;
      if (bold) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (italic) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (underline) {
        style = style.copyWith(decoration: TextDecoration.underline);
      }
      if (fgColor != null) {
        style = style.copyWith(color: fgColor);
      }
      if (bgColor != null) {
        style = style.copyWith(backgroundColor: bgColor);
      }
      // Re-apply the default style's base properties if not overridden
      if (defaultStyle != null) {
        style = defaultStyle.merge(style);
      }
      currentStyle = style;
    }

    int lastIndex = 0;
    for (final match in _ansiRegex.allMatches(text)) {
      // Add text before this escape sequence.
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: currentStyle,
          ),
        );
      }

      // Parse the SGR parameters.
      final params = match.group(1)!;
      if (params.isEmpty) {
        // \x1b[m is equivalent to \x1b[0m (reset).
        bold = false;
        italic = false;
        underline = false;
        fgColor = null;
        bgColor = null;
        currentStyle = defaultStyle ?? const TextStyle();
      } else {
        final codes = params.split(';').map(int.tryParse).toList();
        var i = 0;
        while (i < codes.length) {
          final code = codes[i];
          if (code == null) {
            i++;
            continue;
          }

          switch (code) {
            case 0: // Reset
              bold = false;
              italic = false;
              underline = false;
              fgColor = null;
              bgColor = null;
              currentStyle = defaultStyle ?? const TextStyle();

            case 1: // Bold
              bold = true;

            case 3: // Italic
              italic = true;

            case 4: // Underline
              underline = true;

            case 22: // Normal intensity (not bold)
              bold = false;

            case 23: // Not italic
              italic = false;

            case 24: // Not underlined
              underline = false;

            case 39: // Default foreground
              fgColor = null;

            case 49: // Default background
              bgColor = null;

            default:
              // Standard foreground colors (30-37).
              if (code >= 30 && code <= 37) {
                fgColor = _fgColors[code - 30];
              }
              // Standard background colors (40-47).
              else if (code >= 40 && code <= 47) {
                bgColor = _fgColors[code - 40];
              }
              // Bright foreground colors (90-97).
              else if (code >= 90 && code <= 97) {
                fgColor = _brightFgColors[code - 90];
              }
              // Bright background colors (100-107).
              else if (code >= 100 && code <= 107) {
                bgColor = _brightFgColors[code - 100];
              }
              // 256-color foreground: 38;5;N
              else if (code == 38 &&
                  i + 1 < codes.length &&
                  codes[i + 1] == 5 &&
                  i + 2 < codes.length &&
                  codes[i + 2] != null) {
                fgColor = _color256(codes[i + 2]!);
                i += 2;
              }
              // RGB foreground: 38;2;R;G;B
              else if (code == 38 &&
                  i + 1 < codes.length &&
                  codes[i + 1] == 2 &&
                  i + 4 < codes.length &&
                  codes[i + 2] != null &&
                  codes[i + 3] != null &&
                  codes[i + 4] != null) {
                fgColor = Color.fromARGB(
                  0xFF,
                  codes[i + 2]!,
                  codes[i + 3]!,
                  codes[i + 4]!,
                );
                i += 4;
              }
              // 256-color background: 48;5;N
              else if (code == 48 &&
                  i + 1 < codes.length &&
                  codes[i + 1] == 5 &&
                  i + 2 < codes.length &&
                  codes[i + 2] != null) {
                bgColor = _color256(codes[i + 2]!);
                i += 2;
              }
              // RGB background: 48;2;R;G;B
              else if (code == 48 &&
                  i + 1 < codes.length &&
                  codes[i + 1] == 2 &&
                  i + 4 < codes.length &&
                  codes[i + 2] != null &&
                  codes[i + 3] != null &&
                  codes[i + 4] != null) {
                bgColor = Color.fromARGB(
                  0xFF,
                  codes[i + 2]!,
                  codes[i + 3]!,
                  codes[i + 4]!,
                );
                i += 4;
              }
          }
          i++;
        }
      }

      applyStyle();
      lastIndex = match.end;
    }

    // Add remaining text after the last escape sequence.
    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: currentStyle,
        ),
      );
    }

    // If no ANSI sequences were found, return the original text.
    if (spans.isEmpty && text.isNotEmpty) {
      spans.add(TextSpan(text: text, style: currentStyle));
    }

    return spans;
  }

  /// Strips all ANSI escape sequences from [text], returning plain text.
  static String strip(String text) {
    return text.replaceAll(_ansiRegex, '');
  }

  /// Converts a 256-color index to a [Color].
  static Color _color256(int index) {
    if (index < 8) {
      return _fgColors[index];
    }
    if (index < 16) {
      return _brightFgColors[index - 8];
    }
    if (index < 232) {
      // 6x6x6 color cube.
      final i = index - 16;
      final r = (i ~/ 36) * 51;
      final g = ((i ~/ 6) % 6) * 51;
      final b = (i % 6) * 51;
      return Color.fromARGB(0xFF, r, g, b);
    }
    // Grayscale ramp.
    final gray = 8 + (index - 232) * 10;
    return Color.fromARGB(0xFF, gray, gray, gray);
  }
}
