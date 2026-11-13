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
///
/// Every other escape sequence (cursor movement and erase CSI sequences such
/// as `ESC[K`, OSC titles and hyperlinks, charset selection such as `ESC(B`)
/// is consumed without output, so it never shows up as raw text.
class AnsiParser {
  AnsiParser._();

  /// Matches one escape sequence. Group 1 holds CSI parameter bytes, group 2
  /// intermediate bytes and group 3 the CSI final byte; the group is null for
  /// non-CSI sequences. Order matters: CSI and OSC are tried before the
  /// single-character fallbacks.
  static final RegExp _ansiRegex = RegExp(
    r'\x1b(?:'
    r'\[([0-?]*)([ -/]*)([@-~])' // CSI
    // OSC (titles, hyperlinks) and DCS/SOS/PM/APC strings. An unterminated
    // one ends at the line break so a truncated log cannot swallow the rest.
    r'|\][^\x07\x1b\n]*(?:\x07|\x1b\\)?'
    r'|[PX^_][^\x1b\n]*(?:\x1b\\)?'
    r'|[ -/]+[0-~]' // nF: charset designation like ESC(B
    r'|[0-~]' // Fp/Fe/Fs single-character escapes
    r')?',
  );

  static final RegExp _sgrParams = RegExp(r'^[0-9;]*$');

  /// Returns the SGR parameter string of [match], or null when [match] is
  /// some other escape sequence that only needs to be dropped.
  static String? _sgrParamsOf(RegExpMatch match) {
    if (match.group(3) != 'm' || match.group(2)!.isNotEmpty) return null;
    final params = match.group(1)!;
    return _sgrParams.hasMatch(params) ? params : null;
  }

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
    final baseStyle = defaultStyle ?? const TextStyle();
    var currentStyle = baseStyle;
    var bold = false;
    var italic = false;
    var underline = false;
    Color? fgColor;
    Color? bgColor;

    void applyStyle() {
      // Rebuild from the base so attribute resets (22, 23, 24, 39, 49)
      // actually remove what an earlier code added.
      var style = baseStyle;
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
      currentStyle = style;
    }

    var lastIndex = 0;
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

      lastIndex = match.end;

      // Parse the SGR parameters; other sequences are simply dropped.
      final params = _sgrParamsOf(match);
      if (params == null) continue;
      if (params.isEmpty) {
        // \x1b[m is equivalent to \x1b[0m (reset).
        bold = false;
        italic = false;
        underline = false;
        fgColor = null;
        bgColor = null;
        currentStyle = baseStyle;
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
              currentStyle = baseStyle;

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
    }

    // Add remaining text after the last escape sequence.
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: currentStyle));
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
