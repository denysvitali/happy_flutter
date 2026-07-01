import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';

/// Displays the current user's friends list.
///
/// When empty, shows an illustrated empty state with a coaching prompt
/// and a "Find friends" action that navigates to [FriendSearchScreen].
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: l10n.friendsFindFriends,
            onPressed: () => context.pushNamed('friend-search'),
          ),
        ],
      ),
      body: _buildEmptyState(context, l10n),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.people_outline,
      title: l10n.friendsEmptyTitle,
      subtitle: l10n.friendsEmptySubtitle,
      action: FilledButton.icon(
        onPressed: () => context.pushNamed('friend-search'),
        icon: const Icon(Icons.search),
        label: Text(l10n.friendsFindFriends),
      ),
    );
  }
}
