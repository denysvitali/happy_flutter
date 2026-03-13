import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import '../tool_section_view.dart';

/// Match item model for Grep results.
class GrepMatch {
  /// Constructs a [GrepMatch].
  GrepMatch({
    required this.file,
    required this.lineNumber,
    required this.content,
    this.startIndex,
    this.endIndex,
  });

  /// The file containing the match.
  final String file;

  /// The line number of the match.
  final int lineNumber;

  /// The content of the matching line.
  final String content;

  /// Optional start index of the match within content.
  final int? startIndex;

  /// Optional end index of the match within content.
  final int? endIndex;

  /// Returns the display file name (basename only).
  String get displayFile => file.split('/').lastOrNull ?? file;
}

/// View for displaying Grep tool results.
class GrepView extends StatefulWidget {
  /// Constructs a [GrepView].
  const GrepView({required this.tool, super.key, this.metadata});

  /// The tool invocation data.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  State<GrepView> createState() => _GrepViewState();
}

class _GrepViewState extends State<GrepView> {
  static const int _initialLimit = 20;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final result = widget.tool['result'];

    final pattern = input['pattern'] as String? ?? '';
    final path = input['path'] as String?;
    final outputMode = input['output_mode'] as String?;
    final showLineNumbers = input['-n'] as bool? ?? false;

    final isContentMode = outputMode == 'content';
    final isCountMode = outputMode == 'count';
    final matches = _parseMatches(result, isContentMode);

    // Group matches by file for content mode
    final groupedMatches = _groupByFile(matches);

