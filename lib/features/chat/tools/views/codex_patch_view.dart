import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import '../../syntax_highlighter.dart';
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
              _FileChangeDetail(
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
    final c = ToolViewColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.chipBg,
        borderRadius: BorderRadius.circular(AppRadius.xxxs),
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

  const _FileChangeDetail({
    required this.changeData,
    required this.filePath,
  });
  final Map<String, dynamic> changeData;
  final String filePath;

  String? _stringifyContent(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is List) {
      final buffer = StringBuffer();
      for (final entry in value) {
        final line = _stringifyContent(entry);
        if (line == null) continue;
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(line);
      }
      return buffer.toString();
    }
    if (value is Map) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }

  String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final value = _stringifyContent(data[key]);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final sections = <Widget>[];
    final language = _languageForPath(filePath);

    void addContentSection(
      String heading,
      String? content,
      Color color,
      String? overrideLanguage,
    ) {
      if (content == null || content.isEmpty) return;
      sections.add(_DetailSection(
        heading: heading,
        content: content,
        color: color,
        language: overrideLanguage ?? language,
      ));
    }

    final addData = changeData['add'] as Map<String, dynamic>?;
    if (addData != null) {
      addContentSection(
        'added',
        _firstString(addData, const ['content', 'after', 'new', 'text']),
        c.green,
        null,
      );
    }

    final modifyData = changeData['modify'] as Map<String, dynamic>?;
    if (modifyData != null) {
      addContentSection(
        'before',
        _firstString(modifyData, const ['before', 'old', 'original']),
        c.red,
        null,
      );
      addContentSection(
        'after',
        _firstString(modifyData, const ['after', 'new', 'content', 'text']),
        c.green,
        null,
      );
      addContentSection(
        'diff',
        _firstString(modifyData, const ['diff', 'patch', 'unified_diff']),
        c.blue,
        'diff',
      );
      addContentSection(
        'modify',
        _firstString(modifyData, const ['content']),
        c.blue,
        null,
      );
    }

    final deleteData = changeData['delete'] as Map<String, dynamic>?;
    if (deleteData != null) {
      addContentSection(
        'removed',
        _firstString(deleteData, const ['content', 'before', 'old', 'text']),
        c.red,
        null,
      );
    }

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
    required this.language,
  });
  final String heading;
  final String content;
  final Color color;
  final String? language;

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
                  borderRadius: BorderRadius.circular(AppRadius.xxs),
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
            child: _ExpandableCodeBlock(
              content: content,
              language: language,
              textColor: c.primaryText,
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

// ---------------------------------------------------------------------------
// Expandable, syntax-highlighted code block
// ---------------------------------------------------------------------------

class _ExpandableCodeBlock extends StatefulWidget {
  const _ExpandableCodeBlock({
    required this.content,
    required this.language,
    required this.textColor,
  });
  final String content;
  final String? language;
  final Color textColor;

  @override
  State<_ExpandableCodeBlock> createState() => _ExpandableCodeBlockState();
}

class _ExpandableCodeBlockState extends State<_ExpandableCodeBlock> {
  static const int _collapsedLines = 18;
  static const double _fontSize = AppFontSize.xs;
  static const double _lineHeight = 1.5;
  bool _expanded = false;

  int get _lineCount => '\n'.allMatches(widget.content).length + 1;

  double get _maxHeight =>
      _collapsedLines * _fontSize * _lineHeight + AppSpacing.sm * 2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsToggle = _lineCount > _collapsedLines;
    final showExpanded = _expanded || !needsToggle;

    final codeText = SyntaxHighlighter(
      code: widget.content,
      language: widget.language,
      isDarkMode: isDark,
      fontSize: _fontSize,
      lineHeight: _fontSize * _lineHeight,
    );

    Widget body;
    if (showExpanded) {
      body = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: codeText,
        ),
      );
    } else {
      body = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          height: _maxHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: codeText,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        if (needsToggle)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                _expanded
                    ? 'Show less'
                    : 'Show all $_lineCount lines',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.xs,
                  color: widget.textColor.withValues(alpha: 0.75),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String? _languageForPath(String path) {
  final idx = path.lastIndexOf('.');
  if (idx == -1 || idx == path.length - 1) return null;
  final ext = path.substring(idx + 1).toLowerCase();
  switch (ext) {
    case 'dart':
    case 'js':
    case 'jsx':
    case 'ts':
    case 'tsx':
    case 'json':
    case 'yml':
    case 'yaml':
    case 'xml':
    case 'html':
    case 'css':
    case 'scss':
    case 'md':
    case 'sh':
    case 'bash':
    case 'zsh':
    case 'py':
    case 'go':
    case 'rs':
    case 'rb':
    case 'java':
    case 'kt':
    case 'kts':
    case 'swift':
    case 'c':
    case 'h':
    case 'cpp':
    case 'hpp':
    case 'gradle':
      return ext == 'yml' ? 'yaml' : ext;
    default:
      return null;
  }
}
