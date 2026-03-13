import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/friend.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/friends_notifier.dart';

/// Stub [FriendsNotifier] that returns a seeded [FriendsState] and
/// overrides [refreshFromSync] / [loadFromSync] to be no-ops.
class _StubFriendsNotifier extends FriendsNotifier {
  _StubFriendsNotifier(this._seed);

  final FriendsState _seed;

  @override
  FriendsState build() => _seed;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}

// ── Test data helpers ────────────────────────────────────────────────

UserProfile _friend(
  String id, {
  String name = '',
  String username = '',
  String? bio,
  RelationshipStatus status = RelationshipStatus.friend,
}) {
  return UserProfile(
    id: id,
    firstName: name,
    username: username,
    bio: bio,
    status: status,
  );
}

FriendRequest _request(
  String id, {
  String fromName = 'User',
  String status = 'pending',
}) {
  return FriendRequest(
    id: id,
    fromUserId: 'from-$id',
    fromUserName: fromName,
    toUserId: 'me',
    createdAt: DateTime.now().millisecondsSinceEpoch,
    status: status,
  );
}

// ── Inline FriendsScreen reproduction ───────────────────────────────

/// Lightweight inline version of FriendsScreen that avoids
/// SocialService and sync dependencies for widget testing.
class _InlineFriendsScreen extends ConsumerStatefulWidget {
  const _InlineFriendsScreen();

  @override
  ConsumerState<_InlineFriendsScreen> createState() =>
      _InlineFriendsScreenState();
}

class _InlineFriendsScreenState
    extends ConsumerState<_InlineFriendsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future<void>.microtask(() async {
      await ref
          .read(friendsNotifierProvider.notifier)
          .refreshFromSync();
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendsNotifierProvider);
    final friends = friendsState.friendList;
    final incoming = friendsState.incomingRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Friends'),
                  if (friends.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _CountBadge(count: friends.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Requests'),
                  if (incoming.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    _CountBadge(count: incoming.length),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _FriendsTab(friends: friends),
                _RequestsTab(requests: incoming),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Find Friends',
        child: const Icon(Icons.person_add_alt_1),
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({required this.friends});
  final List<UserProfile> friends;

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 64),
          Icon(Icons.people_outline, size: 48),
          SizedBox(height: 8),
          Center(child: Text('No Friends Yet')),
        ],
      );
    }

    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return _FriendTile(friend: friend);
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});
  final UserProfile friend;

  @override
  Widget build(BuildContext context) {
    final name = friend.name ?? friend.id;
    return ListTile(
      key: ValueKey(friend.id),
      title: Text(name),
      subtitle: Text(friend.bio ?? '@${friend.username}'),
      trailing: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.person_remove_outlined),
        tooltip: 'Remove',
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.requests});
  final List<FriendRequest> requests;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 64),
          Icon(Icons.mark_email_read_outlined, size: 48),
          SizedBox(height: 8),
          Center(child: Text('No Incoming Requests')),
        ],
      );
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return _RequestTile(request: req);
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});
  final FriendRequest request;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey(request.id),
      title: Text(request.fromUserName),
      subtitle: const Text('Wants to connect'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.close),
            tooltip: 'Reject',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.check),
            tooltip: 'Accept',
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Tests ────────────────────────────────────────────────────────────

