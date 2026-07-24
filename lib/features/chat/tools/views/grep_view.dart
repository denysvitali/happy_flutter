import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
import '../tool_section_view.dart';
import 'grep_view_widgets.dart';
import 'search_chips.dart';

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
        WireParsers.asMap(widget.tool['input']) ?? {};
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
              SearchToolBadge(
                label: 'grep',
                pattern: pattern,
                icon: Icons.manage_search,
                accent: cs.tertiary,
              ),
              if (path != null && path.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xsm),
                SearchPathChip(path: path),
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
              child: MatchCountBadge(
                count: matches.length,
                colorScheme: cs,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: GroupedMatchList(
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
    return MatchCountBadge(count: count, colorScheme: cs);
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
        MatchCountBadge(
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
                  FileListMatchRow(
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
