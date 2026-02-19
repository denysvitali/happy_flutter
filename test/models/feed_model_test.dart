import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/feed.dart';

void main() {
  group('FeedBody.fromJson', () {
    test("parses 'friend_request' kind with uid", () {
      final json = {
        'kind': 'friend_request',
        'uid': 'user-abc',
      };

      final body = FeedBody.fromJson(json);

      expect(body.kind, 'friend_request');
      expect(body.uid, 'user-abc');
      expect(body.text, isNull);
    });

    test("parses 'friend_accepted' kind with uid", () {
      final json = {
        'kind': 'friend_accepted',
        'uid': 'user-xyz',
      };

      final body = FeedBody.fromJson(json);

      expect(body.kind, 'friend_accepted');
      expect(body.uid, 'user-xyz');
      expect(body.text, isNull);
    });

    test("parses 'text' kind with text field", () {
      final json = {
        'kind': 'text',
        'text': 'Hello from the feed!',
      };

      final body = FeedBody.fromJson(json);

      expect(body.kind, 'text');
      expect(body.text, 'Hello from the feed!');
      expect(body.uid, isNull);
    });

    test('defaults kind to text when missing', () {
      final json = <String, dynamic>{};

      final body = FeedBody.fromJson(json);

      expect(body.kind, 'text');
    });

    test('handles null uid and text', () {
      final json = {'kind': 'text'};

      final body = FeedBody.fromJson(json);

      expect(body.uid, isNull);
      expect(body.text, isNull);
    });

    test('toJson serializes kind and non-null fields', () {
      const body = FeedBody(
        kind: 'friend_request',
        uid: 'user-123',
      );

      final json = body.toJson();

      expect(json['kind'], 'friend_request');
      expect(json['uid'], 'user-123');
      expect(json.containsKey('text'), isFalse);
    });

    test('toJson omits null fields', () {
      const body = FeedBody(kind: 'text', text: 'Hi!');
      final json = body.toJson();

      expect(json['kind'], 'text');
      expect(json['text'], 'Hi!');
      expect(json.containsKey('uid'), isFalse);
    });
  });

  group('FeedItem.fromJson', () {
    test('parses id, body, and createdAt', () {
      final json = {
        'id': 'feed-item-123',
        'userId': 'user-abc',
        'body': {'kind': 'friend_request', 'uid': 'user-xyz'},
        'createdAt': 1700000000,
      };

      final item = FeedItem.fromJson(json);

      expect(item.id, 'feed-item-123');
      expect(item.createdAt, 1700000000);
      expect(item.body.kind, 'friend_request');
      expect(item.body.uid, 'user-xyz');
    });

    test('parses cursor field', () {
      final json = {
        'id': 'feed-456',
        'userId': 'user-1',
        'body': {'kind': 'text', 'text': 'Hello'},
        'createdAt': 1700000001,
        'cursor': 'cursor-abc',
      };

      final item = FeedItem.fromJson(json);

      expect(item.cursor, 'cursor-abc');
    });

    test('parses counter field', () {
      final json = {
        'id': 'feed-789',
        'userId': 'user-2',
        'body': {'kind': 'text'},
        'createdAt': 1700000002,
        'counter': 5,
      };

      final item = FeedItem.fromJson(json);

      expect(item.counter, 5);
    });

    test('parses repeatKey field', () {
      final json = {
        'id': 'feed-abc',
        'userId': 'user-3',
        'body': {'kind': 'text'},
        'createdAt': 1700000003,
        'repeatKey': 'repeat-key-xyz',
      };

      final item = FeedItem.fromJson(json);

      expect(item.repeatKey, 'repeat-key-xyz');
    });

    test('parses read field defaulting to false', () {
      final json = {
        'id': 'feed-def',
        'userId': 'user-4',
        'body': {'kind': 'text'},
        'createdAt': 1700000004,
      };

      final item = FeedItem.fromJson(json);

      expect(item.read, isFalse);
    });

    test('parses read field when true', () {
      final json = {
        'id': 'feed-ghi',
        'userId': 'user-5',
        'body': {'kind': 'text'},
        'createdAt': 1700000005,
        'read': true,
      };

      final item = FeedItem.fromJson(json);

      expect(item.read, isTrue);
    });

    test('parses optional userName and userAvatarUrl', () {
      final json = {
        'id': 'feed-jkl',
        'userId': 'user-6',
        'userName': 'Alice Smith',
        'userAvatarUrl': 'https://example.com/alice.jpg',
        'body': {'kind': 'text', 'text': 'Mentioned you'},
        'createdAt': 1700000006,
      };

      final item = FeedItem.fromJson(json);

      expect(item.userName, 'Alice Smith');
      expect(item.userAvatarUrl, 'https://example.com/alice.jpg');
    });

    test('handles missing optional fields as null', () {
      final json = {
        'id': 'feed-min',
        'userId': 'user-7',
        'body': {'kind': 'text'},
        'createdAt': 1700000007,
      };

      final item = FeedItem.fromJson(json);

      expect(item.userName, isNull);
      expect(item.userAvatarUrl, isNull);
      expect(item.sessionId, isNull);
      expect(item.repeatKey, isNull);
      expect(item.cursor, isNull);
      expect(item.counter, isNull);
    });

    test('defaults userId to empty string when missing', () {
      final json = {
        'id': 'feed-no-user',
        'body': {'kind': 'text'},
        'createdAt': 1700000008,
      };

      final item = FeedItem.fromJson(json);

      expect(item.userId, '');
    });

    test('handles missing body as empty FeedBody with kind text', () {
      final json = {
        'id': 'feed-no-body',
        'userId': 'user-8',
        'createdAt': 1700000009,
      };

      final item = FeedItem.fromJson(json);

      expect(item.body.kind, 'text');
    });

    test('toJson round-trip preserves all fields', () {
      final original = FeedItem(
        id: 'feed-rt',
        userId: 'user-rt',
        userName: 'Test User',
        body: const FeedBody(kind: 'friend_request', uid: 'user-uid'),
        createdAt: 1700000010,
        cursor: 'cursor-rt',
        counter: 3,
        repeatKey: 'rk-rt',
      );

      final json = original.toJson();

      expect(json['id'], 'feed-rt');
      expect(json['userId'], 'user-rt');
      expect(json['userName'], 'Test User');
      expect(json['createdAt'], 1700000010);
      expect(json['read'], false);
      expect(json['cursor'], 'cursor-rt');
      expect(json['counter'], 3);
      expect(json['repeatKey'], 'rk-rt');
      final bodyJson = json['body'] as Map;
      expect(bodyJson['kind'], 'friend_request');
      expect(bodyJson['uid'], 'user-uid');
    });
  });

  group('FeedItem.copyWith', () {
    test('copies with updated read status', () {
      final item = FeedItem(
        id: 'feed-copy',
        userId: 'user-copy',
        body: const FeedBody(kind: 'text'),
        createdAt: 1700000000,
        read: false,
      );

      final updated = item.copyWith(read: true);

      expect(updated.id, 'feed-copy');
      expect(updated.read, isTrue);
    });

    test('copies with updated cursor', () {
      final item = FeedItem(
        id: 'feed-copy2',
        userId: 'user-copy2',
        body: const FeedBody(kind: 'text'),
        createdAt: 1700000000,
      );

      final updated = item.copyWith(cursor: 'new-cursor');

      expect(updated.cursor, 'new-cursor');
      expect(updated.id, 'feed-copy2');
    });
  });

  group('AppNotification.fromJson', () {
    test('parses all required fields', () {
      final json = {
        'id': 'notif-123',
        'type': 'info',
        'title': 'Test Notification',
        'createdAt': 1700000000,
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.id, 'notif-123');
      expect(notif.type, NotificationType.info);
      expect(notif.title, 'Test Notification');
      expect(notif.createdAt, 1700000000);
    });

    test('parses dismissed field defaulting to false', () {
      final json = {
        'id': 'notif-456',
        'type': 'success',
        'title': 'Success',
        'createdAt': 1700000001,
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.dismissed, isFalse);
    });

    test('read returns true when readAt is set', () {
      final json = {
        'id': 'notif-789',
        'type': 'warning',
        'title': 'Warning',
        'createdAt': 1700000002,
        'readAt': 1700000010,
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.read, isTrue);
      expect(notif.readAt, 1700000010);
    });

    test('read returns false when readAt is null', () {
      final json = {
        'id': 'notif-abc',
        'type': 'info',
        'title': 'Unread',
        'createdAt': 1700000003,
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.read, isFalse);
      expect(notif.readAt, isNull);
    });
  });

  group('NotificationType parsing', () {
    test('parses sessionUpdate type', () {
      expect(
        NotificationType.fromString('sessionUpdate'),
        NotificationType.sessionUpdate,
      );
    });

    test('parses friendUpdate type', () {
      expect(
        NotificationType.fromString('friendUpdate'),
        NotificationType.friendUpdate,
      );
    });

    test('parses message type', () {
      expect(
        NotificationType.fromString('message'),
        NotificationType.message,
      );
    });

    test('unknown type defaults to info', () {
      expect(NotificationType.fromString('unknown'), NotificationType.info);
      expect(NotificationType.fromString(''), NotificationType.info);
    });

    test('value getter returns correct strings', () {
      expect(NotificationType.info.value, 'info');
      expect(NotificationType.success.value, 'success');
      expect(NotificationType.warning.value, 'warning');
      expect(NotificationType.error.value, 'error');
      expect(NotificationType.sessionUpdate.value, 'sessionUpdate');
      expect(NotificationType.friendUpdate.value, 'friendUpdate');
      expect(NotificationType.message.value, 'message');
    });
  });
}
