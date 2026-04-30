import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

/// Screen that shows files associated with a session.
/// Since file data comes from session messages/tools, this screen
/// currently shows a placeholder empty state.
class SessionFilesScreen extends ConsumerWidget {
  /// Creates a [SessionFilesScreen] for the given [sessionId].
  const SessionFilesScreen({
    required this.sessionId,
    this.embedded = false,
    this.onClose,
    super.key,
  });

  /// The ID of the session whose files are shown.
  final String sessionId;

  /// When true, render as a pane inside a tablet master-detail layout.
  /// Skips the outer [Scaffold]/[AppBar] and uses a thin in-pane header.
  final bool embedded;

  /// Called when the in-pane close button is tapped (embedded only).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(
      sessionsNotifierProvider.select((s) => s[sessionId]),
    );
    final body = session == null
        ? const _SessionNotFound()
        : const _EmptyFilesView();
    final title = context.l10n.sessionFilesTitle;

    if (!embedded) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: const [
            IconButton(
              icon: Icon(Icons.refresh),
              // TODO(i18n): refresh tooltip not yet localized
              tooltip: 'Refresh',
              onPressed: null,
            ),
          ],
        ),
        body: body,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilesEmbeddedHeader(title: title, onClose: onClose),
        Expanded(child: body),
      ],
    );
  }
}

class _FilesEmbeddedHeader extends StatelessWidget {
  const _FilesEmbeddedHeader({required this.title, this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: AppBorder.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              // TODO(i18n): close tooltip not yet localized
              tooltip: 'Close',
              onPressed: onClose,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

/// View shown when the session doesn't exist.
class _SessionNotFound extends StatelessWidget {
  const _SessionNotFound();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: context.l10n.sessionFilesNotFound,
    );
  }
}

/// Empty state view when no files are available yet.
class _EmptyFilesView extends StatelessWidget {
  const _EmptyFilesView();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.folder_open_outlined,
      title: context.l10n.sessionFilesEmpty,
      subtitle: context.l10n.sessionFilesEmptySubtitle,
    );
  }
}
