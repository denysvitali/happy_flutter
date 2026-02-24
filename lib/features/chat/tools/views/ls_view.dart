import 'package:flutter/material.dart';
import 'package:happy_flutter/core/utils/path_utils.dart';
import '../tool_section_view.dart';

/// Entry model for LS results.
class LSEntry {
  /// Constructs an [LSEntry].
  LSEntry({
    required this.name,
    required this.isDirectory,
    required this.isFile,
    this.permissions,
    this.size,
  });

  /// The name of the entry.
  final String name;

  /// Whether this entry is a directory.
  final bool isDirectory;

  /// Whether this entry is a regular file.
  final bool isFile;

  /// Optional POSIX permission string.
  final String? permissions;

  /// Optional file size in bytes.
  final int? size;

  /// Whether this entry is a symbolic link.
  bool get isSymlink => !isDirectory && !isFile;

  /// Returns the file extension (lowercase, without dot).
  String get extension {
    if (isDirectory) return '';
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// Returns a color for a file entry based on type/extension.
Color _entryColor(LSEntry entry, ColorScheme cs) {
  if (entry.isDirectory) return const Color(0xFFFFC107);
  if (entry.isSymlink) return const Color(0xFF26C6DA);
  switch (entry.extension) {
    case 'dart':
      return const Color(0xFF42A5F5);
    case 'json':
    case 'yaml':
    case 'yml':
      return const Color(0xFFFFCA28);
    case 'md':
    case 'markdown':
      return const Color(0xFF90A4AE);
    case 'ts':
    case 'tsx':
    case 'js':
    case 'jsx':
      return const Color(0xFFFFA726);
    case 'swift':
      return const Color(0xFFEF5350);
    case 'kt':
    case 'kts':
      return const Color(0xFF7E57C2);
    case 'py':
      return const Color(0xFF26A69A);
    case 'sh':
    case 'bash':
      return const Color(0xFF8D6E63);
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'svg':
    case 'webp':
      return const Color(0xFFEC407A);
    default:
      return cs.onSurfaceVariant;
  }
}

/// Returns an icon for a file entry based on type/extension.
IconData _entryIcon(LSEntry entry) {
  if (entry.isDirectory) return Icons.folder_rounded;
  if (entry.isSymlink) return Icons.link;
  switch (entry.extension) {
    case 'dart':
    case 'ts':
    case 'tsx':
    case 'js':
    case 'jsx':
    case 'swift':
    case 'kt':
    case 'kts':
    case 'py':
    case 'sh':
    case 'bash':
      return Icons.code;
    case 'json':
    case 'yaml':
    case 'yml':
      return Icons.data_object;
    case 'md':
    case 'markdown':
      return Icons.article_outlined;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'svg':
    case 'webp':
      return Icons.image_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

/// View for displaying LS tool results.
class LSView extends StatefulWidget {
  /// Constructs an [LSView].
  const LSView({required this.tool, super.key, this.metadata});

  /// The tool invocation data.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  State<LSView> createState() => _LSViewState();
}

class _LSViewState extends State<LSView> {
  static const int _initialLimit = 30;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final result = widget.tool['result'];
    final state = widget.tool['state'] as String? ?? '';

    final path = input['path'] as String? ?? '/';
    final resolvedPath = resolvePath(path, widget.metadata);
    final entries = _parseEntries(result);

    // Sort: directories first, then files, both alphabetically
    final sorted = [...entries]..sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final dirs = sorted.where((e) => e.isDirectory).toList();
    final files = sorted.where((e) => !e.isDirectory).toList();

    final visibleEntries =
        _showAll ? sorted : sorted.take(_initialLimit).toList();
    final hiddenCount = sorted.length - _initialLimit;

    final cs = Theme.of(context).colorScheme;

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Path header
          _PathHeader(resolvedPath: resolvedPath, colorScheme: cs),

          // Summary row
          if (state == 'completed' || entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  _CountChip(
                    icon: Icons.folder_rounded,
                    count: dirs.length,
                    label: 'dir${dirs.length != 1 ? 's' : ''}',
                    color: const Color(0xFFFFC107),
                    colorScheme: cs,
                  ),
                  const SizedBox(width: 6),
                  _CountChip(
                    icon: Icons.insert_drive_file_outlined,
                    count: files.length,
                    label: 'file${files.length != 1 ? 's' : ''}',
                    color: cs.primary,
                    colorScheme: cs,
                  ),
                ],
              ),
            ),

          // Entry list
          if (visibleEntries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  clipBehavior: Clip.hardEdge,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < visibleEntries.length; i++)
                        _EntryRow(
                          entry: visibleEntries[i],
                          isLast: i == visibleEntries.length - 1 &&
                              (hiddenCount <= 0 || _showAll),
                          colorScheme: cs,
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Show all / collapse button
          if (sorted.length > _initialLimit)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAll
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 15,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showAll
                          ? 'Show less'
                          : 'Show all ${sorted.length} items',
                      style: TextStyle(
                        fontSize: 12,
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
    );
  }

  List<LSEntry> _parseEntries(dynamic result) {
    if (result == null) return [];
    if (result is List) {
      return result
          .map((item) {
            if (item is Map<String, dynamic>) {
              return LSEntry(
                name: item['name'] as String? ??
                    item['file'] as String? ??
                    '',
                isDirectory: item['isDirectory'] as bool? ??
                    item['type'] == 'directory',
                isFile: item['isFile'] as bool? ??
                    item['type'] == 'file',
                permissions: item['permissions'] as String?,
                size: item['size'] as int?,
              );
            }
            if (item is String) {
              return LSEntry(
                name: item,
                isDirectory: item.endsWith('/'),
                isFile: !item.endsWith('/'),
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
                name: item['name'] as String? ??
                    item['file'] as String? ??
                    '',
                isDirectory: item['isDirectory'] as bool? ??
                    item['type'] == 'directory',
                isFile: item['isFile'] as bool? ??
                    item['type'] == 'file',
                permissions: item['permissions'] as String?,
                size: item['size'] as int?,
              );
            }
            if (item is String) {
              return LSEntry(
                name: item,
                isDirectory: item.endsWith('/'),
                isFile: !item.endsWith('/'),
              );
            }
            return null;
          })
          .whereType<LSEntry>()
          .toList();
    }
    return [];
  }
}

/// The path header showing the current directory.
class _PathHeader extends StatelessWidget {
  const _PathHeader({
    required this.resolvedPath,
    required this.colorScheme,
  });

  final String resolvedPath;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.folder_open_rounded,
            size: 15,
            color: Color(0xFFFFC107),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              resolvedPath,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small count chip showing an icon + count + label.
class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.colorScheme,
  });

  final IconData icon;
  final int count;
  final String label;
  final Color color;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row in the LS entry list.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.isLast,
    required this.colorScheme,
  });

  final LSEntry entry;
  final bool isLast;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final color = _entryColor(entry, cs);
    final icon = _entryIcon(entry);

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
          horizontal: 10,
          vertical: 8,
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 10),
            // Name + optional permissions
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    entry.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: entry.isDirectory
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                  if (entry.permissions != null)
                    Text(
                      entry.permissions!,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: cs.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            // Size
            if (entry.size != null)
              Text(
                _formatSize(entry.size!),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: cs.onSurfaceVariant,
                ),
              ),
            // Extension tag (files only)
            if (!entry.isDirectory && entry.extension.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.extension,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
