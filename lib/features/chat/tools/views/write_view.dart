import 'package:flutter/material.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
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
        WireParsers.asMap(widget.tool['input']) ?? {};
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
          const SizedBox(height: AppSpacing.xs),

          // ── File info chip: lines + size ───────────────────
          _WriteInfoChip(
            lineCount: allLines.length,
            byteCount: content.length,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Content section label + preview ───────────────
          _WriteSectionLabel(label: context.l10n.toolSectionContent),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: cs.outlineVariant,
                width: AppBorder.hairline,
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
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xsm,
                  ),
                  color: cs.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Icon(
                        Icons.code,
                        size: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xsm),
                      Text(
                        _languageHint(filePath),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: AppFontSize.xs,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${allLines.length} lines',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: AppFontSize.xs,
                        ),
                      ),
                    ],
                  ),
                ),

                // Code content
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(AppSpacing.sm),
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
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        border: Border(
                          top: BorderSide(
                            color: cs.outlineVariant,
                            width: AppBorder.hairline,
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
                          const SizedBox(width: AppSpacing.xs),
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

/// Small muted chip showing line count and approximate file size.
class _WriteInfoChip extends StatelessWidget {
  const _WriteInfoChip({
    required this.lineCount,
    required this.byteCount,
  });

  final int lineCount;
  final int byteCount;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)}KB';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _InfoPill(
          icon: Icons.format_list_numbered,
          label: '$lineCount line${lineCount != 1 ? 's' : ''}',
          colorScheme: cs,
        ),
        const SizedBox(width: AppSpacing.xs),
        _InfoPill(
          icon: Icons.data_usage,
          label: _formatSize(byteCount),
          colorScheme: cs,
        ),
      ],
    );
  }
}

/// A small muted info pill with an icon and label.
class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xsm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: AppBorder.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.xxs,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
        _CreatedBadge(),
        const SizedBox(width: AppSpacing.sm),

        // File path pill
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xsm,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.xsm),
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
                const SizedBox(width: AppSpacing.xsm),
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
                              fontSize: AppFontSize.sm,
                            ),
                          ),
                        TextSpan(
                          text: filename,
                          style:
                              theme.textTheme.bodySmall?.copyWith(
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
    );
  }
}

/// Animated green "Created" badge with a checkmark.
class _CreatedBadge extends StatefulWidget {
  const _CreatedBadge();

  @override
  State<_CreatedBadge> createState() => _CreatedBadgeState();
}

class _CreatedBadgeState extends State<_CreatedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  static const _green = Color(0xFF1A7F37);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDuration.normal,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: AppCurve.spring,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xsm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.xs),
          border: Border.all(
            color: _green.withValues(alpha: 0.4),
            width: AppBorder.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 12,
              color: _green,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Created',
              style: theme.textTheme.labelSmall?.copyWith(
                color: _green,
                fontWeight: FontWeight.w600,
                fontSize: AppFontSize.xs,
              ),
            ),
          ],
        ),
      ),
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
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(
                '${startLine + i}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.sm,
                  height: AppLineHeight.relaxed,
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
                fontSize: AppFontSize.sm,
                height: AppLineHeight.relaxed,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
