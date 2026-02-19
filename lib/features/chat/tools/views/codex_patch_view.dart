import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tool_section_view.dart';

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
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF30363D)),
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
    final label =
        '$fileCount file${fileCount != 1 ? 's' : ''} changed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFF30363D)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.edit_note,
            size: 14,
            color: Color(0xFF8B949E),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF8B949E),
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
                color: const Color(0xFF0D2818),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF1A4328),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.check_circle_outline,
                    size: 11,
                    color: Color(0xFF3FB950),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'auto-approved',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF3FB950),
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
      padding: const EdgeInsets.all(8),
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
    final IconData icon;
    final Color iconColor;

    if (change.hasDelete && !change.hasAdd && !change.hasModify) {
      icon = Icons.delete_forever_outlined;
      iconColor = const Color(0xFFF85149);
    } else if (change.hasAdd && !change.hasModify && !change.hasDelete) {
      icon = Icons.add_circle_outline;
      iconColor = const Color(0xFF3FB950);
    } else {
      icon = Icons.edit_outlined;
      iconColor = const Color(0xFF58A6FF);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row header
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(6),
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
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Color(0xFF8B949E),
                                ),
                              ),
                            TextSpan(
                              text: change.displayName,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: Color(0xFFE6EDF3),
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
                      color: const Color(0xFF484F58),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: Color(0xFF8B949E),
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

    addSection(
      'add',
      changeData['add'] as Map<String, dynamic>?,
      const Color(0xFF3FB950),
    );
    addSection(
      'modify',
      changeData['modify'] as Map<String, dynamic>?,
      const Color(0xFF58A6FF),
    );
    addSection(
      'delete',
      changeData['delete'] as Map<String, dynamic>?,
      const Color(0xFFF85149),
    );

    if (sections.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF30363D)),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
                  fontSize: 11,
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: SelectableText(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Color(0xFFE6EDF3),
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
