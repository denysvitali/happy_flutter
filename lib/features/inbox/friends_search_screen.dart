import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
      ).showSnackBar(SnackBar(content: Text('Search failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _sendRequest(String userId) async {
    setState(() => _isMutating = true);
    try {
      await _socialService.addFriend(userId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Friend request sent')));
      await _search();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Friends')),
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
                    decoration: const InputDecoration(
                      hintText: 'Search by username',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _isSearching ? null : _search,
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? const Center(
                      child: Text('Search for a username to connect'),
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
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      user.avatarUrl!,
                                      maxWidth: 108,
                                      maxHeight: 108,
                                    )
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(_initials(user.name ?? user.id))
                                  : null,
                            ),
                            title: Text(user.name ?? user.id),
                            subtitle: Text(_statusLabel(user.status)),
                            trailing: FilledButton.tonal(
                              onPressed: isFriend || isPending || _isMutating
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
