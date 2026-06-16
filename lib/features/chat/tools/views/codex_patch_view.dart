import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
import '../../syntax_highlighter.dart';
import '../json_viewer.dart';
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
  const CodexPatchView({required this.tool, super.key, this.metadata});

  /// The tool data map containing input and result.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final rawInput = tool['input'];
    final input = WireParsers.asMap(rawInput) ?? {};
    final changes = input['changes'];
    final patch = _extractPatchText(rawInput);
    final autoApproved = input['auto_approved'] as bool?;

    final parsedChanges = _parseChanges(changes);

    if (parsedChanges.isEmpty && patch == null) {
      return const SizedBox.shrink();
    }

    final fileChanges = parsedChanges.isNotEmpty
        ? parsedChanges
        : _parsePatch(patch!);

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
              fileCount: fileChanges.length,
              autoApproved: autoApproved,
            ),
            _PatchFileList(changes: fileChanges),
          ],
        ),
      ),
    );
  }

  List<FileChange> _parseChanges(dynamic changes) {
    final list = WireParsers.asList(changes);
    if (list != null) return _parseChangeList(list);

    final map = WireParsers.asMap(changes);
    if (map == null || map.isEmpty) return const [];

    final result = <FileChange>[];
    if (_pathFromChangeData(map) != null) {
      final change = _fileChangeFromData(map);
      if (change != null) result.add(change);
      return result;
    }

    for (final entry in map.entries) {
      final path = entry.key;
      final data = WireParsers.asMap(entry.value) ?? {};
      final normalizedKind = _normalizedKind(data);
      final changeData = _normalizedChangeData(data, normalizedKind);
      result.add(
        FileChange(
          path: path,
          hasAdd: changeData['add'] != null,
          hasModify: changeData['modify'] != null,
          hasDelete: changeData['delete'] != null,
          changeData: changeData,
        ),
      );
    }
    return result;
  }

  List<FileChange> _parseChangeList(List<dynamic> changes) {
    final result = <FileChange>[];
    for (final item in changes) {
      final data = WireParsers.asMap(item);
      if (data == null) continue;
      final change = _fileChangeFromData(data);
      if (change != null) result.add(change);
    }
    return result;
  }

  FileChange? _fileChangeFromData(Map<String, dynamic> data) {
    final path = _pathFromChangeData(data);
    if (path == null || path.isEmpty) return null;

    final normalizedKind = _normalizedKind(data);
    final changeData = _normalizedChangeData(data, normalizedKind);
    return FileChange(
      path: path,
      hasAdd: changeData['add'] != null,
      hasModify: changeData['modify'] != null,
      hasDelete: changeData['delete'] != null,
      changeData: changeData,
    );
  }

  String? _pathFromChangeData(Map<String, dynamic> data) {
    for (final key in const [
      'path',
      'file',
      'filePath',
      'file_path',
      'filename',
      'name',
    ]) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _normalizedKind(Map<String, dynamic> data) {
    final rawKind =
        data['kind'] ??
        data['operation'] ??
        data['op'] ??
        data['action'] ??
        data['type'];
    final kind = rawKind is String ? rawKind.toLowerCase() : null;
    return switch (kind) {
      'create' || 'created' || 'add' || 'added' => 'add',
      'update' ||
      'updated' ||
      'modify' ||
      'modified' ||
      'edit' ||
      'edited' => 'modify',
      'delete' || 'deleted' || 'remove' || 'removed' => 'delete',
      _ => null,
    };
  }

  Map<String, dynamic> _normalizedChangeData(
    Map<String, dynamic> data,
    String? normalizedKind,
  ) {
    final changeData = <String, dynamic>{};
    for (final op in const ['add', 'modify', 'delete']) {
      final opValue = data[op];
      if (opValue == null) continue;
      final opMap = WireParsers.asMap(opValue);
      changeData[op] = opMap ?? {'content': opValue.toString()};
    }

    if (changeData.isNotEmpty) return changeData;

    final kind = normalizedKind ?? _inferKindFromFields(data);
    if (kind == null) return data;

    final details = <String, dynamic>{...data}
      ..remove('path')
      ..remove('file')
      ..remove('filePath')
      ..remove('file_path')
      ..remove('filename')
      ..remove('name')
      ..remove('kind')
      ..remove('operation')
      ..remove('op')
      ..remove('action')
      ..remove('type');
    return {kind: details};
  }

  String? _inferKindFromFields(Map<String, dynamic> data) {
    if (data.containsKey('before') ||
        data.containsKey('old') ||
        data.containsKey('original') ||
        data.containsKey('diff') ||
        data.containsKey('patch') ||
        data.containsKey('unified_diff')) {
      return 'modify';
    }
    if (data.containsKey('after') ||
        data.containsKey('new') ||
        data.containsKey('content') ||
        data.containsKey('text')) {
      return 'add';
    }
    return null;
  }

  String? _extractPatchText(dynamic input) {
    if (input is String && input.contains('*** Begin Patch')) return input;
    final inputMap = WireParsers.asMap(input);
    if (inputMap == null) return null;
    for (final key in const ['patch', 'input', 'content']) {
      final value = inputMap[key];
      if (value is String && value.contains('*** Begin Patch')) return value;
    }
    return _findPatchText(inputMap);
  }

  String? _findPatchText(dynamic value) {
    if (value is String && value.contains('*** Begin Patch')) return value;
    final map = WireParsers.asMap(value);
    if (map != null) {
      for (final entry in map.values) {
        final patch = _findPatchText(entry);
        if (patch != null) return patch;
      }
      return null;
    }
    final list = WireParsers.asList(value);
    if (list != null) {
      for (final item in list) {
        final patch = _findPatchText(item);
        if (patch != null) return patch;
      }
    }
    return null;
  }

  List<FileChange> _parsePatch(String patch) {
    final result = <FileChange>[];
    String? currentPath;
    String? currentKind;
    final buffer = StringBuffer();

    void flush() {
      if (currentPath == null || currentKind == null) return;
      final patchText = buffer.toString().trimRight();
      final changeData = <String, dynamic>{
        currentKind: {'patch': patchText},
      };
      result.add(
        FileChange(
          path: currentPath,
          hasAdd: currentKind == 'add',
          hasModify: currentKind == 'modify',
          hasDelete: currentKind == 'delete',
          changeData: changeData,
        ),
      );
    }

    for (final line in patch.split('\n')) {
      String? nextPath;
      String? nextKind;
      if (line.startsWith('*** Add File: ')) {
        nextPath = line.substring('*** Add File: '.length);
        nextKind = 'add';
      } else if (line.startsWith('*** Update File: ')) {
        nextPath = line.substring('*** Update File: '.length);
        nextKind = 'modify';
      } else if (line.startsWith('*** Delete File: ')) {
        nextPath = line.substring('*** Delete File: '.length);
        nextKind = 'delete';
      }

      if (nextPath != null && nextKind != null) {
        flush();
        currentPath = nextPath;
        currentKind = nextKind;
        buffer
          ..clear()
          ..writeln(line);
        continue;
      }

      if (currentPath != null &&
          !line.startsWith('*** Begin Patch') &&
          !line.startsWith('*** End Patch')) {
        buffer.writeln(line);
      }
    }
    flush();

    if (result.isNotEmpty) return result;

    return [
      FileChange(
        path: 'patch',
        hasAdd: false,
        hasModify: true,
        hasDelete: false,
        changeData: {
          'modify': {'patch': patch},
        },
      ),
    ];
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
    final c = ToolViewColors.of(context);
    final label = '$fileCount file${fileCount != 1 ? 's' : ''} changed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.headerBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sm),
          topRight: Radius.circular(AppRadius.sm),
        ),
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note, size: 14, color: c.mutedText),
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
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: c.greenBadgeBg,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: c.greenBadgeBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 11, color: c.green),
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
                      isExpanded ? Icons.expand_less : Icons.expand_more,
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
  const _FileChangeDetail({required this.changeData, required this.filePath});
  final Map<String, dynamic> changeData;
  final String filePath;

  String? _stringifyContent(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is List) {
      final buffer = StringBuffer();
      for (final entry in value) {
        final line = _stringifyContent(entry);
        if (line == null) continue;
        if (buffer.isNotEmpty) buffer.write('\n');
        buffer.write(line);
      }
      return buffer.isEmpty ? null : buffer.toString();
    }
    if (value is Map) {
      // Structured change envelopes from providers (Codex, Gemini) sometimes
      // nest the actual diff text inside an extra Map. Walk the structure
      // and prefer a string leaf that looks like a diff/patch.
      final stringLeaf = _firstStringLeaf(value);
      if (stringLeaf != null) return stringLeaf;
      return null;
    }
    return value.toString();
  }

  /// Returns the first string leaf in [value] that looks like patch content,
  /// or the first string leaf of any kind, or null. Used to avoid rendering
  /// raw JSON for nested structured change envelopes.
  String? _firstStringLeaf(dynamic value) {
    if (value is String) return value.isEmpty ? null : value;
    if (value is List) {
      for (final item in value) {
        final leaf = _firstStringLeaf(item);
        if (leaf != null) return leaf;
      }
      return null;
    }
    if (value is Map) {
      const diffKeys = [
        'patch',
        'diff',
        'unified_diff',
        'content',
        'text',
        'after',
        'new',
        'before',
        'old',
        'original',
        'body',
        'input',
      ];
      for (final key in diffKeys) {
        if (!value.containsKey(key)) continue;
        final leaf = _firstStringLeaf(value[key]);
        if (leaf != null) return leaf;
      }
      for (final entry in value.values) {
        final leaf = _firstStringLeaf(entry);
        if (leaf != null) return leaf;
      }
    }
    return null;
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
      sections.add(
        _DetailSection(
          heading: heading,
          content: content,
          color: color,
          language: overrideLanguage ?? language,
        ),
      );
    }

    final addData = WireParsers.asMap(changeData['add']);
    if (addData != null) {
      addContentSection(
        'added',
        _firstString(addData, const ['content', 'after', 'new', 'text']),
        c.green,
        null,
      );
      addContentSection(
        'patch',
        _firstString(addData, const ['patch', 'diff', 'unified_diff']),
        c.blue,
        'diff',
      );
    }

    final modifyData = WireParsers.asMap(changeData['modify']);
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

    final deleteData = WireParsers.asMap(changeData['delete']);
    if (deleteData != null) {
      addContentSection(
        'removed',
        _firstString(deleteData, const ['content', 'before', 'old', 'text']),
        c.red,
        null,
      );
      addContentSection(
        'patch',
        _firstString(deleteData, const ['patch', 'diff', 'unified_diff']),
        c.blue,
        'diff',
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
        border: Border(top: BorderSide(color: c.border)),
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
              ToolViewCopyButton(text: content, iconSize: 13),
            ],
          ),
          const SizedBox(height: AppSpacing.xsm),
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
  static const double _expandedMaxHeight = 420;
  bool _expanded = false;
  late int _lineCount;

  @override
  void initState() {
    super.initState();
    _lineCount = '\n'.allMatches(widget.content).length + 1;
  }

  @override
  void didUpdateWidget(_ExpandableCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _lineCount = '\n'.allMatches(widget.content).length + 1;
    }
  }

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

    final body = ToolOutputScrollFrame(
      maxHeight: showExpanded ? _expandedMaxHeight : _maxHeight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: codeText,
      ),
    );

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
                _expanded ? 'Show less' : 'Show all $_lineCount lines',
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
