import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../models/sftp_directory.dart';
import '../providers/sftp_provider.dart';

/// Directory manager screen showing shared folder contents and actions
class SftpDirectoryManagerScreen extends ConsumerStatefulWidget {
  const SftpDirectoryManagerScreen({super.key, required this.directory});

  final SftpDirectory directory;

  @override
  ConsumerState<SftpDirectoryManagerScreen> createState() =>
      _SftpDirectoryManagerScreenState();
}

class _SftpDirectoryManagerScreenState
    extends ConsumerState<SftpDirectoryManagerScreen> {
  List<FileSystemEntity> _entities = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'name'; // name, size, modified, type
  late String _currentPath;

  SftpDirectory get _dir => widget.directory;
  bool get _isSubdirectory => _currentPath != _dir.path;

  @override
  void initState() {
    super.initState();
    _currentPath = _dir.path;
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dir = Directory(_currentPath);
      if (!await dir.exists()) {
        setState(() {
          _error = 'Directory no longer exists';
          _isLoading = false;
        });
        return;
      }

      final entities = await dir.list().toList();
      _sortEntities(entities);

      if (mounted) {
        setState(() {
          _entities = entities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load directory: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _sortEntities(List<FileSystemEntity> entities) {
    entities.sort((a, b) {
      final aIsDir = a is Directory;
      final bIsDir = b is Directory;

      // Directories always first
      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;

      switch (_sortBy) {
        case 'name':
          return p.basename(a.path).compareTo(p.basename(b.path));
        case 'modified':
          try {
            final aStat = a.statSync();
            final bStat = b.statSync();
            return bStat.modified.compareTo(aStat.modified);
          } catch (_) {
            return 0;
          }
        case 'size':
          try {
            final aStat = a.statSync();
            final bStat = b.statSync();
            return bStat.size.compareTo(aStat.size);
          } catch (_) {
            return 0;
          }
        case 'type':
          final aExt = p.extension(a.path).toLowerCase();
          final bExt = p.extension(b.path).toLowerCase();
          return aExt.compareTo(bExt);
        default:
          return 0;
      }
    });
  }

  Future<void> _removeShare() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Share'),
        content: Text(
          'Stop sharing "${_dir.name}"?\n\n'
          'The directory will no longer be accessible via SFTP, '
          'but the files will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(sftpNotifierProvider.notifier).removeDirectory(_dir.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _copyShareUrl() async {
    // Generate a connection reference string
    final ref =
        'sftp://<host>:${_dir.port}/${_dir.remotePath ?? _dir.name}';
    await Clipboard.setData(ClipboardData(text: ref));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection reference copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToSubdirectory(String subPath) {
    setState(() {
      _currentPath = subPath;
    });
    _loadDirectory();
  }

  Future<void> _openFile(String filePath) async {
    final uri = Uri.file(filePath);
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No app found to open this file'),
        ),
      );
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Sort by',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _SortOption(
              title: 'Name',
              icon: Icons.sort_by_alpha,
              isSelected: _sortBy == 'name',
              onTap: () {
                Navigator.pop(ctx);
                _setSortBy('name');
              },
            ),
            _SortOption(
              title: 'Modified',
              icon: Icons.access_time,
              isSelected: _sortBy == 'modified',
              onTap: () {
                Navigator.pop(ctx);
                _setSortBy('modified');
              },
            ),
            _SortOption(
              title: 'Size',
              icon: Icons.data_usage,
              isSelected: _sortBy == 'size',
              onTap: () {
                Navigator.pop(ctx);
                _setSortBy('size');
              },
            ),
            _SortOption(
              title: 'Type',
              icon: Icons.category,
              isSelected: _sortBy == 'type',
              onTap: () {
                Navigator.pop(ctx);
                _setSortBy('type');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setSortBy(String sortBy) {
    setState(() {
      _sortBy = sortBy;
      _sortEntities(_entities);
    });
  }

  @override
  Widget build(BuildContext context) {
    final directorySize = _calculateTotalSize();

    return Scaffold(
      appBar: AppBar(
        leading: _isSubdirectory
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  final parent = p.dirname(_currentPath);
                  if (parent != _dir.path &&
                      _currentPath.startsWith(_dir.path)) {
                    _navigateToSubdirectory(parent);
                  } else {
                    _navigateToSubdirectory(_dir.path);
                  }
                },
              )
            : null,
        title: Text(
          _isSubdirectory
              ? p.basename(_currentPath)
              : _dir.name,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: _copyShareUrl,
            tooltip: 'Copy connection info',
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Sort',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDirectory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Share info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.folder_shared,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPath,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.numbers,
                      label: 'Port ${_dir.port}',
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.lock,
                      label: _dir.authMethod.name,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.paste,
                      label: _dir.clipboardMode.name,
                    ),
                    if (directorySize != null) ...[
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.storage,
                        label: _formatSize(directorySize),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${_entities.length} items',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _removeShare,
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.link_off, size: 18),
                  label: const Text('Remove Share'),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(_error!),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _loadDirectory,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _entities.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder_off,
                                  size: 64,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Empty directory',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDirectory,
                            child: ListView.builder(
                              itemCount: _entities.length,
                              itemBuilder: (context, index) {
                                return _FileEntityTile(
                                  entity: _entities[index],
                                  onDirectoryTap: _navigateToSubdirectory,
                                  onFileTap: _openFile,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  int? _calculateTotalSize() {
    if (_entities.isEmpty) return 0;
    try {
      var total = 0;
      for (final entity in _entities) {
        final stat = entity.statSync();
        total += stat.size;
      }
      return total;
    } catch (_) {
      return null;
    }
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

/// A tile for a single file or directory entry
class _FileEntityTile extends StatelessWidget {
  const _FileEntityTile({
    required this.entity,
    required this.onDirectoryTap,
    required this.onFileTap,
  });

  final FileSystemEntity entity;
  final void Function(String subPath) onDirectoryTap;
  final void Function(String filePath) onFileTap;

  @override
  Widget build(BuildContext context) {
    final isDir = entity is Directory;
    final name = p.basename(entity.path);
    final ext = p.extension(entity.path).toLowerCase();

    IconData icon;
    Color iconColor;

    if (isDir) {
      icon = Icons.folder;
      iconColor = Colors.amber;
    } else {
      final iconData = _getFileIcon(ext);
      icon = iconData.$1;
      iconColor = iconData.$2;
    }

    String? subtitle;
    try {
      final stat = entity.statSync();
      if (!isDir) {
        subtitle = _formatSize(stat.size);
      }
      subtitle = '${subtitle ?? ''}  •  ${_formatDate(stat.modified)}'
          .trim();
    } catch (_) {}

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: isDir
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: () {
        if (isDir) {
          onDirectoryTap(entity.path);
        } else {
          onFileTap(entity.path);
        }
      },
    );
  }

  (IconData, Color) _getFileIcon(String ext) {
    switch (ext) {
      case '.dart':
        return (Icons.code, Colors.blue);
      case '.js':
      case '.ts':
      case '.jsx':
      case '.tsx':
        return (Icons.javascript, Colors.amber);
      case '.py':
        return (Icons.code, Colors.green);
      case '.html':
      case '.css':
        return (Icons.web, Colors.orange);
      case '.json':
      case '.yaml':
      case '.yml':
      case '.toml':
      case '.xml':
        return (Icons.data_object, Colors.teal);
      case '.md':
      case '.txt':
      case '.log':
        return (Icons.description, Colors.grey);
      case '.png':
      case '.jpg':
      case '.jpeg':
      case '.gif':
      case '.svg':
      case '.webp':
        return (Icons.image, Colors.purple);
      case '.mp3':
      case '.wav':
      case '.ogg':
        return (Icons.audio_file, Colors.pink);
      case '.mp4':
      case '.mov':
      case '.avi':
        return (Icons.video_file, Colors.red);
      case '.zip':
      case '.tar':
      case '.gz':
      case '.7z':
      case '.rar':
        return (Icons.archive, Colors.brown);
      case '.pdf':
        return (Icons.picture_as_pdf, Colors.red);
      case '.sh':
      case '.bash':
      case '.zsh':
        return (Icons.terminal, Colors.green);
      default:
        return (Icons.insert_drive_file, Colors.grey);
    }
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

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

/// A chip showing a piece of info
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// A sort option tile
class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(title),
      trailing: isSelected
          ? Icon(
              Icons.check,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: onTap,
    );
  }
}
