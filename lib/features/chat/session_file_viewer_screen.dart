import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';

/// Screen that displays the content of a file in a scrollable monospace view.
///
/// The [path] and optional [content] are passed via the constructor
/// (provided as extra data from go_router).
class SessionFileViewerScreen extends StatelessWidget {
  /// Creates a [SessionFileViewerScreen].
  const SessionFileViewerScreen({
    required this.path,
    this.content,
    super.key,
  });

  /// The full file path to display.
  final String path;

  /// Optional file content to display.
  final String? content;

  /// Extracts the file name from the full path.
  String get _fileName {
    if (path.isEmpty) return 'File';
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = content != null && content!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _fileName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // File path header bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    path,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // File content
          Expanded(
            child: hasContent
                ? _FileContentView(content: content!)
                : const _EmptyContentView(),
          ),
        ],
      ),
    );
  }
}

/// Scrollable monospace view for file content.
class _FileContentView extends StatelessWidget {
  const _FileContentView({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            content,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// View shown when no file content is available.
class _EmptyContentView extends StatelessWidget {
  const _EmptyContentView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).fileViewerNoContent,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)
                .fileViewerContentError,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
