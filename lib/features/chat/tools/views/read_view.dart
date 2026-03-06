import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

import '../tool_section_view.dart';
import 'bash_view.dart' show FilePillChip;

/// View for displaying Read tool file content preview.
class ReadView extends StatelessWidget {

  const ReadView({required this.tool, super.key, this.metadata});
  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
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
        content = result['content'] as String? ??
            result['text'] as String? ??
            result['body'] as String?;
        totalLines = result['totalLines'] as int? ??
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
  });
  final String resolvedPath;
  final String extension;
  final int? limit;
  final int? offset;
  final int? totalLines;
  final String? content;

  @override
  State<_ReadViewContent> createState() => _ReadViewContentState();
}

class _ReadViewContentState extends State<_ReadViewContent> {
  static const int _defaultMaxLines = 20;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = widget.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // File path as pill chip
        FilePillChip(path: widget.resolvedPath),
        const SizedBox(height: AppSpacing.sm - 2),
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
            padding: const EdgeInsets.only(top: AppSpacing.sm - 2),
            child: _MetaRow(
              offset: widget.offset,
              limit: widget.limit,
              totalLines: widget.totalLines,
            ),
          ),
        // Content section label + preview
        if (content != null && content.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ReadSectionLabel(label: context.l10n.toolSectionContent),
          const SizedBox(height: AppSpacing.xs),
          _ContentBlock(
            content: content,
            offset: widget.offset,
            expanded: _expanded,
            maxLines: _defaultMaxLines,
            onToggleExpand: () =>
                setState(() => _expanded = !_expanded),
          ),
        ],
        if (content == null && widget.totalLines != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm - 2),
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

/// Small section label for read view blocks.
class _ReadSectionLabel extends StatelessWidget {
  const _ReadSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        letterSpacing: 0.8,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Courier New', 'Courier'],
      ),
    );
  }
}

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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar: file icon + path + copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.sm - 2,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.sm),
                topRight: Radius.circular(AppRadius.sm),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF30363D)),
              ),
            ),
            child: Row(
              children: [
                _FileIcon(extension: extension),
                const SizedBox(width: AppSpacing.sm - 2),
                Expanded(
                  child: Text(
                    resolvedPath,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFE6EDF3),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (content != null)
                  _CopyButton(text: content!, iconSize: 13),
              ],
            ),
          ),
          // Extension / type label row
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.xs + 1,
            ),
            child: Row(
              children: [
                Text(
                  'read',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF8B949E),
                    fontFamily: 'monospace',
                    letterSpacing: 0.4,
                  ),
                ),
                if (extension.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm - 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs + 1,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(AppRadius.xs - 1),
                      border: Border.all(color: const Color(0xFF374151)),
                    ),
                    child: Text(
                      extension.replaceFirst('.', ''),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Color(0xFF60A5FA),
                        fontWeight: FontWeight.w500,
                      ),
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
      _iconForExtension(extension),
      size: 14,
      color: _colorForExtension(extension),
    );
  }

  IconData _iconForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.dart':
      case '.js':
      case '.ts':
      case '.jsx':
      case '.tsx':
      case '.py':
      case '.rb':
      case '.go':
      case '.rs':
      case '.java':
      case '.kt':
      case '.swift':
      case '.cpp':
      case '.c':
      case '.h':
        return Icons.code;
      case '.json':
      case '.yaml':
      case '.yml':
      case '.toml':
      case '.xml':
        return Icons.data_object;
      case '.md':
      case '.txt':
      case '.rst':
        return Icons.article_outlined;
      case '.html':
      case '.css':
      case '.scss':
        return Icons.web;
      case '.sh':
      case '.bash':
      case '.zsh':
        return Icons.terminal;
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.svg':
      case '.gif':
        return Icons.image_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  Color _colorForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.dart':
        return const Color(0xFF54C5F8);
      case '.js':
      case '.jsx':
        return const Color(0xFFF7DF1E);
      case '.ts':
      case '.tsx':
        return const Color(0xFF3178C6);
      case '.py':
        return const Color(0xFF3572A5);
      case '.go':
        return const Color(0xFF00ADD8);
      case '.rs':
        return const Color(0xFFDEA584);
      case '.md':
        return const Color(0xFF8B949E);
      case '.json':
      case '.yaml':
      case '.yml':
        return const Color(0xFF85E89D);
      case '.sh':
      case '.bash':
      case '.zsh':
        return const Color(0xFF3FB950);
      default:
        return const Color(0xFF8B949E);
    }
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
          chips.add(const SizedBox(width: AppSpacing.sm - 2));
        }
        chips.add(_MetaChip('Limit: $limit'));
      }
      if (totalLines != null) {
        if (chips.isNotEmpty) {
          chips.add(const SizedBox(width: AppSpacing.sm - 2));
        }
        chips.add(_MetaChip('$totalLines lines'));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chips,
    );
  }
}

class _MetaChip extends StatelessWidget {

  const _MetaChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm - 1,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: const Color(0xFF374151)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF8B949E),
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _ContentBlock extends StatelessWidget {

  const _ContentBlock({
    required this.content,
    required this.offset,
    required this.expanded,
    required this.maxLines,
    required this.onToggleExpand,
  });
  final String content;
  final int? offset;
  final bool expanded;
  final int maxLines;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final totalLines = lines.length;
    final needsTruncation = totalLines > maxLines;
    final visibleLines = expanded || !needsTruncation
        ? lines
        : lines.take(maxLines).toList();
    final startLine = (offset ?? 0) + 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Content with line numbers
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line numbers column
                _LineNumbers(
                  count: visibleLines.length,
                  startLine: startLine,
                ),
                const SizedBox(width: AppSpacing.md),
                // Content column
                Expanded(
                  child: SelectableText(
                    visibleLines.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFFE6EDF3),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Show more / less button
          if (needsTruncation)
            _ShowMoreButton(
              expanded: expanded,
              hiddenCount: totalLines - maxLines,
              onToggle: onToggleExpand,
            ),
        ],
      ),
    );
  }
}

class _LineNumbers extends StatelessWidget {

  const _LineNumbers({required this.count, required this.startLine});
  final int count;
  final int startLine;

  @override
  Widget build(BuildContext context) {
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      if (i > 0) buffer.write('\n');
      buffer.write(startLine + i);
    }

    return SelectableText(
      buffer.toString(),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: Color(0xFF484F58),
        height: 1.5,
      ),
      textAlign: TextAlign.right,
    );
  }
}

class _ShowMoreButton extends StatelessWidget {

  const _ShowMoreButton({
    required this.expanded,
    required this.hiddenCount,
    required this.onToggle,
  });
  final bool expanded;
  final int hiddenCount;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF30363D))),
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(AppRadius.sm),
            bottomRight: Radius.circular(AppRadius.sm),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: const Color(0xFF8B949E),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              expanded
                  ? 'Show less'
                  : 'Show $hiddenCount more line'
                      '${hiddenCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8B949E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {

  const _CopyButton({required this.text, this.iconSize = 14});
  final String text;
  final double iconSize;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _copied ? Icons.check : Icons.copy,
          key: ValueKey(_copied),
          size: widget.iconSize,
          color: _copied
              ? const Color(0xFF3FB950)
              : const Color(0xFF8B949E),
        ),
      ),
    );
  }
}
