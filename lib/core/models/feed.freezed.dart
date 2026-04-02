// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FeedItem {

 String get id;@JsonKey(fromJson: _feedBodyFromJson) FeedBody get body; int get createdAt; String get userId; String? get userName; String? get userAvatarUrl; bool get read; String? get sessionId; String? get repeatKey; String? get cursor; int? get counter;
/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedItemCopyWith<FeedItem> get copyWith => _$FeedItemCopyWithImpl<FeedItem>(this as FeedItem, _$identity);

  /// Serializes this FeedItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.userAvatarUrl, userAvatarUrl) || other.userAvatarUrl == userAvatarUrl)&&(identical(other.read, read) || other.read == read)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.repeatKey, repeatKey) || other.repeatKey == repeatKey)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.counter, counter) || other.counter == counter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,body,createdAt,userId,userName,userAvatarUrl,read,sessionId,repeatKey,cursor,counter);

@override
String toString() {
  return 'FeedItem(id: $id, body: $body, createdAt: $createdAt, userId: $userId, userName: $userName, userAvatarUrl: $userAvatarUrl, read: $read, sessionId: $sessionId, repeatKey: $repeatKey, cursor: $cursor, counter: $counter)';
}


}

/// @nodoc
abstract mixin class $FeedItemCopyWith<$Res>  {
  factory $FeedItemCopyWith(FeedItem value, $Res Function(FeedItem) _then) = _$FeedItemCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(fromJson: _feedBodyFromJson) FeedBody body, int createdAt, String userId, String? userName, String? userAvatarUrl, bool read, String? sessionId, String? repeatKey, String? cursor, int? counter
});


$FeedBodyCopyWith<$Res> get body;

}
/// @nodoc
class _$FeedItemCopyWithImpl<$Res>
    implements $FeedItemCopyWith<$Res> {
  _$FeedItemCopyWithImpl(this._self, this._then);

  final FeedItem _self;
  final $Res Function(FeedItem) _then;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? body = null,Object? createdAt = null,Object? userId = null,Object? userName = freezed,Object? userAvatarUrl = freezed,Object? read = null,Object? sessionId = freezed,Object? repeatKey = freezed,Object? cursor = freezed,Object? counter = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as FeedBody,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,userAvatarUrl: freezed == userAvatarUrl ? _self.userAvatarUrl : userAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,repeatKey: freezed == repeatKey ? _self.repeatKey : repeatKey // ignore: cast_nullable_to_non_nullable
as String?,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,counter: freezed == counter ? _self.counter : counter // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedBodyCopyWith<$Res> get body {
  
  return $FeedBodyCopyWith<$Res>(_self.body, (value) {
    return _then(_self.copyWith(body: value));
  });
}
}


