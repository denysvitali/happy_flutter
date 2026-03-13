import 'package:flutter/foundation.dart' show listEquals;
import 'package:riverpod/riverpod.dart';

import '../models/feed.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

class FeedNotifier extends Notifier<FeedState> {
  int _lastDataChangeCounter = 0;

  @override
  FeedState build() => FeedState();

  void loadFromSync() {
    if (!sync.isInitialized) return;
    final counter = sync.dataChangeCounter;
    if (counter == _lastDataChangeCounter) return;
    _lastDataChangeCounter = counter;
    final next = sync.feedItems;
    if (listEquals(state.items, next)) return;
    state = state.copyWith(items: next);
  }

  Future<void> refreshFromSync() async {
    if (!sync.isInitialized) {
      return;
    }
    try {
      await sync.feedSync.invalidateAndAwait();
    } catch (e) {
      logger.warning('Failed to refresh feed: $e');
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
  FeedState({this.items = const [], this.notifications = const []});
  final List<FeedItem> items;
  final List<AppNotification> notifications;

  int? _unreadCountCache;
  int? _unreadNotificationsCache;

  FeedState copyWith({
    List<FeedItem>? items,
    List<AppNotification>? notifications,
  }) {
    return FeedState(
      items: items ?? this.items,
      notifications: notifications ?? this.notifications,
    )
      .._unreadCountCache = null
      .._unreadNotificationsCache = null;
  }

  int get unreadCount =>
      _unreadCountCache ??= items.where((i) => !i.read).length;
  int get unreadNotifications =>
      _unreadNotificationsCache ??=
          notifications.where((n) => !n.dismissed && !n.read).length;
}

final feedNotifierProvider = NotifierProvider<FeedNotifier, FeedState>(() {
  return FeedNotifier();
});
