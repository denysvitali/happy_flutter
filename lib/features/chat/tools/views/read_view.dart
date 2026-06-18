import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/components/app_badge.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/theme/file_type_colors.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
import 'package:happy_flutter/features/chat/syntax_highlighter.dart';

import '../tool_section_view.dart';
import '_section_label.dart';
import 'bash_view.dart' show FilePillChip;

/// View for displaying Read tool file content preview.
class ReadView extends StatelessWidget {
  const ReadView({
    required this.tool,
    super.key,
    this.metadata,
    this.sessionId,
  });

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  /// Session ID for file viewer navigation.
  final String? sessionId;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    // Handle both file_path and locations (Gemini format)
    String? filePath;
    if (input['file_path'] != null) {
      filePath = input['file_path'] as String?;
    } else if (input['locations'] != null &&
        input['locations'] is List &&
        (input['locations'] as List).isNotEmpty) {
      filePath = input['locations'][0]['path'] as String?;
    }

    final resolvedPath = filePath != null
        ? resolvePath(filePath, metadata)
        : 'Unknown';
    final limit = input['limit'] as int?;
    final offset = input['offset'] as int?;

    // Parse result content
    String? content;
    int? totalLines;
    if (result != null) {
      if (result is String) {
        content = result;
        totalLines = content.split('\n').length;
      } else if (result is Map<String, dynamic>) {
        content =
            result['content'] as String? ??
            result['text'] as String? ??
            result['body'] as String?;
        totalLines =
            result['totalLines'] as int? ??
            result['numLines'] as int? ??
            (content?.split('\n').length ?? 0);
      }
    }

    final extension = filePath != null ? getFileExtension(filePath) : '';

    return ToolSectionView(
      child: _ReadViewContent(
        resolvedPath: resolvedPath,
        extension: extension,
        limit: limit,
        offset: offset,
        totalLines: totalLines,
        content: state == 'completed' ? content : null,
        sessionId: sessionId,
        machineId: metadata?['machineId'] as String?,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stateful inner widget
// ---------------------------------------------------------------------------

class _ReadViewContent extends StatefulWidget {
  const _ReadViewContent({
    required this.resolvedPath,
    required this.extension,
    this.limit,
    this.offset,
    this.totalLines,
    this.content,
    this.sessionId,
    this.machineId,
  });
  final String resolvedPath;
  final String extension;
  final int? limit;
  final int? offset;
  final int? totalLines;
  final String? content;
  final String? sessionId;
  final String? machineId;

  @override
  State<_ReadViewContent> createState() => _ReadViewContentState();
}

class _ReadViewContentState extends State<_ReadViewContent> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = widget.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // File path as pill chip (tappable to open file viewer)
        FilePillChip(
          path: widget.resolvedPath,
          onTap: widget.sessionId != null
              ? () => context.pushNamed(
                  'session-file',
                  pathParameters: {'sessionId': widget.sessionId!},
                  extra: {'path': widget.resolvedPath},
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.xsm),
        // Styled header (file icon + path + copy button + extension badge)
        _FileHeader(
          resolvedPath: widget.resolvedPath,
          extension: widget.extension,
          content: content,
        ),
        // Metadata row: line range / limit / total
        if (widget.offset != null ||
            widget.limit != null ||
            widget.totalLines != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xsm),
            child: _MetaRow(
              offset: widget.offset,
              limit: widget.limit,
              totalLines: widget.totalLines,
            ),
          ),
        // Content section label + scrollable content block
        if (content != null && content.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SectionLabel(label: context.l10n.toolSectionContent),
          const SizedBox(height: AppSpacing.xs),
          _ContentBlock(
            content: content,
            offset: widget.offset,
            extension: widget.extension,
          ),
        ],
        if (content == null && widget.totalLines != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xsm),
            child: Text(
              'Reading file...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _FileHeader extends StatelessWidget {
  const _FileHeader({
    required this.resolvedPath,
    required this.extension,
    this.content,
  });
  final String resolvedPath;
  final String extension;
  final String? content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar: file icon + path + copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smd,
              vertical: AppSpacing.xsm,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.sm),
                topRight: Radius.circular(AppRadius.sm),
              ),
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Row(
              children: [
                _FileIcon(extension: extension),
                const SizedBox(width: AppSpacing.xsm),
                Expanded(
                  child: Text(
                    resolvedPath,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.sm,
                      color: cs.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (content != null)
                  ToolViewCopyButton(text: content!, iconSize: 13),
              ],
            ),
          ),
          // Extension / type label row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smd,
              vertical: AppSpacing.xxs2,
            ),
            child: Row(
              children: [
                Text(
                  'read',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                    letterSpacing: 0.4,
                  ),
                ),
                if (extension.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.xsm),
                  AppBadge(
                    label: extension.replaceFirst('.', ''),
                    backgroundColor: cs.surfaceContainerHigh,
                    borderColor: cs.outlineVariant,
                    foregroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs2,
                      vertical: 1,
                    ),
                    labelStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.xxs,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.extension});
  final String extension;

