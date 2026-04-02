// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiMessage {

@JsonKey(fromJson: _contentFromJson) ApiMessageContent get content; String get id;@JsonKey(fromJson: _asApiInt) int get seq; String? get localId;@JsonKey(fromJson: _asApiInt) int get createdAt;@JsonKey(fromJson: _asApiIntNullable) int? get updatedAt;
/// Create a copy of ApiMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiMessageCopyWith<ApiMessage> get copyWith => _$ApiMessageCopyWithImpl<ApiMessage>(this as ApiMessage, _$identity);

  /// Serializes this ApiMessage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiMessage&&(identical(other.content, content) || other.content == content)&&(identical(other.id, id) || other.id == id)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.localId, localId) || other.localId == localId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,id,seq,localId,createdAt,updatedAt);

@override
String toString() {
  return 'ApiMessage(content: $content, id: $id, seq: $seq, localId: $localId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ApiMessageCopyWith<$Res>  {
  factory $ApiMessageCopyWith(ApiMessage value, $Res Function(ApiMessage) _then) = _$ApiMessageCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) ApiMessageContent content, String id,@JsonKey(fromJson: _asApiInt) int seq, String? localId,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiIntNullable) int? updatedAt
});


$ApiMessageContentCopyWith<$Res> get content;

}
/// @nodoc
class _$ApiMessageCopyWithImpl<$Res>
    implements $ApiMessageCopyWith<$Res> {
  _$ApiMessageCopyWithImpl(this._self, this._then);

  final ApiMessage _self;
  final $Res Function(ApiMessage) _then;

/// Create a copy of ApiMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? content = null,Object? id = null,Object? seq = null,Object? localId = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as ApiMessageContent,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,localId: freezed == localId ? _self.localId : localId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of ApiMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiMessageContentCopyWith<$Res> get content {
  
  return $ApiMessageContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}


/// Adds pattern-matching-related methods to [ApiMessage].
extension ApiMessagePatterns on ApiMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiMessage value)  $default,){
final _that = this;
switch (_that) {
case _ApiMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ApiMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _contentFromJson)  ApiMessageContent content,  String id, @JsonKey(fromJson: _asApiInt)  int seq,  String? localId, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiIntNullable)  int? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiMessage() when $default != null:
return $default(_that.content,_that.id,_that.seq,_that.localId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _contentFromJson)  ApiMessageContent content,  String id, @JsonKey(fromJson: _asApiInt)  int seq,  String? localId, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiIntNullable)  int? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ApiMessage():
return $default(_that.content,_that.id,_that.seq,_that.localId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _contentFromJson)  ApiMessageContent content,  String id, @JsonKey(fromJson: _asApiInt)  int seq,  String? localId, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiIntNullable)  int? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ApiMessage() when $default != null:
return $default(_that.content,_that.id,_that.seq,_that.localId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiMessage implements ApiMessage {
  const _ApiMessage({@JsonKey(fromJson: _contentFromJson) required this.content, this.id = '', @JsonKey(fromJson: _asApiInt) this.seq = 0, this.localId, @JsonKey(fromJson: _asApiInt) this.createdAt = 0, @JsonKey(fromJson: _asApiIntNullable) this.updatedAt});
  factory _ApiMessage.fromJson(Map<String, dynamic> json) => _$ApiMessageFromJson(json);

@override@JsonKey(fromJson: _contentFromJson) final  ApiMessageContent content;
@override@JsonKey() final  String id;
@override@JsonKey(fromJson: _asApiInt) final  int seq;
@override final  String? localId;
@override@JsonKey(fromJson: _asApiInt) final  int createdAt;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? updatedAt;

/// Create a copy of ApiMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiMessageCopyWith<_ApiMessage> get copyWith => __$ApiMessageCopyWithImpl<_ApiMessage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiMessageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiMessage&&(identical(other.content, content) || other.content == content)&&(identical(other.id, id) || other.id == id)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.localId, localId) || other.localId == localId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,content,id,seq,localId,createdAt,updatedAt);

@override
String toString() {
  return 'ApiMessage(content: $content, id: $id, seq: $seq, localId: $localId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ApiMessageCopyWith<$Res> implements $ApiMessageCopyWith<$Res> {
  factory _$ApiMessageCopyWith(_ApiMessage value, $Res Function(_ApiMessage) _then) = __$ApiMessageCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _contentFromJson) ApiMessageContent content, String id,@JsonKey(fromJson: _asApiInt) int seq, String? localId,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiIntNullable) int? updatedAt
});


