import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/feed.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('FeedNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    FeedItem createTestFeedItem({
      required String id,
      required String userId,
      required String text,
      bool read = false,
    }) {
      return FeedItem(
        id: id,
        userId: userId,
        body: FeedBody(kind: 'text', text: text),
        createdAt: 1234567890,
        read: read,
      );
    }

    test('should initialize with default empty state', () {
      final state = container.read(feedNotifierProvider);
      expect(state.items, isEmpty);
      expect(state.notifications, isEmpty);
      expect(state.unreadCount, 0);
    });

    test('should load from sync when uninitialized', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      // Should not throw when sync is not initialized
      notifier.loadFromSync();

      final state = container.read(feedNotifierProvider);
      expect(state.items, isEmpty);
    });

    test('should refresh from sync when uninitialized', () async {
      final notifier = container.read(feedNotifierProvider.notifier);

      // Should not throw when sync is not initialized
      await notifier.refreshFromSync();

      final state = container.read(feedNotifierProvider);
      expect(state.items, isEmpty);
    });

    test('should mark item as read', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final items = [
        createTestFeedItem(id: 'item-1', userId: 'user-1', text: 'Test 1', read: false),
        createTestFeedItem(id: 'item-2', userId: 'user-2', text: 'Test 2', read: false),
        createTestFeedItem(id: 'item-3', userId: 'user-3', text: 'Test 3', read: true),
      ];

      // Set items via state copy
      notifier.state = FeedState(items: items);

      expect(container.read(feedNotifierProvider).unreadCount, 2);

      notifier.markAsRead('item-1');

      final state = container.read(feedNotifierProvider);
      expect(state.items[0].read, isTrue);
      expect(state.items[1].read, isFalse);
      expect(state.items[2].read, isTrue);
      expect(state.unreadCount, 1);
    });

    test('should clear all state', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final items = [
        createTestFeedItem(id: 'item-1', userId: 'user-1', text: 'Test 1'),
      ];

      notifier.state = FeedState(items: items);
      expect(container.read(feedNotifierProvider).items, isNotEmpty);

      notifier.clear();

      final state = container.read(feedNotifierProvider);
      expect(state.items, isEmpty);
      expect(state.notifications, isEmpty);
      expect(state.unreadCount, 0);
    });

    test('should handle empty markAsRead', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      // Should not throw when marking non-existent item as read
      notifier.markAsRead('non-existent-item');

      final state = container.read(feedNotifierProvider);
      expect(state.items, isEmpty);
    });

    test('should calculate unread count correctly', () {
      final notifier = container.read(feedNotifierProvider.notifier);

      final items = [
        createTestFeedItem(id: 'item-1', userId: 'user-1', text: 'Test 1', read: false),
        createTestFeedItem(id: 'item-2', userId: 'user-2', text: 'Test 2', read: false),
        createTestFeedItem(id: 'item-3', userId: 'user-3', text: 'Test 3', read: false),
        createTestFeedItem(id: 'item-4', userId: 'user-4', text: 'Test 4', read: true),
        createTestFeedItem(id: 'item-5', userId: 'user-5', text: 'Test 5', read: true),
      ];

      notifier.state = FeedState(items: items);

      final state = container.read(feedNotifierProvider);
      expect(state.unreadCount, 3);
    });

    test('should handle different feed body kinds', () {
      final textBody = FeedBody(kind: 'text', text: 'Hello world');
      final friendRequestBody = FeedBody(kind: 'friend_request', uid: 'user-123');
      final friendAcceptedBody = FeedBody(kind: 'friend_accepted', uid: 'user-456');

      expect(textBody.kind, 'text');
      expect(textBody.text, 'Hello world');
      expect(textBody.uid, isNull);

      expect(friendRequestBody.kind, 'friend_request');
      expect(friendRequestBody.uid, 'user-123');
      expect(friendRequestBody.text, isNull);

      expect(friendAcceptedBody.kind, 'friend_accepted');
      expect(friendAcceptedBody.uid, 'user-456');
    });

    test('should handle feed items with optional fields', () {
      final item = FeedItem(
        id: 'full-item',
        userId: 'user-1',
        userName: 'Test User',
        userAvatarUrl: 'https://example.com/avatar.png',
        body: FeedBody(kind: 'text', text: 'Full test'),
        createdAt: 1234567890,
        read: false,
        sessionId: 'session-123',
        repeatKey: 'repeat-1',
        cursor: 'cursor-abc',
        counter: 5,
      );

      expect(item.userName, 'Test User');
      expect(item.userAvatarUrl, 'https://example.com/avatar.png');
      expect(item.sessionId, 'session-123');
      expect(item.repeatKey, 'repeat-1');
      expect(item.cursor, 'cursor-abc');
      expect(item.counter, 5);
    });

    test('should copy feed item correctly', () {
      final original = createTestFeedItem(id: 'item-1', userId: 'user-1', text: 'Original', read: false);
      final copy = original.copyWith(read: true);

      expect(original.read, isFalse);
      expect(copy.read, isTrue);
      expect(copy.id, original.id);
      expect(copy.userId, original.userId);
      expect(copy.body.text, original.body.text);
    });

    test('should copy feed body correctly', () {
      final original = FeedBody(kind: 'text', text: 'Original');
      final copy = original.copyWith(text: 'Updated');

      expect(original.text, 'Original');
      expect(copy.text, 'Updated');
      expect(copy.kind, original.kind);
    });

    test('should handle feed state copyWith', () {
      final original = FeedState();
      final withItems = original.copyWith(
        items: [createTestFeedItem(id: 'item-1', userId: 'user-1', text: 'Test')],
      );

      expect(original.items, isEmpty);
      expect(withItems.items, hasLength(1));

      final withNotifications = original.copyWith(
        notifications: [
          AppNotification(
            id: 'notif-1',
            type: NotificationType.info,
            title: 'Test Notification',
            createdAt: 1234567890,
          ),
        ],
      );

      expect(withNotifications.notifications, hasLength(1));
    });

    test('should calculate unread notifications correctly', () {
      final notifications = [
        AppNotification(
          id: 'notif-1',
          type: NotificationType.info,
          title: 'Unread 1',
          createdAt: 1234567890,
          dismissed: false,
        ),
        AppNotification(
          id: 'notif-2',
          type: NotificationType.success,
          title: 'Read',
          createdAt: 1234567891,
          dismissed: false,
          readAt: 1234567895,
        ),
        AppNotification(
          id: 'notif-3',
          type: NotificationType.warning,
          title: 'Dismissed',
          createdAt: 1234567892,
          dismissed: true,
        ),
        AppNotification(
          id: 'notif-4',
          type: NotificationType.error,
          title: 'Unread 2',
          createdAt: 1234567893,
          dismissed: false,
        ),
      ];

      final state = FeedState(notifications: notifications);
      expect(state.unreadNotifications, 2); // notif-1 and notif-4
    });

    test('should handle notification types correctly', () {
      expect(NotificationType.info.value, 'info');
      expect(NotificationType.success.value, 'success');
      expect(NotificationType.warning.value, 'warning');
      expect(NotificationType.error.value, 'error');
      expect(NotificationType.sessionUpdate.value, 'sessionUpdate');
      expect(NotificationType.friendUpdate.value, 'friendUpdate');
      expect(NotificationType.message.value, 'message');

      expect(NotificationType.fromString('info'), NotificationType.info);
      expect(NotificationType.fromString('success'), NotificationType.success);
      expect(NotificationType.fromString('unknown'), NotificationType.info); // default fallback
    });

    test('should handle notification read status', () {
      final unread = AppNotification(
        id: 'unread',
        type: NotificationType.info,
        title: 'Unread',
        createdAt: 1234567890,
      );

      final read = AppNotification(
        id: 'read',
        type: NotificationType.info,
        title: 'Read',
        createdAt: 1234567890,
        readAt: 1234567895,
      );

      expect(unread.read, isFalse);
      expect(read.read, isTrue);
    });

    test('should copy notification correctly', () {
      final original = AppNotification(
        id: 'notif-1',
        type: NotificationType.info,
        title: 'Original',
        body: 'Body text',
        createdAt: 1234567890,
        data: {'key': 'value'},
      );

      final copy = original.copyWith(
        title: 'Updated',
        readAt: 1234567895,
      );

      expect(original.title, 'Original');
      expect(copy.title, 'Updated');
      expect(copy.id, original.id);
      expect(copy.type, original.type);
      expect(copy.body, original.body);
      expect(copy.data, original.data);
      expect(copy.read, isTrue);
    });
  });
}