/// Adds pattern-matching-related methods to [FeedItem].
extension FeedItemPatterns on FeedItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedItem value)  $default,){
final _that = this;
switch (_that) {
case _FeedItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedItem value)?  $default,){
final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _feedBodyFromJson)  FeedBody body,  int createdAt,  String userId,  String? userName,  String? userAvatarUrl,  bool read,  String? sessionId,  String? repeatKey,  String? cursor,  int? counter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
return $default(_that.id,_that.body,_that.createdAt,_that.userId,_that.userName,_that.userAvatarUrl,_that.read,_that.sessionId,_that.repeatKey,_that.cursor,_that.counter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _feedBodyFromJson)  FeedBody body,  int createdAt,  String userId,  String? userName,  String? userAvatarUrl,  bool read,  String? sessionId,  String? repeatKey,  String? cursor,  int? counter)  $default,) {final _that = this;
switch (_that) {
case _FeedItem():
return $default(_that.id,_that.body,_that.createdAt,_that.userId,_that.userName,_that.userAvatarUrl,_that.read,_that.sessionId,_that.repeatKey,_that.cursor,_that.counter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(fromJson: _feedBodyFromJson)  FeedBody body,  int createdAt,  String userId,  String? userName,  String? userAvatarUrl,  bool read,  String? sessionId,  String? repeatKey,  String? cursor,  int? counter)?  $default,) {final _that = this;
switch (_that) {
case _FeedItem() when $default != null:
return $default(_that.id,_that.body,_that.createdAt,_that.userId,_that.userName,_that.userAvatarUrl,_that.read,_that.sessionId,_that.repeatKey,_that.cursor,_that.counter);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedItem implements FeedItem {
  const _FeedItem({required this.id, @JsonKey(fromJson: _feedBodyFromJson) required this.body, required this.createdAt, this.userId = '', this.userName, this.userAvatarUrl, this.read = false, this.sessionId, this.repeatKey, this.cursor, this.counter});
  factory _FeedItem.fromJson(Map<String, dynamic> json) => _$FeedItemFromJson(json);

@override final  String id;
@override@JsonKey(fromJson: _feedBodyFromJson) final  FeedBody body;
@override final  int createdAt;
@override@JsonKey() final  String userId;
@override final  String? userName;
@override final  String? userAvatarUrl;
@override@JsonKey() final  bool read;
@override final  String? sessionId;
@override final  String? repeatKey;
@override final  String? cursor;
@override final  int? counter;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedItemCopyWith<_FeedItem> get copyWith => __$FeedItemCopyWithImpl<_FeedItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedItem&&(identical(other.id, id) || other.id == id)&&(identical(other.body, body) || other.body == body)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.userName, userName) || other.userName == userName)&&(identical(other.userAvatarUrl, userAvatarUrl) || other.userAvatarUrl == userAvatarUrl)&&(identical(other.read, read) || other.read == read)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.repeatKey, repeatKey) || other.repeatKey == repeatKey)&&(identical(other.cursor, cursor) || other.cursor == cursor)&&(identical(other.counter, counter) || other.counter == counter));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,body,createdAt,userId,userName,userAvatarUrl,read,sessionId,repeatKey,cursor,counter);

@override
String toString() {
  return 'FeedItem(id: $id, body: $body, createdAt: $createdAt, userId: $userId, userName: $userName, userAvatarUrl: $userAvatarUrl, read: $read, sessionId: $sessionId, repeatKey: $repeatKey, cursor: $cursor, counter: $counter)';
}


}

/// @nodoc
abstract mixin class _$FeedItemCopyWith<$Res> implements $FeedItemCopyWith<$Res> {
  factory _$FeedItemCopyWith(_FeedItem value, $Res Function(_FeedItem) _then) = __$FeedItemCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(fromJson: _feedBodyFromJson) FeedBody body, int createdAt, String userId, String? userName, String? userAvatarUrl, bool read, String? sessionId, String? repeatKey, String? cursor, int? counter
});


@override $FeedBodyCopyWith<$Res> get body;

}
/// @nodoc
class __$FeedItemCopyWithImpl<$Res>
    implements _$FeedItemCopyWith<$Res> {
  __$FeedItemCopyWithImpl(this._self, this._then);

  final _FeedItem _self;
  final $Res Function(_FeedItem) _then;

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? body = null,Object? createdAt = null,Object? userId = null,Object? userName = freezed,Object? userAvatarUrl = freezed,Object? read = null,Object? sessionId = freezed,Object? repeatKey = freezed,Object? cursor = freezed,Object? counter = freezed,}) {
  return _then(_FeedItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as FeedBody,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,userName: freezed == userName ? _self.userName : userName // ignore: cast_nullable_to_non_nullable
as String?,userAvatarUrl: freezed == userAvatarUrl ? _self.userAvatarUrl : userAvatarUrl // ignore: cast_nullable_to_non_nullable
as String?,read: null == read ? _self.read : read // ignore: cast_nullable_to_non_nullable
as bool,sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,repeatKey: freezed == repeatKey ? _self.repeatKey : repeatKey // ignore: cast_nullable_to_non_nullable
as String?,cursor: freezed == cursor ? _self.cursor : cursor // ignore: cast_nullable_to_non_nullable
as String?,counter: freezed == counter ? _self.counter : counter // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of FeedItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedBodyCopyWith<$Res> get body {
  
  return $FeedBodyCopyWith<$Res>(_self.body, (value) {
    return _then(_self.copyWith(body: value));
  });
}
}


/// @nodoc
mixin _$FeedBody {

 String get kind; String? get uid; String? get text;
/// Create a copy of FeedBody
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedBodyCopyWith<FeedBody> get copyWith => _$FeedBodyCopyWithImpl<FeedBody>(this as FeedBody, _$identity);

  /// Serializes this FeedBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedBody&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,uid,text);

@override
String toString() {
  return 'FeedBody(kind: $kind, uid: $uid, text: $text)';
}


}

