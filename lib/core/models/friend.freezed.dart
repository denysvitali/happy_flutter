// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'friend.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AvatarRef {

 String get path; String get url; int? get width; int? get height; String? get thumbhash;
/// Create a copy of AvatarRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AvatarRefCopyWith<AvatarRef> get copyWith => _$AvatarRefCopyWithImpl<AvatarRef>(this as AvatarRef, _$identity);

  /// Serializes this AvatarRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AvatarRef&&(identical(other.path, path) || other.path == path)&&(identical(other.url, url) || other.url == url)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.thumbhash, thumbhash) || other.thumbhash == thumbhash));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,url,width,height,thumbhash);

@override
String toString() {
  return 'AvatarRef(path: $path, url: $url, width: $width, height: $height, thumbhash: $thumbhash)';
}


}

/// @nodoc
abstract mixin class $AvatarRefCopyWith<$Res>  {
  factory $AvatarRefCopyWith(AvatarRef value, $Res Function(AvatarRef) _then) = _$AvatarRefCopyWithImpl;
@useResult
$Res call({
 String path, String url, int? width, int? height, String? thumbhash
});




}
/// @nodoc
class _$AvatarRefCopyWithImpl<$Res>
    implements $AvatarRefCopyWith<$Res> {
  _$AvatarRefCopyWithImpl(this._self, this._then);

  final AvatarRef _self;
  final $Res Function(AvatarRef) _then;

/// Create a copy of AvatarRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? url = null,Object? width = freezed,Object? height = freezed,Object? thumbhash = freezed,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,thumbhash: freezed == thumbhash ? _self.thumbhash : thumbhash // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AvatarRef].
extension AvatarRefPatterns on AvatarRef {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AvatarRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AvatarRef() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AvatarRef value)  $default,){
final _that = this;
switch (_that) {
case _AvatarRef():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AvatarRef value)?  $default,){
final _that = this;
switch (_that) {
case _AvatarRef() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  String url,  int? width,  int? height,  String? thumbhash)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AvatarRef() when $default != null:
return $default(_that.path,_that.url,_that.width,_that.height,_that.thumbhash);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  String url,  int? width,  int? height,  String? thumbhash)  $default,) {final _that = this;
switch (_that) {
case _AvatarRef():
return $default(_that.path,_that.url,_that.width,_that.height,_that.thumbhash);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  String url,  int? width,  int? height,  String? thumbhash)?  $default,) {final _that = this;
switch (_that) {
case _AvatarRef() when $default != null:
return $default(_that.path,_that.url,_that.width,_that.height,_that.thumbhash);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AvatarRef implements AvatarRef {
  const _AvatarRef({this.path = '', this.url = '', this.width, this.height, this.thumbhash});
  factory _AvatarRef.fromJson(Map<String, dynamic> json) => _$AvatarRefFromJson(json);

@override@JsonKey() final  String path;
@override@JsonKey() final  String url;
@override final  int? width;
@override final  int? height;
@override final  String? thumbhash;

/// Create a copy of AvatarRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AvatarRefCopyWith<_AvatarRef> get copyWith => __$AvatarRefCopyWithImpl<_AvatarRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AvatarRefToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AvatarRef&&(identical(other.path, path) || other.path == path)&&(identical(other.url, url) || other.url == url)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.thumbhash, thumbhash) || other.thumbhash == thumbhash));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,url,width,height,thumbhash);

@override
String toString() {
  return 'AvatarRef(path: $path, url: $url, width: $width, height: $height, thumbhash: $thumbhash)';
}


}

/// @nodoc
abstract mixin class _$AvatarRefCopyWith<$Res> implements $AvatarRefCopyWith<$Res> {
  factory _$AvatarRefCopyWith(_AvatarRef value, $Res Function(_AvatarRef) _then) = __$AvatarRefCopyWithImpl;
@override @useResult
$Res call({
 String path, String url, int? width, int? height, String? thumbhash
});




}
/// @nodoc
class __$AvatarRefCopyWithImpl<$Res>
    implements _$AvatarRefCopyWith<$Res> {
  __$AvatarRefCopyWithImpl(this._self, this._then);

  final _AvatarRef _self;
  final $Res Function(_AvatarRef) _then;

/// Create a copy of AvatarRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? url = null,Object? width = freezed,Object? height = freezed,Object? thumbhash = freezed,}) {
  return _then(_AvatarRef(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,thumbhash: freezed == thumbhash ? _self.thumbhash : thumbhash // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$UserProfile {

 String get id; String get firstName; String? get lastName; String get username; AvatarRef? get avatar; String? get bio;@JsonKey(fromJson: _statusFromJson, toJson: _statusToJson) RelationshipStatus get status;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);

  /// Serializes this UserProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,firstName,lastName,username,avatar,bio,status);

@override
String toString() {
  return 'UserProfile(id: $id, firstName: $firstName, lastName: $lastName, username: $username, avatar: $avatar, bio: $bio, status: $status)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 String id, String firstName, String? lastName, String username, AvatarRef? avatar, String? bio,@JsonKey(fromJson: _statusFromJson, toJson: _statusToJson) RelationshipStatus status
});


$AvatarRefCopyWith<$Res>? get avatar;

}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? firstName = null,Object? lastName = freezed,Object? username = null,Object? avatar = freezed,Object? bio = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as AvatarRef?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RelationshipStatus,
  ));
}
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarRefCopyWith<$Res>? get avatar {
    if (_self.avatar == null) {
    return null;
  }

  return $AvatarRefCopyWith<$Res>(_self.avatar!, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String firstName,  String? lastName,  String username,  AvatarRef? avatar,  String? bio, @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)  RelationshipStatus status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.username,_that.avatar,_that.bio,_that.status);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String firstName,  String? lastName,  String username,  AvatarRef? avatar,  String? bio, @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)  RelationshipStatus status)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.id,_that.firstName,_that.lastName,_that.username,_that.avatar,_that.bio,_that.status);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String firstName,  String? lastName,  String username,  AvatarRef? avatar,  String? bio, @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)  RelationshipStatus status)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.id,_that.firstName,_that.lastName,_that.username,_that.avatar,_that.bio,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserProfile extends UserProfile {
  const _UserProfile({required this.id, this.firstName = '', this.lastName, this.username = '', this.avatar, this.bio, @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson) this.status = RelationshipStatus.none}): super._();
  factory _UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

