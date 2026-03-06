import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/models/friend.dart';
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

  bool _isSearching = false;
  bool _isMutating = false;
  List<UserProfile> _results = const <UserProfile>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _results = const <UserProfile>[]);
      return;
    }

    final searchFailedMsg = context.l10n.friendsSearchFailed;
    setState(() => _isSearching = true);
    try {
      final results = await _socialService.searchUsers(query);
      if (!mounted) {
        return;
      }
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(searchFailedMsg)));
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _sendRequest(String userId) async {
    final requestSentMsg = context.l10n.friendsRequestSent;
    final actionFailedMsg = context.l10n.friendsActionFailed;
    setState(() => _isMutating = true);
    try {
      await _socialService.addFriend(userId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(requestSentMsg)));
      await _search();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(actionFailedMsg)));
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsAddFriend)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Search by username',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _isSearching ? null : _search,
                  child: Text(l10n.commonSearch),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Search for friends',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Search for a username to connect',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                              color:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final user = _results[index];
                        final isFriend =
                            user.status == RelationshipStatus.friend;
                        final isPending = user.status.isPending;

                        return Card(
                          key: ValueKey(user.id),
                          elevation: AppElevation.none,
                          margin:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            side: BorderSide(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: theme
                                      .colorScheme
                                      .primaryContainer,
                                  backgroundImage: user.avatarUrl != null
                                      ? CachedNetworkImageProvider(
                                          user.avatarUrl!,
                                          maxWidth: 108,
                                          maxHeight: 108,
                                        )
                                      : null,
                                  child: user.avatarUrl == null
                                      ? Text(
                                          _initials(
                                            user.name ?? user.id,
                                          ),
                                          style: TextStyle(
                                            color: theme.colorScheme
                                                .onPrimaryContainer,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(
                                  width: AppSpacing.md,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name ?? user.id,
                                        style: theme.textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(
                                        height: AppSpacing.xsm,
                                      ),
                                      Text(
                                        _statusLabel(user.status),
                                        style: theme.textTheme
                                            .bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  width: AppSpacing.md,
                                ),
                                FilledButton.tonal(
                                  onPressed: isFriend ||
                                          isPending ||
                                          _isMutating
                                      ? null
                                      : () => _sendRequest(user.id),
                                  child: Text(
                                    isFriend
                                        ? 'Friends'
                                        : isPending
                                        ? 'Pending'
                                        : 'Add',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.friend:
        return 'Already friends';
      case RelationshipStatus.pending:
        return 'Incoming request';
      case RelationshipStatus.requested:
        return 'Request pending';
      case RelationshipStatus.rejected:
        return 'Request rejected';
      case RelationshipStatus.none:
        return 'Not connected';
    }
  }

  String _initials(String value) {
    if (value.isEmpty) {
      return '?';
    }
    return value.substring(0, 1).toUpperCase();
  }
}
