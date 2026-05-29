import 'package:flutter/material.dart';
import 'package:happy_flutter/core/components/app_badge.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/theme/file_type_colors.dart';
import 'package:happy_flutter/core/utils/wire_parsers.dart';
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
///
/// Delegates to the canonical [FileTypeColors] palette, falling back to the
/// theme's muted on-surface color for unknown extensions.
Color _fileColor(String ext, ColorScheme cs) {
  if (ext.isEmpty) return cs.onSurfaceVariant;
  final mapped = FileTypeColors.colorForExtension(ext);
  return mapped == FileTypeColors.defaultColor ? cs.onSurfaceVariant : mapped;
}

/// Returns a Material icon for a file based on its extension.
IconData _fileIcon(String ext) => FileTypeColors.iconForExtension(ext);

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
        WireParsers.asMap(widget.tool['input']) ?? {};
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
                const SizedBox(width: AppSpacing.xsm),
                _PathChip(path: path),
              ],
            ],
          ),

          // Summary row
          if (state == 'completed' || files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.smd),
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
              padding: const EdgeInsets.only(top: AppSpacing.xsm),
              child: GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAll
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: AppIconSize.sm,
                      color: cs.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _showAll
                          ? 'Show less'
                          : 'Show all ${files.length} files',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
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
    return AppBadge(
      label: count == 0
          ? 'No files found'
          : '$count file${count != 1 ? 's' : ''} found',
      backgroundColor: cs.primary.withValues(alpha: 0.12),
      foregroundColor: cs.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxxs,
      ),
      labelStyle: const TextStyle(fontSize: AppFontSize.xs),
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
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.xxs2,
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
            Icons.travel_explore,
            size: AppIconSize.sm,
            color: cs.primary,
          ),
          const SizedBox(width: AppSpacing.xsm),
          Text(
            'glob',
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
            height: AppIconSize.xs,
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
        vertical: AppSpacing.xxs2,
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
            Icons.folder_outlined,
            size: AppIconSize.xs,
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
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.xsm + 1,
        ),
        child: Row(
          children: [
            // Extension icon
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xxs2),
              ),
              child: Icon(icon, size: AppIconSize.sm, color: color),
            ),
            const SizedBox(width: AppSpacing.smd),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    file.displayName,
                    style: TextStyle(
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  if (file.path != file.displayName)
                    Text(
                      _parentDir(file.path),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFontSize.xxs,
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ),
            // Extension tag
            if (ext.isNotEmpty)
              AppBadge(
                label: ext,
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs2,
                  vertical: AppSpacing.xxs,
                ),
                labelStyle: const TextStyle(
                  fontSize: AppFontSize.xxs,
                  fontFamily: 'monospace',
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
