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

/// A group of matches for a single file: a borderless file header followed
/// by a tinted code block with a line-number gutter.
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
    final gutterWidth = '$maxLine'.length * 7.5;
    final count = totalInFile ?? matches.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // File header
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
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
                            text: '  $parentDir/',
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
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xsm),
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
/// de-indented, highlighted source line. Long lines are clipped to a
/// snippet around the first hit; tapping expands the full line.
class GrepMatchRow extends StatefulWidget {
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
  State<GrepMatchRow> createState() => _GrepMatchRowState();
}

class _GrepMatchRowState extends State<GrepMatchRow> {
  static const int _collapsedLines = 2;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final gutter = widget.gutterWidth;
    final line = widget.match.content.trim();
    final ranges = widget.highlighter.ranges(line);
    final snippet = _expanded ? null : matchSnippet(line, ranges);

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gutter != null) ...[
              SizedBox(
                width: gutter,
                child: Text(
                  widget.match.lineNumber > 0
                      ? '${widget.match.lineNumber}'
                      : '',
                  textAlign: TextAlign.right,
                  style: _codeStyle.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.smd),
            ],
            Expanded(
              child: HighlightedText(
                content: snippet?.text ?? line,
                ranges: snippet?.ranges ?? ranges,
                maxLines: _expanded ? null : _collapsedLines,
                colorScheme: cs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A clipped view of a long line with highlight ranges remapped.
typedef MatchSnippet = ({String text, List<(int, int)> ranges});

/// Drops the prefix of [line] when its first hit sits deep inside it, so
/// the collapsed preview opens on the match instead of boilerplate.
MatchSnippet? matchSnippet(
  String line,
  List<(int, int)> ranges, {
  int lead = 24,
}) {
  if (ranges.isEmpty) return null;
  final first = ranges.first.$1;
  if (first <= lead * 2) return null;
  // Start at the next word boundary so the preview never opens mid-token.
  final space = line.indexOf(' ', first - lead);
  final cut = space >= 0 && space < first ? space + 1 : first - lead;
  const prefix = '… ';
  final shift = prefix.length - cut;
  return (
    text: '$prefix${line.substring(cut)}',
    ranges: [for (final (a, b) in ranges) (a + shift, b + shift)],
  );
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

/// Renders a code line with the given ranges highlighted.
class HighlightedText extends StatelessWidget {
  /// Creates a [HighlightedText].
  const HighlightedText({
    required this.content,
    required this.ranges,
    required this.colorScheme,
    super.key,
    this.maxLines,
  });

  /// The text content.
  final String content;

  /// `[start, end)` ranges to highlight.
  final List<(int, int)> ranges;

  /// The current color scheme.
  final ColorScheme colorScheme;

  /// Optional line cap; overflow is ellipsized.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final hit = TextStyle(
      fontWeight: FontWeight.w700,
      color: cs.onTertiaryContainer,
      backgroundColor: cs.tertiaryContainer,
    );

    final spans = <TextSpan>[];
    var start = 0;
    for (final (from, to) in ranges) {
      if (from < start || to > content.length) continue;
      if (from > start) {
        spans.add(TextSpan(text: content.substring(start, from)));
      }
      spans.add(TextSpan(text: content.substring(from, to), style: hit));
      start = to;
    }
    if (start < content.length) {
      spans.add(TextSpan(text: content.substring(start)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: _codeStyle.copyWith(color: cs.onSurface),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
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
