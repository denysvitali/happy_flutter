import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/tablet/embedded_pane.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/session_utils.dart';
import '../sessions/session_avatar.dart';
import '../sessions/widgets/session_cards.dart';

/// Screen that shows ALL sessions sorted by date, grouped by
/// "Today"/"Yesterday"/etc. Reuses SessionCard from sessions_screen.dart.
class SessionRecentScreen extends ConsumerWidget {
  /// Creates a [SessionRecentScreen].
  const SessionRecentScreen({
    this.embedded = false,
    this.onClose,
    super.key,
  });

  /// When true, render as a pane inside a tablet master-detail layout.
  /// Skips the outer [Scaffold]/[AppBar] and uses a thin in-pane header.
  final bool embedded;

  /// Called when the in-pane close button is tapped (embedded only).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessionIds = ref.watch(recentSessionIdsProvider);
    final showFlavorIcons = ref.watch(
      settingsNotifierProvider.select((s) => s.showFlavorIcons),
    );
    final avatarStyle = ref.watch(
      settingsNotifierProvider.select((s) => _parseAvatarStyle(s.avatarStyle)),
    );

    String localizeDateGroup(DateGroup group) {
      return switch (group) {
        DateGroup.today => l10n.dateGroupToday,
        DateGroup.yesterday => l10n.dateGroupYesterday,
        DateGroup.thisWeek => l10n.dateGroupThisWeek,
        DateGroup.thisMonth => l10n.dateGroupThisMonth,
        DateGroup.older => l10n.dateGroupOlder,
      };
    }

    final body = sessionIds.isEmpty
        ? const _EmptyRecentView()
        : RefreshIndicator(
            onRefresh: () =>
                ref.read(sessionsNotifierProvider.notifier).refreshFromSync(),
            child: _SessionRecentList(
              sessionIds: sessionIds,
              localizeDateGroup: localizeDateGroup,
              showFlavorIcons: showFlavorIcons,
              avatarStyle: avatarStyle,
            ),
          );

    return EmbeddedPaneShell(
      title: l10n.sessionsRecentTitle,
      body: body,
      embedded: embedded,
      onClose: onClose,
    );
  }
}

/// Parses an avatar style string to the corresponding [AvatarStyle] enum.
///
/// Returns null if the string doesn't match a known style
/// (causes hash-based selection).
AvatarStyle? _parseAvatarStyle(String? style) {
  return switch (style) {
    'gradient' => AvatarStyle.gradient,
    'pixelated' => AvatarStyle.pixelated,
    'brutalist' => AvatarStyle.brutalist,
    'geometric' => AvatarStyle.geometric,
    'rings' => AvatarStyle.rings,
    'constellation' => AvatarStyle.constellation,
    'wave' => AvatarStyle.wave,
    _ => null,
  };
}

class _SessionRecentList extends StatelessWidget {
  const _SessionRecentList({
    required this.sessionIds,
    required this.localizeDateGroup,
    required this.showFlavorIcons,
    this.avatarStyle,
  });

  final List<String> sessionIds;
  final String Function(DateGroup) localizeDateGroup;
  final bool showFlavorIcons;
  final AvatarStyle? avatarStyle;

  @override
  Widget build(BuildContext context) {
    final ref = ProviderScope.containerOf(context);
    final sessionList = sessionIds
        .map((id) => ref.read(sessionByIdProvider(id)))
        .whereType<Session>()
        .toList(growable: false);
    final groupedItems = groupSessionsByDate(
      sessionList,
      localize: localizeDateGroup,
      getLastMessageTimestamp: sync.getLastMessageTimestamp,
    );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: groupedItems.length,
      itemBuilder: (context, index) {
        final item = groupedItems[index];
        return switch (item) {
          SessionHistoryDateHeader(:final date) => _DateHeader(
            key: ValueKey(date),
            date: date,
          ),
          SessionHistorySession(:final session) => _buildSessionCard(
            context,
            session,
            groupedItems,
            index,
          ),
        };
      },
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    Session session,
    List<SessionHistoryItem> items,
    int index,
  ) {
    final prevItem = index > 0 ? items[index - 1] : null;
    final nextItem = index < items.length - 1 ? items[index + 1] : null;
    final isFirst = prevItem is SessionHistoryDateHeader;
    final isLast = nextItem is SessionHistoryDateHeader || nextItem == null;
    final isSingle = isFirst && isLast;

    return Padding(
      key: ValueKey(session.id),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: SessionCard(
        session: session,
        onTap: () => context.push('/chat/${session.id}'),
        isFirst: isFirst,
        isLast: isLast,
        isSingle: isSingle,
        showFlavorIcon: showFlavorIcons,
        avatarStyle: avatarStyle,
        lastMessageTimestamp: sync.getLastMessageTimestamp(session.id),
        lastMessagePreview: sync.getLastMessagePreview(session.id),
        lastMessageRole: sync.getLastMessageRole(session.id),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, super.key});

  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: Text(
        date.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: AppFontSize.md,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyRecentView extends StatelessWidget {
  const _EmptyRecentView();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.history,
      title: context.l10n.sessionsRecentEmpty,
    );
  }
}