@override $ApiMessageContentCopyWith<$Res> get content;

}
/// @nodoc
class __$ApiMessageCopyWithImpl<$Res>
    implements _$ApiMessageCopyWith<$Res> {
  __$ApiMessageCopyWithImpl(this._self, this._then);

  final _ApiMessage _self;
  final $Res Function(_ApiMessage) _then;

/// Create a copy of ApiMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? content = null,Object? id = null,Object? seq = null,Object? localId = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_ApiMessage(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as ApiMessageContent,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,localId: freezed == localId ? _self.localId : localId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of ApiMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ApiMessageContentCopyWith<$Res> get content {
  
  return $ApiMessageContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}
}


/// @nodoc
mixin _$ApiMessageContent {

 String get t; String get c;
/// Create a copy of ApiMessageContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiMessageContentCopyWith<ApiMessageContent> get copyWith => _$ApiMessageContentCopyWithImpl<ApiMessageContent>(this as ApiMessageContent, _$identity);

  /// Serializes this ApiMessageContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiMessageContent&&(identical(other.t, t) || other.t == t)&&(identical(other.c, c) || other.c == c));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,c);

@override
String toString() {
  return 'ApiMessageContent(t: $t, c: $c)';
}


}

/// @nodoc
abstract mixin class $ApiMessageContentCopyWith<$Res>  {
  factory $ApiMessageContentCopyWith(ApiMessageContent value, $Res Function(ApiMessageContent) _then) = _$ApiMessageContentCopyWithImpl;
@useResult
$Res call({
 String t, String c
});




}
/// @nodoc
class _$ApiMessageContentCopyWithImpl<$Res>
    implements $ApiMessageContentCopyWith<$Res> {
  _$ApiMessageContentCopyWithImpl(this._self, this._then);

  final ApiMessageContent _self;
  final $Res Function(ApiMessageContent) _then;

/// Create a copy of ApiMessageContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? t = null,Object? c = null,}) {
  return _then(_self.copyWith(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,c: null == c ? _self.c : c // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiMessageContent].
extension ApiMessageContentPatterns on ApiMessageContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiMessageContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiMessageContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiMessageContent value)  $default,){
final _that = this;
switch (_that) {
case _ApiMessageContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiMessageContent value)?  $default,){
final _that = this;
switch (_that) {
case _ApiMessageContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String t,  String c)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiMessageContent() when $default != null:
return $default(_that.t,_that.c);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String t,  String c)  $default,) {final _that = this;
switch (_that) {
case _ApiMessageContent():
return $default(_that.t,_that.c);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String t,  String c)?  $default,) {final _that = this;
switch (_that) {
case _ApiMessageContent() when $default != null:
return $default(_that.t,_that.c);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiMessageContent implements ApiMessageContent {
  const _ApiMessageContent({this.t = '', this.c = ''});
  factory _ApiMessageContent.fromJson(Map<String, dynamic> json) => _$ApiMessageContentFromJson(json);

@override@JsonKey() final  String t;
@override@JsonKey() final  String c;

/// Create a copy of ApiMessageContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiMessageContentCopyWith<_ApiMessageContent> get copyWith => __$ApiMessageContentCopyWithImpl<_ApiMessageContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiMessageContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiMessageContent&&(identical(other.t, t) || other.t == t)&&(identical(other.c, c) || other.c == c));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,t,c);

@override
String toString() {
  return 'ApiMessageContent(t: $t, c: $c)';
}


}

/// @nodoc
abstract mixin class _$ApiMessageContentCopyWith<$Res> implements $ApiMessageContentCopyWith<$Res> {
  factory _$ApiMessageContentCopyWith(_ApiMessageContent value, $Res Function(_ApiMessageContent) _then) = __$ApiMessageContentCopyWithImpl;
@override @useResult
$Res call({
 String t, String c
});




}
/// @nodoc
class __$ApiMessageContentCopyWithImpl<$Res>
    implements _$ApiMessageContentCopyWith<$Res> {
  __$ApiMessageContentCopyWithImpl(this._self, this._then);

  final _ApiMessageContent _self;
  final $Res Function(_ApiMessageContent) _then;

/// Create a copy of ApiMessageContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? t = null,Object? c = null,}) {
  return _then(_ApiMessageContent(
t: null == t ? _self.t : t // ignore: cast_nullable_to_non_nullable
as String,c: null == c ? _self.c : c // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ToolCall {

 String get name; String get state; int get createdAt;@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? get input; int? get startedAt; int? get completedAt; String? get description;@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? get result;@JsonKey(fromJson: _permissionOrNull) Permission? get permission;
/// Create a copy of ToolCall
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallCopyWith<ToolCall> get copyWith => _$ToolCallCopyWithImpl<ToolCall>(this as ToolCall, _$identity);

  /// Serializes this ToolCall to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCall&&(identical(other.name, name) || other.name == name)&&(identical(other.state, state) || other.state == state)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.input, input)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.result, result)&&(identical(other.permission, permission) || other.permission == permission));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,state,createdAt,const DeepCollectionEquality().hash(input),startedAt,completedAt,description,const DeepCollectionEquality().hash(result),permission);

@override
String toString() {
  return 'ToolCall(name: $name, state: $state, createdAt: $createdAt, input: $input, startedAt: $startedAt, completedAt: $completedAt, description: $description, result: $result, permission: $permission)';
}


}

/// @nodoc
abstract mixin class $ToolCallCopyWith<$Res>  {
  factory $ToolCallCopyWith(ToolCall value, $Res Function(ToolCall) _then) = _$ToolCallCopyWithImpl;
@useResult
$Res call({
 String name, String state, int createdAt,@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? input, int? startedAt, int? completedAt, String? description,@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? result,@JsonKey(fromJson: _permissionOrNull) Permission? permission
});


$PermissionCopyWith<$Res>? get permission;

}
/// @nodoc
class _$ToolCallCopyWithImpl<$Res>
    implements $ToolCallCopyWith<$Res> {
  _$ToolCallCopyWithImpl(this._self, this._then);

  final ToolCall _self;
  final $Res Function(ToolCall) _then;

/// Create a copy of ToolCall
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? state = null,Object? createdAt = null,Object? input = freezed,Object? startedAt = freezed,Object? completedAt = freezed,Object? description = freezed,Object? result = freezed,Object? permission = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,input: freezed == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as int?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as int?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,permission: freezed == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as Permission?,
  ));
}
/// Create a copy of ToolCall
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PermissionCopyWith<$Res>? get permission {
    if (_self.permission == null) {
    return null;
  }

  return $PermissionCopyWith<$Res>(_self.permission!, (value) {
    return _then(_self.copyWith(permission: value));
  });
}
}


/// Adds pattern-matching-related methods to [ToolCall].
extension ToolCallPatterns on ToolCall {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCall value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCall() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCall value)  $default,){
final _that = this;
switch (_that) {
case _ToolCall():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCall value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCall() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String state,  int createdAt, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? input,  int? startedAt,  int? completedAt,  String? description, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? result, @JsonKey(fromJson: _permissionOrNull)  Permission? permission)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCall() when $default != null:
return $default(_that.name,_that.state,_that.createdAt,_that.input,_that.startedAt,_that.completedAt,_that.description,_that.result,_that.permission);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String state,  int createdAt, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? input,  int? startedAt,  int? completedAt,  String? description, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? result, @JsonKey(fromJson: _permissionOrNull)  Permission? permission)  $default,) {final _that = this;
switch (_that) {
case _ToolCall():
return $default(_that.name,_that.state,_that.createdAt,_that.input,_that.startedAt,_that.completedAt,_that.description,_that.result,_that.permission);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String state,  int createdAt, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? input,  int? startedAt,  int? completedAt,  String? description, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? result, @JsonKey(fromJson: _permissionOrNull)  Permission? permission)?  $default,) {final _that = this;
switch (_that) {
case _ToolCall() when $default != null:
return $default(_that.name,_that.state,_that.createdAt,_that.input,_that.startedAt,_that.completedAt,_that.description,_that.result,_that.permission);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ToolCall implements ToolCall {
  const _ToolCall({required this.name, required this.state, required this.createdAt, @JsonKey(fromJson: _mapOrNull) final  Map<String, dynamic>? input, this.startedAt, this.completedAt, this.description, @JsonKey(fromJson: _mapOrNull) final  Map<String, dynamic>? result, @JsonKey(fromJson: _permissionOrNull) this.permission}): _input = input,_result = result;
  factory _ToolCall.fromJson(Map<String, dynamic> json) => _$ToolCallFromJson(json);

@override final  String name;
@override final  String state;
@override final  int createdAt;
 final  Map<String, dynamic>? _input;
@override@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? get input {
  final value = _input;
  if (value == null) return null;
  if (_input is EqualUnmodifiableMapView) return _input;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  int? startedAt;
@override final  int? completedAt;
@override final  String? description;
 final  Map<String, dynamic>? _result;
@override@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? get result {
  final value = _result;
  if (value == null) return null;
  if (_result is EqualUnmodifiableMapView) return _result;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(fromJson: _permissionOrNull) final  Permission? permission;

/// Create a copy of ToolCall
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallCopyWith<_ToolCall> get copyWith => __$ToolCallCopyWithImpl<_ToolCall>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolCallToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCall&&(identical(other.name, name) || other.name == name)&&(identical(other.state, state) || other.state == state)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._input, _input)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._result, _result)&&(identical(other.permission, permission) || other.permission == permission));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,state,createdAt,const DeepCollectionEquality().hash(_input),startedAt,completedAt,description,const DeepCollectionEquality().hash(_result),permission);

@override
String toString() {
  return 'ToolCall(name: $name, state: $state, createdAt: $createdAt, input: $input, startedAt: $startedAt, completedAt: $completedAt, description: $description, result: $result, permission: $permission)';
}


}

