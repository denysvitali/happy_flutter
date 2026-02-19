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
      expect(state.friendList.map((f) => f.id).toSet(),
        containsAll(['user-1', 'user-3']));
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

      expect(container.read(friendsNotifierProvider).pendingRequests,
        hasLength(2));

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
      expect(container.read(friendsNotifierProvider).pendingRequests,
        isNotEmpty);

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
}
