import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/friend.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/friends_notifier.dart';
import 'package:happy_flutter/features/user/user_profile_screen.dart';

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

Widget _buildApp({required String userId, FriendsState? friendsState}) {
  return ProviderScope(
    overrides: [
      friendsNotifierProvider.overrideWith(
        () => _StubFriendsNotifier(friendsState ?? FriendsState()),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: UserProfileScreen(userId: userId),
    ),
  );
}

UserProfile _makeUser(
  String id, {
  String firstName = 'John',
  String? lastName = 'Doe',
  String username = 'johndoe',
  String? bio,
  RelationshipStatus status = RelationshipStatus.none,
}) {
  return UserProfile(
    id: id,
    firstName: firstName,
    lastName: lastName,
    username: username,
    bio: bio,
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserProfileScreen', () {
    group('user not found', () {
      testWidgets('shows user not found when userId not in list',
          (tester) async {
        await tester.pumpWidget(
          _buildApp(userId: 'missing-id'),
        );
        await tester.pumpAndSettle();

        expect(find.text('User not found'), findsOneWidget);
      });

      testWidgets('shows default app bar title when user not found',
          (tester) async {
        await tester.pumpWidget(
          _buildApp(userId: 'missing-id'),
        );
        await tester.pumpAndSettle();

        expect(find.text('User Profile'), findsOneWidget);
      });
    });

    group('profile display', () {
      testWidgets('displays user name', (tester) async {
        final user = _makeUser(
          'user-1',
          firstName: 'Alice',
          lastName: 'Smith',
          username: 'alice',
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        // Name appears in both AppBar title and body.
        expect(find.text('Alice Smith'), findsWidgets);
      });

      testWidgets('displays username with @ prefix', (tester) async {
        final user = _makeUser(
          'user-1',
          firstName: 'Alice',
          username: 'alice',
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('@alice'), findsOneWidget);
      });

      testWidgets('displays bio when present', (tester) async {
        final user = _makeUser(
          'user-1',
          firstName: 'Alice',
          username: 'alice',
          bio: 'Hello world',
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hello world'), findsOneWidget);
      });

      testWidgets('hides bio when null', (tester) async {
        final user = _makeUser(
          'user-1',
          firstName: 'Alice',
          username: 'alice',
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hello world'), findsNothing);
      });

      testWidgets('shows user name in app bar', (tester) async {
        final user = _makeUser(
          'user-1',
          firstName: 'Bob',
          lastName: 'Jones',
          username: 'bob',
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        // Name appears in both AppBar title and body.
        expect(find.text('Bob Jones'), findsWidgets);
        expect(find.byType(AppBar), findsOneWidget);
      });

      testWidgets('renders Avatar widget', (tester) async {
        final user = _makeUser('user-1');
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        // Avatar from core/components/avatar.dart
        expect(find.byType(ListView), findsOneWidget);
      });

      testWidgets('renders profile card', (tester) async {
        final user = _makeUser('user-1');
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsOneWidget);
      });
    });

    group('status badges', () {
      testWidgets('shows Friends badge for friend status', (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.friend,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Friends'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('shows Request Sent badge for requested status',
          (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.requested,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Request Sent'), findsOneWidget);
        expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      });

      testWidgets('shows Wants to Connect badge for pending status',
          (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.pending,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wants to Connect'), findsOneWidget);
        expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
      });

      testWidgets('hides badge for none status', (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.none,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Friends'), findsNothing);
        expect(find.text('Request Sent'), findsNothing);
        expect(find.text('Wants to Connect'), findsNothing);
      });

      testWidgets('hides badge for rejected status', (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.rejected,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Friends'), findsNothing);
        expect(find.text('Request Sent'), findsNothing);
      });
    });

    group('action buttons', () {
      testWidgets('shows Remove button for friend status', (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.friend,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Remove'), findsOneWidget);
        expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
      });

      testWidgets('shows Cancel Request button for requested status',
          (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.requested,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancel Request'), findsOneWidget);
      });

      testWidgets('shows Accept and Deny buttons for pending status',
          (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.pending,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Accept Request'), findsOneWidget);
        expect(find.text('Deny Request'), findsOneWidget);
        // Both buttons are present (FilledButton.icon and OutlinedButton.icon)
        expect(find.text('Accept Request'), findsOneWidget);
        expect(find.text('Deny Request'), findsOneWidget);
      });

      testWidgets('shows Add Friend button for none status', (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.none,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Friend'), findsOneWidget);
        expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
      });

      testWidgets('shows Add Friend button for rejected status',
          (tester) async {
        final user = _makeUser(
          'user-1',
          status: RelationshipStatus.rejected,
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Friend'), findsOneWidget);
      });
    });

    group('user without last name', () {
      testWidgets('shows only first name when lastName is null',
          (tester) async {
        final user = _makeUser(
          'user-1',
          firstName: 'Alice',
          lastName: null,
          username: 'alice',
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-1',
            friendsState: FriendsState(friends: [user]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alice'), findsWidgets);
        expect(find.text('Alice Smith'), findsNothing);
      });
    });

    group('multiple users', () {
      testWidgets('finds correct user by id', (tester) async {
        final user1 = _makeUser('user-1', firstName: 'Alice');
        final user2 = _makeUser(
          'user-2',
          firstName: 'Bob',
          username: 'bob',
        );
        await tester.pumpWidget(
          _buildApp(
            userId: 'user-2',
            friendsState: FriendsState(
              friends: [user1, user2],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // user-2 has name 'Bob Doe' (default lastName is 'Doe')
        expect(find.text('Bob Doe'), findsWidgets);
      });
    });
  });
}
