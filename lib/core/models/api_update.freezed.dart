// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_update.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiUpdateNewMessage {

 String get t; String get sid; Map<String, dynamic> get message;
/// Create a copy of ApiUpdateNewMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiUpdateNewMessageCopyWith<ApiUpdateNewMessage> get copyWith => _$ApiUpdateNewMessageCopyWithImpl<ApiUpdateNewMessage>(this as ApiUpdateNewMessage, _$identity);

  /// Serializes this ApiUpdateNewMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiUpdateNewMessage&&(identical(other.t, t) || other.t == t)&&(identical(other.sid, sid) || other.sid == sid)&&const DeepCollectionEquality().equals(other.message, message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,sid,const DeepCollectionEquality().hash(message));

@override
String toString() {
  return 'ApiUpdateNewMessage(t: $t, sid: $sid, message: $message)';
}


}

/// @nodoc
abstract mixin class $ApiUpdateNewMessageCopyWith<$Res>  {
  factory $ApiUpdateNewMessageCopyWith(ApiUpdateNewMessage value, $Res Function(ApiUpdateNewMessage) _then) = _$ApiUpdateNewMessageCopyWithImpl;
@useResult
$Res call({
 String t, String sid, Map<String, dynamic> message
});




}
/// @nodoc
class _$ApiUpdateNewMessageCopyWithImpl<$Res>
    implements $ApiUpdateNewMessageCopyWith<$Res> {
  _$ApiUpdateNewMessageCopyWithImpl(this._self, this._then);

  final ApiUpdateNewMessage _self;
  final $Res Function(ApiUpdateNewMessage) _then;

/// Create a copy of ApiUpdateNewMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? t = null,Object? sid = null,Object? message = null,}) {
  return _then(_self.copyWith(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,sid: null == sid ? _self.sid : sid // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiUpdateNewMessage].
extension ApiUpdateNewMessagePatterns on ApiUpdateNewMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiUpdateNewMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiUpdateNewMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiUpdateNewMessage value)  $default,){
final _that = this;
switch (_that) {
case _ApiUpdateNewMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiUpdateNewMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ApiUpdateNewMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String t,  String sid,  Map<String, dynamic> message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiUpdateNewMessage() when $default != null:
return $default(_that.t,_that.sid,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String t,  String sid,  Map<String, dynamic> message)  $default,) {final _that = this;
switch (_that) {
case _ApiUpdateNewMessage():
return $default(_that.t,_that.sid,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String t,  String sid,  Map<String, dynamic> message)?  $default,) {final _that = this;
switch (_that) {
case _ApiUpdateNewMessage() when $default != null:
return $default(_that.t,_that.sid,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiUpdateNewMessage implements ApiUpdateNewMessage {
  const _ApiUpdateNewMessage({this.t = '', this.sid = '', final  Map<String, dynamic> message = const <String, dynamic>{}}): _message = message;
  factory _ApiUpdateNewMessage.fromJson(Map<String, dynamic> json) => _$ApiUpdateNewMessageFromJson(json);

@override@JsonKey() final  String t;
@override@JsonKey() final  String sid;
 final  Map<String, dynamic> _message;
@override@JsonKey() Map<String, dynamic> get message {
  if (_message is EqualUnmodifiableMapView) return _message;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_message);
}


/// Create a copy of ApiUpdateNewMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiUpdateNewMessageCopyWith<_ApiUpdateNewMessage> get copyWith => __$ApiUpdateNewMessageCopyWithImpl<_ApiUpdateNewMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiUpdateNewMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiUpdateNewMessage&&(identical(other.t, t) || other.t == t)&&(identical(other.sid, sid) || other.sid == sid)&&const DeepCollectionEquality().equals(other._message, _message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,sid,const DeepCollectionEquality().hash(_message));

@override
String toString() {
  return 'ApiUpdateNewMessage(t: $t, sid: $sid, message: $message)';
}


}

/// @nodoc
abstract mixin class _$ApiUpdateNewMessageCopyWith<$Res> implements $ApiUpdateNewMessageCopyWith<$Res> {
  factory _$ApiUpdateNewMessageCopyWith(_ApiUpdateNewMessage value, $Res Function(_ApiUpdateNewMessage) _then) = __$ApiUpdateNewMessageCopyWithImpl;
@override @useResult
$Res call({
 String t, String sid, Map<String, dynamic> message
});




}
/// @nodoc
class __$ApiUpdateNewMessageCopyWithImpl<$Res>
    implements _$ApiUpdateNewMessageCopyWith<$Res> {
  __$ApiUpdateNewMessageCopyWithImpl(this._self, this._then);

  final _ApiUpdateNewMessage _self;
  final $Res Function(_ApiUpdateNewMessage) _then;

/// Create a copy of ApiUpdateNewMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? t = null,Object? sid = null,Object? message = null,}) {
  return _then(_ApiUpdateNewMessage(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,sid: null == sid ? _self.sid : sid // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self._message : message // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}


/// @nodoc
mixin _$ApiUpdateNewSession {

 String get t; String get id; int get createdAt; int get updatedAt;
/// Create a copy of ApiUpdateNewSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiUpdateNewSessionCopyWith<ApiUpdateNewSession> get copyWith => _$ApiUpdateNewSessionCopyWithImpl<ApiUpdateNewSession>(this as ApiUpdateNewSession, _$identity);

  /// Serializes this ApiUpdateNewSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiUpdateNewSession&&(identical(other.t, t) || other.t == t)&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,id,createdAt,updatedAt);

@override
String toString() {
  return 'ApiUpdateNewSession(t: $t, id: $id, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ApiUpdateNewSessionCopyWith<$Res>  {
  factory $ApiUpdateNewSessionCopyWith(ApiUpdateNewSession value, $Res Function(ApiUpdateNewSession) _then) = _$ApiUpdateNewSessionCopyWithImpl;
@useResult
$Res call({
 String t, String id, int createdAt, int updatedAt
});




}
/// @nodoc
class _$ApiUpdateNewSessionCopyWithImpl<$Res>
    implements $ApiUpdateNewSessionCopyWith<$Res> {
  _$ApiUpdateNewSessionCopyWithImpl(this._self, this._then);

  final ApiUpdateNewSession _self;
  final $Res Function(ApiUpdateNewSession) _then;

/// Create a copy of ApiUpdateNewSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? t = null,Object? id = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiUpdateNewSession].
extension ApiUpdateNewSessionPatterns on ApiUpdateNewSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiUpdateNewSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiUpdateNewSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiUpdateNewSession value)  $default,){
final _that = this;
switch (_that) {
case _ApiUpdateNewSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiUpdateNewSession value)?  $default,){
final _that = this;
switch (_that) {
case _ApiUpdateNewSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String t,  String id,  int createdAt,  int updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiUpdateNewSession() when $default != null:
return $default(_that.t,_that.id,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String t,  String id,  int createdAt,  int updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ApiUpdateNewSession():
return $default(_that.t,_that.id,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String t,  String id,  int createdAt,  int updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ApiUpdateNewSession() when $default != null:
return $default(_that.t,_that.id,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiUpdateNewSession implements ApiUpdateNewSession {
  const _ApiUpdateNewSession({this.t = '', this.id = '', this.createdAt = 0, this.updatedAt = 0});
  factory _ApiUpdateNewSession.fromJson(Map<String, dynamic> json) => _$ApiUpdateNewSessionFromJson(json);

@override@JsonKey() final  String t;
@override@JsonKey() final  String id;
@override@JsonKey() final  int createdAt;
@override@JsonKey() final  int updatedAt;

/// Create a copy of ApiUpdateNewSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiUpdateNewSessionCopyWith<_ApiUpdateNewSession> get copyWith => __$ApiUpdateNewSessionCopyWithImpl<_ApiUpdateNewSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiUpdateNewSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiUpdateNewSession&&(identical(other.t, t) || other.t == t)&&(identical(other.id, id) || other.id == id)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,id,createdAt,updatedAt);

@override
String toString() {
  return 'ApiUpdateNewSession(t: $t, id: $id, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ApiUpdateNewSessionCopyWith<$Res> implements $ApiUpdateNewSessionCopyWith<$Res> {
  factory _$ApiUpdateNewSessionCopyWith(_ApiUpdateNewSession value, $Res Function(_ApiUpdateNewSession) _then) = __$ApiUpdateNewSessionCopyWithImpl;
@override @useResult
$Res call({
 String t, String id, int createdAt, int updatedAt
});




}
/// @nodoc
class __$ApiUpdateNewSessionCopyWithImpl<$Res>
    implements _$ApiUpdateNewSessionCopyWith<$Res> {
  __$ApiUpdateNewSessionCopyWithImpl(this._self, this._then);

  final _ApiUpdateNewSession _self;
  final $Res Function(_ApiUpdateNewSession) _then;

/// Create a copy of ApiUpdateNewSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? t = null,Object? id = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_ApiUpdateNewSession(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ApiDeleteSession {

 String get t; String get sid;
/// Create a copy of ApiDeleteSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiDeleteSessionCopyWith<ApiDeleteSession> get copyWith => _$ApiDeleteSessionCopyWithImpl<ApiDeleteSession>(this as ApiDeleteSession, _$identity);

  /// Serializes this ApiDeleteSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiDeleteSession&&(identical(other.t, t) || other.t == t)&&(identical(other.sid, sid) || other.sid == sid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,sid);

@override
String toString() {
  return 'ApiDeleteSession(t: $t, sid: $sid)';
}


}

/// @nodoc
abstract mixin class $ApiDeleteSessionCopyWith<$Res>  {
  factory $ApiDeleteSessionCopyWith(ApiDeleteSession value, $Res Function(ApiDeleteSession) _then) = _$ApiDeleteSessionCopyWithImpl;
@useResult
$Res call({
 String t, String sid
});




}
/// @nodoc
class _$ApiDeleteSessionCopyWithImpl<$Res>
    implements $ApiDeleteSessionCopyWith<$Res> {
  _$ApiDeleteSessionCopyWithImpl(this._self, this._then);

  final ApiDeleteSession _self;
  final $Res Function(ApiDeleteSession) _then;

/// Create a copy of ApiDeleteSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? t = null,Object? sid = null,}) {
  return _then(_self.copyWith(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,sid: null == sid ? _self.sid : sid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiDeleteSession].
extension ApiDeleteSessionPatterns on ApiDeleteSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiDeleteSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiDeleteSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiDeleteSession value)  $default,){
final _that = this;
switch (_that) {
case _ApiDeleteSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiDeleteSession value)?  $default,){
final _that = this;
switch (_that) {
case _ApiDeleteSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String t,  String sid)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiDeleteSession() when $default != null:
return $default(_that.t,_that.sid);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String t,  String sid)  $default,) {final _that = this;
switch (_that) {
case _ApiDeleteSession():
return $default(_that.t,_that.sid);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String t,  String sid)?  $default,) {final _that = this;
switch (_that) {
case _ApiDeleteSession() when $default != null:
return $default(_that.t,_that.sid);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiDeleteSession implements ApiDeleteSession {
  const _ApiDeleteSession({this.t = '', this.sid = ''});
  factory _ApiDeleteSession.fromJson(Map<String, dynamic> json) => _$ApiDeleteSessionFromJson(json);

@override@JsonKey() final  String t;
@override@JsonKey() final  String sid;

/// Create a copy of ApiDeleteSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiDeleteSessionCopyWith<_ApiDeleteSession> get copyWith => __$ApiDeleteSessionCopyWithImpl<_ApiDeleteSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiDeleteSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiDeleteSession&&(identical(other.t, t) || other.t == t)&&(identical(other.sid, sid) || other.sid == sid));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,sid);

@override
String toString() {
  return 'ApiDeleteSession(t: $t, sid: $sid)';
}


}

/// @nodoc
abstract mixin class _$ApiDeleteSessionCopyWith<$Res> implements $ApiDeleteSessionCopyWith<$Res> {
  factory _$ApiDeleteSessionCopyWith(_ApiDeleteSession value, $Res Function(_ApiDeleteSession) _then) = __$ApiDeleteSessionCopyWithImpl;
@override @useResult
$Res call({
 String t, String sid
});




}
/// @nodoc
class __$ApiDeleteSessionCopyWithImpl<$Res>
    implements _$ApiDeleteSessionCopyWith<$Res> {
  __$ApiDeleteSessionCopyWithImpl(this._self, this._then);

  final _ApiDeleteSession _self;
  final $Res Function(_ApiDeleteSession) _then;

/// Create a copy of ApiDeleteSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? t = null,Object? sid = null,}) {
  return _then(_ApiDeleteSession(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,sid: null == sid ? _self.sid : sid // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ApiUpdateSessionState {

 String get t; String get id; VersionedValue? get agentState; VersionedValue? get metadata;
/// Create a copy of ApiUpdateSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiUpdateSessionStateCopyWith<ApiUpdateSessionState> get copyWith => _$ApiUpdateSessionStateCopyWithImpl<ApiUpdateSessionState>(this as ApiUpdateSessionState, _$identity);

  /// Serializes this ApiUpdateSessionState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiUpdateSessionState&&(identical(other.t, t) || other.t == t)&&(identical(other.id, id) || other.id == id)&&(identical(other.agentState, agentState) || other.agentState == agentState)&&(identical(other.metadata, metadata) || other.metadata == metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,id,agentState,metadata);

@override
String toString() {
  return 'ApiUpdateSessionState(t: $t, id: $id, agentState: $agentState, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class $ApiUpdateSessionStateCopyWith<$Res>  {
  factory $ApiUpdateSessionStateCopyWith(ApiUpdateSessionState value, $Res Function(ApiUpdateSessionState) _then) = _$ApiUpdateSessionStateCopyWithImpl;
@useResult
$Res call({
 String t, String id, VersionedValue? agentState, VersionedValue? metadata
});


$VersionedValueCopyWith<$Res>? get agentState;$VersionedValueCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$ApiUpdateSessionStateCopyWithImpl<$Res>
    implements $ApiUpdateSessionStateCopyWith<$Res> {
  _$ApiUpdateSessionStateCopyWithImpl(this._self, this._then);

  final ApiUpdateSessionState _self;
  final $Res Function(ApiUpdateSessionState) _then;

/// Create a copy of ApiUpdateSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? t = null,Object? id = null,Object? agentState = freezed,Object? metadata = freezed,}) {
  return _then(_self.copyWith(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentState: freezed == agentState ? _self.agentState : agentState // ignore: cast_nullable_to_non_nullable
as VersionedValue?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as VersionedValue?,
  ));
}
/// Create a copy of ApiUpdateSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionedValueCopyWith<$Res>? get agentState {
    if (_self.agentState == null) {
    return null;
  }

  return $VersionedValueCopyWith<$Res>(_self.agentState!, (value) {
    return _then(_self.copyWith(agentState: value));
  });
}/// Create a copy of ApiUpdateSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionedValueCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $VersionedValueCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// Adds pattern-matching-related methods to [ApiUpdateSessionState].
extension ApiUpdateSessionStatePatterns on ApiUpdateSessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiUpdateSessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiUpdateSessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiUpdateSessionState value)  $default,){
final _that = this;
switch (_that) {
case _ApiUpdateSessionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiUpdateSessionState value)?  $default,){
final _that = this;
switch (_that) {
case _ApiUpdateSessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String t,  String id,  VersionedValue? agentState,  VersionedValue? metadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiUpdateSessionState() when $default != null:
return $default(_that.t,_that.id,_that.agentState,_that.metadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String t,  String id,  VersionedValue? agentState,  VersionedValue? metadata)  $default,) {final _that = this;
switch (_that) {
case _ApiUpdateSessionState():
return $default(_that.t,_that.id,_that.agentState,_that.metadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String t,  String id,  VersionedValue? agentState,  VersionedValue? metadata)?  $default,) {final _that = this;
switch (_that) {
case _ApiUpdateSessionState() when $default != null:
return $default(_that.t,_that.id,_that.agentState,_that.metadata);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiUpdateSessionState implements ApiUpdateSessionState {
  const _ApiUpdateSessionState({this.t = '', this.id = '', this.agentState, this.metadata});
  factory _ApiUpdateSessionState.fromJson(Map<String, dynamic> json) => _$ApiUpdateSessionStateFromJson(json);

@override@JsonKey() final  String t;
@override@JsonKey() final  String id;
@override final  VersionedValue? agentState;
@override final  VersionedValue? metadata;

/// Create a copy of ApiUpdateSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiUpdateSessionStateCopyWith<_ApiUpdateSessionState> get copyWith => __$ApiUpdateSessionStateCopyWithImpl<_ApiUpdateSessionState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiUpdateSessionStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiUpdateSessionState&&(identical(other.t, t) || other.t == t)&&(identical(other.id, id) || other.id == id)&&(identical(other.agentState, agentState) || other.agentState == agentState)&&(identical(other.metadata, metadata) || other.metadata == metadata));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,id,agentState,metadata);

@override
String toString() {
  return 'ApiUpdateSessionState(t: $t, id: $id, agentState: $agentState, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$ApiUpdateSessionStateCopyWith<$Res> implements $ApiUpdateSessionStateCopyWith<$Res> {
  factory _$ApiUpdateSessionStateCopyWith(_ApiUpdateSessionState value, $Res Function(_ApiUpdateSessionState) _then) = __$ApiUpdateSessionStateCopyWithImpl;
@override @useResult
$Res call({
 String t, String id, VersionedValue? agentState, VersionedValue? metadata
});


@override $VersionedValueCopyWith<$Res>? get agentState;@override $VersionedValueCopyWith<$Res>? get metadata;

}
/// @nodoc
class __$ApiUpdateSessionStateCopyWithImpl<$Res>
    implements _$ApiUpdateSessionStateCopyWith<$Res> {
  __$ApiUpdateSessionStateCopyWithImpl(this._self, this._then);

  final _ApiUpdateSessionState _self;
  final $Res Function(_ApiUpdateSessionState) _then;

/// Create a copy of ApiUpdateSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? t = null,Object? id = null,Object? agentState = freezed,Object? metadata = freezed,}) {
  return _then(_ApiUpdateSessionState(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,agentState: freezed == agentState ? _self.agentState : agentState // ignore: cast_nullable_to_non_nullable
as VersionedValue?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as VersionedValue?,
  ));
}

/// Create a copy of ApiUpdateSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionedValueCopyWith<$Res>? get agentState {
    if (_self.agentState == null) {
    return null;
  }

  return $VersionedValueCopyWith<$Res>(_self.agentState!, (value) {
    return _then(_self.copyWith(agentState: value));
  });
}/// Create a copy of ApiUpdateSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VersionedValueCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $VersionedValueCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// @nodoc
mixin _$VersionedValue {

 int get version;/// The serialised value string. Null on the wire is normalised to `''`.
 String get value;
/// Create a copy of VersionedValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VersionedValueCopyWith<VersionedValue> get copyWith => _$VersionedValueCopyWithImpl<VersionedValue>(this as VersionedValue, _$identity);

  /// Serializes this VersionedValue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VersionedValue&&(identical(other.version, version) || other.version == version)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,value);

@override
String toString() {
  return 'VersionedValue(version: $version, value: $value)';
}


}

/// @nodoc
abstract mixin class $VersionedValueCopyWith<$Res>  {
  factory $VersionedValueCopyWith(VersionedValue value, $Res Function(VersionedValue) _then) = _$VersionedValueCopyWithImpl;
@useResult
$Res call({
 int version, String value
});




}
/// @nodoc
class _$VersionedValueCopyWithImpl<$Res>
    implements $VersionedValueCopyWith<$Res> {
  _$VersionedValueCopyWithImpl(this._self, this._then);

  final VersionedValue _self;
  final $Res Function(VersionedValue) _then;

/// Create a copy of VersionedValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? value = null,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VersionedValue].
extension VersionedValuePatterns on VersionedValue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VersionedValue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VersionedValue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VersionedValue value)  $default,){
final _that = this;
switch (_that) {
case _VersionedValue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VersionedValue value)?  $default,){
final _that = this;
switch (_that) {
case _VersionedValue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version,  String value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VersionedValue() when $default != null:
return $default(_that.version,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version,  String value)  $default,) {final _that = this;
switch (_that) {
case _VersionedValue():
return $default(_that.version,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version,  String value)?  $default,) {final _that = this;
switch (_that) {
case _VersionedValue() when $default != null:
return $default(_that.version,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VersionedValue implements VersionedValue {
  const _VersionedValue({this.version = 0, this.value = ''});
  factory _VersionedValue.fromJson(Map<String, dynamic> json) => _$VersionedValueFromJson(json);

@override@JsonKey() final  int version;
/// The serialised value string. Null on the wire is normalised to `''`.
@override@JsonKey() final  String value;

/// Create a copy of VersionedValue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VersionedValueCopyWith<_VersionedValue> get copyWith => __$VersionedValueCopyWithImpl<_VersionedValue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VersionedValueToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VersionedValue&&(identical(other.version, version) || other.version == version)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,value);

@override
String toString() {
  return 'VersionedValue(version: $version, value: $value)';
}


}

/// @nodoc
abstract mixin class _$VersionedValueCopyWith<$Res> implements $VersionedValueCopyWith<$Res> {
  factory _$VersionedValueCopyWith(_VersionedValue value, $Res Function(_VersionedValue) _then) = __$VersionedValueCopyWithImpl;
@override @useResult
$Res call({
 int version, String value
});




}
/// @nodoc
class __$VersionedValueCopyWithImpl<$Res>
    implements _$VersionedValueCopyWith<$Res> {
  __$VersionedValueCopyWithImpl(this._self, this._then);

  final _VersionedValue _self;
  final $Res Function(_VersionedValue) _then;

/// Create a copy of VersionedValue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? value = null,}) {
  return _then(_VersionedValue(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
