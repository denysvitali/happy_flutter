import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import '../tool_section_view.dart';
import '../tool_view_colors.dart';

/// File change model for CodexPatch results.
class FileChange {

  /// Creates a [FileChange].
  FileChange({
    required this.path,
    required this.hasAdd,
    required this.hasModify,
    required this.hasDelete,
    required this.changeData,
  });
  /// The full file path.
  final String path;

  /// Whether this change includes an add operation.
  final bool hasAdd;

  /// Whether this change includes a modify operation.
  final bool hasModify;

  /// Whether this change includes a delete operation.
  final bool hasDelete;

  /// The raw change data for detailed display.
  final Map<String, dynamic> changeData;

  /// Directory portion of the path.
  String get dir {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '';
  }

  /// Filename portion of the path.
  String get displayName {
    final lastSlash = path.lastIndexOf('/');
    return lastSlash >= 0 ? path.substring(lastSlash + 1) : path;
  }

  /// Human-readable operation label.
  String get operationLabel {
    final ops = <String>[];
    if (hasAdd) ops.add('add');
    if (hasModify) ops.add('modify');
    if (hasDelete) ops.add('delete');
    return ops.join(', ');
  }
}

/// View for displaying CodexPatch tool with file changes summary.
class CodexPatchView extends StatelessWidget {

  const CodexPatchView({
    required this.tool, super.key,
    this.metadata,
  });
  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final changes = input['changes'] as Map<String, dynamic>?;
    final autoApproved = input['auto_approved'] as bool?;

    if (changes == null || changes.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsedChanges = _parseChanges(changes);

    return ToolSectionView(
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _PatchHeaderBar(
              fileCount: parsedChanges.length,
              autoApproved: autoApproved,
            ),
            _PatchFileList(changes: parsedChanges),
          ],
        ),
      ),
    );
  }

  List<FileChange> _parseChanges(Map<String, dynamic> changes) {
    final result = <FileChange>[];
    for (final entry in changes.entries) {
      final path = entry.key;
      final data = entry.value as Map<String, dynamic>? ?? {};
      result.add(FileChange(
        path: path,
        hasAdd: data['add'] != null,
        hasModify: data['modify'] != null,
        hasDelete: data['delete'] != null,
        changeData: data,
      ));
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Header bar
// ---------------------------------------------------------------------------

class _PatchHeaderBar extends StatelessWidget {

  const _PatchHeaderBar({
    required this.fileCount,
    this.autoApproved,
  });
  final int fileCount;
  final bool? autoApproved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = ToolViewColors.of(context);
    final label =
        '$fileCount file${fileCount != 1 ? 's' : ''} changed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.headerBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sm),
          topRight: Radius.circular(AppRadius.sm),
        ),
        border: Border(
          bottom: BorderSide(color: c.border),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note,
            size: 14,
            color: c.mutedText,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: c.mutedText,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (autoApproved ?? false)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: c.greenBadgeBg,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                  color: c.greenBadgeBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 11,
                    color: c.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'auto-approved',
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: c.green,
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
  final Set<int> _expanded = {};

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
    final c = ToolViewColors.of(context);

    final IconData icon;
    final Color iconColor;

    if (change.hasDelete && !change.hasAdd && !change.hasModify) {
      icon = Icons.delete_forever_outlined;
      iconColor = c.red;
    } else if (change.hasAdd && !change.hasModify && !change.hasDelete) {
      icon = Icons.add_circle_outline;
      iconColor = c.green;
    } else {
      icon = Icons.edit_outlined;
      iconColor = c.blue;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Container(
        decoration: BoxDecoration(
          color: c.headerBg,
          borderRadius: BorderRadius.circular(AppRadius.xsm),
          border: Border.all(color: c.border),
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
                    Icon(icon, size: 15, color: iconColor),
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
                                  color: c.mutedText,
                                ),
                              ),
                            TextSpan(
                              text: change.displayName,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: AppFontSize.sm,
                                color: c.primaryText,
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
                      isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 14,
                      color: c.lineNumberText,
                    ),
                  ],
                ),
              ),
            ),
            // Expanded detail
            if (isExpanded)
              _FileChangeDetail(changeData: change.changeData),
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
    final c = ToolViewColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.chipBg,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.chipBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: AppFontSize.xxs,
          color: c.mutedText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable detail panel for a file change
// ---------------------------------------------------------------------------

class _FileChangeDetail extends StatelessWidget {

  const _FileChangeDetail({required this.changeData});
  final Map<String, dynamic> changeData;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final sections = <Widget>[];

    void addSection(
      String heading,
      Map<String, dynamic>? data,
      Color color,
    ) {
      if (data == null) return;
      final content = data['content'] as String?;
      if (content == null || content.isEmpty) return;
      sections.add(
        _DetailSection(
          heading: heading,
          content: content,
          color: color,
        ),
      );
    }

    addSection('add', changeData['add'] as Map<String, dynamic>?,
        c.green);
    addSection('modify', changeData['modify'] as Map<String, dynamic>?,
        c.blue);
    addSection('delete', changeData['delete'] as Map<String, dynamic>?,
        c.red);

    if (sections.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.smd,
        right: AppSpacing.smd,
        bottom: AppSpacing.smd,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: c.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: sections,
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {

  const _DetailSection({
    required this.heading,
    required this.content,
    required this.color,
  });
  final String heading;
  final String content;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                heading,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.xs,
                  color: color,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              _CopyButton(text: content, iconSize: 13),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: c.border),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.xs,
                color: c.primaryText,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Copy button
// ---------------------------------------------------------------------------

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
    final c = ToolViewColors.of(context);

    return GestureDetector(
      onTap: _handleCopy,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _copied ? Icons.check : Icons.copy,
          key: ValueKey(_copied),
          size: widget.iconSize,
          color: _copied ? c.copyIconDone : c.copyIcon,
        ),
      ),
    );
  }
}
