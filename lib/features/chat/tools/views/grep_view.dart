import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// Match item model for Grep results.
class GrepMatch {
  final String file;
  final int lineNumber;
  final String content;
  final int? startIndex;
  final int? endIndex;

  GrepMatch({
    required this.file,
    required this.lineNumber,
    required this.content,
    this.startIndex,
    this.endIndex,
  });

  String get displayFile => file.split('/').lastOrNull ?? file;
}

/// View for displaying Grep tool results.
class GrepView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const GrepView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final pattern = input['pattern'] as String? ?? '';
    final path = input['path'] as String?;
    final outputMode = input['output_mode'] as String?;
    final showLineNumbers = input['-n'] as bool? ?? false;

    // Parse result based on output mode
    final isContentMode = outputMode == 'content';
    final isCountMode = outputMode == 'count';
    final matches = _parseMatches(result, isContentMode);

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pattern display
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    'grep: $pattern',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Path if provided
          if (path != null && path.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder,
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Path: $path',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Count mode - show count only
          if (isCountMode && result != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildCountResult(context, result),
            ),
          // Content mode - show matches
          if (isContentMode && matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: matches.take(20).map((match) {
                  return _buildMatchItem(context, match, showLineNumbers, matches.length > 20);
                }).toList(),
              ),
            ),
          // Files with matches mode
          if (!isContentMode && !isCountMode && matches.isEmpty && result != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildFilesList(context, result),
            ),
        ],
      ),
    );
  }

  List<GrepMatch> _parseMatches(dynamic result, bool isContentMode) {
    if (result == null) return [];
    if (result is List) {
      return result
          .map((item) {
            if (item is Map<String, dynamic>) {
              return GrepMatch(
                file: item['path'] as String? ?? item['file'] as String? ?? '',
                lineNumber: item['lineNumber'] as int? ?? item['line'] as int? ?? 0,
                content: item['content'] as String? ?? item['line'] as String? ?? '',
                startIndex: item['startIndex'] as int?,
                endIndex: item['endIndex'] as int?,
              );
            }
            if (item is String) {
              // Parse string format: "file:line:content"
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
      // Parse string format - each line may contain "file:line:content"
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

  Widget _buildMatchItem(BuildContext context, GrepMatch match, bool showLineNumbers, bool hasMore) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLineNumbers)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${match.lineNumber}:',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Expanded(
              child: SelectableText(
                match.content,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountResult(BuildContext context, dynamic result) {
    final theme = Theme.of(context);
    int count = 0;

    if (result is Map<String, dynamic>) {
      count = result['count'] as int? ?? result['total'] as int? ?? 0;
    } else if (result is String) {
      count = int.tryParse(result.trim()) ?? 0;
    } else if (result is int) {
      count = result;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count matches',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildFilesList(BuildContext context, dynamic result) {
    final theme = Theme.of(context);
    final files = <String>[];

    if (result is List) {
      for (final item in result) {
        if (item is String) {
          files.add(item);
        } else if (item is Map<String, dynamic>) {
          final path = item['path'] as String? ?? item['file'] as String?;
          if (path != null) files.add(path);
        }
      }
    } else if (result is Map<String, dynamic>) {
      final filesList = result['files'] as List?;
      if (filesList != null) {
        for (final item in filesList) {
          if (item is String) {
            files.add(item);
          } else if (item is Map<String, dynamic>) {
            final path = item['path'] as String?;
            if (path != null) files.add(path);
          }
        }
      }
    }

    if (files.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${files.length} file${files.length != 1 ? 's' : ''} with matches',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...files.take(15).map((file) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(
                  Icons.description,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    file.split('/').lastOrNull ?? file,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        if (files.length > 15)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ ${files.length - 15} more',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