    final cs = Theme.of(context).colorScheme;

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: pattern badge + path chip
          Row(
            children: [
              _GrepPatternBadge(pattern: pattern),
              if (path != null && path.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xsm),
                _GrepPathChip(path: path),
              ],
            ],
          ),

          // Count mode
          if (isCountMode && result != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.smd),
              child: _buildCountResult(context, result),
            ),

          // Content mode — grouped by file
          if (isContentMode && matches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.smd),
              child: _MatchCountBadge(
                count: matches.length,
                colorScheme: cs,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _GroupedMatchList(
                groupedMatches: groupedMatches,
                pattern: pattern,
                showLineNumbers: showLineNumbers,
                totalMatches: matches.length,
                initialLimit: _initialLimit,
                showAll: _showAll,
                onToggleShowAll: () =>
                    setState(() => _showAll = !_showAll),
              ),
            ),
          ],

          // Files-with-matches mode
          if (!isContentMode && !isCountMode && result != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.smd),
              child: _buildFilesList(context, result),
            ),
        ],
      ),
    );
  }

  Map<String, List<GrepMatch>> _groupByFile(List<GrepMatch> matches) {
    final grouped = <String, List<GrepMatch>>{};
    for (final m in matches) {
      grouped.putIfAbsent(m.file, () => []).add(m);
    }
    return grouped;
  }

  List<GrepMatch> _parseMatches(dynamic result, bool isContentMode) {
    if (result == null) return [];
    if (result is List) {
      return result
          .map((item) {
            if (item is Map<String, dynamic>) {
              return GrepMatch(
                file: item['path'] as String? ??
                    item['file'] as String? ??
                    '',
                lineNumber: item['lineNumber'] as int? ??
                    item['line'] as int? ??
                    0,
                content: item['content'] as String? ??
                    item['line'] as String? ??
                    '',
                startIndex: item['startIndex'] as int?,
                endIndex: item['endIndex'] as int?,
              );
            }
            if (item is String) {
              final parts = item.split(':');
              if (parts.length >= 3) {
                return GrepMatch(
                  file: parts[0],
                  lineNumber: int.tryParse(parts[1]) ?? 0,
                  content: parts.skip(2).join(':'),
                );
              }
            }
            return null;
          })
          .whereType<GrepMatch>()
          .toList();
    }
    if (result is String && isContentMode) {
      final lines = result.split('\n');
      return lines
          .map((line) {
            if (line.trim().isEmpty) return null;
            final parts = line.split(':');
            if (parts.length >= 3) {
              return GrepMatch(
                file: parts[0],
                lineNumber: int.tryParse(parts[1]) ?? 0,
                content: parts.skip(2).join(':'),
              );
            }
            return null;
          })
          .whereType<GrepMatch>()
          .toList();
    }
    return [];
  }

  Widget _buildCountResult(BuildContext context, dynamic result) {
    final cs = Theme.of(context).colorScheme;
    var count = 0;
    if (result is Map<String, dynamic>) {
      count = result['count'] as int? ?? result['total'] as int? ?? 0;
    } else if (result is String) {
      count = int.tryParse(result.trim()) ?? 0;
    } else if (result is int) {
      count = result;
    }
    return _MatchCountBadge(count: count, colorScheme: cs);
  }

  Widget _buildFilesList(BuildContext context, dynamic result) {
    final cs = Theme.of(context).colorScheme;
    final files = <String>[];

    if (result is List) {
      for (final item in result) {
        if (item is String) {
          files.add(item);
        } else if (item is Map<String, dynamic>) {
          final p = item['path'] as String? ?? item['file'] as String?;
          if (p != null) files.add(p);
        }
      }
    } else if (result is Map<String, dynamic>) {
      final filesList = result['files'] as List?;
      if (filesList != null) {
        for (final item in filesList) {
          if (item is String) {
            files.add(item);
          } else if (item is Map<String, dynamic>) {
            final p = item['path'] as String?;
            if (p != null) files.add(p);
          }
        }
      }
    }

    if (files.isEmpty) return const SizedBox.shrink();

    final visible = files.take(15).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MatchCountBadge(
          count: files.length,
          label:
              '${files.length} file${files.length != 1 ? 's' : ''}'
              ' with matches',
          colorScheme: cs,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: ClipRRect(
            clipBehavior: Clip.hardEdge,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < visible.length; i++)
                  _FileMatchRow(
                    filePath: visible[i],
                    isLast: i == visible.length - 1,
                    colorScheme: cs,
                  ),
              ],
            ),
          ),
        ),
        if (files.length > 15)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '+ ${files.length - 15} more files',
              style: TextStyle(
                fontSize: AppFontSize.sm,
                fontStyle: FontStyle.italic,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Badge showing the grep pattern.
class _GrepPatternBadge extends StatelessWidget {
  const _GrepPatternBadge({required this.pattern});

  final String pattern;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xsm),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.manage_search,
            size: 14,
            color: cs.tertiary,
          ),
          const SizedBox(width: AppSpacing.xsm),
          Text(
            'grep',
            style: TextStyle(
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: AppSpacing.xsm),
          Container(
            width: 1,
            height: 12,
            color: cs.outlineVariant,
          ),
          const SizedBox(width: AppSpacing.xsm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: SelectableText(
              pattern,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
                color: cs.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip showing the search path.
class _GrepPathChip extends StatelessWidget {
  const _GrepPathChip({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xsm),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 13, color: cs.secondary),
          const SizedBox(width: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              path,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.xs,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill badge showing total match count.
class _MatchCountBadge extends StatelessWidget {
  const _MatchCountBadge({
    required this.count,
    required this.colorScheme,
    this.label,
  });

  final int count;
  final ColorScheme colorScheme;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final displayLabel =
        label ?? '$count match${count != 1 ? 'es' : ''}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: cs.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          fontSize: AppFontSize.xs,
          fontWeight: FontWeight.w600,
          color: cs.tertiary,
        ),
      ),
    );
  }
}

/// Renders all match groups with show-more support.
class _GroupedMatchList extends StatelessWidget {
  const _GroupedMatchList({
    required this.groupedMatches,
    required this.pattern,
    required this.showLineNumbers,
    required this.totalMatches,
    required this.initialLimit,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final Map<String, List<GrepMatch>> groupedMatches;
  final String pattern;
  final bool showLineNumbers;
  final int totalMatches;
  final int initialLimit;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final allEntries = groupedMatches.entries.toList();

    // Collect which files/matches to show within limit
    var shown = 0;
    final visibleEntries = <MapEntry<String, List<GrepMatch>>>[];
    for (final entry in allEntries) {
      if (!showAll && shown >= initialLimit) break;
      final matchesLeft = showAll
          ? entry.value.length
          : (initialLimit - shown).clamp(0, entry.value.length);
      visibleEntries.add(
        MapEntry(entry.key, entry.value.take(matchesLeft).toList()),
      );
      shown += matchesLeft;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibleEntries.map((entry) {
          return _FileMatchGroup(
            filePath: entry.key,
            matches: entry.value,
            pattern: pattern,
            showLineNumbers: showLineNumbers,
            colorScheme: cs,
          );
        }),
        if (totalMatches > initialLimit)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xsm),
            child: GestureDetector(
              onTap: onToggleShowAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showAll ? Icons.expand_less : Icons.expand_more,
                    size: 15,
                    color: cs.tertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    showAll
                        ? 'Show less'
                        : 'Show all $totalMatches matches',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: cs.tertiary,
                      fontWeight: FontWeight.w500,
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

/// A group of matches for a single file.
class _FileMatchGroup extends StatelessWidget {
  const _FileMatchGroup({
    required this.filePath,
    required this.matches,
    required this.pattern,
    required this.showLineNumbers,
    required this.colorScheme,
  });

  final String filePath;
  final List<GrepMatch> matches;
  final String pattern;
  final bool showLineNumbers;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final displayFile = filePath.split('/').lastOrNull ?? filePath;
    final parentDir = _parentDir(filePath);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.smd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // File header
          Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: 13,
                color: cs.secondary,
              ),
              const SizedBox(width: AppSpacing.xxs2),
              Flexible(
                child: Text(
                  displayFile,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Courier New', 'Courier'],
                  ),
                ),
              ),
              if (parentDir.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    parentDir,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.xxs,
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.xsm),
              _MatchCountPill(count: matches.length, cs: cs),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Match rows
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(AppRadius.xsm),
            ),
            child: ClipRRect(
              clipBehavior: Clip.hardEdge,
              borderRadius: BorderRadius.circular(AppRadius.xsm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < matches.length; i++)
                    _MatchRow(
                      match: matches[i],
                      pattern: pattern,
                      showLineNumbers: showLineNumbers,
                      isLast: i == matches.length - 1,
                      colorScheme: cs,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _parentDir(String path) {
    final segments = path.split('/');
    if (segments.length <= 1) return '';
    return segments.take(segments.length - 1).join('/');
  }
}

/// Small pill showing per-file match count.
class _MatchCountPill extends StatelessWidget {
  const _MatchCountPill({required this.count, required this.cs});

  final int count;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs2,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: cs.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: AppFontSize.xxs,
          fontWeight: FontWeight.w600,
          color: cs.secondary,
        ),
      ),
    );
  }
}

