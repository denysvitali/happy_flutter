import 'package:flutter/foundation.dart' show listEquals;
import 'package:riverpod/riverpod.dart';

import '../models/friend.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

class FriendsNotifier extends Notifier<FriendsState> {
  int _lastDataChangeCounter = -1;

  @override
  FriendsState build() => FriendsState();

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final nextFriends = sync.friends;
    final nextRequests = sync.friendRequests;
    if (listEquals(state.friends, nextFriends) &&
        listEquals(state.pendingRequests, nextRequests)) {
      return;
    }
    state = state.copyWith(friends: nextFriends, pendingRequests: nextRequests);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.friendsSync.invalidateAndAwait();
    } catch (e, stack) {
      logger.warning('Failed to refresh friends', e, stack);
    }
    loadFromSync();
  }

  void setFriends(List<UserProfile> friends) {
    state = state.copyWith(friends: friends);
  }

  void addFriend(UserProfile friend) {
    state = state.copyWith(friends: [...state.friends, friend]);
  }

  void removeFriend(String userId) {
    state = state.copyWith(
      friends: state.friends.where((f) => f.id != userId).toList(),
    );
  }

  void updateFriendStatus(String userId, RelationshipStatus status) {
    state = state.copyWith(
      friends: state.friends.map((f) {
        if (f.id == userId) {
          return f.copyWith(status: status);
        }
        return f;
      }).toList(),
    );
  }

  void setPendingRequests(List<FriendRequest> requests) {
    state = state.copyWith(pendingRequests: requests);
  }

  void addPendingRequest(FriendRequest request) {
    state = state.copyWith(
      pendingRequests: [...state.pendingRequests, request],
    );
  }

  void removePendingRequest(String requestId) {
    state = state.copyWith(
      pendingRequests: state.pendingRequests
          .where((r) => r.id != requestId)
          .toList(),
    );
  }

  void clear() {
    state = FriendsState();
  }

  /// Applies [fn] (a local state mutation) immediately, then awaits
  /// [action]. Rolls back via [fn] on failure and logs a warning.
  /// Returns whether [action] succeeded.
  Future<bool> optimisticRemove(
    List<UserProfile> Function(FriendsState) itemsGetter,
    void Function(FriendsState, List<UserProfile>) itemsSetter,
    Future<void> Function() action,
  ) async {
    final before = itemsGetter(state);
    itemsSetter(state, before.where((f) => f.id != 'PLACEHOLDER').toList());
    try {
      await action();
      return true;
    } catch (e, stack) {
      itemsSetter(state, before);
      logger.warning(
        'OptimisticMutation: friend action failed, rolled back',
        e,
        stack,
      );
      return false;
    }
  }

  /// Optimistically removes [userId] from the friends list, then calls
  /// [action] to perform the server operation. Rolls back on failure.
  Future<bool> optimisticRemoveFriend(
    String userId,
    Future<void> Function() action,
  ) async {
    final snapshot = state.friends;
    state = state.copyWith(
      friends: state.friends.where((f) => f.id != userId).toList(),
    );
    try {
      await action();
      return true;
    } catch (e, stack) {
      state = state.copyWith(friends: snapshot);
      logger.warning(
        'OptimisticMutation: removeFriend($userId) failed, rolled back',
        e,
        stack,
      );
      return false;
    }
  }
}

class FriendsState {
  FriendsState({this.friends = const [], this.pendingRequests = const []});
  final List<UserProfile> friends;
  final List<FriendRequest> pendingRequests;

  // Cached computed lists — populated lazily on first access.
  List<UserProfile>? _friendList;
  List<FriendRequest>? _incomingRequests;

  FriendsState copyWith({
    List<UserProfile>? friends,
    List<FriendRequest>? pendingRequests,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
    ).._friendList = null
    .._incomingRequests = null;
  }

  List<UserProfile> get friendList => _friendList ??= friends
      .where((f) => f.status == RelationshipStatus.friend)
      .toList();

  List<FriendRequest> get incomingRequests => _incomingRequests ??=
      pendingRequests.where((r) => r.status == 'pending').toList();
}

final friendsNotifierProvider = NotifierProvider<FriendsNotifier, FriendsState>(
  () {
    return FriendsNotifier();
  },
);