/// @nodoc
abstract mixin class _$ToolCallCopyWith<$Res> implements $ToolCallCopyWith<$Res> {
  factory _$ToolCallCopyWith(_ToolCall value, $Res Function(_ToolCall) _then) = __$ToolCallCopyWithImpl;
@override @useResult
$Res call({
 String name, String state, int createdAt,@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? input, int? startedAt, int? completedAt, String? description,@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? result,@JsonKey(fromJson: _permissionOrNull) Permission? permission
});


@override $PermissionCopyWith<$Res>? get permission;

}
/// @nodoc
class __$ToolCallCopyWithImpl<$Res>
    implements _$ToolCallCopyWith<$Res> {
  __$ToolCallCopyWithImpl(this._self, this._then);

  final _ToolCall _self;
  final $Res Function(_ToolCall) _then;

/// Create a copy of ToolCall
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? state = null,Object? createdAt = null,Object? input = freezed,Object? startedAt = freezed,Object? completedAt = freezed,Object? description = freezed,Object? result = freezed,Object? permission = freezed,}) {
  return _then(_ToolCall(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,input: freezed == input ? _self._input : input // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as int?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as int?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,result: freezed == result ? _self._result : result // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,permission: freezed == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as Permission?,
  ));
}

/// Create a copy of ToolCall
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PermissionCopyWith<$Res>? get permission {
    if (_self.permission == null) {
    return null;
  }

  return $PermissionCopyWith<$Res>(_self.permission!, (value) {
    return _then(_self.copyWith(permission: value));
  });
}
}


