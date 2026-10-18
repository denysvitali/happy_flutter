import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import 'session_list_helpers.dart';

/// Archive overrides hide rows from every live projection. The explicit
/// archive browser still retains them, including before the server catalog
/// acknowledges the already-confirmed archive action.
List<Session> boardArchivedSessions({
  required Map<String, Session> sessions,
  required List<Session> inactive,
  required Set<String> archivedIds,
  required String searchQuery,
  required int? Function(String) timestampFor,
}) {
  final rows = <String, Session>{for (final s in inactive) s.id: s};
  for (final id in archivedIds) {
    final session = sessions[id];
    if (session != null && sessionMatchesSearch(session, searchQuery)) {
      rows[id] = session.copyWith(archived: true);
    }
  }
  int timestamp(Session s) =>
      timestampFor(s.id) ?? s.lastMessageAt ?? s.updatedAt;
  return rows.values.toList()..sort((a, b) {
    final activity = timestamp(b).compareTo(timestamp(a));
    return activity != 0 ? activity : a.id.compareTo(b.id);
  });
}

/// Keeps archived conversations reachable without mixing them with live work.
class SessionBoardCollection extends StatelessWidget {
  const SessionBoardCollection({
    required this.activeCount,
    required this.archivedCount,
    required this.showArchived,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final int activeCount;
  final int archivedCount;
  final bool showArchived;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              ChoiceChip(
                key: const ValueKey('sessions-active-scope'),
                label: Text('${l10n.sessionsBoardActive} $activeCount'),
                selected: !showArchived,
                onSelected: (_) => onChanged(false),
              ),
              const SizedBox(width: AppSpacing.sm),
              ChoiceChip(
                key: const ValueKey('sessions-archived-scope'),
                avatar: const Icon(
                  Icons.archive_outlined,
                  size: AppIconSize.md,
                ),
                label: Text('${l10n.sessionsArchivedLabel} $archivedCount'),
                selected: showArchived,
                onSelected: (_) => onChanged(true),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class SessionBoardEmpty extends StatelessWidget {
  const SessionBoardEmpty({required this.archived, this.onCreate, super.key});

  final bool archived;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        Icon(
          archived ? Icons.archive_outlined : Icons.chat_bubble_outline,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          archived
              ? context.l10n.sessionsBoardNoArchived
              : context.l10n.sessionsBoardNoActive,
          textAlign: TextAlign.center,
          style: AppText.title(Theme.of(context)),
        ),
        if (!archived && onCreate != null) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.sessionsNew),
            ),
          ),
        ],
      ],
    );
  }
}
