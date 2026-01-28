import 'package:flutter/material.dart';
import '../tool_section_view.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';

/// Entry model for LS results.
class LSEntry {
  final String name;
  final bool isDirectory;
  final bool isFile;
  final String? permissions;
  final int? size;

  LSEntry({
    required this.name,
    required this.isDirectory,
    required this.isFile,
    this.permissions,
    this.size,
  });

  bool get isSymlink => !isDirectory && !isFile;
}

/// View for displaying LS tool results.
class LSView extends StatelessWidget {
  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  const LSView({super.key, required this.tool, this.metadata});

  @override
  Widget build(BuildContext context) {
    final input = tool['input'] as Map<String, dynamic>? ?? {};
    final result = tool['result'];
    final state = tool['state'] as String? ?? '';

    final path = input['path'] as String? ?? '/';

    // Resolve path with metadata
    final resolvedPath = resolvePath(path, metadata);
    final displayName = resolvedPath.split('/').lastOrNull ?? resolvedPath;

    // Parse result as entries
    final entries = _parseEntries(result);

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Path header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_open,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    resolvedPath,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Entry count
          if (state == 'completed' && entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${entries.length} item${entries.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          // Entries list
          if (entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: entries.map((entry) {
                  return _buildEntryItem(context, entry);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  List<LSEntry> _parseEntries(dynamic result) {
    if (result == null) return [];
    if (result is List) {
      return result
          .map((item) {
            if (item is Map<String, dynamic>) {
              return LSEntry(
                name: item['name'] as String? ?? item['file'] as String? ?? '',
                isDirectory: item['isDirectory'] as bool? ??
                    item['type'] == 'directory' ??
                    false,
                isFile: item['isFile'] as bool? ??
                    item['type'] == 'file' ??
                    false,
                permissions: item['permissions'] as String?,
                size: item['size'] as int?,
              );
            }
            if (item is String) {
              // Simple string - assume it's a file/folder name
              return LSEntry(
                name: item,
                isDirectory: false,
                isFile: true,
              );
            }
            return null;
          })
          .whereType<LSEntry>()
          .toList();
    }
    if (result is Map<String, dynamic>) {
      final entries = result['entries'] as List?;
      final files = result['files'] as List?;
      final items = result['items'] as List?;

      final source = entries ?? files ?? items ?? [];
      return source
          .map((item) {
            if (item is Map<String, dynamic>) {
              return LSEntry(
                name: item['name'] as String? ?? item['file'] as String? ?? '',
                isDirectory: item['isDirectory'] as bool? ??
                    item['type'] == 'directory' ??
                    false,
                isFile: item['isFile'] as bool? ??
                    item['type'] == 'file' ??
                    false,
                permissions: item['permissions'] as String?,
                size: item['size'] as int?,
              );
            }
            if (item is String) {
              return LSEntry(
                name: item,
                isDirectory: false,
                isFile: true,
              );
            }
            return null;
          })
          .whereType<LSEntry>()
          .toList();
    }
    return [];
  }

  Widget _buildEntryItem(BuildContext context, LSEntry entry) {
    final theme = Theme.of(context);

    IconData iconData;
    Color iconColor;

    if (entry.isDirectory) {
      iconData = Icons.folder;
      iconColor = const Color(0xFFFFC107);
    } else if (entry.isFile) {
      iconData = Icons.description;
      iconColor = theme.colorScheme.onSurfaceVariant;
    } else {
      iconData = Icons.insert_drive_file;
      iconColor = theme.colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(iconData, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              entry.name,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (entry.size != null)
            Text(
              _formatSize(entry.size!),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
