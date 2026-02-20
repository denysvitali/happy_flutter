/// Friend and social relationship models
library;

/// Avatar reference with path, url and optional dimensions.
class AvatarRef {

  const AvatarRef({
    required this.path,
    required this.url,
    this.width,
    this.height,
    this.thumbhash,
  });

  factory AvatarRef.fromJson(Map<String, dynamic> json) {
    return AvatarRef(
      path: (json['path'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      width: json['width'] as int?,
      height: json['height'] as int?,
      thumbhash: json['thumbhash'] as String?,
    );
  }

  final String path;
  final String url;
  final int? width;
  final int? height;
  final String? thumbhash;

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'url': url,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (thumbhash != null) 'thumbhash': thumbhash,
    };
  }
}

/// User profile for friends/social features
class UserProfile {

  UserProfile({
    required this.id,
    required this.firstName,
    required this.username,
    required this.status,
    this.lastName,
    this.avatar,
    this.bio,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final avatarRaw = json['avatar'];
    final avatar = avatarRaw is Map<String, dynamic>
        ? AvatarRef.fromJson(avatarRaw)
        : null;

    return UserProfile(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
      username: json['username'] as String? ?? '',
      avatar: avatar,
      bio: json['bio'] as String?,
      status: RelationshipStatus.fromString(
        json['status'] as String? ?? 'none',
      ),
    );
  }
  final String id;
  final String firstName;
  final String? lastName;
  final String username;
  final AvatarRef? avatar;
  final String? bio;
  final RelationshipStatus status;

  /// Full display name composed from first and optional last name.
  String get displayName =>
      firstName + (lastName != null ? ' $lastName' : '');

  /// Convenience getter returning the display name (falls back to username).
  String? get name =>
      displayName.isNotEmpty ? displayName : username;

  /// Backward-compatible getter returning the avatar URL if available.
  String? get avatarUrl => avatar?.url;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      'username': username,
      if (avatar != null) 'avatar': avatar!.toJson(),
      if (bio != null) 'bio': bio,
      'status': status.value,
    };
  }

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? username,
    AvatarRef? avatar,
    String? bio,
    RelationshipStatus? status,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      status: status ?? this.status,
    );
  }
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

/// Friend request model
class FriendRequest { // 'pending', 'accepted', 'rejected'

  FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.createdAt,
    required this.status,
    this.fromUserAvatarUrl,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUserName: json['fromUserName'] as String,
      fromUserAvatarUrl: json['fromUserAvatarUrl'] as String?,
      toUserId: json['toUserId'] as String,
      createdAt: json['createdAt'] as int,
      status: json['status'] as String,
    );
  }
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String? fromUserAvatarUrl;
  final String toUserId;
  final int createdAt;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'fromUserAvatarUrl': fromUserAvatarUrl,
      'toUserId': toUserId,
      'createdAt': createdAt,
      'status': status,
    };
  }
}
