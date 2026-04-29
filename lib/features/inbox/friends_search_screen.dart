import 'package:flutter/material.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_tappable.dart';
import '../../core/components/avatar.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/friend.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/social_service.dart';
import '../../core/theme/app_tokens.dart';

class FriendsSearchScreen extends StatefulWidget {
  const FriendsSearchScreen({super.key});

  @override
  State<FriendsSearchScreen> createState() => _FriendsSearchScreenState();
}

class _FriendsSearchScreenState extends State<FriendsSearchScreen> {
  final SocialService _socialService = SocialService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isSearching = false;
  final Set<String> _mutatingUserIds = {};
  bool _hasSearched = false;
  List<UserProfile> _results = const <UserProfile>[];

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const <UserProfile>[];
        _hasSearched = false;
      });
      return;
    }

    final searchFailedMsg = context.l10n.friendsSearchFailed;
    setState(() => _isSearching = true);
    try {
      final results = await _socialService.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _hasSearched = true;
      });
    } catch (error, st) {
      logger.warning('[FriendsSearchScreen] _search failed: $error', error, st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(searchFailedMsg)));
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendRequest(String userId) async {
    final requestSentMsg = context.l10n.friendsRequestSent;
    final actionFailedMsg = context.l10n.friendsActionFailed;
    setState(() => _mutatingUserIds.add(userId));
    try {
      await _socialService.addFriend(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(requestSentMsg)));
      await _search();
    } catch (error, st) {
      logger.warning(
        '[FriendsSearchScreen] _sendRequest failed: userId=$userId $error',
        error,
        st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(actionFailedMsg)));
    } finally {
      if (mounted) setState(() => _mutatingUserIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsAddFriend)),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (value) {
                if (value.isEmpty && _hasSearched) {
                  setState(() {
                    _results = const <UserProfile>[];
                    _hasSearched = false;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: l10n.friendsSearchByUsername,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: SizedBox(
                          width: AppSpacing.xl,
                          height: AppSpacing.xl,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _results = const <UserProfile>[];
                            _hasSearched = false;
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: BorderSide(
                    color: cs.primary,
                    width: AppBorder.thick,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          // Results
          Expanded(child: _buildResults(theme, cs, l10n)),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme, ColorScheme cs, AppLocalizations l10n) {
    // Empty state: never searched yet
    if (!_hasSearched && _results.isEmpty) {
      return AppEmptyState(
        icon: Icons.person_search,
        title: l10n.friendsSearchEmptyTitle,
        subtitle: l10n.friendsSearchEmptySubtitle,
      );
    }

    // Empty state: searched but nothing found
    if (_hasSearched && _results.isEmpty) {
      return AppEmptyState(
        icon: Icons.search_off,
        title: l10n.friendsSearchEmptyTitle,
        subtitle: l10n.friendsSearchEmptySubtitle,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return _SearchResultTile(
          key: ValueKey(user.id),
          user: user,
          l10n: l10n,
          isMutating: _mutatingUserIds.contains(user.id),
          onAdd: () => _sendRequest(user.id),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────
// Search result tile
// ─────────────────────────────────────────────────────

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.user,
    required this.l10n,
    required this.isMutating,
    required this.onAdd,
    super.key,
  });

  final UserProfile user;
  final AppLocalizations l10n;
  final bool isMutating;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isFriend = user.status == RelationshipStatus.friend;
    final isPending = user.status.isPending;
    final name = user.name ?? user.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppTappable(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Avatar(
                id: user.id,
                size: AppTouchTarget.comfortable,
                imageUrl: user.avatarUrl,
              ),
              const SizedBox(width: AppSpacing.md),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xsm),
                    Row(
                      children: [
                        if (isFriend)
                          Icon(Icons.check_circle, size: 14, color: cs.primary),
                        if (isPending)
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                        if (isFriend || isPending)
                          const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            _statusLabel(user.status),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isFriend
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Action button
              if (isFriend)
                FilledButton.tonal(
                  onPressed: null,
                  child: Text(l10n.friendsStatusFriends),
                )
              else if (isPending)
                FilledButton.tonal(
                  onPressed: null,
                  child: Text(l10n.friendsStatusPending),
                )
              else
                FilledButton.icon(
                  onPressed: isMutating ? null : onAdd,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: Text(l10n.friendsAddFriendAction),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.friend:
        return l10n.friendsAlreadyFriends;
      case RelationshipStatus.pending:
        return l10n.friendsIncomingRequest;
      case RelationshipStatus.requested:
        return l10n.friendsRequestPending;
      case RelationshipStatus.rejected:
        return l10n.friendsRequestRejected;
      case RelationshipStatus.none:
        return l10n.friendsNotConnected;
    }
  }
}
