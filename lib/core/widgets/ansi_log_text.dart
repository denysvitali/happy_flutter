import 'package:flutter/material.dart';

import '../utils/ansi_span_cache.dart';

/// Selectable monospace log output that renders ANSI SGR colours and styles
/// instead of showing raw escape sequences, and drops every other escape
/// (cursor moves, erase, OSC titles/hyperlinks).
///
/// Parsing goes through [AnsiSpanCache], so polling views that rebuild with
/// unchanged content reuse the previous spans.
class AnsiLogText extends StatelessWidget {
  const AnsiLogText(this.text, {required this.style, super.key});

  /// Raw log text, possibly containing ANSI escape sequences.
  final String text;

  /// Base style for uncoloured text.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        style: style,
        children: AnsiSpanCache.instance.parse(text, defaultStyle: style),
      ),
    );
  }
}
