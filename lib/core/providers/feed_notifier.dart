import 'package:flutter/foundation.dart' show listEquals;
import 'package:riverpod/riverpod.dart';

import '../models/feed.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

class FeedNotifier extends Notifier<FeedState> {
  int _lastDataChangeCounter = -1;

  @override
  FeedState build() => FeedState();

  void loadFromSync() {
    if (!sync.isInitialized) {
      state = state.copyWith(isLoading: false);
      return;
    }
    final counter = sync.domainChangeCounter(SyncDomain.feed);
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.feedItems;
    if (listEquals(state.items, next)) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }
    state = state.copyWith(items: next, isLoading: false, clearError: true);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      state = state.copyWith(isLoading: false);
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await sync.feedSync.invalidateAndAwait();
    } catch (e, stack) {
      logger.warning('Failed to refresh feed', e, stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to refresh feed',
      );
    }
    loadFromSync();
  }

  void markAsRead(String itemId) {
    state = state.copyWith(
      items: state.items.map((item) {
        if (item.id == itemId) {
          return item.copyWith(read: true);
        }
        return item;
      }).toList(),
    );
  }

  void clear() {
    state = FeedState();
  }
}

class FeedState {
  FeedState({
    this.items = const [],
    this.notifications = const [],
    this.isLoading = false,
    this.errorMessage,
  });
  final List<FeedItem> items;
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? errorMessage;

  int? _unreadCountCache;
  int? _unreadNotificationsCache;

  FeedState copyWith({
    List<FeedItem>? items,
    List<AppNotification>? notifications,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return FeedState(
        items: items ?? this.items,
        notifications: notifications ?? this.notifications,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      )
      .._unreadCountCache = null
      .._unreadNotificationsCache = null;
  }

  int get unreadCount =>
      _unreadCountCache ??= items.where((i) => !i.read).length;
  int get unreadNotifications => _unreadNotificationsCache ??= notifications
      .where((n) => !n.dismissed && !n.read)
      .length;
}

final feedNotifierProvider = NotifierProvider<FeedNotifier, FeedState>(() {
  return FeedNotifier();
});
