/// Presence status for a friend.
///
/// Note: live presence data is not yet available from the server.
/// All friends default to [FriendPresence.offline] until a
/// presence subscription is implemented.
enum FriendPresence {
  /// Friend is currently online and active.
  online,

  /// Friend is online but has been idle for a while.
  away,

  /// Friend is not reachable.
  offline;

  /// Parse a raw wire string, falling back to [offline].
  static FriendPresence fromString(String? raw) {
    switch (raw) {
      case 'online':
        return FriendPresence.online;
      case 'away':
        return FriendPresence.away;
      default:
        return FriendPresence.offline;
    }
  }
}

/// A friend entry as returned by the server.
///
/// Only a minimal schema is defined here. Extend as the
/// friends API evolves.
class Friend {
  const Friend({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.presence = FriendPresence.offline,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: (json['id'] as String?) ?? '',
      displayName: (json['displayName'] as String?) ??
          (json['username'] as String?) ??
          '',
      avatarUrl: json['avatarUrl'] as String?,
      presence: FriendPresence.fromString(json['presence'] as String?),
    );
  }

  /// Unique identifier.
  final String id;

  /// Human-readable name shown in the UI.
  final String displayName;

  /// Optional remote avatar URL.
  final String? avatarUrl;

  /// Current online/away/offline presence.
  ///
  /// Defaults to [FriendPresence.offline] when not provided by the server.
  final FriendPresence presence;

  Friend copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    FriendPresence? presence,
  }) {
    return Friend(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      presence: presence ?? this.presence,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'presence': presence.name,
    };
  }
}