Widget _buildApp({required FriendsState friendsState}) {
  return ProviderScope(
    overrides: [
      friendsNotifierProvider.overrideWith(
        () => _StubFriendsNotifier(friendsState),
      ),
    ],
    child: const MaterialApp(
      home: _InlineFriendsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FriendsScreen', () {
    testWidgets('renders app bar with Friends title',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(friendsState: FriendsState()),
      );
      await tester.pump();

      expect(find.text('Friends'), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows loading indicator initially',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(friendsState: FriendsState()),
      );
      // Before microtask resolves.
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('shows two tabs: Friends and Requests',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(friendsState: FriendsState()),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Friends'), findsWidgets);
      expect(find.text('Requests'), findsOneWidget);
    });

    testWidgets('shows FAB for adding friends', (tester) async {
      await tester.pumpWidget(
        _buildApp(friendsState: FriendsState()),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.byIcon(Icons.person_add_alt_1),
        findsOneWidget,
      );
    });

    group('Friends tab', () {
      testWidgets('shows empty state when no friends',
          (tester) async {
        await tester.pumpWidget(
          _buildApp(friendsState: FriendsState()),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.people_outline),
          findsOneWidget,
        );
        expect(
          find.text('No Friends Yet'),
          findsOneWidget,
        );
      });

      testWidgets('renders friend list items', (tester) async {
        final state = FriendsState(
          friends: [
            _friend(
              'f1',
              name: 'Alice',
              username: 'alice',
              bio: 'Hello',
            ),
            _friend(
              'f2',
              name: 'Bob',
              username: 'bob',
            ),
          ],
        );

        await tester.pumpWidget(
          _buildApp(friendsState: state),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Bob'), findsOneWidget);
        expect(find.text('Hello'), findsOneWidget);
        expect(find.text('@bob'), findsOneWidget);
      });

      testWidgets('shows remove button on friend tiles',
          (tester) async {
        final state = FriendsState(
          friends: [
            _friend(
              'f1',
              name: 'Alice',
              username: 'alice',
            ),
          ],
        );

        await tester.pumpWidget(
          _buildApp(friendsState: state),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.person_remove_outlined),
          findsOneWidget,
        );
        expect(
          find.byTooltip('Remove'),
          findsOneWidget,
        );
      });

      testWidgets('shows count badge when friends exist',
          (tester) async {
        final state = FriendsState(
          friends: [
            _friend('f1', name: 'A', username: 'a'),
            _friend('f2', name: 'B', username: 'b'),
            _friend('f3', name: 'C', username: 'c'),
          ],
        );

        await tester.pumpWidget(
          _buildApp(friendsState: state),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('renders multiple friends in scrollable list',
          (tester) async {
        final friends = List.generate(
          15,
          (i) => _friend(
            'f$i',
            name: 'Friend $i',
            username: 'friend$i',
          ),
        );

        await tester.pumpWidget(
          _buildApp(
            friendsState: FriendsState(friends: friends),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Friend 0'), findsOneWidget);
      });
    });

    group('Requests tab', () {
      testWidgets('shows empty state when no requests',
          (tester) async {
        await tester.pumpWidget(
          _buildApp(friendsState: FriendsState()),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Switch to Requests tab.
        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.mark_email_read_outlined),
          findsOneWidget,
        );
        expect(
          find.text('No Incoming Requests'),
          findsOneWidget,
        );
      });

      testWidgets('renders incoming request items',
          (tester) async {
        final state = FriendsState(
          pendingRequests: [
            _request('r1', fromName: 'Charlie'),
            _request('r2', fromName: 'Diana'),
          ],
        );

        await tester.pumpWidget(
          _buildApp(friendsState: state),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Switch to Requests tab.
        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle();

        expect(find.text('Charlie'), findsOneWidget);
        expect(find.text('Diana'), findsOneWidget);
        expect(
          find.text('Wants to connect'),
          findsNWidgets(2),
        );
      });

      testWidgets('shows accept and reject buttons',
          (tester) async {
        final state = FriendsState(
          pendingRequests: [
            _request('r1', fromName: 'Eve'),
          ],
        );

        await tester.pumpWidget(
          _buildApp(friendsState: state),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle();

        expect(find.byTooltip('Accept'), findsOneWidget);
        expect(find.byTooltip('Reject'), findsOneWidget);
      });

      testWidgets('shows count badge for pending requests',
          (tester) async {
        final state = FriendsState(
          pendingRequests: [
            _request('r1', fromName: 'F'),
            _request('r2', fromName: 'G'),
          ],
        );

        await tester.pumpWidget(
          _buildApp(friendsState: state),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // The badge '2' should appear on the Requests tab.
        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('only shows pending requests, not accepted',
          (tester) async {
        final state = FriendsState(
          pendingRequests: [
            _request('r1', fromName: 'Pending'),
            _request(
              'r2',
              fromName: 'Accepted',
              status: 'accepted',
            ),
          ],
        );

        await tester.pumpWidget(
          _buildApp(friendsState: state),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle();

        expect(find.text('Pending'), findsOneWidget);
        // 'Accepted' should not appear in requests tab.
        expect(find.text('Accepted'), findsNothing);
      });
    });

    group('Combined data', () {
      testWidgets('shows both friends and requests',
          (tester) async {
        final state = FriendsState(
          friends: [
            _friend(
              'f1',
              name: 'Friend',
              username: 'friend',
            ),
          ],
          pendingRequests: [
            _request('r1', fromName: 'Requester'),
          ],
        );

        await tester.pumpWidget(
          _buildApp(friendsState: state),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Friends tab visible by default.
        expect(find.text('Friend'), findsOneWidget);

        // Switch to requests.
        await tester.tap(find.text('Requests'));
        await tester.pumpAndSettle();
        expect(find.text('Requester'), findsOneWidget);
      });
    });
  });
}
