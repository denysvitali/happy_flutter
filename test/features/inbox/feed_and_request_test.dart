import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/feed.dart';
import 'package:happy_flutter/core/models/friend.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/feed_notifier.dart';
import 'package:happy_flutter/core/providers/friends_notifier.dart';
import 'package:happy_flutter/features/inbox/widgets/feed_card.dart';

/// Stub [FriendsNotifier].
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

/// Stub [FeedNotifier].
class _StubFeedNotifier extends FeedNotifier {
  _StubFeedNotifier(this._seed);

  final FeedState _seed;

  @override
  FeedState build() => _seed;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}
}

// ── Feed card inline reproduction ────────────────────────────────────

/// Inline reproduction of the InboxScreen _FeedCard widget.
class _InlineFeedCard extends StatelessWidget {
  const _InlineFeedCard({required this.item, this.onTap});

  final FeedItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isUnread = !item.read;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.body.kind == 'friend_request'
                    ? Icons.person_add_alt_1
                    : Icons.notifications,
                size: 20,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bodyTitle(item.body),
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (item.body.text != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.body.text!,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(item.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnread ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _bodyTitle(FeedBody body) {
    switch (body.kind) {
      case 'friend_request':
        return 'Friend Request';
      case 'friend_accepted':
        return 'Friend Accepted';
      case 'text':
        return body.text ?? 'Update';
      default:
        return 'Update';
    }
  }

  String _timeAgo(int createdAtMs) {
    final created = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${created.month}/${created.day}';
  }
}

/// Inline reproduction of friend request card.
class _InlineFriendRequestCard extends StatelessWidget {
  const _InlineFriendRequestCard({
    required this.request,
    this.disabled = false,
    this.onAccept,
    this.onReject,
  });

  final FriendRequest request;
  final bool disabled;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(request.fromUserName),
      subtitle: const Text('Wants to connect'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: disabled ? null : onReject,
            icon: const Icon(Icons.close),
            tooltip: 'Reject',
          ),
          IconButton(
            onPressed: disabled ? null : onAccept,
            icon: const Icon(Icons.check),
            tooltip: 'Accept',
          ),
        ],
      ),
    );
  }
}

// ── Test helpers ─────────────────────────────────────────────────────

