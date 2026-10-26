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
class SessionBoardCollection extends StatefulWidget {
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
  State<SessionBoardCollection> createState() => _SessionBoardCollectionState();
}

class _SessionBoardCollectionState extends State<SessionBoardCollection>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showArchived ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(SessionBoardCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.showArchived ? 1 : 0;
    if (_controller.index != index) _controller.index = index;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppText.label(theme),
          unselectedLabelStyle: AppText.secondary(theme),
          labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          onTap: (index) => widget.onChanged(index == 1),
          tabs: [
            Tab(
              key: const ValueKey('sessions-active-scope'),
              text: '${l10n.sessionsBoardActive} ${widget.activeCount}',
            ),
            Tab(
              key: const ValueKey('sessions-archived-scope'),
              text: '${l10n.sessionsArchivedLabel} ${widget.archivedCount}',
            ),
          ],
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class SessionBoardEmpty extends StatelessWidget {
  const SessionBoardEmpty({
    required this.archived,
    this.onCreate,
    this.onShowArchived,
    super.key,
  });

  final bool archived;
  final VoidCallback? onCreate;
  final VoidCallback? onShowArchived;

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
        if (!archived && onShowArchived != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: OutlinedButton.icon(
              onPressed: onShowArchived,
              icon: const Icon(Icons.archive_outlined),
              label: Text(context.l10n.sessionsArchivedLabel),
            ),
          ),
        ],
      ],
    );
  }
}
