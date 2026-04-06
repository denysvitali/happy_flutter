/// Activity feed and notification models
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed.freezed.dart';
part 'feed.g.dart';

FeedBody _feedBodyFromJson(dynamic value) {
  if (value is Map<String, dynamic>) return FeedBody.fromJson(value);
  return const FeedBody();
}

/// Activity feed item
@freezed
abstract class FeedItem with _$FeedItem {
  const factory FeedItem({
    required String id,
    @JsonKey(fromJson: _feedBodyFromJson) required FeedBody body,
    required int createdAt,
    @Default('') String userId,
    String? userName,
    String? userAvatarUrl,
    @Default(false) bool read,
    String? sessionId,
    String? repeatKey,
    String? cursor,
    int? counter,
  }) = _FeedItem;

  factory FeedItem.fromJson(Map<String, dynamic> json) =>
      _$FeedItemFromJson(json);
}

/// Feed body content — discriminated union on [kind].
///
/// Supported kinds: `'friend_request'`, `'friend_accepted'`, `'text'`.
@JsonSerializable(includeIfNull: false)
@freezed
abstract class FeedBody with _$FeedBody {
  const factory FeedBody({
    @Default('text') String kind,
    String? uid,
    String? text,
  }) = _FeedBody;

  factory FeedBody.fromJson(Map<String, dynamic> json) =>
      _$FeedBodyFromJson(json);
}

NotificationType _notificationTypeFromJson(String value) =>
    NotificationType.fromString(value);

String _notificationTypeToJson(NotificationType type) => type.value;

/// App notification
@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    @JsonKey(
      fromJson: _notificationTypeFromJson,
      toJson: _notificationTypeToJson,
    )
    required NotificationType type,
    required String title,
    required int createdAt,
    String? body,
    Map<String, dynamic>? data,
    @Default(false) bool dismissed,
    int? readAt,
  }) = _AppNotification;

  const AppNotification._();

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  /// Whether the notification has been read
  bool get read => readAt != null;
}

enum NotificationType {
  info,
  success,
  warning,
  error,
  sessionUpdate,
  friendUpdate,
  message;

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
