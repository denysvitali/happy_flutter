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
    final displayLabel = label ?? '$count match${count != 1 ? 'es' : ''}';
    return AppBadge(
      label: displayLabel,
      backgroundColor: cs.tertiary.withValues(alpha: 0.12),
      foregroundColor: cs.tertiary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxxs,
      ),
      labelStyle: const TextStyle(fontSize: AppFontSize.sm),
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
    this.searchPath,
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

  /// Directory the search was scoped to; file headers are shown relative
  /// to it.
  final String? searchPath;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final highlighter = MatchHighlighter(pattern);

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in visibleEntries)
          FileMatchGroup(
            filePath: entry.key,
            matches: entry.value,
            totalInFile: groupedMatches[entry.key]?.length,
            highlighter: highlighter,
            showLineNumbers: showLineNumbers,
            colorScheme: cs,
            searchPath: searchPath,
          ),
        if (totalMatches > initialLimit)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggleShowAll,
              style: TextButton.styleFrom(
                foregroundColor: cs.tertiary,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w500,
                ),
              ),
              icon: Icon(
                showAll ? Icons.expand_less : Icons.expand_more,
                size: AppIconSize.md,
              ),
              label: Text(
                showAll ? 'Show less' : 'Show all $totalMatches matches',
              ),
            ),
          ),
      ],
    );
  }
}

/// A group of matches for a single file: a header strip followed by
/// compact code lines with a line-number gutter.
class FileMatchGroup extends StatelessWidget {
  /// Creates a [FileMatchGroup].
  const FileMatchGroup({
    required this.filePath,
    required this.matches,
    required this.highlighter,
    required this.showLineNumbers,
    required this.colorScheme,
    super.key,
    this.totalInFile,
    this.searchPath,
  });

  /// The file path.
  final String filePath;

  /// Matches within this file that are visible.
  final List<GrepMatch> matches;

  /// Total matches in the file, when more than [matches] exist.
  final int? totalInFile;

  /// Highlights pattern occurrences in each line.
  final MatchHighlighter highlighter;

  /// Whether to show line numbers.
  final bool showLineNumbers;

  /// The current color scheme.
  final ColorScheme colorScheme;

  /// Directory the search was scoped to.
  final String? searchPath;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final relative = relativeMatchPath(filePath, searchPath);
    final slash = relative.lastIndexOf('/');
    final displayFile = slash >= 0 ? relative.substring(slash + 1) : relative;
    final parentDir = slash > 0 ? relative.substring(0, slash) : '';
    final showGutter = showLineNumbers || matches.any((m) => m.lineNumber > 0);
    final maxLine = matches.fold<int>(
      0,
      (acc, m) => m.lineNumber > acc ? m.lineNumber : acc,
    );
    final gutterWidth = '$maxLine'.length * 7.5 + AppSpacing.sm;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // File header
          Container(
            color: cs.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smd,
              vertical: AppSpacing.xsm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: AppIconSize.sm,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xsm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: displayFile,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        if (parentDir.isNotEmpty)
                          TextSpan(
                            text: '  $parentDir',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: AppFontSize.sm),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                MatchCountPill(count: totalInFile ?? matches.length, cs: cs),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final match in matches)
                  GrepMatchRow(
                    match: match,
                    highlighter: highlighter,
                    gutterWidth: showGutter ? gutterWidth : null,
                    colorScheme: cs,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns [filePath] relative to [searchPath] when it lives under it.
String relativeMatchPath(String filePath, String? searchPath) {
  if (searchPath == null || searchPath.isEmpty || searchPath == '.') {
    return filePath;
  }
  final base = searchPath.endsWith('/') ? searchPath : '$searchPath/';
  return filePath.startsWith(base) ? filePath.substring(base.length) : filePath;
}

/// Small pill showing per-file match count.
class MatchCountPill extends StatelessWidget {
  /// Creates a [MatchCountPill].
  const MatchCountPill({required this.count, required this.cs, super.key});

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
        horizontal: AppSpacing.xsm,
        vertical: 1,
      ),
      labelStyle: const TextStyle(fontSize: AppFontSize.xs),
    );
  }
}

/// A single match line: right-aligned line number gutter plus the
/// de-indented, highlighted source line.
class GrepMatchRow extends StatelessWidget {
  /// Creates a [GrepMatchRow].
  const GrepMatchRow({
    required this.match,
    required this.highlighter,
    required this.colorScheme,
    super.key,
    this.gutterWidth,
  });

  /// The match to display.
  final GrepMatch match;

  /// Highlights pattern occurrences.
  final MatchHighlighter highlighter;

  /// Width of the line-number gutter, or null to hide it.
  final double? gutterWidth;

  /// The current color scheme.
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final gutter = gutterWidth;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gutter != null)
            SizedBox(
              width: gutter + AppSpacing.smd,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  match.lineNumber > 0 ? '${match.lineNumber}' : '',
                  textAlign: TextAlign.right,
                  style: _codeStyle.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.smd),
              child: HighlightedText(
                content: match.content.trim(),
                highlighter: highlighter,
                highlightColor: cs.tertiary,
                baseColor: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _codeStyle = TextStyle(
  fontSize: AppFontSize.sm,
  fontFamily: 'monospace',
  fontFamilyFallback: ['Courier New', 'Courier'],
  height: AppLineHeight.normal,
);

/// Finds pattern occurrences in a line. Treats the pattern as a
/// case-insensitive regular expression (grep semantics) and falls back to a
/// literal search when it does not compile.
class MatchHighlighter {
  /// Creates a [MatchHighlighter] for [pattern].
  MatchHighlighter(this.pattern) : _regex = _compile(pattern);

  /// The raw search pattern.
  final String pattern;

  final RegExp? _regex;

  static RegExp? _compile(String pattern) {
    if (pattern.isEmpty) return null;
    try {
      return RegExp(pattern, caseSensitive: false);
    } on FormatException {
      return RegExp(RegExp.escape(pattern), caseSensitive: false);
    }
  }

  /// Non-empty `[start, end)` ranges of matches in [content].
  List<(int, int)> ranges(String content) {
    final regex = _regex;
    if (regex == null) return const [];
    return [
      for (final m in regex.allMatches(content))
        if (m.end > m.start) (m.start, m.end),
    ];
  }
}

/// Renders text with pattern occurrences highlighted.
class HighlightedText extends StatelessWidget {
  /// Creates a [HighlightedText].
  const HighlightedText({
    required this.content,
    required this.highlighter,
    required this.highlightColor,
    required this.baseColor,
    super.key,
  });

  /// The text content.
  final String content;

  /// Locates the ranges to highlight.
  final MatchHighlighter highlighter;

  /// Color for highlighted spans.
  final Color highlightColor;

  /// Color for non-highlighted spans.
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final base = _codeStyle.copyWith(color: baseColor);
    final hit = _codeStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: highlightColor,
      backgroundColor: highlightColor.withValues(alpha: 0.15),
    );

    final spans = <TextSpan>[];
    var start = 0;
    for (final (from, to) in highlighter.ranges(content)) {
      if (from > start) {
        spans.add(TextSpan(text: content.substring(start, from)));
      }
      spans.add(TextSpan(text: content.substring(from, to), style: hit));
      start = to;
    }
    if (start < content.length) {
      spans.add(TextSpan(text: content.substring(start)));
    }

    return SelectableText.rich(TextSpan(style: base, children: spans));
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
    final dir = lastSlash >= 0 ? filePath.substring(0, lastSlash + 1) : '';
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
              size: AppIconSize.md,
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
