import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/utils.dart' show prettyJson;
import '../json_syntax.dart' show JsonSyntaxColors, buildJsonSpans;
import '../json_viewer.dart' show ToolOutputScrollFrame;
import '../tool_view_helpers.dart';
import '../tool_view_widgets.dart';

/// Boxed result pane for an MCP tool call that answered with text content.
///
/// MCP servers overwhelmingly answer with a single-line JSON blob. Rendered
/// verbatim that is one very long line in a horizontally scrolling frame — the
/// user sees the first ~45 characters and no hint that anything follows. This
/// view pretty-prints parseable JSON so the payload becomes short, readable
/// lines, caps the collapsed height in *lines* (not pixels, so the cut never
/// lands mid-glyph), and puts the copy affordance in a proper title bar
/// instead of a bare floating icon above the box.
class McpResultView extends StatefulWidget {
  const McpResultView({
    required this.text,
    super.key,
    this.collapsedMaxLines = 14,
    this.expandedMaxHeight = 360,
  });

  /// The raw text content returned by the MCP tool.
  final String text;

  /// Number of lines shown before the "Show more" row appears.
  final int collapsedMaxLines;

  /// Height cap once expanded; the pane scrolls internally beyond this.
  final double expandedMaxHeight;

  @override
  State<McpResultView> createState() => _McpResultViewState();
}

class _McpResultViewState extends State<McpResultView> {
  bool _expanded = false;

  /// Pretty-printed payload plus whether it was recognised as JSON.
  late _McpPayload _payload;

  @override
  void initState() {
    super.initState();
    _payload = _McpPayload.parse(widget.text);
  }

  @override
  void didUpdateWidget(McpResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _payload = _McpPayload.parse(widget.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final lines = _payload.lines;
    final needsTruncation = lines.length > widget.collapsedMaxLines;
    final visibleText = needsTruncation && !_expanded
        ? lines.take(widget.collapsedMaxLines).join('\n')
        : _payload.text;

    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Courier'],
      fontSize: AppFontSize.sm,
      color: cs.onSurface,
      height: AppLineHeight.relaxed,
    );

    final body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      child: ToolOutputScrollFrame(
        maxHeight: _expanded ? widget.expandedMaxHeight : null,
        // Keys, strings, numbers and booleans each get their own color when
        // the payload is JSON; anything else stays plain monospace.
        child: _payload.isJson
            ? SelectableText.rich(
                TextSpan(
                  style: baseStyle,
                  children: buildJsonSpans(
                    visibleText,
                    JsonSyntaxColors.of(theme.brightness, cs.onSurface),
                  ),
                ),
              )
            : SelectableText(visibleText, style: baseStyle),
      ),
    );

    return Container(
      decoration: toolCardDecoration(cs),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _McpResultTitleBar(label: _payload.label, copyText: _payload.text),
          body,
          if (needsTruncation)
            ToolViewShowMoreButton(
              expanded: _expanded,
              hiddenCount: lines.length - widget.collapsedMaxLines,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
        ],
      ),
    );
  }
}

/// Title bar for [McpResultView] — payload label on the left, copy on the
/// right, matching the chrome shared by the bash / read / diff result cards.
class _McpResultTitleBar extends StatelessWidget {
  const _McpResultTitleBar({required this.label, required this.copyText});

  final String label;
  final String copyText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: toolCardHeaderDecoration(cs),
      padding: const EdgeInsets.only(left: AppSpacing.smd),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFontSize.xs,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          // Padded tap target — the bare 14 px icon this replaces was well
          // under the 44 px minimum and easy to miss on a phone.
          Semantics(
            button: true,
            label: 'Copy output',
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.smd,
                vertical: AppSpacing.sm,
              ),
              child: ToolViewCopyButton(text: copyText, iconSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Display form of an MCP text payload: pretty-printed when it is JSON, with
/// a short label describing what the pane holds.
class _McpPayload {
  const _McpPayload({
    required this.text,
    required this.lines,
    required this.label,
    required this.isJson,
  });

  factory _McpPayload.parse(String raw) {
    final decoded = tryDecodeJsonCollection(raw);
    final pretty = decoded != null ? prettyJson(decoded) : raw.trimRight();
    final lines = pretty.isEmpty ? const <String>[] : pretty.split('\n');
    final kind = decoded != null ? 'JSON' : 'OUTPUT';
    final count = lines.length;
    return _McpPayload(
      text: pretty,
      lines: lines,
      label: '$kind · $count line${count == 1 ? '' : 's'}',
      isJson: decoded != null,
    );
  }

  final String text;
  final List<String> lines;
  final String label;

  /// Whether the payload parsed as JSON, and so may be syntax-highlighted.
  final bool isJson;
}
