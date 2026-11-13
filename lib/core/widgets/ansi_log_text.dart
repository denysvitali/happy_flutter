import 'package:flutter/material.dart';

import '../ui/neutralize_inner_scroll.dart';
import '../utils/ansi_span_cache.dart';

/// Selectable monospace log output that renders ANSI SGR colours and styles
/// instead of showing raw escape sequences, and drops every other escape
/// (cursor moves, erase, OSC titles/hyperlinks).
///
/// Parsing goes through [AnsiSpanCache], so polling views that rebuild with
/// unchanged content reuse the previous spans.
///
/// Always placed inside a scroll view: the [SelectableText]'s own phantom
/// scrollable is neutralized so vertical drags reach that scroll view instead
/// of bouncing against nothing (see [NeutralizeInnerScroll]).
class AnsiLogText extends StatelessWidget {
  const AnsiLogText(this.text, {required this.style, super.key});

  /// Raw log text, possibly containing ANSI escape sequences.
  final String text;

  /// Base style for uncoloured text.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return NeutralizeInnerScroll(
      child: SelectableText.rich(
        TextSpan(
          style: style,
          children: AnsiSpanCache.instance.parse(text, defaultStyle: style),
        ),
      ),
    );
  }
}
