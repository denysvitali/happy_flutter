// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FeedItem _$FeedItemFromJson(Map<String, dynamic> json) => _FeedItem(
  id: json['id'] as String,
  body: _feedBodyFromJson(json['body']),
  createdAt: (json['createdAt'] as num).toInt(),
  userId: json['userId'] as String? ?? '',
  userName: json['userName'] as String?,
  userAvatarUrl: json['userAvatarUrl'] as String?,
  read: json['read'] as bool? ?? false,
  sessionId: json['sessionId'] as String?,
  repeatKey: json['repeatKey'] as String?,
  cursor: json['cursor'] as String?,
  counter: (json['counter'] as num?)?.toInt(),
);

Map<String, dynamic> _$FeedItemToJson(_FeedItem instance) => <String, dynamic>{
  'id': instance.id,
  'body': instance.body.toJson(),
  'createdAt': instance.createdAt,
  'userId': instance.userId,
  'userName': instance.userName,
  'userAvatarUrl': instance.userAvatarUrl,
  'read': instance.read,
  'sessionId': instance.sessionId,
  'repeatKey': instance.repeatKey,
  'cursor': instance.cursor,
  'counter': instance.counter,
};

_FeedBody _$FeedBodyFromJson(Map<String, dynamic> json) => _FeedBody(
  kind: json['kind'] as String? ?? 'text',
  uid: json['uid'] as String?,
  text: json['text'] as String?,
);

Map<String, dynamic> _$FeedBodyToJson(_FeedBody instance) => <String, dynamic>{
  'kind': instance.kind,
  'uid': instance.uid,
  'text': instance.text,
};

_AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    _AppNotification(
      id: json['id'] as String,
      type: _notificationTypeFromJson(json['type'] as String),
      title: json['title'] as String,
      createdAt: (json['createdAt'] as num).toInt(),
      body: json['body'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      dismissed: json['dismissed'] as bool? ?? false,
      readAt: (json['readAt'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AppNotificationToJson(_AppNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _notificationTypeToJson(instance.type),
      'title': instance.title,
      'createdAt': instance.createdAt,
      'body': instance.body,
      'data': instance.data,
      'dismissed': instance.dismissed,
      'readAt': instance.readAt,
    };
