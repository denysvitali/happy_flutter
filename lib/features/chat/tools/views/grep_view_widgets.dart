import 'package:flutter/material.dart';

import '../../../../core/components/app_badge.dart';
import '../../../../core/theme/app_tokens.dart';
import 'grep_view.dart';



/// Pill badge showing total match count.
class MatchCountBadge extends StatelessWidget {
  /// Creates a [MatchCountBadge].
  const MatchCountBadge({
    required this.count,
    required this.colorScheme,
    super.key,
    this.label,
  });

  /// The match count.
  final int count;

  /// The current color scheme.
  final ColorScheme colorScheme;

  /// Optional label override.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final displayLabel =
        label ?? '$count match${count != 1 ? 'es' : ''}';
    return AppBadge(
      label: displayLabel,
      backgroundColor: cs.tertiary.withValues(alpha: 0.12),
      foregroundColor: cs.tertiary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxxs,
      ),
      labelStyle: const TextStyle(fontSize: AppFontSize.xs),
    );
  }
}

/// Renders all match groups with show-more support.
class GroupedMatchList extends StatelessWidget {
  /// Creates a [GroupedMatchList].
  const GroupedMatchList({
    required this.groupedMatches,
    required this.pattern,
    required this.showLineNumbers,
    required this.totalMatches,
    required this.initialLimit,
    required this.showAll,
    required this.onToggleShowAll,
    super.key,
  });

  /// Matches grouped by file path.
  final Map<String, List<GrepMatch>> groupedMatches;

  /// The search pattern.
  final String pattern;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Total number of matches.
  final int totalMatches;

  /// Initial display limit before expanding.
  final int initialLimit;

  /// Whether all matches are shown.
  final bool showAll;

  /// Callback to toggle show-all state.
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final allEntries = groupedMatches.entries.toList();

    // Collect which files/matches to show within limit
    var shown = 0;
    final visibleEntries =
        <MapEntry<String, List<GrepMatch>>>[];
    for (final entry in allEntries) {
      if (!showAll && shown >= initialLimit) break;
      final matchesLeft = showAll
          ? entry.value.length
          : (initialLimit - shown)
              .clamp(0, entry.value.length);
      visibleEntries.add(
        MapEntry(
          entry.key,
          entry.value.take(matchesLeft).toList(),
        ),
      );
      shown += matchesLeft;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibleEntries.map((entry) {
          return FileMatchGroup(
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
                    showAll
                        ? Icons.expand_less
                        : Icons.expand_more,
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
class FileMatchGroup extends StatelessWidget {
  /// Creates a [FileMatchGroup].
  const FileMatchGroup({
    required this.filePath,
    required this.matches,
    required this.pattern,
    required this.showLineNumbers,
    required this.colorScheme,
    super.key,
  });

  /// The file path.
  final String filePath;

  /// Matches within this file.
  final List<GrepMatch> matches;

  /// The search pattern for highlighting.
  final String pattern;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// The current color scheme.
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final displayFile =
        filePath.split('/').lastOrNull ?? filePath;
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
                    fontFamilyFallback: const [
                      'Courier New',
                      'Courier',
                    ],
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
              MatchCountPill(count: matches.length, cs: cs),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Match rows
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    cs.outlineVariant.withValues(alpha: 0.5),
              ),
              borderRadius:
                  BorderRadius.circular(AppRadius.xsm),
            ),
            child: ClipRRect(
              clipBehavior: Clip.hardEdge,
              borderRadius:
                  BorderRadius.circular(AppRadius.xsm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < matches.length; i++)
                    GrepMatchRow(
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
class MatchCountPill extends StatelessWidget {
  /// Creates a [MatchCountPill].
  const MatchCountPill({
    required this.count,
    required this.cs,
    super.key,
  });

  /// The count to display.
  final int count;

  /// The current color scheme.
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: '$count',
      backgroundColor: cs.secondary.withValues(alpha: 0.12),
      foregroundColor: cs.secondary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs2,
        vertical: 1,
      ),
      labelStyle: const TextStyle(fontSize: AppFontSize.xxs),
    );
  }
}

/// A single match line row.
class GrepMatchRow extends StatelessWidget {
  /// Creates a [GrepMatchRow].
  const GrepMatchRow({
    required this.match,
    required this.pattern,
    required this.showLineNumbers,
    required this.isLast,
    required this.colorScheme,
    super.key,
  });

  /// The match to display.
  final GrepMatch match;

  /// The search pattern for highlighting.
  final String pattern;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// Whether this is the last row in its group.
  final bool isLast;

  /// The current color scheme.
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
                  color:
                      cs.outlineVariant.withValues(alpha: 0.3),
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
                    color: cs.onSurfaceVariant
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            // Highlighted content
            Expanded(
              child: HighlightedText(
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
class HighlightedText extends StatelessWidget {
  /// Creates a [HighlightedText].
  const HighlightedText({
    required this.content,
    required this.pattern,
    required this.highlightColor,
    required this.baseColor,
    super.key,
  });

  /// The text content.
  final String content;

  /// The pattern to highlight.
  final String pattern;

  /// Color for highlighted spans.
  final Color highlightColor;

  /// Color for non-highlighted spans.
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
      final idx =
          lowerContent.indexOf(lowerPattern, start);
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
          text: content.substring(
            idx,
            idx + pattern.length,
          ),
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
class FileListMatchRow extends StatelessWidget {
  /// Creates a [FileListMatchRow].
  const FileListMatchRow({
    required this.filePath,
    required this.isLast,
    required this.colorScheme,
    super.key,
  });

  /// The file path.
  final String filePath;

  /// Whether this is the last row.
  final bool isLast;

  /// The current color scheme.
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
                  color: cs.outlineVariant
                      .withValues(alpha: 0.35),
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
