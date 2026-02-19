/// Friend and social relationship models
library;

/// User profile for friends/social features
class UserProfile {

  UserProfile({
    required this.id,
    required this.status, required this.createdAt, this.name,
    this.email,
    this.avatarUrl,
    this.lastSeenAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      status: RelationshipStatus.fromString(
        json['status'] as String? ?? 'none',
      ),
      lastSeenAt: json['lastSeenAt'] as int?,
      createdAt: json['createdAt'] as int,
    );
  }
  final String id;
  final String? name;
  final String? email;
  final String? avatarUrl;
  final RelationshipStatus status;
  final int? lastSeenAt;
  final int createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'status': status.value,
      'lastSeenAt': lastSeenAt,
      'createdAt': createdAt,
    };
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    RelationshipStatus? status,
    int? lastSeenAt,
    int? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Relationship status between users
enum RelationshipStatus {
  none,
  pendingOutgoing,
  pendingIncoming,
  friends,
  blocked,
  blockedByThem,
  ;

  static RelationshipStatus fromString(String value) {
    switch (value) {
      case 'pendingOutgoing':
        return pendingOutgoing;
      case 'pendingIncoming':
        return pendingIncoming;
      case 'friends':
        return friends;
      case 'blocked':
        return blocked;
      case 'blockedByThem':
        return blockedByThem;
      default:
        return none;
    }
  }

  String get value {
    switch (this) {
      case none:
        return 'none';
      case pendingOutgoing:
        return 'pendingOutgoing';
      case pendingIncoming:
        return 'pendingIncoming';
      case friends:
        return 'friends';
      case blocked:
        return 'blocked';
      case blockedByThem:
        return 'blockedByThem';
    }
  }

  bool get isFriend => this == friends;
  bool get isPending => this == pendingOutgoing || this == pendingIncoming;
  bool get isBlocked => this == blocked || this == blockedByThem;
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