/// @nodoc
mixin _$Permission {

 String get id; String get status; String? get reason; String? get mode;@JsonKey(fromJson: _stringListOrNull) List<String>? get allowedTools; String? get decision; int? get date;
/// Create a copy of Permission
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PermissionCopyWith<Permission> get copyWith => _$PermissionCopyWithImpl<Permission>(this as Permission, _$identity);

  /// Serializes this Permission to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Permission&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other.allowedTools, allowedTools)&&(identical(other.decision, decision) || other.decision == decision)&&(identical(other.date, date) || other.date == date));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,reason,mode,const DeepCollectionEquality().hash(allowedTools),decision,date);

@override
String toString() {
  return 'Permission(id: $id, status: $status, reason: $reason, mode: $mode, allowedTools: $allowedTools, decision: $decision, date: $date)';
}


}

/// @nodoc
abstract mixin class $PermissionCopyWith<$Res>  {
  factory $PermissionCopyWith(Permission value, $Res Function(Permission) _then) = _$PermissionCopyWithImpl;
@useResult
$Res call({
 String id, String status, String? reason, String? mode,@JsonKey(fromJson: _stringListOrNull) List<String>? allowedTools, String? decision, int? date
});




}
/// @nodoc
class _$PermissionCopyWithImpl<$Res>
    implements $PermissionCopyWith<$Res> {
  _$PermissionCopyWithImpl(this._self, this._then);

  final Permission _self;
  final $Res Function(Permission) _then;

/// Create a copy of Permission
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? status = null,Object? reason = freezed,Object? mode = freezed,Object? allowedTools = freezed,Object? decision = freezed,Object? date = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,allowedTools: freezed == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>?,decision: freezed == decision ? _self.decision : decision // ignore: cast_nullable_to_non_nullable
as String?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Permission].
extension PermissionPatterns on Permission {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Permission value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Permission() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Permission value)  $default,){
final _that = this;
switch (_that) {
case _Permission():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Permission value)?  $default,){
final _that = this;
switch (_that) {
case _Permission() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String status,  String? reason,  String? mode, @JsonKey(fromJson: _stringListOrNull)  List<String>? allowedTools,  String? decision,  int? date)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Permission() when $default != null:
return $default(_that.id,_that.status,_that.reason,_that.mode,_that.allowedTools,_that.decision,_that.date);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String status,  String? reason,  String? mode, @JsonKey(fromJson: _stringListOrNull)  List<String>? allowedTools,  String? decision,  int? date)  $default,) {final _that = this;
switch (_that) {
case _Permission():
return $default(_that.id,_that.status,_that.reason,_that.mode,_that.allowedTools,_that.decision,_that.date);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String status,  String? reason,  String? mode, @JsonKey(fromJson: _stringListOrNull)  List<String>? allowedTools,  String? decision,  int? date)?  $default,) {final _that = this;
switch (_that) {
case _Permission() when $default != null:
return $default(_that.id,_that.status,_that.reason,_that.mode,_that.allowedTools,_that.decision,_that.date);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Permission implements Permission {
  const _Permission({required this.id, required this.status, this.reason, this.mode, @JsonKey(fromJson: _stringListOrNull) final  List<String>? allowedTools, this.decision, this.date}): _allowedTools = allowedTools;
  factory _Permission.fromJson(Map<String, dynamic> json) => _$PermissionFromJson(json);

@override final  String id;
@override final  String status;
@override final  String? reason;
@override final  String? mode;
 final  List<String>? _allowedTools;
@override@JsonKey(fromJson: _stringListOrNull) List<String>? get allowedTools {
  final value = _allowedTools;
  if (value == null) return null;
  if (_allowedTools is EqualUnmodifiableListView) return _allowedTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? decision;
@override final  int? date;

/// Create a copy of Permission
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PermissionCopyWith<_Permission> get copyWith => __$PermissionCopyWithImpl<_Permission>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PermissionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Permission&&(identical(other.id, id) || other.id == id)&&(identical(other.status, status) || other.status == status)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other._allowedTools, _allowedTools)&&(identical(other.decision, decision) || other.decision == decision)&&(identical(other.date, date) || other.date == date));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,status,reason,mode,const DeepCollectionEquality().hash(_allowedTools),decision,date);

@override
String toString() {
  return 'Permission(id: $id, status: $status, reason: $reason, mode: $mode, allowedTools: $allowedTools, decision: $decision, date: $date)';
}


}

