import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';

/// Screen that shows files associated with a session.
/// Since file data comes from session messages/tools, this screen
/// currently shows a placeholder empty state.
class SessionFilesScreen extends ConsumerWidget {
  /// Creates a [SessionFilesScreen] for the given [sessionId].
  const SessionFilesScreen({required this.sessionId, super.key});

  /// The ID of the session whose files are shown.
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(
      sessionsNotifierProvider.select((s) => s[sessionId]),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sessionFilesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: null,
          ),
        ],
      ),
      body: session == null
          ? const _SessionNotFound()
          : const _EmptyFilesView(),
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
