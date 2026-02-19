import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// View for displaying Write tool content.
///
/// Shows the file path prominently with a "Created" badge, then a
/// preview of the first 10 lines with a "Show full content" toggle
/// for longer files.
class WriteView extends StatefulWidget {

  const WriteView({required this.tool, super.key, this.metadata});
  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  @override
  State<WriteView> createState() => _WriteViewState();
}

class _WriteViewState extends State<WriteView> {
  static const int _previewLineCount = 10;

  bool _showFull = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final filePath = input['path'] as String? ??
        input['file_path'] as String? ??
        '';
    final content = input['content'] as String? ?? '';

    final allLines = content.split('\n');
    final isLong = allLines.length > _previewLineCount;
    final visibleLines =
        _showFull ? allLines : allLines.take(_previewLineCount).toList();

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Created badge + original path header ──────────
          _WritePathHeader(filePath: filePath),
          const SizedBox(height: 8),

          // ── Content section label + preview ───────────────
          _WriteSectionLabel(label: 'CONTENT'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: cs.outlineVariant,
                width: 0.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: cs.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Icon(
                        Icons.code,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _languageHint(filePath),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${allLines.length} lines',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Code content
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: _LineNumberedCode(
                    lines: visibleLines,
                    startLine: 1,
                    theme: theme,
                  ),
                ),

                // Show full / collapse toggle
                if (isLong)
                  InkWell(
                    onTap: () =>
                        setState(() => _showFull = !_showFull),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        border: Border(
                          top: BorderSide(
                            color: cs.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showFull
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showFull
                                ? 'Show less'
                                : 'Show full content'
                                    ' (${allLines.length - _previewLineCount}'
                                    ' more lines)',
                            style:
                                theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a simple language hint derived from the file extension.
  String _languageHint(String path) {
    if (path.isEmpty) return 'text';
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'dart': 'Dart',
      'ts': 'TypeScript',
      'tsx': 'TypeScript',
      'js': 'JavaScript',
      'jsx': 'JavaScript',
      'py': 'Python',
      'kt': 'Kotlin',
      'swift': 'Swift',
      'json': 'JSON',
      'yaml': 'YAML',
      'yml': 'YAML',
      'md': 'Markdown',
      'sh': 'Shell',
      'html': 'HTML',
      'css': 'CSS',
    };
    return map[ext] ?? ext;
  }
}

/// Small all-caps section label for write view content blocks.
class _WriteSectionLabel extends StatelessWidget {
  const _WriteSectionLabel({required this.label});

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

/// File path header with a green "Created" badge.
class _WritePathHeader extends StatelessWidget {

  const _WritePathHeader({required this.filePath});
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
        // Created badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1A7F37).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: const Color(0xFF1A7F37).withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_circle_outline,
                size: 12,
                color: Color(0xFF1A7F37),
              ),
              const SizedBox(width: 4),
              Text(
                'Created',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF1A7F37),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // File path pill
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: cs.outlineVariant, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
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
                            style:
                                theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        TextSpan(
                          text: filename,
                          style:
                              theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface,
                            fontFamily: 'monospace',
                            fontSize: 12,
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
    );
  }
}

/// Renders code lines with line numbers.
class _LineNumberedCode extends StatelessWidget {

  const _LineNumberedCode({
    required this.lines,
    required this.startLine,
    required this.theme,
  });
  final List<String> lines;
  final int startLine;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Line numbers column
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(lines.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${startLine + i}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            );
          }),
        ),
        // Code column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((line) {
            return Text(
              line.isEmpty ? ' ' : line,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface,
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
