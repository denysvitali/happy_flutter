import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/feed.dart';
import '../models/friend.dart';

/// Service for social features used by Inbox.
class SocialService {
  SocialService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Search users by username query.
  Future<List<UserProfile>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const <UserProfile>[];
    }

    try {
      final response = await _client.get(
        '/v1/user/search',
        queryParameters: <String, dynamic>{'query': trimmed},
      );

      if (!_client.isSuccess(response)) {
        throw SocialServiceException(
          'Failed to search users: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final rawUsers = (data is Map<String, dynamic>) ? data['users'] : data;
      if (rawUsers is! List) {
        return const <UserProfile>[];
      }

      return rawUsers
          .whereType<Map<String, dynamic>>()
          .map(_mapFriendProfile)
          .toList(growable: false);
    } on DioException catch (error) {
      throw SocialServiceException(
        error.message ?? 'Failed to search users',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// Send friend request, or accept an incoming request.
  Future<void> addFriend(String userId) async {
    await _postRelationship('/v1/friends/add', userId);
  }

  /// Remove friend, reject incoming request, or cancel outgoing request.
  Future<void> removeFriend(String userId) async {
    await _postRelationship('/v1/friends/remove', userId);
  }

  /// Fetch latest friends list.
  Future<List<UserProfile>> fetchFriends() async {
    try {
      final response = await _client.get('/v1/friends');

      if (!_client.isSuccess(response)) {
        throw SocialServiceException(
          'Failed to load friends: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final rawFriends = (data is Map<String, dynamic>)
          ? data['friends']
          : data;
      if (rawFriends is! List) {
        return const <UserProfile>[];
      }

      return rawFriends
          .whereType<Map<String, dynamic>>()
          .map(_mapFriendProfile)
          .toList(growable: false);
    } on DioException catch (error) {
      throw SocialServiceException(
        error.message ?? 'Failed to load friends',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// Fetch latest feed items.
  Future<List<FeedItem>> fetchFeed({int limit = 50}) async {
    try {
      final response = await _client.get(
        '/v1/feed',
        queryParameters: <String, dynamic>{'limit': limit},
      );

      if (!_client.isSuccess(response)) {
        throw SocialServiceException(
          'Failed to load feed: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      final data = response.data;
      final rawItems = (data is Map<String, dynamic>) ? data['items'] : data;
      if (rawItems is! List) {
        return const <FeedItem>[];
      }

      return rawItems
          .whereType<Map<String, dynamic>>()
          .map(_mapFeedItem)
          .toList(growable: false);
    } on DioException catch (error) {
      throw SocialServiceException(
        error.message ?? 'Failed to load feed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<void> _postRelationship(String path, String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw const SocialServiceException('User ID cannot be empty');
    }

    try {
      final response = await _client.post(
        path,
        data: <String, dynamic>{'uid': trimmed},
      );

      if (!_client.isSuccess(response)) {
        throw SocialServiceException(
          'Relationship update failed: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (error) {
      throw SocialServiceException(
        error.message ?? 'Relationship update failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  UserProfile _mapFriendProfile(Map<String, dynamic> raw) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = (raw['id'] as String?) ?? (raw['uid'] as String?) ?? 'unknown';
    final firstName = raw['firstName'] as String?;
    final lastName = raw['lastName'] as String?;
    final username = raw['username'] as String?;
    final name = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ').trim();
    final avatar = raw['avatar'];
    String? avatarUrl;
    if (avatar is Map<String, dynamic>) {
      avatarUrl = avatar['url'] as String?;
    } else {
      avatarUrl = raw['avatarUrl'] as String?;
    }

    return UserProfile(
      id: id,
      name: name.isNotEmpty ? name : username,
      email: raw['email'] as String?,
      avatarUrl: avatarUrl,
      status: _mapRelationshipStatus(raw['status'] as String?),
      lastSeenAt: _asInt(raw['lastSeenAt']),
      createdAt: _asInt(raw['createdAt']) ?? now,
    );
  }

  FeedItem _mapFeedItem(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? '';
    final createdAt =
        _asInt(raw['createdAt']) ?? DateTime.now().millisecondsSinceEpoch;
    final bodyRaw = raw['body'];
    final bodyMap = bodyRaw is Map<String, dynamic>
        ? bodyRaw
        : <String, dynamic>{};
    final kind = bodyMap['kind'] as String?;

    FeedType type;
    FeedBody body;
    String userId = raw['userId'] as String? ?? 'system';

    switch (kind) {
      case 'friend_request':
        type = FeedType.friendRequest;
        userId = (bodyMap['uid'] as String?) ?? userId;
        body = FeedBody(
          title: 'Friend request',
          message: 'New friend request',
          extra: bodyMap,
        );
        break;
      case 'friend_accepted':
        type = FeedType.friendAccepted;
        userId = (bodyMap['uid'] as String?) ?? userId;
        body = FeedBody(
          title: 'Friend accepted',
          message: 'Your request was accepted',
          extra: bodyMap,
        );
        break;
      case 'text':
        type = FeedType.system;
        body = FeedBody(
          title: 'Update',
          message: bodyMap['text'] as String?,
          extra: bodyMap,
        );
        break;
      default:
        type = FeedType.system;
        body = FeedBody(
          title: 'Update',
          message: raw['message'] as String?,
          extra: bodyMap.isEmpty ? raw : bodyMap,
        );
        break;
    }

    return FeedItem(
      id: id,
      userId: userId,
      userName: raw['userName'] as String?,
      userAvatarUrl: raw['userAvatarUrl'] as String?,
      type: type,
      body: body,
      createdAt: createdAt,
      read: raw['read'] as bool? ?? false,
      sessionId: raw['sessionId'] as String?,
    );
  }

  RelationshipStatus _mapRelationshipStatus(String? status) {
    switch (status) {
      case 'friend':
      case 'friends':
        return RelationshipStatus.friends;
      case 'requested':
        return RelationshipStatus.pendingOutgoing;
      case 'pending':
        return RelationshipStatus.pendingIncoming;
      case 'blocked':
        return RelationshipStatus.blocked;
      case 'blockedByThem':
        return RelationshipStatus.blockedByThem;
      default:
        return RelationshipStatus.none;
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }
}

class SocialServiceException implements Exception {
  const SocialServiceException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'SocialServiceException: $message';
}
