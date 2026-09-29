import 'package:flutter/foundation.dart' show immutable;

const _unset = Object();

/// Represents an inbound friend request from another user.
@immutable
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.fromDisplayName,
    required this.createdAt,
    this.fromAvatarUrl,
  });

  final String id;
  final String fromUserId;
  final String fromUsername;
  final String fromDisplayName;

  /// Unix timestamp in milliseconds.
  final int createdAt;
  final String? fromAvatarUrl;

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUsername: json['fromUsername'] as String? ?? '',
      fromDisplayName: json['fromDisplayName'] as String? ??
          json['fromUsername'] as String? ??
          '',
      createdAt: (json['createdAt'] as num).toInt(),
      fromAvatarUrl: json['fromAvatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromUserId': fromUserId,
        'fromUsername': fromUsername,
        'fromDisplayName': fromDisplayName,
        'createdAt': createdAt,
        if (fromAvatarUrl != null) 'fromAvatarUrl': fromAvatarUrl,
      };

  FriendRequest copyWith({
    String? id,
    String? fromUserId,
    String? fromUsername,
    String? fromDisplayName,
    int? createdAt,
    Object? fromAvatarUrl = _unset,
  }) {
    return FriendRequest(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      fromUsername: fromUsername ?? this.fromUsername,
      fromDisplayName: fromDisplayName ?? this.fromDisplayName,
      createdAt: createdAt ?? this.createdAt,
      fromAvatarUrl: fromAvatarUrl == _unset
          ? this.fromAvatarUrl
          : fromAvatarUrl as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendRequest &&
          other.id == id &&
          other.fromUserId == fromUserId &&
          other.fromUsername == fromUsername &&
          other.fromDisplayName == fromDisplayName &&
          other.createdAt == createdAt &&
          other.fromAvatarUrl == fromAvatarUrl;

  @override
  int get hashCode => Object.hash(
        id,
        fromUserId,
        fromUsername,
        fromDisplayName,
        createdAt,
        fromAvatarUrl,
      );
}
