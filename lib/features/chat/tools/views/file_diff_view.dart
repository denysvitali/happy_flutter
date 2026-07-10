import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/ui/diff/calculate_diff.dart';
import 'package:happy_flutter/core/ui/diff/unified_diff_view.dart';

/// Shared chrome for diff-rendering tool views.
///
/// Displays a rounded card with a file-path header, +/- line counts, an
/// optional copy button, and an expand/collapse toggle for large diffs. The
/// body is rendered by the canonical [UnifiedDiffView].
class FileDiffView extends StatefulWidget {
  /// Creates a [FileDiffView].
  const FileDiffView({
    required this.oldText,
    required this.newText,
    super.key,
    this.filePath,
    this.rawCopyText,
    this.onPathTap,
    this.icon,
    this.collapseThreshold = 16,
    this.contextLines = 3,
  });

  /// Old/original text.
  final String oldText;

  /// New/modified text.
  final String newText;

  /// Optional file path shown in the header.
  final String? filePath;

  /// Optional text copied by the header copy button.
  final String? rawCopyText;

  /// Called when the user taps the file path in the header.
  final VoidCallback? onPathTap;

  /// Optional leading icon in the header.
  final IconData? icon;

  /// Number of lines (old + new) below which the diff is shown inline.
  final int collapseThreshold;

  /// Number of context lines around each hunk.
  final int contextLines;

  @override
  State<FileDiffView> createState() => _FileDiffViewState();
}

class _FileDiffViewState extends State<FileDiffView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final oldLines = widget.oldText.isEmpty
        ? 0
        : widget.oldText.split('\n').length;
    final newLines = widget.newText.isEmpty
        ? 0
        : widget.newText.split('\n').length;
    final totalLines = oldLines + newLines;
    // Badges show changed-line counts (GitHub +/- convention), not the
    // total size of the old/new texts.
    final stats = calculateUnifiedDiff(widget.oldText, widget.newText).stats;
    final removedCount = widget.oldText.isEmpty ? 0 : stats.deletions;
    final addedCount = widget.newText.isEmpty ? 0 : stats.additions;
    final isShort = totalLines <= widget.collapseThreshold;
    final show = isShort || _expanded;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _FileDiffHeader(
            filePath: widget.filePath,
            oldCount: removedCount,
            newCount: addedCount,
            icon: widget.icon,
            copyText: widget.rawCopyText,
            onPathTap: widget.onPathTap,
          ),
          if (!isShort)
            _FileDiffExpandToggle(
              expanded: _expanded,
              totalLines: totalLines,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
          if (show)
            _FileDiffBody(
              oldText: widget.oldText,
              newText: widget.newText,
              contextLines: widget.contextLines,
            ),
        ],
      ),
    );
  }
}

/// A numbered, collapsible diff card for multi-edit tools.
class FileDiffCard extends StatefulWidget {
  /// Creates a [FileDiffCard].
  const FileDiffCard({
    required this.number,
    required this.oldText,
    required this.newText,
    super.key,
    this.replaceAll = false,
    this.contextLines = 2,
  });

  /// Edit number shown in the header chip.
  final int number;

  /// Old/original text.
  final String oldText;

  /// New/modified text.
  final String newText;

  /// Whether this edit replaces all occurrences.
  final bool replaceAll;

  /// Number of context lines around each hunk.
  final int contextLines;

  @override
  State<FileDiffCard> createState() => _FileDiffCardState();
}

class _FileDiffCardState extends State<FileDiffCard> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: cs.outlineVariant,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _collapsed = !_collapsed),
            child: Container(
              color: cs.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${widget.number}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: AppFontSize.xs,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit ${widget.number}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.replaceAll) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        'replace all',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onTertiaryContainer,
                          fontSize: AppFontSize.xxs,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _collapsed
                        ? Icons.expand_more
                        : Icons.expand_less,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (!_collapsed)
            _FileDiffBody(
              oldText: widget.oldText,
              newText: widget.newText,
              contextLines: widget.contextLines,
            ),
        ],
      ),
    );
  }
}

/// Header bar showing the file path, line-count badges, and copy button.
class _FileDiffHeader extends StatelessWidget {
  const _FileDiffHeader({
    required this.oldCount,
    required this.newCount,
    this.filePath,
    this.icon,
    this.copyText,
    this.onPathTap,
  });

  final String? filePath;
  final int oldCount;
  final int newCount;
  final IconData? icon;
  final String? copyText;
  final VoidCallback? onPathTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final path = filePath ?? '';
    final lastSlash = path.lastIndexOf('/');
    final dir = lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '';
    final filename = lastSlash >= 0 ? path.substring(lastSlash + 1) : path;

    final pathWidget = path.isEmpty
        ? Text(
            'diff',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          )
        : RichText(
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                if (dir.isNotEmpty)
                  TextSpan(
                    text: dir,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.sm,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                TextSpan(
                  text: filename,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.sm,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
          if (icon != null) ...[
            Icon(icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: onPathTap != null
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPathTap,
                    child: pathWidget,
                  )
                : pathWidget,
          ),
          if (oldCount > 0 || newCount > 0) ...[
            if (oldCount > 0) ...[
              _LineCountBadge(count: oldCount, isAddition: false),
              if (newCount > 0) const SizedBox(width: 6),
            ],
            if (newCount > 0)
              _LineCountBadge(count: newCount, isAddition: true),
            if (copyText != null) const SizedBox(width: 8),
          ],
          if (copyText != null)
            ToolViewCopyButton(text: copyText!, iconSize: 14),
        ],
      ),
    );
  }
}

class _LineCountBadge extends StatelessWidget {
  const _LineCountBadge({required this.count, required this.isAddition});

  final int count;
  final bool isAddition;

  @override
  Widget build(BuildContext context) {
    return Text(
      isAddition ? '+$count' : '-$count',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: AppFontSize.sm,
        color: isAddition ? AppColors.success : AppColors.error,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Full-width expand/collapse toggle row.
class _FileDiffExpandToggle extends StatelessWidget {
  const _FileDiffExpandToggle({
    required this.expanded,
    required this.totalLines,
    required this.onToggle,
  });

  final bool expanded;
  final int totalLines;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onToggle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 14,
              color: cs.primary,
            ),
            const SizedBox(width: 4),
            Text(
              expanded
                  ? 'Hide diff'
                  : 'Show diff ($totalLines lines)',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: cs.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Body that renders the canonical diff view.
class _FileDiffBody extends StatelessWidget {
  const _FileDiffBody({
    required this.oldText,
    required this.newText,
    required this.contextLines,
  });

  final String oldText;
  final String newText;
  final int contextLines;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppRadius.sm),
        bottomRight: Radius.circular(AppRadius.sm),
      ),
      child: UnifiedDiffView(
        oldText: oldText,
        newText: newText,
        contextLines: contextLines,
        showLineNumbers: true,
        showPlusMinusSymbols: true,
      ),
    );
  }
}
