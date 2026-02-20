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
    final id = (raw['id'] as String?) ?? (raw['uid'] as String?) ?? 'unknown';
    final firstName = (raw['firstName'] as String?) ?? '';
    final lastName = raw['lastName'] as String?;
    final username = (raw['username'] as String?) ?? '';
    final avatarRaw = raw['avatar'];
    AvatarRef? avatar;
    if (avatarRaw is Map<String, dynamic>) {
      avatar = AvatarRef.fromJson(avatarRaw);
    }

    return UserProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      avatar: avatar,
      bio: raw['bio'] as String?,
      status: RelationshipStatus.fromString(
        raw['status'] as String? ?? 'none',
      ),
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
    final kind = bodyMap['kind'] as String? ?? 'text';
    var userId = raw['userId'] as String? ?? 'system';

    // Derive userId from uid in body for relationship events
    if (kind == 'friend_request' || kind == 'friend_accepted') {
      userId = (bodyMap['uid'] as String?) ?? userId;
    }

    final body = FeedBody(
      kind: kind,
      uid: bodyMap['uid'] as String?,
      text: bodyMap['text'] as String?,
    );

    return FeedItem(
      id: id,
      userId: userId,
      userName: raw['userName'] as String?,
      userAvatarUrl: raw['userAvatarUrl'] as String?,
      body: body,
      createdAt: createdAt,
      read: raw['read'] as bool? ?? false,
      sessionId: raw['sessionId'] as String?,
    );
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
