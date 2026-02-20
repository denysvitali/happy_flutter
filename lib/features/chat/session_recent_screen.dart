import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/session_utils.dart';
import '../sessions/session_avatar.dart';
import '../sessions/sessions_screen.dart';

/// Screen that shows ALL sessions sorted by date, grouped by
/// "Today"/"Yesterday"/etc. Reuses SessionCard from sessions_screen.dart.
class SessionRecentScreen extends ConsumerWidget {
  /// Creates a [SessionRecentScreen].
  const SessionRecentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final sessionList = sessions.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    String localizeDateGroup(DateGroup group) {
      return switch (group) {
        DateGroup.today => l10n.dateGroupToday,
        DateGroup.yesterday => l10n.dateGroupYesterday,
        DateGroup.lastSevenDays => l10n.dateGroupLastSevenDays,
        DateGroup.older => l10n.dateGroupOlder,
      };
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Recent Sessions')),
      body: sessionList.isEmpty
          ? const _EmptyRecentView()
          : RefreshIndicator(
              onRefresh: () =>
                  ref
                      .read(sessionsNotifierProvider.notifier)
                      .refreshFromSync(),
              child: _SessionRecentList(
                sessionList: sessionList,
                localizeDateGroup: localizeDateGroup,
                showFlavorIcons: settings.showFlavorIcons,
                avatarStyle: _parseAvatarStyle(settings.avatarStyle),
              ),
            ),
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
    _ => null,
  };
}

class _SessionRecentList extends StatelessWidget {
  const _SessionRecentList({
    required this.sessionList,
    required this.localizeDateGroup,
    required this.showFlavorIcons,
    this.avatarStyle,
  });

  final List<Session> sessionList;
  final String Function(DateGroup) localizeDateGroup;
  final bool showFlavorIcons;
  final AvatarStyle? avatarStyle;

  @override
  Widget build(BuildContext context) {
    final groupedItems = groupSessionsByDate(
      sessionList,
      localize: localizeDateGroup,
    );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: groupedItems.length,
      itemBuilder: (context, index) {
        final item = groupedItems[index];
        return switch (item) {
          SessionHistoryDateHeader(:final date) => _DateHeader(date: date),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SessionCard(
        session: session,
        onTap: () => context.push('/chat/${session.id}'),
        isFirst: isFirst,
        isLast: isLast,
        isSingle: isSingle,
        showFlavorIcon: showFlavorIcons,
        avatarStyle: avatarStyle,
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        date.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 13,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No recent sessions',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
