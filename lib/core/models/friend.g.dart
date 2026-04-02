// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AvatarRef _$AvatarRefFromJson(Map<String, dynamic> json) => _AvatarRef(
  path: json['path'] as String? ?? '',
  url: json['url'] as String? ?? '',
  width: (json['width'] as num?)?.toInt(),
  height: (json['height'] as num?)?.toInt(),
  thumbhash: json['thumbhash'] as String?,
);

Map<String, dynamic> _$AvatarRefToJson(_AvatarRef instance) {
  final json = <String, dynamic>{'path': instance.path, 'url': instance.url};
  if (instance.width != null) json['width'] = instance.width;
  if (instance.height != null) json['height'] = instance.height;
  if (instance.thumbhash != null) json['thumbhash'] = instance.thumbhash;
  return json;
}

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  id: json['id'] as String,
  firstName: json['firstName'] as String? ?? '',
  lastName: json['lastName'] as String?,
  username: json['username'] as String? ?? '',
  avatar: json['avatar'] == null
      ? null
      : AvatarRef.fromJson(json['avatar'] as Map<String, dynamic>),
  bio: json['bio'] as String?,
  status: json['status'] == null
      ? RelationshipStatus.none
      : _statusFromJson(json['status'] as String),
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'firstName': instance.firstName,
      'lastName': instance.lastName,
      'username': instance.username,
      'avatar': instance.avatar?.toJson(),
      'bio': instance.bio,
      'status': _statusToJson(instance.status),
    };

_FriendRequest _$FriendRequestFromJson(Map<String, dynamic> json) =>
    _FriendRequest(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUserName: json['fromUserName'] as String,
      toUserId: json['toUserId'] as String,
      createdAt: (json['createdAt'] as num).toInt(),
      status: json['status'] as String,
      fromUserAvatarUrl: json['fromUserAvatarUrl'] as String?,
    );

Map<String, dynamic> _$FriendRequestToJson(_FriendRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromUserId': instance.fromUserId,
      'fromUserName': instance.fromUserName,
      'toUserId': instance.toUserId,
      'createdAt': instance.createdAt,
      'status': instance.status,
      'fromUserAvatarUrl': instance.fromUserAvatarUrl,
    };
