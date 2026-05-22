import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/friends_api.dart';
import '../models/friend_request.dart';
import '../services/logger_service.dart' show logger;

// ─── FriendsState ─────────────────────────────────────────────────────────────

/// Immutable state for the friends / friend-requests feature.
class FriendsState {
  const FriendsState({
    this.pendingRequests = const [],
    this.isLoading = false,
    this.error,
    // Set of request IDs currently being acted on (accept/decline in-flight).
    this.pendingActionIds = const {},
  });

  final List<FriendRequest> pendingRequests;
  final bool isLoading;
  final String? error;
  final Set<String> pendingActionIds;

  FriendsState copyWith({
    List<FriendRequest>? pendingRequests,
    bool? isLoading,
    Object? error = _unset,
    Set<String>? pendingActionIds,
  }) {
    return FriendsState(
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error == _unset ? this.error : error as String?,
      pendingActionIds: pendingActionIds ?? this.pendingActionIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendsState &&
          other.isLoading == isLoading &&
          other.error == error &&
          _listEquals(other.pendingRequests, pendingRequests) &&
          _setEquals(other.pendingActionIds, pendingActionIds);

  @override
  int get hashCode => Object.hash(
        isLoading,
        error,
        Object.hashAll(pendingRequests),
        Object.hashAll(pendingActionIds),
      );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

const _unset = Object();

// ─── FriendsNotifier ──────────────────────────────────────────────────────────

class FriendsNotifier extends Notifier<FriendsState> {
  late final FriendsApi _api;

  @override
  FriendsState build() {
    _api = FriendsApi();
    return const FriendsState();
  }

  /// Loads friend requests from the server.
  Future<void> refreshFromSync() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final requests = await _api.fetchPendingRequests();
      state = state.copyWith(
        pendingRequests: requests,
        isLoading: false,
      );
    } catch (e, st) {
      logger.warning('FriendsNotifier.refreshFromSync failed', e, st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Re-reads from a local snapshot (no-op; state is already in memory).
  void loadFromSync() {
    // Friends state is server-driven; nothing to load from local cache.
    // Callers that call this after a socket event should use refreshFromSync().
  }

  /// Optimistically removes the request then calls accept on the API.
  Future<void> acceptRequest(String requestId) async {
    _markPending(requestId);
    _removeOptimistically(requestId);
    final ok = await _api.acceptRequest(requestId);
    _unmarkPending(requestId);
    if (!ok) {
      logger.warning('acceptRequest failed for $requestId — re-fetching');
      await refreshFromSync();
    }
  }

  /// Optimistically removes the request then calls decline on the API.
  Future<void> declineRequest(String requestId) async {
    _markPending(requestId);
    _removeOptimistically(requestId);
    final ok = await _api.declineRequest(requestId);
    _unmarkPending(requestId);
    if (!ok) {
      logger.warning('declineRequest failed for $requestId — re-fetching');
      await refreshFromSync();
    }
  }

  void _removeOptimistically(String requestId) {
    state = state.copyWith(
      pendingRequests: state.pendingRequests
          .where((r) => r.id != requestId)
          .toList(),
    );
  }

  void _markPending(String requestId) {
    state = state.copyWith(
      pendingActionIds: {...state.pendingActionIds, requestId},
    );
  }

  void _unmarkPending(String requestId) {
    state = state.copyWith(
      pendingActionIds: state.pendingActionIds
          .where((id) => id != requestId)
          .toSet(),
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final friendsNotifierProvider =
    NotifierProvider<FriendsNotifier, FriendsState>(FriendsNotifier.new);
