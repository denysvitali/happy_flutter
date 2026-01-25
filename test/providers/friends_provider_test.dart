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
        name: 'John Doe',
        email: 'john@example.com',
        avatarUrl: 'https://example.com/avatar1.png',
        status: RelationshipStatus.friends,
        createdAt: 1234567890,
      );

      notifier.addFriend(friend);

      final state = container.read(friendsNotifierProvider);
      expect(state.friends, hasLength(1));
      expect(state.friends.first.name, 'John Doe');
    });

    test('should set all friends at once', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friends = [
        UserProfile(
          id: 'user-1',
          name: 'John Doe',
          status: RelationshipStatus.friends,
          createdAt: 1234567890,
        ),
        UserProfile(
          id: 'user-2',
          name: 'Jane Smith',
          status: RelationshipStatus.friends,
          createdAt: 1234567891,
        ),
        UserProfile(
          id: 'user-3',
          name: 'Bob Johnson',
          status: RelationshipStatus.friends,
          createdAt: 1234567892,
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
        name: 'John Doe',
        status: RelationshipStatus.friends,
        createdAt: 1234567890,
      );

      final friend2 = UserProfile(
        id: 'user-2',
        name: 'Jane Smith',
        status: RelationshipStatus.friends,
        createdAt: 1234567891,
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
        name: 'John Doe',
        status: RelationshipStatus.pendingOutgoing,
        createdAt: 1234567890,
      );

      notifier.addFriend(friend);

      notifier.updateFriendStatus('user-1', RelationshipStatus.friends);

      final state = container.read(friendsNotifierProvider);
      expect(state.friends.first.status, RelationshipStatus.friends);
    });

    test('should filter friend list correctly', () {
      final notifier = container.read(friendsNotifierProvider.notifier);

      final friends = [
        UserProfile(
          id: 'user-1',
          name: 'Friend 1',
          status: RelationshipStatus.friends,
          createdAt: 1234567890,
        ),
        UserProfile(
          id: 'user-2',
          name: 'Pending 1',
          status: RelationshipStatus.pendingOutgoing,
          createdAt: 1234567891,
        ),
        UserProfile(
          id: 'user-3',
          name: 'Friend 2',
          status: RelationshipStatus.friends,
          createdAt: 1234567892,
        ),
        UserProfile(
          id: 'user-4',
          name: 'Pending 2',
          status: RelationshipStatus.pendingIncoming,
          createdAt: 1234567893,
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
        name: 'John Doe',
        status: RelationshipStatus.friends,
        createdAt: 1234567890,
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
          name: 'Friend',
          status: RelationshipStatus.friends,
          createdAt: 1234567890,
        ),
        UserProfile(
          id: 'user-2',
          name: 'Pending Outgoing',
          status: RelationshipStatus.pendingOutgoing,
          createdAt: 1234567891,
        ),
        UserProfile(
          id: 'user-3',
          name: 'Pending Incoming',
          status: RelationshipStatus.pendingIncoming,
          createdAt: 1234567892,
        ),
        UserProfile(
          id: 'user-4',
          name: 'Blocked',
          status: RelationshipStatus.blocked,
          createdAt: 1234567893,
        ),
        UserProfile(
          id: 'user-5',
          name: 'Blocked By Them',
          status: RelationshipStatus.blockedByThem,
          createdAt: 1234567894,
        ),
        UserProfile(
          id: 'user-6',
          name: 'None',
          status: RelationshipStatus.none,
          createdAt: 1234567895,
        ),
      ];

      notifier.setFriends(friends);

      final state = container.read(friendsNotifierProvider);
      expect(state.friends, hasLength(6));

      final friend = state.friends.firstWhere((f) => f.id == 'user-1');
      expect(friend.status.isFriend, isTrue);
      expect(friend.status.isPending, isFalse);
      expect(friend.status.isBlocked, isFalse);

      final pending = state.friends.firstWhere((f) => f.id == 'user-2');
      expect(pending.status.isPending, isTrue);
      expect(pending.status.isFriend, isFalse);

      final blocked = state.friends.firstWhere((f) => f.id == 'user-4');
      expect(blocked.status.isBlocked, isTrue);
    });
  });
}
