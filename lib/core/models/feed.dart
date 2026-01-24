/// Activity feed and notification models

/// Activity feed item
class FeedItem {
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final FeedType type;
  final FeedBody body;
  final int createdAt;
  final bool read;
  final String? sessionId;

  FeedItem({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.type,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.sessionId,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      type: FeedType.fromString(json['type'] as String),
      body: FeedBody.fromJson(json['body'] as Map<String, dynamic>),
      createdAt: json['createdAt'] as int,
      read: json['read'] as bool? ?? false,
      sessionId: json['sessionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'type': type.value,
      'body': body.toJson(),
      'createdAt': createdAt,
      'read': read,
      'sessionId': sessionId,
    };
  }

  FeedItem copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    FeedType? type,
    FeedBody? body,
    int? createdAt,
    bool? read,
    String? sessionId,
  }) {
    return FeedItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      type: type ?? this.type,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

/// Types of feed items
enum FeedType {
  sessionInvite,
  friendRequest,
  friendAccepted,
  mention,
  reaction,
  artifactShared,
  sessionEnded,
  system,
  ;

  static FeedType fromString(String value) {
    switch (value) {
      case 'sessionInvite':
        return sessionInvite;
      case 'friendRequest':
        return friendRequest;
      case 'friendAccepted':
        return friendAccepted;
      case 'mention':
        return mention;
      case 'reaction':
        return reaction;
      case 'artifactShared':
        return artifactShared;
      case 'sessionEnded':
        return sessionEnded;
      default:
        return system;
    }
  }

  String get value {
    switch (this) {
      case sessionInvite:
        return 'sessionInvite';
      case friendRequest:
        return 'friendRequest';
      case friendAccepted:
        return 'friendAccepted';
      case mention:
        return 'mention';
      case reaction:
        return 'reaction';
      case artifactShared:
        return 'artifactShared';
      case sessionEnded:
        return 'sessionEnded';
      case system:
        return 'system';
    }
  }

  String get displayName {
    switch (this) {
      case sessionInvite:
        return 'Session Invite';
      case friendRequest:
        return 'Friend Request';
      case friendAccepted:
        return 'Friend Accepted';
      case mention:
        return 'Mention';
      case reaction:
        return 'Reaction';
      case artifactShared:
        return 'Artifact Shared';
      case sessionEnded:
        return 'Session Ended';
      case system:
        return 'System';
    }
  }
}

/// Feed body content based on type
class FeedBody {
  final String title;
  final String? message;
  final String? linkUrl;
  final Map<String, dynamic>? extra;

  FeedBody({
    required this.title,
    this.message,
    this.linkUrl,
    this.extra,
  });

  factory FeedBody.fromJson(Map<String, dynamic> json) {
    return FeedBody(
      title: json['title'] as String,
      message: json['message'] as String?,
      linkUrl: json['linkUrl'] as String?,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'linkUrl': linkUrl,
      'extra': extra,
    };
  }
}

/// App notification
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final int createdAt;
  bool dismissed;
  int? readAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data,
    required this.createdAt,
    this.dismissed = false,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] as int,
      dismissed: json['dismissed'] as bool? ?? false,
      readAt: json['readAt'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': createdAt,
      'dismissed': dismissed,
      'readAt': readAt,
    };
  }

  /// Whether the notification has been read
  bool get read => readAt != null;

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    int? createdAt,
    bool? dismissed,
    int? readAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      dismissed: dismissed ?? this.dismissed,
      readAt: readAt ?? this.readAt,
    );
  }
}

enum NotificationType {
  info,
  success,
  warning,
  error,
  sessionUpdate,
  friendUpdate,
  message,
  ;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'sessionUpdate':
        return sessionUpdate;
      case 'friendUpdate':
        return friendUpdate;
      case 'message':
        return message;
      default:
        return info;
    }
  }

  String get value {
    switch (this) {
      case info:
        return 'info';
      case success:
        return 'success';
      case warning:
        return 'warning';
      case error:
        return 'error';
      case sessionUpdate:
        return 'sessionUpdate';
      case friendUpdate:
        return 'friendUpdate';
      case message:
        return 'message';
    }
  }
}
