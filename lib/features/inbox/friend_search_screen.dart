import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';

/// Screen for searching and adding new friends.
///
/// Stub implementation — full search + add flow to be implemented
/// when the friends API is available.
class FriendSearchScreen extends ConsumerStatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  ConsumerState<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState
    extends ConsumerState<FriendSearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendsFindFriends),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SearchBar(
              controller: _controller,
              hintText: l10n.friendsSearchHint,
              leading: const Icon(Icons.search),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
