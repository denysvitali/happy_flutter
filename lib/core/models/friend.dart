/// Friend and social relationship models
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'friend.freezed.dart';
part 'friend.g.dart';

/// Avatar reference with path, url and optional dimensions.
@freezed
abstract class AvatarRef with _$AvatarRef {
  const factory AvatarRef({
    @Default('') String path,
    @Default('') String url,
    int? width,
    int? height,
    String? thumbhash,
  }) = _AvatarRef;

  factory AvatarRef.fromJson(Map<String, dynamic> json) =>
      _$AvatarRefFromJson(json);
}

/// Relationship status between users
enum RelationshipStatus {
  none,
  requested,
  pending,
  friend,
  rejected,
  ;

  static RelationshipStatus fromString(String value) {
    switch (value) {
      case 'requested':
        return requested;
      case 'pending':
        return pending;
      case 'friend':
      // backward-compat alias from old server versions
      case 'friends':
        return friend;
      case 'rejected':
        return rejected;
      default:
        return none;
    }
  }

  String get value {
    switch (this) {
      case none:
        return 'none';
      case requested:
        return 'requested';
      case pending:
        return 'pending';
      case friend:
        return 'friend';
      case rejected:
        return 'rejected';
    }
  }

  bool get isFriend => this == friend;
  bool get isPending => this == requested || this == pending;
  bool get isRejected => this == rejected;
}

RelationshipStatus _statusFromJson(String value) =>
    RelationshipStatus.fromString(value);

String _statusToJson(RelationshipStatus status) => status.value;

/// User profile for friends/social features
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    @Default('') String firstName,
    String? lastName,
    @Default('') String username,
    AvatarRef? avatar,
    String? bio,
    @Default(RelationshipStatus.none)
    @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
    RelationshipStatus status,
  }) = _UserProfile;

  const UserProfile._();

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  /// Full display name composed from first and optional last name.
  String get displayName =>
      firstName + (lastName != null ? ' $lastName' : '');

  /// Convenience getter returning the display name (falls back to username).
  String? get name =>
      displayName.isNotEmpty ? displayName : username;

  /// Backward-compatible getter returning the avatar URL if available.
  String? get avatarUrl => avatar?.url;
}

/// Friend request model
@freezed
abstract class FriendRequest with _$FriendRequest {
  const factory FriendRequest({
    required String id,
    required String fromUserId,
    required String fromUserName,
    required String toUserId,
    required int createdAt,
    required String status,
    String? fromUserAvatarUrl,
  }) = _FriendRequest;

  factory FriendRequest.fromJson(Map<String, dynamic> json) =>
      _$FriendRequestFromJson(json);
}
