import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';

import '../tool_section_view.dart';
import 'file_diff_view.dart';

/// View for displaying MultiEdit tool with multiple diffs.
///
/// Shows a summary header "X edits in filename", then each edit as a
/// numbered, collapsible diff card.
class MultiEditView extends StatelessWidget {
  /// Creates a [MultiEditView].
  const MultiEditView({required this.tool, super.key, this.metadata});

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(tool['input']) ?? {};
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
          _MultiEditHeader(
            editCount: parsedEdits.length,
            filePath: filePath,
          ),
          const SizedBox(height: 8),
          ...parsedEdits.asMap().entries.map((entry) {
            final index = entry.key;
            final edit = entry.value;
            return Padding(
              key: Key('edit_$index'),
              padding: const EdgeInsets.only(bottom: AppSpacing.xsm),
              child: FileDiffCard(
                number: index + 1,
                oldText: _trimIndent(
                  edit['old_string'] as String? ?? '',
                ),
                newText: _trimIndent(
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