/// A single match line row.
class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.match,
    required this.pattern,
    required this.showLineNumbers,
    required this.isLast,
    required this.colorScheme,
  });

  final GrepMatch match;
  final String pattern;
  final bool showLineNumbers;
  final bool isLast;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final content = match.content.trimRight();

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.xsm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line number
            if (showLineNumbers || match.lineNumber > 0)
              Padding(
                padding: const EdgeInsets.only(
                  right: AppSpacing.sm,
                  top: 1,
                ),
                child: Text(
                  '${match.lineNumber}',
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    fontFamily: 'monospace',
                    color:
                        cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            // Highlighted content
            Expanded(
              child: _HighlightedText(
                content: content,
                pattern: pattern,
                highlightColor: cs.tertiary,
                baseColor: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders text with pattern occurrences highlighted.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.content,
    required this.pattern,
    required this.highlightColor,
    required this.baseColor,
  });

  final String content;
  final String pattern;
  final Color highlightColor;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    if (pattern.isEmpty) {
      return SelectableText(
        content,
        style: TextStyle(
          fontSize: AppFontSize.sm,
          fontFamily: 'monospace',
          color: baseColor,
        ),
      );
    }

    final spans = <TextSpan>[];
    final lowerContent = content.toLowerCase();
    final lowerPattern = pattern.toLowerCase();
    var start = 0;

    while (true) {
      final idx = lowerContent.indexOf(lowerPattern, start);
      if (idx < 0) {
        if (start < content.length) {
          spans.add(
            TextSpan(
              text: content.substring(start),
              style: TextStyle(
                fontSize: AppFontSize.sm,
                fontFamily: 'monospace',
                color: baseColor,
              ),
            ),
          );
        }
        break;
      }
      if (idx > start) {
        spans.add(
          TextSpan(
            text: content.substring(start, idx),
            style: TextStyle(
              fontSize: AppFontSize.sm,
              fontFamily: 'monospace',
              color: baseColor,
            ),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: content.substring(idx, idx + pattern.length),
          style: TextStyle(
            fontSize: AppFontSize.sm,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
            color: highlightColor,
            backgroundColor:
                highlightColor.withValues(alpha: 0.15),
          ),
        ),
      );
      start = idx + pattern.length;
    }

    return SelectableText.rich(TextSpan(children: spans));
  }
}

/// A simple row for a file in files-with-matches mode.
class _FileMatchRow extends StatelessWidget {
  const _FileMatchRow({
    required this.filePath,
    required this.isLast,
    required this.colorScheme,
  });

  final String filePath;
  final bool isLast;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final lastSlash = filePath.lastIndexOf('/');
    final dir = lastSlash >= 0
        ? filePath.substring(0, lastSlash + 1)
        : '';
    final filename = lastSlash >= 0
        ? filePath.substring(lastSlash + 1)
        : filePath;

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 15,
              color: cs.secondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    if (dir.isNotEmpty)
                      TextSpan(
                        text: dir,
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          fontFamily: 'monospace',
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    TextSpan(
                      text: filename,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