@override final  String id;
@override@JsonKey() final  String firstName;
@override final  String? lastName;
@override@JsonKey() final  String username;
@override final  AvatarRef? avatar;
@override final  String? bio;
@override@JsonKey(fromJson: _statusFromJson, toJson: _statusToJson) final  RelationshipStatus status;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.firstName, firstName) || other.firstName == firstName)&&(identical(other.lastName, lastName) || other.lastName == lastName)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.bio, bio) || other.bio == bio)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,firstName,lastName,username,avatar,bio,status);

@override
String toString() {
  return 'UserProfile(id: $id, firstName: $firstName, lastName: $lastName, username: $username, avatar: $avatar, bio: $bio, status: $status)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String firstName, String? lastName, String username, AvatarRef? avatar, String? bio,@JsonKey(fromJson: _statusFromJson, toJson: _statusToJson) RelationshipStatus status
});


@override $AvatarRefCopyWith<$Res>? get avatar;

}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? firstName = null,Object? lastName = freezed,Object? username = null,Object? avatar = freezed,Object? bio = freezed,Object? status = null,}) {
  return _then(_UserProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,firstName: null == firstName ? _self.firstName : firstName // ignore: cast_nullable_to_non_nullable
as String,lastName: freezed == lastName ? _self.lastName : lastName // ignore: cast_nullable_to_non_nullable
as String?,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,avatar: freezed == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as AvatarRef?,bio: freezed == bio ? _self.bio : bio // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RelationshipStatus,
  ));
}

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AvatarRefCopyWith<$Res>? get avatar {
    if (_self.avatar == null) {
    return null;
  }

  return $AvatarRefCopyWith<$Res>(_self.avatar!, (value) {
    return _then(_self.copyWith(avatar: value));
  });
}
}


/// @nodoc
mixin _$FriendRequest {

 String get id; String get fromUserId; String get fromUserName; String get toUserId; int get createdAt; String get status; String? get fromUserAvatarUrl;
/// Create a copy of FriendRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FriendRequestCopyWith<FriendRequest> get copyWith => _$FriendRequestCopyWithImpl<FriendRequest>(this as FriendRequest, _$identity);

  /// Serializes this FriendRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FriendRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.fromUserId, fromUserId) || other.fromUserId == fromUserId)&&(identical(other.fromUserName, fromUserName) || other.fromUserName == fromUserName)&&(identical(other.toUserId, toUserId) || other.toUserId == toUserId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.fromUserAvatarUrl, fromUserAvatarUrl) || other.fromUserAvatarUrl == fromUserAvatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fromUserId,fromUserName,toUserId,createdAt,status,fromUserAvatarUrl);

@override
String toString() {
  return 'FriendRequest(id: $id, fromUserId: $fromUserId, fromUserName: $fromUserName, toUserId: $toUserId, createdAt: $createdAt, status: $status, fromUserAvatarUrl: $fromUserAvatarUrl)';
}


}

