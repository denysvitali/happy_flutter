import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/components/diff_view_widget.dart'
    as dw show DiffView;
import '../tool_section_view.dart';

/// View for displaying MultiEdit tool with multiple diffs.
///
/// Shows a summary header "X edits in filename", then each edit as a
/// numbered, collapsible diff card.
class MultiEditView extends StatelessWidget {

  const MultiEditView({required this.tool, super.key, this.metadata});
  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final filePath = input['path'] as String? ??
        input['file_path'] as String? ??
        '';
    final edits = input['edits'] as List?;

    if (edits == null || edits.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsedEdits = edits
        .map((e) {
          if (e is! Map<String, dynamic>) return null;
          return {
            'old_string': e['old_string'] as String? ?? '',
            'new_string': e['new_string'] as String? ?? '',
            'replace_all': e['replace_all'] as bool? ?? false,
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (parsedEdits.isEmpty) {
      return const SizedBox.shrink();
    }

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Summary header ──────────────────────────────
          _MultiEditHeader(
            editCount: parsedEdits.length,
            filePath: filePath,
          ),
          const SizedBox(height: 8),

          // ── Edit cards ──────────────────────────────────
          ...parsedEdits.asMap().entries.map((entry) {
            final index = entry.key;
            final edit = entry.value;
            return Padding(
              key: Key('edit_$index'),
              padding: const EdgeInsets.only(bottom: 6),
              child: _EditCard(
                number: index + 1,
                oldString: _trimIndent(
                  edit['old_string'] as String? ?? '',
                ),
                newString: _trimIndent(
                  edit['new_string'] as String? ?? '',
                ),
                replaceAll: edit['replace_all'] as bool? ?? false,
              ),
            );
          }),
        ],
      ),
    );
  }

  String _trimIndent(String text) {
    if (text.isEmpty) return '';
    final lines = text.split('\n');
    if (lines.length == 1) return text.trim();

    final minIndent = lines
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.length - line.trimLeft().length)
        .reduce((a, b) => a < b ? a : b);

    return lines.map((line) {
      if (line.trim().isEmpty) return line;
      return line.length > minIndent
          ? line.substring(minIndent)
          : line;
    }).join('\n');
  }
}

/// Summary header showing the total edit count and the target file.
class _MultiEditHeader extends StatelessWidget {

  const _MultiEditHeader({
    required this.editCount,
    required this.filePath,
  });
  final int editCount;
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final lastSlash = filePath.lastIndexOf('/');
    final dir =
        lastSlash >= 0 ? filePath.substring(0, lastSlash + 1) : '';
    final filename = lastSlash >= 0
        ? filePath.substring(lastSlash + 1)
        : filePath;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Edit-count badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            '$editCount ${editCount == 1 ? 'edit' : 'edits'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: AppFontSize.xs,
            ),
          ),
        ),

        if (filePath.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.xsm),
                border: Border.all(
                  color: cs.outlineVariant,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_document,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          if (dir.isNotEmpty)
                            TextSpan(
                              text: dir,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFamily: 'monospace',
                                fontSize: AppFontSize.sm,
                              ),
                            ),
                          TextSpan(
                            text: filename,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                              color: cs.onSurface,
                              fontFamily: 'monospace',
                              fontSize: AppFontSize.sm,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A numbered, collapsible diff card for a single edit.
class _EditCard extends StatefulWidget {

  const _EditCard({
    required this.number,
    required this.oldString,
    required this.newString,
    required this.replaceAll,
  });
  final int number;
  final String oldString;
  final String newString;
  final bool replaceAll;

  @override
  State<_EditCard> createState() => _EditCardState();
}

class _EditCardState extends State<_EditCard> {
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
          // Card header: number + collapse toggle
          InkWell(
            onTap: () =>
                setState(() => _collapsed = !_collapsed),
            child: Container(
              color: cs.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              child: Row(
                children: [
                  // Number chip
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
                        style:
                            theme.textTheme.labelSmall?.copyWith(
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

          // Diff content
          if (!_collapsed)
            dw.DiffView(
              oldText: widget.oldString,
              newText: widget.newString,
              showLineNumbers: true,
              showPlusMinusSymbols: true,
              contextLines: 2,
            ),
        ],
      ),
    );
  }
}
