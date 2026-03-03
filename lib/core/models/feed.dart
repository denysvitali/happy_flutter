/// Activity feed and notification models
library;

/// Activity feed item
class FeedItem {

  FeedItem({
    required this.id,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.userName,
    this.userAvatarUrl,
    this.read = false,
    this.sessionId,
    this.repeatKey,
    this.cursor,
    this.counter,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      body: FeedBody.fromJson(json['body'] as Map<String, dynamic>? ?? {}),
      createdAt: json['createdAt'] as int,
      read: json['read'] as bool? ?? false,
      sessionId: json['sessionId'] as String?,
      repeatKey: json['repeatKey'] as String?,
      cursor: json['cursor'] as String?,
      counter: json['counter'] as int?,
    );
  }
  final String id;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final FeedBody body;
  final int createdAt;
  final bool read;
  final String? sessionId;
  final String? repeatKey;
  final String? cursor;
  final int? counter;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      if (userName != null) 'userName': userName,
      if (userAvatarUrl != null) 'userAvatarUrl': userAvatarUrl,
      'body': body.toJson(),
      'createdAt': createdAt,
      'read': read,
      if (sessionId != null) 'sessionId': sessionId,
      if (repeatKey != null) 'repeatKey': repeatKey,
      if (cursor != null) 'cursor': cursor,
      if (counter != null) 'counter': counter,
    };
  }

  FeedItem copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    FeedBody? body,
    int? createdAt,
    bool? read,
    String? sessionId,
    String? repeatKey,
    String? cursor,
    int? counter,
  }) {
    return FeedItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
      sessionId: sessionId ?? this.sessionId,
      repeatKey: repeatKey ?? this.repeatKey,
      cursor: cursor ?? this.cursor,
      counter: counter ?? this.counter,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          userName == other.userName &&
          userAvatarUrl == other.userAvatarUrl &&
          body == other.body &&
          createdAt == other.createdAt &&
          read == other.read &&
          sessionId == other.sessionId &&
          repeatKey == other.repeatKey &&
          cursor == other.cursor &&
          counter == other.counter;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        userName,
        userAvatarUrl,
        body,
        createdAt,
        read,
        sessionId,
        repeatKey,
        cursor,
        counter,
      );
}

/// Feed body content — discriminated union on [kind].
///
/// Supported kinds: `'friend_request'`, `'friend_accepted'`, `'text'`.
class FeedBody {

  const FeedBody({required this.kind, this.uid, this.text});

  factory FeedBody.fromJson(Map<String, dynamic> json) {
    return FeedBody(
      kind: json['kind'] as String? ?? 'text',
      uid: json['uid'] as String?,
      text: json['text'] as String?,
    );
  }

  /// Discriminant: `'friend_request'`, `'friend_accepted'`, or `'text'`.
  final String kind;

  /// User ID associated with the event (friend_request / friend_accepted).
  final String? uid;

  /// Message text (text kind).
  final String? text;

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (uid != null) 'uid': uid,
        if (text != null) 'text': text,
      };

  FeedBody copyWith({
    String? kind,
    String? uid,
    String? text,
  }) {
    return FeedBody(
      kind: kind ?? this.kind,
      uid: uid ?? this.uid,
      text: text ?? this.text,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedBody &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          uid == other.uid &&
          text == other.text;

  @override
  int get hashCode => Object.hash(kind, uid, text);
}

/// App notification
class AppNotification {

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt, this.body,
    this.data,
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
  final String id;
  final NotificationType type;
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final int createdAt;
  final bool dismissed;
  final int? readAt;

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
      case 'info':
        return info;
      case 'success':
        return success;
      case 'warning':
        return warning;
      case 'error':
        return error;
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