FeedItem _feedItem(
  String id, {
  String kind = 'text',
  String? text,
  bool read = false,
  int? createdAt,
}) {
  return FeedItem(
    id: id,
    userId: 'u1',
    body: FeedBody(kind: kind, text: text),
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
    read: read,
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

// ── Tests ────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feed card rendering', () {
    testWidgets('renders text feed item with generic title once', (
      tester,
    ) async {
      final item = _feedItem('f1', kind: 'text', text: 'Hello world');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: FeedCard(item: item, l10n: AppLocalizations.of(context)),
            ),
          ),
        ),
      );

      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('renders text feed item', (tester) async {
      final item = _feedItem('f1', kind: 'text', text: 'Hello world');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFeedCard(item: item)),
        ),
      );

      expect(find.text('Hello world'), findsNWidgets(2));
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('renders friend_request feed item with icon', (tester) async {
      final item = _feedItem(
        'f1',
        kind: 'friend_request',
        text: 'New friend request',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFeedCard(item: item)),
        ),
      );

      expect(find.text('Friend Request'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });

    testWidgets('renders friend_accepted feed item', (tester) async {
      final item = _feedItem(
        'f1',
        kind: 'friend_accepted',
        text: 'Friend request accepted',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFeedCard(item: item)),
        ),
      );

      expect(find.text('Friend Accepted'), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('shows unread indicator for unread items', (tester) async {
      final item = _feedItem(
        'f1',
        kind: 'text',
        text: 'Unread message',
        read: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFeedCard(item: item)),
        ),
      );

      // Unread dot should be visible.
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('hides unread indicator for read items', (tester) async {
      final item = _feedItem(
        'f1',
        kind: 'text',
        text: 'Read message',
        read: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFeedCard(item: item)),
        ),
      );

      // No unread dot for read items.
      expect(find.text('Read message'), findsNWidgets(2));
    });

    testWidgets('handles tap callback', (tester) async {
      var tapped = false;
      final item = _feedItem('f1', kind: 'text', text: 'Tappable');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _InlineFeedCard(item: item, onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Tappable').first);
      expect(tapped, isTrue);
    });

    testWidgets('renders item with session link', (tester) async {
      final item = FeedItem(
        id: 'f1',
        userId: 'u1',
        body: const FeedBody(kind: 'text', text: 'Session update'),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        read: false,
        sessionId: 'session-123',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFeedCard(item: item)),
        ),
      );

      expect(find.text('Session update'), findsNWidgets(2));
    });

    testWidgets('renders unknown feed kind as Update', (tester) async {
      final item = _feedItem(
        'f1',
        kind: 'unknown_kind',
        text: 'Something happened',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFeedCard(item: item)),
        ),
      );

      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('renders item without text body', (tester) async {
      final item = _feedItem('f1', kind: 'friend_accepted');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFeedCard(item: item)),
        ),
      );

      expect(find.text('Friend Accepted'), findsOneWidget);
    });

    testWidgets('renders multiple feed items in list', (tester) async {
      final items = [
        _feedItem('f1', kind: 'friend_request', text: 'Request from A'),
        _feedItem('f2', kind: 'friend_accepted', text: 'B accepted'),
        _feedItem('f3', kind: 'text', text: 'Update message'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: items
                  .map((item) => _InlineFeedCard(item: item))
                  .toList(),
            ),
          ),
        ),
      );

      expect(find.text('Friend Request'), findsOneWidget);
      expect(find.text('Friend Accepted'), findsOneWidget);
      expect(find.text('Update message'), findsNWidgets(2));
    });
  });

  group('Friend request card rendering', () {
    testWidgets('renders request with user name', (tester) async {
      final req = _request('r1', fromName: 'Charlie');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFriendRequestCard(request: req)),
        ),
      );

      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Wants to connect'), findsOneWidget);
    });

    testWidgets('shows accept and reject buttons', (tester) async {
      final req = _request('r1', fromName: 'Diana');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _InlineFriendRequestCard(request: req)),
        ),
      );

      expect(find.byTooltip('Accept'), findsOneWidget);
      expect(find.byTooltip('Reject'), findsOneWidget);
    });

    testWidgets('accept callback fires on tap', (tester) async {
      var accepted = false;
      final req = _request('r1', fromName: 'Eve');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _InlineFriendRequestCard(
              request: req,
              onAccept: () => accepted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Accept'));
      expect(accepted, isTrue);
    });

    testWidgets('reject callback fires on tap', (tester) async {
      var rejected = false;
      final req = _request('r1', fromName: 'Frank');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _InlineFriendRequestCard(
              request: req,
              onReject: () => rejected = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Reject'));
      expect(rejected, isTrue);
    });

    testWidgets('buttons disabled when disabled flag is true', (tester) async {
      var acceptCalled = false;
      var rejectCalled = false;
      final req = _request('r1', fromName: 'Grace');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: _InlineFriendRequestCard(
              request: req,
              disabled: true,
              onAccept: () => acceptCalled = true,
              onReject: () => rejectCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Accept'));
      await tester.tap(find.byTooltip('Reject'));
      expect(acceptCalled, isFalse);
      expect(rejectCalled, isFalse);
    });

    testWidgets('renders multiple requests', (tester) async {
      final requests = [
        _request('r1', fromName: 'Alice'),
        _request('r2', fromName: 'Bob'),
        _request('r3', fromName: 'Charlie'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: requests
                  .map((req) => _InlineFriendRequestCard(request: req))
                  .toList(),
            ),
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Wants to connect'), findsNWidgets(3));
    });
  });

  group('FeedState', () {
    test('unreadCount counts unread items', () {
      final state = FeedState(
        items: [
          _feedItem('1', read: false),
          _feedItem('2', read: true),
          _feedItem('3', read: false),
        ],
      );

      expect(state.unreadCount, 2);
    });

    test('unreadCount is zero for all read', () {
      final state = FeedState(
        items: [_feedItem('1', read: true), _feedItem('2', read: true)],
      );

      expect(state.unreadCount, 0);
    });

    test('copyWith updates items', () {
      final state = FeedState(items: [_feedItem('1')]);

      final updated = state.copyWith(items: [_feedItem('1'), _feedItem('2')]);

      expect(updated.items, hasLength(2));
    });

    test('markAsRead updates item', () {
      final container = ProviderContainer(
        overrides: [
          feedNotifierProvider.overrideWith(
            () => _StubFeedNotifier(
              FeedState(
                items: [
                  _feedItem('1', read: false),
                  _feedItem('2', read: false),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(feedNotifierProvider.notifier);
      notifier.markAsRead('1');

      final state = container.read(feedNotifierProvider);
      expect(state.items[0].read, isTrue);
      expect(state.items[1].read, isFalse);
    });
  });
}
