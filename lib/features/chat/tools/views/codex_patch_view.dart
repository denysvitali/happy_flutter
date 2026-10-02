import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

import '../tool_section_view.dart';
import '../tool_view_widgets.dart';
import 'codex_patch_data.dart';
import 'codex_patch_detail.dart';

export 'codex_patch_data.dart' show FileChange;

/// View for displaying CodexPatch tool with file changes summary.
class CodexPatchView extends StatelessWidget {
  const CodexPatchView({required this.tool, super.key, this.metadata});

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final patch = CodexPatchData.fromTool(tool);
    if (patch.fileChanges.isEmpty) return const SizedBox.shrink();

    return ToolSectionView(
      child: Container(
        decoration: toolCardDecoration(cs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PatchHeaderBar(
              fileCount: patch.fileChanges.length,
              autoApproved: patch.autoApproved,
            ),
            _PatchFileList(changes: patch.fileChanges),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header bar
// ---------------------------------------------------------------------------

class _PatchHeaderBar extends StatelessWidget {
  const _PatchHeaderBar({required this.fileCount, this.autoApproved});
  final int fileCount;
  final bool? autoApproved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final label = '$fileCount file${fileCount != 1 ? 's' : ''} changed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: toolCardHeaderDecoration(cs),
      child: Row(
        children: [
          Icon(Icons.edit_note, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (autoApproved ?? false)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: AppOpacity.subtle),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: AppColors.success),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: AppIconSize.xs,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'auto-approved',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// File list
// ---------------------------------------------------------------------------

class _PatchFileList extends StatefulWidget {
  const _PatchFileList({required this.changes});
  final List<FileChange> changes;

  @override
  State<_PatchFileList> createState() => _PatchFileListState();
}

class _PatchFileListState extends State<_PatchFileList> {
  late final Set<int> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {for (var i = 0; i < widget.changes.length; i++) i};
  }

  @override
  void didUpdateWidget(_PatchFileList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _expanded.removeWhere((idx) => idx >= widget.changes.length);
    for (var i = oldWidget.changes.length; i < widget.changes.length; i++) {
      _expanded.add(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: widget.changes.asMap().entries.map((entry) {
          final idx = entry.key;
          final change = entry.value;
          final isExpanded = _expanded.contains(idx);
          return _FileChangeRow(
            change: change,
            isExpanded: isExpanded,
            onToggle: () => setState(() {
              if (isExpanded) {
                _expanded.remove(idx);
              } else {
                _expanded.add(idx);
              }
            }),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single file row (collapsible)
// ---------------------------------------------------------------------------

class _FileChangeRow extends StatelessWidget {
  const _FileChangeRow({
    required this.change,
    required this.isExpanded,
    required this.onToggle,
  });
  final FileChange change;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final IconData icon;
    final Color iconColor;

    if (change.hasDelete && !change.hasAdd && !change.hasModify) {
      icon = Icons.delete_forever_outlined;
      iconColor = AppColors.error;
    } else if (change.hasAdd && !change.hasModify && !change.hasDelete) {
      icon = Icons.add_circle_outline;
      iconColor = AppColors.success;
    } else {
      icon = Icons.edit_outlined;
      iconColor = cs.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.xsm),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row header
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppRadius.xsm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: AppIconSize.md, color: iconColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            if (change.dir.isNotEmpty)
                              TextSpan(
                                text: change.dir,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: AppFontSize.sm,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            TextSpan(
                              text: change.displayName,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: AppFontSize.sm,
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _OperationChip(label: change.operationLabel),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            // Expanded detail
            if (isExpanded)
              CodexPatchDetail(
                changeData: change.changeData,
                filePath: change.path,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Operation chip
// ---------------------------------------------------------------------------

class _OperationChip extends StatelessWidget {
  const _OperationChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.xxxs),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: AppFontSize.sm,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
