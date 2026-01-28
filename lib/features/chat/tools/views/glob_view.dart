import 'package:flutter/material.dart';
import '../tool_section_view.dart';

/// File item model for Glob results.
class GlobFile {
  final String path;
  final String? basename;

  GlobFile({required this.path, this.basename});

  String get displayName => basename ?? path.split('/').lastOrNull ?? path;
}

/// View for displaying Glob tool results.
class GlobView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const GlobView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final pattern = input['pattern'] as String? ?? '';
    final path = input['path'] as String?;

    // Parse result as file list
    final files = _parseFiles(result);

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
                    'Pattern: $pattern',
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
          // Results count
          if (state == 'completed' && files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${files.length} file${files.length != 1 ? 's' : ''} found',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // File list
          if (files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: files.take(10).map((file) {
                  return _buildFileItem(context, file, files.length > 10);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<GlobFile> _parseFiles(dynamic result) {
    if (result == null) return [];
    if (result is List) {
      return result
          .map((item) {
            if (item is String) {
              return GlobFile(
                path: item,
                basename: item.split('/').lastOrNull,
              );
            }
            if (item is Map<String, dynamic>) {
              return GlobFile(
                path: item['path'] as String? ?? item['filePath'] as String? ?? '',
                basename: item['basename'] as String?,
              );
            }
            return null;
          })
          .whereType<GlobFile>()
          .toList();
    }
    if (result is Map<String, dynamic>) {
      final files = result['files'] as List?;
      if (files != null) {
        return files
            .map((item) {
              if (item is String) {
                return GlobFile(
                  path: item,
                  basename: item.split('/').lastOrNull,
                );
              }
              if (item is Map<String, dynamic>) {
                return GlobFile(
                  path: item['path'] as String? ?? '',
                  basename: item['basename'] as String?,
                );
              }
              return null;
            })
            .whereType<GlobFile>()
            .toList();
      }
    }
    return [];
  }

  Widget _buildFileItem(BuildContext context, GlobFile file, bool hasMore) {
    final theme = Theme.of(context);

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
              file.displayName,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
