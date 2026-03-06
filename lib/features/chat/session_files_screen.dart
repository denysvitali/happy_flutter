import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final sessions = ref.watch(sessionsNotifierProvider);
    final session = sessions[sessionId];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // File data is not yet available via the sessions provider.
              // This button is a placeholder for future refresh support.
            },
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Session not found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state view when no files are available yet.
class _EmptyFilesView extends StatelessWidget {
  const _EmptyFilesView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No files yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Files modified during the session will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
