import 'package:flutter/material.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.smd,
            ),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    path,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.sm,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: AppBorder.hairline,
            color: theme.colorScheme.outlineVariant,
          ),

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
        padding: AppScreenPadding.standard,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontSize: AppFontSize.md,
              height: AppLineHeight.relaxed,
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
    return AppEmptyState(
      icon: Icons.description_outlined,
      title: AppLocalizations.of(context).fileViewerNoContent,
      subtitle:
          AppLocalizations.of(context).fileViewerContentError,
    );
  }
}
