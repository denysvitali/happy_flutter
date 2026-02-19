import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/friend.dart';

void main() {
  group('RelationshipStatus parsing', () {
    test('none string returns RelationshipStatus.none', () {
      expect(
        RelationshipStatus.fromString('none'),
        RelationshipStatus.none,
      );
    });

    test('requested string returns RelationshipStatus.requested', () {
      expect(
        RelationshipStatus.fromString('requested'),
        RelationshipStatus.requested,
      );
    });

    test('pending string returns RelationshipStatus.pending', () {
      expect(
        RelationshipStatus.fromString('pending'),
        RelationshipStatus.pending,
      );
    });

    test('friend string returns RelationshipStatus.friend', () {
      expect(
        RelationshipStatus.fromString('friend'),
        RelationshipStatus.friend,
      );
    });

    test('friends alias returns RelationshipStatus.friend', () {
      expect(
        RelationshipStatus.fromString('friends'),
        RelationshipStatus.friend,
      );
    });

    test('rejected string returns RelationshipStatus.rejected', () {
      expect(
        RelationshipStatus.fromString('rejected'),
        RelationshipStatus.rejected,
      );
    });

    test('unknown string falls back to RelationshipStatus.none', () {
      expect(
        RelationshipStatus.fromString('unknown-value'),
        RelationshipStatus.none,
      );
      expect(
        RelationshipStatus.fromString(''),
        RelationshipStatus.none,
      );
      expect(
        RelationshipStatus.fromString('FRIENDS'),
        RelationshipStatus.none,
      );
    });
  });

  group('RelationshipStatus helper properties', () {
    test('isFriend returns true only for friend', () {
      expect(RelationshipStatus.friend.isFriend, isTrue);
      expect(RelationshipStatus.none.isFriend, isFalse);
      expect(RelationshipStatus.requested.isFriend, isFalse);
      expect(RelationshipStatus.rejected.isFriend, isFalse);
    });

    test('isPending returns true for pending statuses', () {
      expect(RelationshipStatus.requested.isPending, isTrue);
      expect(RelationshipStatus.pending.isPending, isTrue);
      expect(RelationshipStatus.none.isPending, isFalse);
      expect(RelationshipStatus.friend.isPending, isFalse);
    });

    test('isRejected returns true for rejected status', () {
      expect(RelationshipStatus.rejected.isRejected, isTrue);
      expect(RelationshipStatus.none.isRejected, isFalse);
      expect(RelationshipStatus.friend.isRejected, isFalse);
    });

    test('value getter returns correct string representation', () {
      expect(RelationshipStatus.none.value, 'none');
      expect(RelationshipStatus.requested.value, 'requested');
      expect(RelationshipStatus.pending.value, 'pending');
      expect(RelationshipStatus.friend.value, 'friend');
      expect(RelationshipStatus.rejected.value, 'rejected');
    });
  });

  group('UserProfile.fromJson', () {
    test('parses required fields correctly', () {
      final json = {
        'id': 'user-123',
        'firstName': 'Jane',
        'username': 'jane123',
        'status': 'friend',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.firstName, 'Jane');
      expect(profile.username, 'jane123');
      expect(profile.status, RelationshipStatus.friend);
    });

    test('parses optional lastName field and displayName', () {
      final json = {
        'id': 'user-456',
        'firstName': 'John',
        'lastName': 'Doe',
        'username': 'johndoe',
        'status': 'none',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.firstName, 'John');
      expect(profile.lastName, 'Doe');
      expect(profile.displayName, 'John Doe');
      expect(profile.name, 'John Doe');
    });

    test('parses optional bio field', () {
      final json = {
        'id': 'user-789',
        'firstName': 'Alice',
        'username': 'alice',
        'bio': 'Hello world',
        'status': 'none',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.bio, 'Hello world');
    });

    test('parses avatar object and exposes avatarUrl getter', () {
      final json = {
        'id': 'user-abc',
        'firstName': 'Bob',
        'username': 'bob',
        'avatar': {
          'path': '/avatars/bob.jpg',
          'url': 'https://cdn.example.com/bob.jpg',
          'width': 200,
          'height': 200,
        },
        'status': 'friend',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.avatar, isNotNull);
      expect(profile.avatar!.url, 'https://cdn.example.com/bob.jpg');
      expect(profile.avatarUrl, 'https://cdn.example.com/bob.jpg');
    });

    test('handles missing optional fields as null', () {
      final json = {
        'id': 'user-ghi',
        'firstName': '',
        'username': '',
        'status': 'none',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.lastName, isNull);
      expect(profile.avatar, isNull);
      expect(profile.avatarUrl, isNull);
      expect(profile.bio, isNull);
    });

    test('handles missing status as none', () {
      final json = {
        'id': 'user-jkl',
        'firstName': 'Eve',
        'username': 'eve',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.status, RelationshipStatus.none);
    });

    test('parses all fields together', () {
      final json = {
        'id': 'user-full',
        'firstName': 'Jane',
        'lastName': 'Smith',
        'username': 'janesmith',
        'bio': 'Software engineer',
        'avatar': {
          'path': '/avatars/jane.jpg',
          'url': 'https://cdn.example.com/jane.jpg',
        },
        'status': 'requested',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-full');
      expect(profile.displayName, 'Jane Smith');
      expect(profile.username, 'janesmith');
      expect(profile.bio, 'Software engineer');
      expect(profile.avatarUrl, 'https://cdn.example.com/jane.jpg');
      expect(profile.status, RelationshipStatus.requested);
    });

    test('toJson serializes all fields', () {
      final profile = UserProfile(
        id: 'user-serial',
        firstName: 'Test',
        lastName: 'User',
        username: 'testuser',
        status: RelationshipStatus.friend,
      );
      final serialized = profile.toJson();

      expect(serialized['id'], 'user-serial');
      expect(serialized['firstName'], 'Test');
      expect(serialized['lastName'], 'User');
      expect(serialized['username'], 'testuser');
      expect(serialized['status'], 'friend');
    });
  });

  group('UserProfile.copyWith', () {
    test('copies with updated firstName', () {
      final original = UserProfile(
        id: 'user-1',
        firstName: 'Original',
        username: 'original',
        status: RelationshipStatus.friend,
      );

      final updated = original.copyWith(firstName: 'Updated');

      expect(updated.id, 'user-1');
      expect(updated.firstName, 'Updated');
      expect(updated.status, RelationshipStatus.friend);
    });

    test('copies with updated status', () {
      final original = UserProfile(
        id: 'user-2',
        firstName: 'Test',
        username: 'test',
        status: RelationshipStatus.none,
      );

      final updated = original.copyWith(
        status: RelationshipStatus.pending,
      );

      expect(updated.status, RelationshipStatus.pending);
    });
  });

  group('FriendRequest.fromJson', () {
    test('parses all required fields', () {
      final json = {
        'id': 'req-123',
        'fromUserId': 'user-from',
        'fromUserName': 'Alice',
        'toUserId': 'user-to',
        'createdAt': 1700000000,
        'status': 'pending',
      };

      final request = FriendRequest.fromJson(json);

      expect(request.id, 'req-123');
      expect(request.fromUserId, 'user-from');
      expect(request.fromUserName, 'Alice');
      expect(request.toUserId, 'user-to');
      expect(request.createdAt, 1700000000);
      expect(request.status, 'pending');
    });

    test('parses optional fromUserAvatarUrl', () {
      final json = {
        'id': 'req-456',
        'fromUserId': 'user-from',
        'fromUserName': 'Bob',
        'fromUserAvatarUrl': 'https://example.com/bob.jpg',
        'toUserId': 'user-to',
        'createdAt': 1700000001,
        'status': 'accepted',
      };

      final request = FriendRequest.fromJson(json);

      expect(request.fromUserAvatarUrl, 'https://example.com/bob.jpg');
      expect(request.status, 'accepted');
    });

    test('handles missing optional fromUserAvatarUrl', () {
      final json = {
        'id': 'req-789',
        'fromUserId': 'user-from',
        'fromUserName': 'Carol',
        'toUserId': 'user-to',
        'createdAt': 1700000002,
        'status': 'rejected',
      };

      final request = FriendRequest.fromJson(json);

      expect(request.fromUserAvatarUrl, isNull);
    });

    test('toJson round-trip preserves all fields', () {
      final json = {
        'id': 'req-rt',
        'fromUserId': 'user-a',
        'fromUserName': 'Dave',
        'fromUserAvatarUrl': 'https://example.com/dave.jpg',
        'toUserId': 'user-b',
        'createdAt': 1700000003,
        'status': 'pending',
      };

      final request = FriendRequest.fromJson(json);
      final serialized = request.toJson();

      expect(serialized['id'], 'req-rt');
      expect(serialized['fromUserId'], 'user-a');
      expect(serialized['fromUserName'], 'Dave');
      expect(serialized['fromUserAvatarUrl'],
          'https://example.com/dave.jpg');
      expect(serialized['toUserId'], 'user-b');
      expect(serialized['createdAt'], 1700000003);
      expect(serialized['status'], 'pending');
    });
  });

  group('AvatarRef', () {
    test('fromJson parses all fields', () {
      final json = {
        'path': '/avatars/test.jpg',
        'url': 'https://cdn.example.com/test.jpg',
        'width': 400,
        'height': 400,
        'thumbhash': 'abc123',
      };

      final ref = AvatarRef.fromJson(json);

      expect(ref.path, '/avatars/test.jpg');
      expect(ref.url, 'https://cdn.example.com/test.jpg');
      expect(ref.width, 400);
      expect(ref.height, 400);
      expect(ref.thumbhash, 'abc123');
    });

    test('toJson serializes non-null fields only', () {
      const ref = AvatarRef(
        path: '/avatars/test.jpg',
        url: 'https://cdn.example.com/test.jpg',
      );

      final json = ref.toJson();

      expect(json['path'], '/avatars/test.jpg');
      expect(json['url'], 'https://cdn.example.com/test.jpg');
      expect(json.containsKey('width'), isFalse);
      expect(json.containsKey('height'), isFalse);
      expect(json.containsKey('thumbhash'), isFalse);
    });
  });
}
