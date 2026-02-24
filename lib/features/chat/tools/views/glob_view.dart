import 'package:flutter/material.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import '../tool_section_view.dart';

/// File item model for Glob results.
class GlobFile {
  /// Constructs a [GlobFile].
  GlobFile({required this.path, this.basename});

  /// The full path of the file.
  final String path;

  /// Optional basename override.
  final String? basename;

  /// Returns the display name for this file.
  String get displayName => basename ?? path.split('/').lastOrNull ?? path;

  /// Returns the file extension (lowercase, without dot).
  String get extension {
    final name = displayName;
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// Returns a color for a file based on its extension.
Color _fileColor(String ext, ColorScheme cs) {
  switch (ext) {
    case 'dart':
      return const Color(0xFF42A5F5); // blue
    case 'json':
      return const Color(0xFFFFCA28); // yellow
    case 'md':
    case 'markdown':
      return const Color(0xFF90A4AE); // blue-grey
    case 'yaml':
    case 'yml':
      return const Color(0xFF66BB6A); // green
    case 'ts':
    case 'tsx':
    case 'js':
    case 'jsx':
      return const Color(0xFFFFA726); // orange
    case 'swift':
      return const Color(0xFFEF5350); // red
    case 'kt':
    case 'kts':
      return const Color(0xFF7E57C2); // purple
    case 'py':
      return const Color(0xFF26A69A); // teal
    case 'sh':
    case 'bash':
      return const Color(0xFF8D6E63); // brown
    case 'html':
    case 'htm':
      return const Color(0xFFEF5350); // red
    case 'css':
    case 'scss':
    case 'less':
      return const Color(0xFF42A5F5); // blue
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'svg':
    case 'webp':
      return const Color(0xFFEC407A); // pink
    default:
      return cs.onSurfaceVariant;
  }
}

/// Returns a Material icon for a file based on its extension.
IconData _fileIcon(String ext) {
  switch (ext) {
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
    case 'html':
    case 'htm':
    case 'css':
    case 'scss':
    case 'less':
      return Icons.web_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

/// View for displaying Glob tool results.
class GlobView extends StatefulWidget {
  /// Constructs a [GlobView].
  const GlobView({required this.tool, super.key, this.metadata});

  /// The tool invocation data.
  final Map<String, dynamic> tool;

  /// Optional metadata for path resolution.
  final Map<String, dynamic>? metadata;

  @override
  State<GlobView> createState() => _GlobViewState();
}

class _GlobViewState extends State<GlobView> {
  static const int _initialLimit = 10;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final result = widget.tool['result'];
    final state = widget.tool['state'] as String? ?? '';

    final pattern = input['pattern'] as String? ?? '';
    final path = input['path'] as String?;

    final files = _parseFiles(result);
    final visibleFiles =
        _showAll ? files : files.take(_initialLimit).toList();
    final hiddenCount = files.length - _initialLimit;

    final cs = Theme.of(context).colorScheme;

    return ToolSectionView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pattern badge row
          Row(
            children: [
              _PatternBadge(pattern: pattern),
              if (path != null && path.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs + 2),
                _PathChip(path: path),
              ],
            ],
          ),

          // Summary row
          if (state == 'completed' || files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
              child: Row(
                children: [
                  _ResultCountChip(count: files.length, cs: cs),
                ],
              ),
            ),

          // File list
          if (visibleFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
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
                      for (int i = 0; i < visibleFiles.length; i++)
                        _FileRow(
                          file: visibleFiles[i],
                          isLast: i == visibleFiles.length - 1 &&
                              (hiddenCount <= 0 || _showAll),
                          colorScheme: cs,
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Show all / collapse button
          if (files.length > _initialLimit)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
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
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _showAll
                          ? 'Show less'
                          : 'Show all ${files.length} files',
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
                path: item['path'] as String? ??
                    item['filePath'] as String? ??
                    '',
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
}

/// Small chip showing the result count.
class _ResultCountChip extends StatelessWidget {
  const _ResultCountChip({required this.count, required this.cs});

  final int count;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        count == 0
            ? 'No files found'
            : '$count file${count != 1 ? 's' : ''} found',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );
  }
}

/// A styled badge showing the glob pattern.
class _PatternBadge extends StatelessWidget {
  const _PatternBadge({required this.pattern});

  final String pattern;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xs + 2),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.travel_explore,
            size: 14,
            color: cs.primary,
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            'glob',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          Container(
            width: 1,
            height: 12,
            color: cs.outlineVariant,
          ),
          const SizedBox(width: AppSpacing.xs + 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: SelectableText(
              pattern,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chip showing the search path.
class _PathChip extends StatelessWidget {
  const _PathChip({required this.path});

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
        borderRadius: BorderRadius.circular(AppRadius.xs + 2),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 13,
            color: cs.secondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              path,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single row in the file list.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.isLast,
    required this.colorScheme,
  });

  final GlobFile file;
  final bool isLast;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final ext = file.extension;
    final color = _fileColor(ext, colorScheme);
    final icon = _fileIcon(ext);
    final cs = colorScheme;

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
          horizontal: AppSpacing.sm + 2,
          vertical: 7,
        ),
        child: Row(
          children: [
            // Extension icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xs + 1),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    file.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  if (file.path != file.displayName)
                    Text(
                      _parentDir(file.path),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),
            // Extension tag
            if (ext.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 1,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  ext,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _parentDir(String path) {
    final segments = path.split('/');
    if (segments.length <= 1) return path;
    return segments.take(segments.length - 1).join('/');
  }
}