/// @nodoc
abstract mixin class _$PermissionCopyWith<$Res> implements $PermissionCopyWith<$Res> {
  factory _$PermissionCopyWith(_Permission value, $Res Function(_Permission) _then) = __$PermissionCopyWithImpl;
@override @useResult
$Res call({
 String id, String status, String? reason, String? mode,@JsonKey(fromJson: _stringListOrNull) List<String>? allowedTools, String? decision, int? date
});




}
/// @nodoc
class __$PermissionCopyWithImpl<$Res>
    implements _$PermissionCopyWith<$Res> {
  __$PermissionCopyWithImpl(this._self, this._then);

  final _Permission _self;
  final $Res Function(_Permission) _then;

/// Create a copy of Permission
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? status = null,Object? reason = freezed,Object? mode = freezed,Object? allowedTools = freezed,Object? decision = freezed,Object? date = freezed,}) {
  return _then(_Permission(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,allowedTools: freezed == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>?,decision: freezed == decision ? _self.decision : decision // ignore: cast_nullable_to_non_nullable
as String?,date: freezed == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$MessageMeta {

 String? get sentFrom; String? get permissionMode; String? get model; String? get fallbackModel; String? get customSystemPrompt; String? get appendSystemPrompt;@JsonKey(fromJson: _stringListOrNull) List<String>? get allowedTools;@JsonKey(fromJson: _stringListOrNull) List<String>? get disallowedTools; String? get displayText;
/// Create a copy of MessageMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageMetaCopyWith<MessageMeta> get copyWith => _$MessageMetaCopyWithImpl<MessageMeta>(this as MessageMeta, _$identity);

  /// Serializes this MessageMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageMeta&&(identical(other.sentFrom, sentFrom) || other.sentFrom == sentFrom)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode)&&(identical(other.model, model) || other.model == model)&&(identical(other.fallbackModel, fallbackModel) || other.fallbackModel == fallbackModel)&&(identical(other.customSystemPrompt, customSystemPrompt) || other.customSystemPrompt == customSystemPrompt)&&(identical(other.appendSystemPrompt, appendSystemPrompt) || other.appendSystemPrompt == appendSystemPrompt)&&const DeepCollectionEquality().equals(other.allowedTools, allowedTools)&&const DeepCollectionEquality().equals(other.disallowedTools, disallowedTools)&&(identical(other.displayText, displayText) || other.displayText == displayText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sentFrom,permissionMode,model,fallbackModel,customSystemPrompt,appendSystemPrompt,const DeepCollectionEquality().hash(allowedTools),const DeepCollectionEquality().hash(disallowedTools),displayText);

@override
String toString() {
  return 'MessageMeta(sentFrom: $sentFrom, permissionMode: $permissionMode, model: $model, fallbackModel: $fallbackModel, customSystemPrompt: $customSystemPrompt, appendSystemPrompt: $appendSystemPrompt, allowedTools: $allowedTools, disallowedTools: $disallowedTools, displayText: $displayText)';
}


}

/// @nodoc
abstract mixin class $MessageMetaCopyWith<$Res>  {
  factory $MessageMetaCopyWith(MessageMeta value, $Res Function(MessageMeta) _then) = _$MessageMetaCopyWithImpl;
@useResult
$Res call({
 String? sentFrom, String? permissionMode, String? model, String? fallbackModel, String? customSystemPrompt, String? appendSystemPrompt,@JsonKey(fromJson: _stringListOrNull) List<String>? allowedTools,@JsonKey(fromJson: _stringListOrNull) List<String>? disallowedTools, String? displayText
});




}
/// @nodoc
class _$MessageMetaCopyWithImpl<$Res>
    implements $MessageMetaCopyWith<$Res> {
  _$MessageMetaCopyWithImpl(this._self, this._then);

  final MessageMeta _self;
  final $Res Function(MessageMeta) _then;

/// Create a copy of MessageMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sentFrom = freezed,Object? permissionMode = freezed,Object? model = freezed,Object? fallbackModel = freezed,Object? customSystemPrompt = freezed,Object? appendSystemPrompt = freezed,Object? allowedTools = freezed,Object? disallowedTools = freezed,Object? displayText = freezed,}) {
  return _then(_self.copyWith(
sentFrom: freezed == sentFrom ? _self.sentFrom : sentFrom // ignore: cast_nullable_to_non_nullable
as String?,permissionMode: freezed == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,fallbackModel: freezed == fallbackModel ? _self.fallbackModel : fallbackModel // ignore: cast_nullable_to_non_nullable
as String?,customSystemPrompt: freezed == customSystemPrompt ? _self.customSystemPrompt : customSystemPrompt // ignore: cast_nullable_to_non_nullable
as String?,appendSystemPrompt: freezed == appendSystemPrompt ? _self.appendSystemPrompt : appendSystemPrompt // ignore: cast_nullable_to_non_nullable
as String?,allowedTools: freezed == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>?,disallowedTools: freezed == disallowedTools ? _self.disallowedTools : disallowedTools // ignore: cast_nullable_to_non_nullable
as List<String>?,displayText: freezed == displayText ? _self.displayText : displayText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MessageMeta].
extension MessageMetaPatterns on MessageMeta {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageMeta value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageMeta() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageMeta value)  $default,){
final _that = this;
switch (_that) {
case _MessageMeta():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageMeta value)?  $default,){
final _that = this;
switch (_that) {
case _MessageMeta() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? sentFrom,  String? permissionMode,  String? model,  String? fallbackModel,  String? customSystemPrompt,  String? appendSystemPrompt, @JsonKey(fromJson: _stringListOrNull)  List<String>? allowedTools, @JsonKey(fromJson: _stringListOrNull)  List<String>? disallowedTools,  String? displayText)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageMeta() when $default != null:
return $default(_that.sentFrom,_that.permissionMode,_that.model,_that.fallbackModel,_that.customSystemPrompt,_that.appendSystemPrompt,_that.allowedTools,_that.disallowedTools,_that.displayText);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? sentFrom,  String? permissionMode,  String? model,  String? fallbackModel,  String? customSystemPrompt,  String? appendSystemPrompt, @JsonKey(fromJson: _stringListOrNull)  List<String>? allowedTools, @JsonKey(fromJson: _stringListOrNull)  List<String>? disallowedTools,  String? displayText)  $default,) {final _that = this;
switch (_that) {
case _MessageMeta():
return $default(_that.sentFrom,_that.permissionMode,_that.model,_that.fallbackModel,_that.customSystemPrompt,_that.appendSystemPrompt,_that.allowedTools,_that.disallowedTools,_that.displayText);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? sentFrom,  String? permissionMode,  String? model,  String? fallbackModel,  String? customSystemPrompt,  String? appendSystemPrompt, @JsonKey(fromJson: _stringListOrNull)  List<String>? allowedTools, @JsonKey(fromJson: _stringListOrNull)  List<String>? disallowedTools,  String? displayText)?  $default,) {final _that = this;
switch (_that) {
case _MessageMeta() when $default != null:
return $default(_that.sentFrom,_that.permissionMode,_that.model,_that.fallbackModel,_that.customSystemPrompt,_that.appendSystemPrompt,_that.allowedTools,_that.disallowedTools,_that.displayText);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MessageMeta implements MessageMeta {
  const _MessageMeta({this.sentFrom, this.permissionMode, this.model, this.fallbackModel, this.customSystemPrompt, this.appendSystemPrompt, @JsonKey(fromJson: _stringListOrNull) final  List<String>? allowedTools, @JsonKey(fromJson: _stringListOrNull) final  List<String>? disallowedTools, this.displayText}): _allowedTools = allowedTools,_disallowedTools = disallowedTools;
  factory _MessageMeta.fromJson(Map<String, dynamic> json) => _$MessageMetaFromJson(json);

@override final  String? sentFrom;
@override final  String? permissionMode;
@override final  String? model;
@override final  String? fallbackModel;
@override final  String? customSystemPrompt;
@override final  String? appendSystemPrompt;
 final  List<String>? _allowedTools;
@override@JsonKey(fromJson: _stringListOrNull) List<String>? get allowedTools {
  final value = _allowedTools;
  if (value == null) return null;
  if (_allowedTools is EqualUnmodifiableListView) return _allowedTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String>? _disallowedTools;
@override@JsonKey(fromJson: _stringListOrNull) List<String>? get disallowedTools {
  final value = _disallowedTools;
  if (value == null) return null;
  if (_disallowedTools is EqualUnmodifiableListView) return _disallowedTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? displayText;

/// Create a copy of MessageMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageMetaCopyWith<_MessageMeta> get copyWith => __$MessageMetaCopyWithImpl<_MessageMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MessageMetaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageMeta&&(identical(other.sentFrom, sentFrom) || other.sentFrom == sentFrom)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode)&&(identical(other.model, model) || other.model == model)&&(identical(other.fallbackModel, fallbackModel) || other.fallbackModel == fallbackModel)&&(identical(other.customSystemPrompt, customSystemPrompt) || other.customSystemPrompt == customSystemPrompt)&&(identical(other.appendSystemPrompt, appendSystemPrompt) || other.appendSystemPrompt == appendSystemPrompt)&&const DeepCollectionEquality().equals(other._allowedTools, _allowedTools)&&const DeepCollectionEquality().equals(other._disallowedTools, _disallowedTools)&&(identical(other.displayText, displayText) || other.displayText == displayText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sentFrom,permissionMode,model,fallbackModel,customSystemPrompt,appendSystemPrompt,const DeepCollectionEquality().hash(_allowedTools),const DeepCollectionEquality().hash(_disallowedTools),displayText);

@override
String toString() {
  return 'MessageMeta(sentFrom: $sentFrom, permissionMode: $permissionMode, model: $model, fallbackModel: $fallbackModel, customSystemPrompt: $customSystemPrompt, appendSystemPrompt: $appendSystemPrompt, allowedTools: $allowedTools, disallowedTools: $disallowedTools, displayText: $displayText)';
}


}

/// @nodoc
abstract mixin class _$MessageMetaCopyWith<$Res> implements $MessageMetaCopyWith<$Res> {
  factory _$MessageMetaCopyWith(_MessageMeta value, $Res Function(_MessageMeta) _then) = __$MessageMetaCopyWithImpl;
@override @useResult
$Res call({
 String? sentFrom, String? permissionMode, String? model, String? fallbackModel, String? customSystemPrompt, String? appendSystemPrompt,@JsonKey(fromJson: _stringListOrNull) List<String>? allowedTools,@JsonKey(fromJson: _stringListOrNull) List<String>? disallowedTools, String? displayText
});




}
/// @nodoc
class __$MessageMetaCopyWithImpl<$Res>
    implements _$MessageMetaCopyWith<$Res> {
  __$MessageMetaCopyWithImpl(this._self, this._then);

  final _MessageMeta _self;
  final $Res Function(_MessageMeta) _then;

/// Create a copy of MessageMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sentFrom = freezed,Object? permissionMode = freezed,Object? model = freezed,Object? fallbackModel = freezed,Object? customSystemPrompt = freezed,Object? appendSystemPrompt = freezed,Object? allowedTools = freezed,Object? disallowedTools = freezed,Object? displayText = freezed,}) {
  return _then(_MessageMeta(
sentFrom: freezed == sentFrom ? _self.sentFrom : sentFrom // ignore: cast_nullable_to_non_nullable
as String?,permissionMode: freezed == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,fallbackModel: freezed == fallbackModel ? _self.fallbackModel : fallbackModel // ignore: cast_nullable_to_non_nullable
as String?,customSystemPrompt: freezed == customSystemPrompt ? _self.customSystemPrompt : customSystemPrompt // ignore: cast_nullable_to_non_nullable
as String?,appendSystemPrompt: freezed == appendSystemPrompt ? _self.appendSystemPrompt : appendSystemPrompt // ignore: cast_nullable_to_non_nullable
as String?,allowedTools: freezed == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>?,disallowedTools: freezed == disallowedTools ? _self._disallowedTools : disallowedTools // ignore: cast_nullable_to_non_nullable
as List<String>?,displayText: freezed == displayText ? _self.displayText : displayText // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