/// @nodoc
abstract mixin class $FeedBodyCopyWith<$Res>  {
  factory $FeedBodyCopyWith(FeedBody value, $Res Function(FeedBody) _then) = _$FeedBodyCopyWithImpl;
@useResult
$Res call({
 String kind, String? uid, String? text
});




}
/// @nodoc
class _$FeedBodyCopyWithImpl<$Res>
    implements $FeedBodyCopyWith<$Res> {
  _$FeedBodyCopyWithImpl(this._self, this._then);

  final FeedBody _self;
  final $Res Function(FeedBody) _then;

/// Create a copy of FeedBody
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? uid = freezed,Object? text = freezed,}) {
  return _then(_self.copyWith(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,uid: freezed == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FeedBody].
extension FeedBodyPatterns on FeedBody {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedBody value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedBody() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedBody value)  $default,){
final _that = this;
switch (_that) {
case _FeedBody():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedBody value)?  $default,){
final _that = this;
switch (_that) {
case _FeedBody() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  String? uid,  String? text)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedBody() when $default != null:
return $default(_that.kind,_that.uid,_that.text);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  String? uid,  String? text)  $default,) {final _that = this;
switch (_that) {
case _FeedBody():
return $default(_that.kind,_that.uid,_that.text);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  String? uid,  String? text)?  $default,) {final _that = this;
switch (_that) {
case _FeedBody() when $default != null:
return $default(_that.kind,_that.uid,_that.text);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedBody implements FeedBody {
  const _FeedBody({this.kind = 'text', this.uid, this.text});
  factory _FeedBody.fromJson(Map<String, dynamic> json) => _$FeedBodyFromJson(json);

@override@JsonKey() final  String kind;
@override final  String? uid;
@override final  String? text;

/// Create a copy of FeedBody
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedBodyCopyWith<_FeedBody> get copyWith => __$FeedBodyCopyWithImpl<_FeedBody>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedBodyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedBody&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.text, text) || other.text == text));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,kind,uid,text);

@override
String toString() {
  return 'FeedBody(kind: $kind, uid: $uid, text: $text)';
}


}

