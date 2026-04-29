import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/friend.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('FriendsProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with default state', () {
      final state = container.read(friendsNotifierProvider);
      expect(state.friends, isEmpty);
      expect(state.pendingRequests, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('should add a friend', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friend = UserProfile(
        id: 'user-1',
        firstName: 'John',
        lastName: 'Doe',
        username: 'johndoe',
        avatar: AvatarRef(
          path: '/avatars/1.png',
          url: 'https://example.com/avatar1.png',
        ),
        status: RelationshipStatus.friend,
      );

      notifier.addFriend(friend);

      final state = container.read(friendsNotifierProvider);
      expect(state.friends, hasLength(1));
      expect(state.friends.first.firstName, 'John');
    });

    test('should set all friends at once', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friends = [
        UserProfile(
          id: 'user-1',
          firstName: 'John',
          username: 'john',
          status: RelationshipStatus.friend,
        ),
        UserProfile(
          id: 'user-2',
          firstName: 'Jane',
          username: 'jane',
          status: RelationshipStatus.friend,
        ),
        UserProfile(
          id: 'user-3',
          firstName: 'Bob',
          username: 'bob',
          status: RelationshipStatus.friend,
        ),
      ];

      notifier.setFriends(friends);

      final state = container.read(friendsNotifierProvider);
      expect(state.friends, hasLength(3));
    });

    test('should remove a friend', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friend1 = UserProfile(
        id: 'user-1',
        firstName: 'John',
        username: 'john',
        status: RelationshipStatus.friend,
      );

      final friend2 = UserProfile(
        id: 'user-2',
        firstName: 'Jane',
        username: 'jane',
        status: RelationshipStatus.friend,
      );

      notifier.addFriend(friend1);
      notifier.addFriend(friend2);

      expect(container.read(friendsNotifierProvider).friends, hasLength(2));

      notifier.removeFriend('user-1');

      final state = container.read(friendsNotifierProvider);
      expect(state.friends, hasLength(1));
      expect(state.friends.first.id, 'user-2');
    });

    test('should update friend status', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friend = UserProfile(
        id: 'user-1',
        firstName: 'John',
        username: 'john',
        status: RelationshipStatus.requested,
      );

      notifier.addFriend(friend);

      notifier.updateFriendStatus('user-1', RelationshipStatus.friend);

      final state = container.read(friendsNotifierProvider);
      expect(state.friends.first.status, RelationshipStatus.friend);
    });

    test('should filter friend list correctly', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friends = [
        UserProfile(
          id: 'user-1',
          firstName: 'Friend 1',
          username: 'friend1',
          status: RelationshipStatus.friend,
        ),
        UserProfile(
          id: 'user-2',
          firstName: 'Pending 1',
          username: 'pending1',
          status: RelationshipStatus.requested,
        ),
        UserProfile(
          id: 'user-3',
          firstName: 'Friend 2',
          username: 'friend2',
          status: RelationshipStatus.friend,
        ),
        UserProfile(
          id: 'user-4',
          firstName: 'Pending 2',
          username: 'pending2',
          status: RelationshipStatus.pending,
        ),
      ];

      notifier.setFriends(friends);

      final state = container.read(friendsNotifierProvider);
      expect(state.friends, hasLength(4));
      expect(state.friendList, hasLength(2));
      expect(
        state.friendList.map((f) => f.id).toSet(),
        containsAll(['user-1', 'user-3']),
      );
    });

    test('should add a pending friend request', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final request = FriendRequest(
        id: 'request-1',
        fromUserId: 'user-2',
        fromUserName: 'Jane Smith',
        fromUserAvatarUrl: 'https://example.com/avatar2.png',
        toUserId: 'current-user',
        createdAt: 1234567890,
        status: 'pending',
      );

      notifier.addPendingRequest(request);

      final state = container.read(friendsNotifierProvider);
      expect(state.pendingRequests, hasLength(1));
      expect(state.pendingRequests.first.fromUserName, 'Jane Smith');
    });

    test('should set all pending requests at once', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final requests = [
        FriendRequest(
          id: 'request-1',
          fromUserId: 'user-2',
          fromUserName: 'Jane Smith',
          toUserId: 'current-user',
          createdAt: 1234567890,
          status: 'pending',
        ),
        FriendRequest(
          id: 'request-2',
          fromUserId: 'user-3',
          fromUserName: 'Bob Johnson',
          toUserId: 'current-user',
          createdAt: 1234567891,
          status: 'pending',
        ),
      ];

      notifier.setPendingRequests(requests);

      final state = container.read(friendsNotifierProvider);
      expect(state.pendingRequests, hasLength(2));
    });

    test('should remove a pending request', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final request1 = FriendRequest(
        id: 'request-1',
        fromUserId: 'user-2',
        fromUserName: 'Jane Smith',
        toUserId: 'current-user',
        createdAt: 1234567890,
        status: 'pending',
      );

      final request2 = FriendRequest(
        id: 'request-2',
        fromUserId: 'user-3',
        fromUserName: 'Bob Johnson',
        toUserId: 'current-user',
        createdAt: 1234567891,
        status: 'pending',
      );

      notifier.addPendingRequest(request1);
      notifier.addPendingRequest(request2);

      expect(
        container.read(friendsNotifierProvider).pendingRequests,
        hasLength(2),
      );

      notifier.removePendingRequest('request-1');

      final state = container.read(friendsNotifierProvider);
      expect(state.pendingRequests, hasLength(1));
      expect(state.pendingRequests.first.id, 'request-2');
    });

    test('should filter incoming requests correctly', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final requests = [
        FriendRequest(
          id: 'request-1',
          fromUserId: 'user-2',
          fromUserName: 'Jane Smith',
          toUserId: 'current-user',
          createdAt: 1234567890,
          status: 'pending',
        ),
        FriendRequest(
          id: 'request-2',
          fromUserId: 'user-3',
          fromUserName: 'Bob Johnson',
          toUserId: 'current-user',
          createdAt: 1234567891,
          status: 'accepted',
        ),
      ];

      notifier.setPendingRequests(requests);

      final state = container.read(friendsNotifierProvider);
      expect(state.incomingRequests, hasLength(1));
      expect(state.incomingRequests.first.id, 'request-1');
    });

    test('should clear all state', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friend = UserProfile(
        id: 'user-1',
        firstName: 'John',
        username: 'john',
        status: RelationshipStatus.friend,
      );

      final request = FriendRequest(
        id: 'request-1',
        fromUserId: 'user-2',
        fromUserName: 'Jane Smith',
        toUserId: 'current-user',
        createdAt: 1234567890,
        status: 'pending',
      );

      notifier.addFriend(friend);
      notifier.addPendingRequest(request);

      expect(container.read(friendsNotifierProvider).friends, isNotEmpty);
      expect(
        container.read(friendsNotifierProvider).pendingRequests,
        isNotEmpty,
      );

      notifier.clear();

      final state = container.read(friendsNotifierProvider);
      expect(state.friends, isEmpty);
      expect(state.pendingRequests, isEmpty);
    });

    test('should handle all relationship statuses', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friends = [
        UserProfile(
          id: 'user-1',
          firstName: 'Friend',
          username: 'friend',
          status: RelationshipStatus.friend,
        ),
        UserProfile(
          id: 'user-2',
          firstName: 'Requested',
          username: 'requested',
          status: RelationshipStatus.requested,
        ),
        UserProfile(
          id: 'user-3',
          firstName: 'Pending',
          username: 'pending',
          status: RelationshipStatus.pending,
        ),
        UserProfile(
          id: 'user-4',
          firstName: 'Rejected',
          username: 'rejected',
          status: RelationshipStatus.rejected,
        ),
        UserProfile(
          id: 'user-5',
          firstName: 'None',
          username: 'none',
          status: RelationshipStatus.none,
        ),
      ];

      notifier.setFriends(friends);

      final state = container.read(friendsNotifierProvider);
      expect(state.friends, hasLength(5));

      final friend = state.friends.firstWhere((f) => f.id == 'user-1');
      expect(friend.status.isFriend, isTrue);
      expect(friend.status.isPending, isFalse);
      expect(friend.status.isRejected, isFalse);

      final requested = state.friends.firstWhere((f) => f.id == 'user-2');
      expect(requested.status.isPending, isTrue);
      expect(requested.status.isFriend, isFalse);

      final pending = state.friends.firstWhere((f) => f.id == 'user-3');
      expect(pending.status.isPending, isTrue);
      expect(pending.status.isFriend, isFalse);

      final rejected = state.friends.firstWhere((f) => f.id == 'user-4');
      expect(rejected.status.isRejected, isTrue);
      expect(rejected.status.isFriend, isFalse);
    });
  });

  group('FriendsState', () {
    test('friendList returns only friends with friend status', () {
      final state = FriendsState(
        friends: [
          UserProfile(
            id: '1',
            firstName: 'Friend',
            username: 'f1',
            status: RelationshipStatus.friend,
          ),
          UserProfile(
            id: '2',
            firstName: 'Pending',
            username: 'p1',
            status: RelationshipStatus.pending,
          ),
          UserProfile(
            id: '3',
            firstName: 'Requested',
            username: 'r1',
            status: RelationshipStatus.requested,
          ),
          UserProfile(
            id: '4',
            firstName: 'Rejected',
            username: 'rj1',
            status: RelationshipStatus.rejected,
          ),
          UserProfile(
            id: '5',
            firstName: 'None',
            username: 'n1',
            status: RelationshipStatus.none,
          ),
        ],
      );

      expect(state.friendList, hasLength(1));
      expect(state.friendList.first.id, '1');
    });

    test('incomingRequests returns only pending requests', () {
      final state = FriendsState(
        pendingRequests: [
          FriendRequest(
            id: 'r1',
            fromUserId: 'u1',
            fromUserName: 'Pending',
            toUserId: 'me',
            createdAt: 0,
            status: 'pending',
          ),
          FriendRequest(
            id: 'r2',
            fromUserId: 'u2',
            fromUserName: 'Accepted',
            toUserId: 'me',
            createdAt: 0,
            status: 'accepted',
          ),
          FriendRequest(
            id: 'r3',
            fromUserId: 'u3',
            fromUserName: 'Rejected',
            toUserId: 'me',
            createdAt: 0,
            status: 'rejected',
          ),
        ],
      );

      expect(state.incomingRequests, hasLength(1));
      expect(state.incomingRequests.first.id, 'r1');
    });

    test('copyWith resets cached friendList', () {
      final state = FriendsState(
        friends: [
          UserProfile(
            id: '1',
            firstName: 'A',
            username: 'a',
            status: RelationshipStatus.friend,
          ),
          UserProfile(
            id: '2',
            firstName: 'B',
            username: 'b',
            status: RelationshipStatus.requested,
          ),
        ],
      );

      // Populate cache.
      expect(state.friendList, hasLength(1));

      final updated = state.copyWith(
        friends: [
          UserProfile(
            id: '1',
            firstName: 'A',
            username: 'a',
            status: RelationshipStatus.friend,
          ),
          UserProfile(
            id: '2',
            firstName: 'B',
            username: 'b',
            status: RelationshipStatus.friend,
          ),
        ],
      );

      expect(updated.friendList, hasLength(2));
    });

    test('copyWith resets cached incomingRequests', () {
      final state = FriendsState(
        pendingRequests: [
          FriendRequest(
            id: 'r1',
            fromUserId: 'u1',
            fromUserName: 'X',
            toUserId: 'me',
            createdAt: 0,
            status: 'pending',
          ),
        ],
      );

      // Populate cache.
      expect(state.incomingRequests, hasLength(1));

      final updated = state.copyWith(
        pendingRequests: [
          FriendRequest(
            id: 'r1',
            fromUserId: 'u1',
            fromUserName: 'X',
            toUserId: 'me',
            createdAt: 0,
            status: 'pending',
          ),
          FriendRequest(
            id: 'r2',
            fromUserId: 'u2',
            fromUserName: 'Y',
            toUserId: 'me',
            createdAt: 0,
            status: 'pending',
          ),
        ],
      );

      expect(updated.incomingRequests, hasLength(2));
    });

    test('friendList caches result between accesses', () {
      final state = FriendsState(
        friends: [
          UserProfile(
            id: '1',
            firstName: 'A',
            username: 'a',
            status: RelationshipStatus.friend,
          ),
        ],
      );

      final first = state.friendList;
      final second = state.friendList;
      expect(identical(first, second), isTrue);
    });

    test('incomingRequests caches result between accesses', () {
      final state = FriendsState(
        pendingRequests: [
          FriendRequest(
            id: 'r1',
            fromUserId: 'u1',
            fromUserName: 'X',
            toUserId: 'me',
            createdAt: 0,
            status: 'pending',
          ),
        ],
      );

      final first = state.incomingRequests;
      final second = state.incomingRequests;
      expect(identical(first, second), isTrue);
    });

    test('default state has empty lists', () {
      final state = FriendsState();
      expect(state.friends, isEmpty);
      expect(state.pendingRequests, isEmpty);
      expect(state.friendList, isEmpty);
      expect(state.incomingRequests, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      final friends = [
        UserProfile(
          id: '1',
          firstName: 'A',
          username: 'a',
          status: RelationshipStatus.friend,
        ),
      ];
      final requests = [
        FriendRequest(
          id: 'r1',
          fromUserId: 'u1',
          fromUserName: 'X',
          toUserId: 'me',
          createdAt: 0,
          status: 'pending',
        ),
      ];

      final state = FriendsState(friends: friends, pendingRequests: requests);

      // copyWith with no arguments preserves everything.
      final copy = state.copyWith();
      expect(copy.friends, hasLength(1));
      expect(copy.pendingRequests, hasLength(1));
    });

    test('copyWith preserves and clears load metadata', () {
      final state = FriendsState(isLoading: true, errorMessage: 'failed');

      final updated = state.copyWith(
        friends: [
          UserProfile(
            id: '1',
            firstName: 'A',
            username: 'a',
            status: RelationshipStatus.friend,
          ),
        ],
      );
      expect(updated.isLoading, isTrue);
      expect(updated.errorMessage, 'failed');

      final cleared = updated.copyWith(isLoading: false, clearError: true);
      expect(cleared.isLoading, isFalse);
      expect(cleared.errorMessage, isNull);
    });
  });
}