/// @nodoc
abstract mixin class $FriendRequestCopyWith<$Res>  {
  factory $FriendRequestCopyWith(FriendRequest value, $Res Function(FriendRequest) _then) = _$FriendRequestCopyWithImpl;
@useResult
$Res call({
 String id, String fromUserId, String fromUserName, String toUserId, int createdAt, String status, String? fromUserAvatarUrl
});




}
/// @nodoc
class _$FriendRequestCopyWithImpl<$Res>
    implements $FriendRequestCopyWith<$Res> {
  _$FriendRequestCopyWithImpl(this._self, this._then);

  final FriendRequest _self;
  final $Res Function(FriendRequest) _then;

/// Create a copy of FriendRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fromUserId = null,Object? fromUserName = null,Object? toUserId = null,Object? createdAt = null,Object? status = null,Object? fromUserAvatarUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromUserId: null == fromUserId ? _self.fromUserId : fromUserId // ignore: cast_nullable_to_non_nullable
as String,fromUserName: null == fromUserName ? _self.fromUserName : fromUserName // ignore: cast_nullable_to_non_nullable
as String,toUserId: null == toUserId ? _self.toUserId : toUserId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fromUserAvatarUrl: freezed == fromUserAvatarUrl ? _self.fromUserAvatarUrl : fromUserAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FriendRequest].
extension FriendRequestPatterns on FriendRequest {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FriendRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FriendRequest() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FriendRequest value)  $default,){
final _that = this;
switch (_that) {
case _FriendRequest():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FriendRequest value)?  $default,){
final _that = this;
switch (_that) {
case _FriendRequest() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fromUserId,  String fromUserName,  String toUserId,  int createdAt,  String status,  String? fromUserAvatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FriendRequest() when $default != null:
return $default(_that.id,_that.fromUserId,_that.fromUserName,_that.toUserId,_that.createdAt,_that.status,_that.fromUserAvatarUrl);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fromUserId,  String fromUserName,  String toUserId,  int createdAt,  String status,  String? fromUserAvatarUrl)  $default,) {final _that = this;
switch (_that) {
case _FriendRequest():
return $default(_that.id,_that.fromUserId,_that.fromUserName,_that.toUserId,_that.createdAt,_that.status,_that.fromUserAvatarUrl);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fromUserId,  String fromUserName,  String toUserId,  int createdAt,  String status,  String? fromUserAvatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _FriendRequest() when $default != null:
return $default(_that.id,_that.fromUserId,_that.fromUserName,_that.toUserId,_that.createdAt,_that.status,_that.fromUserAvatarUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FriendRequest implements FriendRequest {
  const _FriendRequest({required this.id, required this.fromUserId, required this.fromUserName, required this.toUserId, required this.createdAt, required this.status, this.fromUserAvatarUrl});
  factory _FriendRequest.fromJson(Map<String, dynamic> json) => _$FriendRequestFromJson(json);

@override final  String id;
@override final  String fromUserId;
@override final  String fromUserName;
@override final  String toUserId;
@override final  int createdAt;
@override final  String status;
@override final  String? fromUserAvatarUrl;

/// Create a copy of FriendRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FriendRequestCopyWith<_FriendRequest> get copyWith => __$FriendRequestCopyWithImpl<_FriendRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FriendRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FriendRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.fromUserId, fromUserId) || other.fromUserId == fromUserId)&&(identical(other.fromUserName, fromUserName) || other.fromUserName == fromUserName)&&(identical(other.toUserId, toUserId) || other.toUserId == toUserId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.status, status) || other.status == status)&&(identical(other.fromUserAvatarUrl, fromUserAvatarUrl) || other.fromUserAvatarUrl == fromUserAvatarUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fromUserId,fromUserName,toUserId,createdAt,status,fromUserAvatarUrl);

@override
String toString() {
  return 'FriendRequest(id: $id, fromUserId: $fromUserId, fromUserName: $fromUserName, toUserId: $toUserId, createdAt: $createdAt, status: $status, fromUserAvatarUrl: $fromUserAvatarUrl)';
}


}

/// @nodoc
abstract mixin class _$FriendRequestCopyWith<$Res> implements $FriendRequestCopyWith<$Res> {
  factory _$FriendRequestCopyWith(_FriendRequest value, $Res Function(_FriendRequest) _then) = __$FriendRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, String fromUserId, String fromUserName, String toUserId, int createdAt, String status, String? fromUserAvatarUrl
});




}
/// @nodoc
class __$FriendRequestCopyWithImpl<$Res>
    implements _$FriendRequestCopyWith<$Res> {
  __$FriendRequestCopyWithImpl(this._self, this._then);

  final _FriendRequest _self;
  final $Res Function(_FriendRequest) _then;

/// Create a copy of FriendRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fromUserId = null,Object? fromUserName = null,Object? toUserId = null,Object? createdAt = null,Object? status = null,Object? fromUserAvatarUrl = freezed,}) {
  return _then(_FriendRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fromUserId: null == fromUserId ? _self.fromUserId : fromUserId // ignore: cast_nullable_to_non_nullable
as String,fromUserName: null == fromUserName ? _self.fromUserName : fromUserName // ignore: cast_nullable_to_non_nullable
as String,toUserId: null == toUserId ? _self.toUserId : toUserId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,fromUserAvatarUrl: freezed == fromUserAvatarUrl ? _self.fromUserAvatarUrl : fromUserAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
