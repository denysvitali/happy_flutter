import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/feed.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('FeedProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with default state', () {
      final state = container.read(feedNotifierProvider);
      expect(state.items, isEmpty);
      expect(state.notifications, isEmpty);
    });

    test('should add a feed item', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final item = FeedItem(
        id: 'feed-1',
        userId: 'user-1',
        userName: 'John Doe',
        userAvatarUrl: 'https://example.com/avatar1.png',
        body: FeedBody(kind: 'session_invite'),
        createdAt: 1234567890,
      );

      notifier.addFeedItem(item);

      final state = container.read(feedNotifierProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.body.kind, 'session_invite');
    });

    test('should add feed items in reverse chronological order', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final item1 = FeedItem(
        id: 'feed-1',
        userId: 'user-1',
        body: FeedBody(kind: 'friend_request'),
        createdAt: 1234567890,
      );

      final item2 = FeedItem(
        id: 'feed-2',
        userId: 'user-2',
        body: FeedBody(kind: 'text'),
        createdAt: 1234567900,
      );

      notifier.addFeedItem(item1);
      notifier.addFeedItem(item2);

      final state = container.read(feedNotifierProvider);
      expect(state.items, hasLength(2));
      expect(state.items.first.id, 'feed-2'); // Newest first
      expect(state.items.last.id, 'feed-1');
    });

    test('should set all feed items at once', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final items = [
        FeedItem(
          id: 'feed-1',
          userId: 'user-1',
          body: FeedBody(kind: 'session_invite'),
          createdAt: 1234567890,
        ),
        FeedItem(
          id: 'feed-2',
          userId: 'user-2',
          body: FeedBody(kind: 'friend_request'),
          createdAt: 1234567891,
        ),
        FeedItem(
          id: 'feed-3',
          userId: 'user-3',
          body: FeedBody(kind: 'text'),
          createdAt: 1234567892,
        ),
      ];

      notifier.setFeedItems(items);

      final state = container.read(feedNotifierProvider);
      expect(state.items, hasLength(3));
    });

    test('should mark a feed item as read', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final item = FeedItem(
        id: 'feed-1',
        userId: 'user-1',
        body: FeedBody(kind: 'friend_request'),
        createdAt: 1234567890,
        read: false,
      );

      notifier.addFeedItem(item);
      expect(container.read(feedNotifierProvider).items.first.read, isFalse);

      notifier.markAsRead('feed-1');

      final state = container.read(feedNotifierProvider);
      expect(state.items.first.read, isTrue);
    });

    test('should mark all feed items as read', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final items = [
        FeedItem(
          id: 'feed-1',
          userId: 'user-1',
          body: FeedBody(kind: 'friend_request'),
          createdAt: 1234567890,
          read: false,
        ),
        FeedItem(
          id: 'feed-2',
          userId: 'user-2',
          body: FeedBody(kind: 'text'),
          createdAt: 1234567891,
          read: false,
        ),
      ];

      notifier.setFeedItems(items);
      expect(container.read(feedNotifierProvider).unreadCount, 2);

      notifier.markAllAsRead();

      final state = container.read(feedNotifierProvider);
      expect(state.unreadCount, 0);
      expect(state.items.every((item) => item.read), isTrue);
    });

    test('should remove a feed item', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final item1 = FeedItem(
        id: 'feed-1',
        userId: 'user-1',
        body: FeedBody(kind: 'friend_request'),
        createdAt: 1234567890,
      );

      final item2 = FeedItem(
        id: 'feed-2',
        userId: 'user-2',
        body: FeedBody(kind: 'text'),
        createdAt: 1234567891,
      );

      notifier.addFeedItem(item1);
      notifier.addFeedItem(item2);

      expect(container.read(feedNotifierProvider).items, hasLength(2));

      notifier.removeFeedItem('feed-1');

      final state = container.read(feedNotifierProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.id, 'feed-2');
    });

    test('should add a notification', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final notification = AppNotification(
        id: 'notif-1',
        type: NotificationType.info,
        title: 'Test Notification',
        body: 'This is a test notification',
        createdAt: 1234567890,
      );

      notifier.addNotification(notification);

      final state = container.read(feedNotifierProvider);
      expect(state.notifications, hasLength(1));
      expect(state.notifications.first.type, NotificationType.info);
    });

    test('should add notifications in reverse chronological order', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final notif1 = AppNotification(
        id: 'notif-1',
        type: NotificationType.info,
        title: 'Notification 1',
        createdAt: 1234567890,
      );

      final notif2 = AppNotification(
        id: 'notif-2',
        type: NotificationType.success,
        title: 'Notification 2',
        createdAt: 1234567900,
      );

      notifier.addNotification(notif1);
      notifier.addNotification(notif2);

      final state = container.read(feedNotifierProvider);
      expect(state.notifications, hasLength(2));
      expect(state.notifications.first.id, 'notif-2'); // Newest first
    });

    test('should set all notifications at once', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final notifications = [
        AppNotification(
          id: 'notif-1',
          type: NotificationType.info,
          title: 'Info',
          createdAt: 1234567890,
        ),
        AppNotification(
          id: 'notif-2',
          type: NotificationType.warning,
          title: 'Warning',
          createdAt: 1234567891,
        ),
        AppNotification(
          id: 'notif-3',
          type: NotificationType.error,
          title: 'Error',
          createdAt: 1234567892,
        ),
      ];

      notifier.setNotifications(notifications);

      final state = container.read(feedNotifierProvider);
      expect(state.notifications, hasLength(3));
    });

    test('should dismiss a notification', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final notification = AppNotification(
        id: 'notif-1',
        type: NotificationType.info,
        title: 'Test Notification',
        createdAt: 1234567890,
        dismissed: false,
      );

      notifier.addNotification(notification);
      expect(
        container.read(feedNotifierProvider).notifications.first.dismissed,
        isFalse,
      );

      notifier.dismissNotification('notif-1');

      final state = container.read(feedNotifierProvider);
      expect(state.notifications.first.dismissed, isTrue);
    });

    test('should count unread items correctly', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final items = [
        FeedItem(
          id: 'feed-1',
          userId: 'user-1',
          body: FeedBody(kind: 'friend_request'),
          createdAt: 1234567890,
          read: true,
        ),
        FeedItem(
          id: 'feed-2',
          userId: 'user-2',
          body: FeedBody(kind: 'text'),
          createdAt: 1234567891,
          read: false,
        ),
        FeedItem(
          id: 'feed-3',
          userId: 'user-3',
          body: FeedBody(kind: 'session_invite'),
          createdAt: 1234567892,
          read: false,
        ),
      ];

      notifier.setFeedItems(items);

      final state = container.read(feedNotifierProvider);
      expect(state.unreadCount, 2);
    });

    test('should count unread notifications correctly', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final notifications = [
        AppNotification(
          id: 'notif-1',
          type: NotificationType.info,
          title: 'Info',
          createdAt: 1234567890,
          dismissed: false,
          readAt: 1234567891,
        ),
        AppNotification(
          id: 'notif-2',
          type: NotificationType.warning,
          title: 'Warning',
          createdAt: 1234567892,
          dismissed: false,
        ),
        AppNotification(
          id: 'notif-3',
          type: NotificationType.success,
          title: 'Success',
          createdAt: 1234567893,
          dismissed: true,
        ),
      ];

      notifier.setNotifications(notifications);

      final state = container.read(feedNotifierProvider);
      expect(state.unreadNotifications, 1); // Only notif-2 is unread and not dismissed
    });

    test('should clear all state', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final item = FeedItem(
        id: 'feed-1',
        userId: 'user-1',
        body: FeedBody(kind: 'friend_request'),
        createdAt: 1234567890,
      );

      final notification = AppNotification(
        id: 'notif-1',
        type: NotificationType.info,
        title: 'Info',
        createdAt: 1234567890,
      );

      notifier.addFeedItem(item);
      notifier.addNotification(notification);

      expect(container.read(feedNotifierProvider).items, isNotEmpty);
      expect(
        container.read(feedNotifierProvider).notifications,
        isNotEmpty,
      );

      notifier.clear();

      final state = container.read(feedNotifierProvider);
      expect(state.items, isEmpty);
      expect(state.notifications, isEmpty);
    });

    test('should handle multiple feed item kinds', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final items = [
        FeedItem(
          id: 'feed-1',
          userId: 'user-1',
          body: FeedBody(kind: 'session_invite'),
          createdAt: 1234567890,
        ),
        FeedItem(
          id: 'feed-2',
          userId: 'user-2',
          body: FeedBody(kind: 'friend_request'),
          createdAt: 1234567891,
        ),
        FeedItem(
          id: 'feed-3',
          userId: 'user-3',
          body: FeedBody(kind: 'friend_accepted'),
          createdAt: 1234567892,
        ),
        FeedItem(
          id: 'feed-4',
          userId: 'user-4',
          body: FeedBody(kind: 'text', text: 'A mention'),
          createdAt: 1234567893,
        ),
        FeedItem(
          id: 'feed-5',
          userId: 'user-5',
          body: FeedBody(kind: 'text', text: 'A reaction'),
          createdAt: 1234567894,
        ),
        FeedItem(
          id: 'feed-6',
          userId: 'user-6',
          body: FeedBody(kind: 'text', text: 'Artifact shared'),
          createdAt: 1234567895,
        ),
        FeedItem(
          id: 'feed-7',
          userId: 'user-7',
          body: FeedBody(kind: 'text', text: 'Session ended'),
          createdAt: 1234567896,
        ),
        FeedItem(
          id: 'feed-8',
          userId: 'user-8',
          body: FeedBody(kind: 'text', text: 'System message'),
          createdAt: 1234567897,
        ),
      ];

      notifier.setFeedItems(items);

      final state = container.read(feedNotifierProvider);
      expect(state.items, hasLength(8));
    });

    test('should handle all notification types', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final notifications = [
        AppNotification(
          id: 'notif-1',
          type: NotificationType.info,
          title: 'Info',
          createdAt: 1234567890,
        ),
        AppNotification(
          id: 'notif-2',
          type: NotificationType.success,
          title: 'Success',
          createdAt: 1234567891,
        ),
        AppNotification(
          id: 'notif-3',
          type: NotificationType.warning,
          title: 'Warning',
          createdAt: 1234567892,
        ),
        AppNotification(
          id: 'notif-4',
          type: NotificationType.error,
          title: 'Error',
          createdAt: 1234567893,
        ),
        AppNotification(
          id: 'notif-5',
          type: NotificationType.sessionUpdate,
          title: 'Session Update',
          createdAt: 1234567894,
        ),
        AppNotification(
          id: 'notif-6',
          type: NotificationType.friendUpdate,
          title: 'Friend Update',
          createdAt: 1234567895,
        ),
        AppNotification(
          id: 'notif-7',
          type: NotificationType.message,
          title: 'Message',
          createdAt: 1234567896,
        ),
      ];

      notifier.setNotifications(notifications);

      final state = container.read(feedNotifierProvider);
      expect(state.notifications, hasLength(7));
    });
  });
}