  @override
  Widget build(BuildContext context) {
    return Icon(
      FileTypeColors.iconForExtension(extension),
      size: AppIconSize.sm,
      color: FileTypeColors.colorForExtension(extension),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({this.offset, this.limit, this.totalLines});
  final int? offset;
  final int? limit;
  final int? totalLines;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    // Build a combined "Lines X-Y of Z" label when possible
    if (offset != null && limit != null && totalLines != null) {
      final from = offset! + 1;
      final to = (offset! + limit!).clamp(0, totalLines!);
      chips.add(_MetaChip('Lines $from\u2013$to of $totalLines'));
    } else {
      if (offset != null) {
        chips.add(_MetaChip('From line ${offset! + 1}'));
      }
      if (limit != null) {
        if (chips.isNotEmpty) {
          chips.add(const SizedBox(width: AppSpacing.xsm));
        }
        chips.add(_MetaChip('Limit: $limit'));
      }
      if (totalLines != null) {
        if (chips.isNotEmpty) {
          chips.add(const SizedBox(width: AppSpacing.xsm));
        }
        chips.add(_MetaChip('$totalLines lines'));
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: chips);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBadge(
      label: label,
      backgroundColor: cs.surfaceContainerHigh,
      borderColor: cs.outlineVariant,
      foregroundColor: cs.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs2,
        vertical: AppSpacing.xs - 1,
      ),
      labelStyle: const TextStyle(
        fontSize: AppFontSize.xs,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
      ),
    );
  }
}

class _ContentBlock extends StatefulWidget {
  const _ContentBlock({
    required this.content,
    required this.offset,
    required this.extension,
  });
  final String content;
  final int? offset;
  final String extension;

  @override
  State<_ContentBlock> createState() => _ContentBlockState();
}

class _ContentBlockState extends State<_ContentBlock> {
  // Explicit, non-primary controller — same pattern as ToolOutputScrollFrame.
  // Keeps this inline pane independent of the ambient PrimaryScrollController
  // (which the chat list shares), so dragging here scrolls the pane instead of
  // bouncing back, and the offset survives streaming rebuilds.
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final lines = widget.content.split('\n');
    final startLine = (widget.offset ?? 0) + 1;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: cs.outlineVariant),
      ),
      // Bounded scrollable viewport. Long files render in a fixed-height
      // pane (instead of growing the chat row), and the user can drag/scroll
      // within the pane to reach lines past the viewport.
      //
      // Vertical scroll only. We deliberately do not wrap in a horizontal
      // scroll view: the line-numbers + code layout uses `Expanded` to
      // share the row width, and a horizontal SingleChildScrollView would
      // hand the inner Row unbounded width and trip RenderFlex. Long lines
      // wrap to the available width instead of forcing sideways scrolling.
      //
      // `SizedBox(height:)` (not `ConstrainedBox(maxHeight:)`) is required
      // so the viewport reports a bounded intrinsic height up the tree.
      // A SCV's intrinsic size equals its child's intrinsic size — so a
      // ConstrainedBox that only sets maxHeight would still let the parent
      // Column grow to the child's natural height, blowing past the bound.
      child: SizedBox(
        height: _kContentMaxHeight,
        child: Scrollbar(
          controller: _controller,
          child: SingleChildScrollView(
            controller: _controller,
            primary: false,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.smd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Line numbers column
                  _LineNumbers(count: lines.length, startLine: startLine),
                  const SizedBox(width: AppSpacing.md),
                  // Content column with syntax highlighting
                  Expanded(
                    child: SyntaxHighlighter(
                      code: widget.content,
                      language: widget.extension.isNotEmpty
                          ? widget.extension.replaceFirst('.', '')
                          : null,
                      isDarkMode: isDarkMode,
                      fontSize: AppFontSize.sm,
                      lineHeight: AppLineHeight.relaxed * AppFontSize.sm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Maximum height of the inline Read content pane. Bounds the chat row
/// for large files — the user scrolls within the pane to see the rest.
const double _kContentMaxHeight = 400;

class _LineNumbers extends StatelessWidget {
  const _LineNumbers({required this.count, required this.startLine});
  final int count;
  final int startLine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      if (i > 0) buffer.write('\n');
      buffer.write(startLine + i);
    }

    return SelectableText(
      buffer.toString(),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: AppFontSize.sm,
        color: cs.onSurfaceVariant,
        height: AppLineHeight.relaxed,
      ),
      textAlign: TextAlign.right,
    );
  }
}