/// @nodoc
abstract mixin class _$FeedBodyCopyWith<$Res> implements $FeedBodyCopyWith<$Res> {
  factory _$FeedBodyCopyWith(_FeedBody value, $Res Function(_FeedBody) _then) = __$FeedBodyCopyWithImpl;
@override @useResult
$Res call({
 String kind, String? uid, String? text
});




}
/// @nodoc
class __$FeedBodyCopyWithImpl<$Res>
    implements _$FeedBodyCopyWith<$Res> {
  __$FeedBodyCopyWithImpl(this._self, this._then);

  final _FeedBody _self;
  final $Res Function(_FeedBody) _then;

/// Create a copy of FeedBody
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? uid = freezed,Object? text = freezed,}) {
  return _then(_FeedBody(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,uid: freezed == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String?,text: freezed == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AppNotification {

 String get id;@JsonKey(fromJson: _notificationTypeFromJson, toJson: _notificationTypeToJson) NotificationType get type; String get title; int get createdAt; String? get body; Map<String, dynamic>? get data; bool get dismissed; int? get readAt;
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppNotificationCopyWith<AppNotification> get copyWith => _$AppNotificationCopyWithImpl<AppNotification>(this as AppNotification, _$identity);

  /// Serializes this AppNotification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.dismissed, dismissed) || other.dismissed == dismissed)&&(identical(other.readAt, readAt) || other.readAt == readAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,title,createdAt,body,const DeepCollectionEquality().hash(data),dismissed,readAt);

@override
String toString() {
  return 'AppNotification(id: $id, type: $type, title: $title, createdAt: $createdAt, body: $body, data: $data, dismissed: $dismissed, readAt: $readAt)';
}


}

/// @nodoc
abstract mixin class $AppNotificationCopyWith<$Res>  {
  factory $AppNotificationCopyWith(AppNotification value, $Res Function(AppNotification) _then) = _$AppNotificationCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(fromJson: _notificationTypeFromJson, toJson: _notificationTypeToJson) NotificationType type, String title, int createdAt, String? body, Map<String, dynamic>? data, bool dismissed, int? readAt
});




}
/// @nodoc
class _$AppNotificationCopyWithImpl<$Res>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._self, this._then);

  final AppNotification _self;
  final $Res Function(AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? title = null,Object? createdAt = null,Object? body = freezed,Object? data = freezed,Object? dismissed = null,Object? readAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,dismissed: null == dismissed ? _self.dismissed : dismissed // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppNotification].
extension AppNotificationPatterns on AppNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppNotification value)  $default,){
final _that = this;
switch (_that) {
case _AppNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppNotification value)?  $default,){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _notificationTypeFromJson, toJson: _notificationTypeToJson)  NotificationType type,  String title,  int createdAt,  String? body,  Map<String, dynamic>? data,  bool dismissed,  int? readAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.createdAt,_that.body,_that.data,_that.dismissed,_that.readAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _notificationTypeFromJson, toJson: _notificationTypeToJson)  NotificationType type,  String title,  int createdAt,  String? body,  Map<String, dynamic>? data,  bool dismissed,  int? readAt)  $default,) {final _that = this;
switch (_that) {
case _AppNotification():
return $default(_that.id,_that.type,_that.title,_that.createdAt,_that.body,_that.data,_that.dismissed,_that.readAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(fromJson: _notificationTypeFromJson, toJson: _notificationTypeToJson)  NotificationType type,  String title,  int createdAt,  String? body,  Map<String, dynamic>? data,  bool dismissed,  int? readAt)?  $default,) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.type,_that.title,_that.createdAt,_that.body,_that.data,_that.dismissed,_that.readAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppNotification extends AppNotification {
  const _AppNotification({required this.id, @JsonKey(fromJson: _notificationTypeFromJson, toJson: _notificationTypeToJson) required this.type, required this.title, required this.createdAt, this.body, final  Map<String, dynamic>? data, this.dismissed = false, this.readAt}): _data = data,super._();
  factory _AppNotification.fromJson(Map<String, dynamic> json) => _$AppNotificationFromJson(json);

@override final  String id;
@override@JsonKey(fromJson: _notificationTypeFromJson, toJson: _notificationTypeToJson) final  NotificationType type;
@override final  String title;
@override final  int createdAt;
@override final  String? body;
 final  Map<String, dynamic>? _data;
@override Map<String, dynamic>? get data {
  final value = _data;
  if (value == null) return null;
  if (_data is EqualUnmodifiableMapView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool dismissed;
@override final  int? readAt;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppNotificationCopyWith<_AppNotification> get copyWith => __$AppNotificationCopyWithImpl<_AppNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.title, title) || other.title == title)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.body, body) || other.body == body)&&const DeepCollectionEquality().equals(other._data, _data)&&(identical(other.dismissed, dismissed) || other.dismissed == dismissed)&&(identical(other.readAt, readAt) || other.readAt == readAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,title,createdAt,body,const DeepCollectionEquality().hash(_data),dismissed,readAt);

@override
String toString() {
  return 'AppNotification(id: $id, type: $type, title: $title, createdAt: $createdAt, body: $body, data: $data, dismissed: $dismissed, readAt: $readAt)';
}


}

/// @nodoc
abstract mixin class _$AppNotificationCopyWith<$Res> implements $AppNotificationCopyWith<$Res> {
  factory _$AppNotificationCopyWith(_AppNotification value, $Res Function(_AppNotification) _then) = __$AppNotificationCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(fromJson: _notificationTypeFromJson, toJson: _notificationTypeToJson) NotificationType type, String title, int createdAt, String? body, Map<String, dynamic>? data, bool dismissed, int? readAt
});




}
/// @nodoc
class __$AppNotificationCopyWithImpl<$Res>
    implements _$AppNotificationCopyWith<$Res> {
  __$AppNotificationCopyWithImpl(this._self, this._then);

  final _AppNotification _self;
  final $Res Function(_AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? title = null,Object? createdAt = null,Object? body = freezed,Object? data = freezed,Object? dismissed = null,Object? readAt = freezed,}) {
  return _then(_AppNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as NotificationType,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,dismissed: null == dismissed ? _self.dismissed : dismissed // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
