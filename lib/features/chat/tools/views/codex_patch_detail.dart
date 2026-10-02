import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/tool_view_buttons.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/wire/wire_parsers.dart';

import '../../syntax_highlighter.dart';
import '../json_viewer.dart';

/// Collapsible, syntax-highlighted content for one normalized file change.
class CodexPatchDetail extends StatelessWidget {
  const CodexPatchDetail({
    required this.changeData,
    required this.filePath,
    super.key,
  });
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
    final cs = Theme.of(context).colorScheme;
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
        AppColors.success,
        null,
      );
      addContentSection(
        'patch',
        _firstString(addData, const ['patch', 'diff', 'unified_diff']),
        cs.primary,
        'diff',
      );
    }

    final modifyData = WireParsers.asMap(changeData['modify']);
    if (modifyData != null) {
      addContentSection(
        'before',
        _firstString(modifyData, const [
          'before',
          'old',
          'original',
          'oldText',
          'old_string',
        ]),
        AppColors.error,
        null,
      );
      addContentSection(
        'after',
        _firstString(modifyData, const [
          'after',
          'new',
          'content',
          'text',
          'newText',
          'new_string',
        ]),
        AppColors.success,
        null,
      );
      addContentSection(
        'diff',
        _firstString(modifyData, const ['diff', 'patch', 'unified_diff']),
        cs.primary,
        'diff',
      );
      addContentSection(
        'modify',
        _firstString(modifyData, const ['content']),
        cs.primary,
        null,
      );
    }

    final deleteData = WireParsers.asMap(changeData['delete']);
    if (deleteData != null) {
      addContentSection(
        'removed',
        _firstString(deleteData, const ['content', 'before', 'old', 'text']),
        AppColors.error,
        null,
      );
      addContentSection(
        'patch',
        _firstString(deleteData, const ['patch', 'diff', 'unified_diff']),
        cs.primary,
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
        border: Border(top: BorderSide(color: cs.outlineVariant)),
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
    final cs = Theme.of(context).colorScheme;

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
                  fontSize: AppFontSize.sm,
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
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: _ExpandableCodeBlock(
              content: content,
              language: language,
              textColor: cs.onSurface,
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
  static const double _fontSize = AppFontSize.sm;
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
                  fontSize: AppFontSize.sm,
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
