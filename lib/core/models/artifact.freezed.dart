// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'artifact.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Artifact {

@JsonKey(fromJson: _asRequiredString) String get id;// Base64 encoded encrypted JSON
@JsonKey(fromJson: _asRequiredString) String get header;@JsonKey(fromJson: _asApiInt) int get headerVersion;// Base64 encoded encryption key
@JsonKey(fromJson: _asRequiredString) String get dataEncryptionKey;@JsonKey(fromJson: _asApiInt) int get seq;@JsonKey(fromJson: _asApiInt) int get createdAt;@JsonKey(fromJson: _asApiInt) int get updatedAt; String? get body;// Base64 encoded encrypted JSON
@JsonKey(fromJson: _asApiIntNullable) int? get bodyVersion;
/// Create a copy of Artifact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtifactCopyWith<Artifact> get copyWith => _$ArtifactCopyWithImpl<Artifact>(this as Artifact, _$identity);

  /// Serializes this Artifact to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Artifact&&(identical(other.id, id) || other.id == id)&&(identical(other.header, header) || other.header == header)&&(identical(other.headerVersion, headerVersion) || other.headerVersion == headerVersion)&&(identical(other.dataEncryptionKey, dataEncryptionKey) || other.dataEncryptionKey == dataEncryptionKey)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.body, body) || other.body == body)&&(identical(other.bodyVersion, bodyVersion) || other.bodyVersion == bodyVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,header,headerVersion,dataEncryptionKey,seq,createdAt,updatedAt,body,bodyVersion);

@override
String toString() {
  return 'Artifact(id: $id, header: $header, headerVersion: $headerVersion, dataEncryptionKey: $dataEncryptionKey, seq: $seq, createdAt: $createdAt, updatedAt: $updatedAt, body: $body, bodyVersion: $bodyVersion)';
}


}

/// @nodoc
abstract mixin class $ArtifactCopyWith<$Res>  {
  factory $ArtifactCopyWith(Artifact value, $Res Function(Artifact) _then) = _$ArtifactCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _asRequiredString) String id,@JsonKey(fromJson: _asRequiredString) String header,@JsonKey(fromJson: _asApiInt) int headerVersion,@JsonKey(fromJson: _asRequiredString) String dataEncryptionKey,@JsonKey(fromJson: _asApiInt) int seq,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiInt) int updatedAt, String? body,@JsonKey(fromJson: _asApiIntNullable) int? bodyVersion
});




}
/// @nodoc
class _$ArtifactCopyWithImpl<$Res>
    implements $ArtifactCopyWith<$Res> {
  _$ArtifactCopyWithImpl(this._self, this._then);

  final Artifact _self;
  final $Res Function(Artifact) _then;

/// Create a copy of Artifact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? header = null,Object? headerVersion = null,Object? dataEncryptionKey = null,Object? seq = null,Object? createdAt = null,Object? updatedAt = null,Object? body = freezed,Object? bodyVersion = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,headerVersion: null == headerVersion ? _self.headerVersion : headerVersion // ignore: cast_nullable_to_non_nullable
as int,dataEncryptionKey: null == dataEncryptionKey ? _self.dataEncryptionKey : dataEncryptionKey // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,bodyVersion: freezed == bodyVersion ? _self.bodyVersion : bodyVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Artifact].
extension ArtifactPatterns on Artifact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Artifact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Artifact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Artifact value)  $default,){
final _that = this;
switch (_that) {
case _Artifact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Artifact value)?  $default,){
final _that = this;
switch (_that) {
case _Artifact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asRequiredString)  String id, @JsonKey(fromJson: _asRequiredString)  String header, @JsonKey(fromJson: _asApiInt)  int headerVersion, @JsonKey(fromJson: _asRequiredString)  String dataEncryptionKey, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  String? body, @JsonKey(fromJson: _asApiIntNullable)  int? bodyVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Artifact() when $default != null:
return $default(_that.id,_that.header,_that.headerVersion,_that.dataEncryptionKey,_that.seq,_that.createdAt,_that.updatedAt,_that.body,_that.bodyVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asRequiredString)  String id, @JsonKey(fromJson: _asRequiredString)  String header, @JsonKey(fromJson: _asApiInt)  int headerVersion, @JsonKey(fromJson: _asRequiredString)  String dataEncryptionKey, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  String? body, @JsonKey(fromJson: _asApiIntNullable)  int? bodyVersion)  $default,) {final _that = this;
switch (_that) {
case _Artifact():
return $default(_that.id,_that.header,_that.headerVersion,_that.dataEncryptionKey,_that.seq,_that.createdAt,_that.updatedAt,_that.body,_that.bodyVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _asRequiredString)  String id, @JsonKey(fromJson: _asRequiredString)  String header, @JsonKey(fromJson: _asApiInt)  int headerVersion, @JsonKey(fromJson: _asRequiredString)  String dataEncryptionKey, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  String? body, @JsonKey(fromJson: _asApiIntNullable)  int? bodyVersion)?  $default,) {final _that = this;
switch (_that) {
case _Artifact() when $default != null:
return $default(_that.id,_that.header,_that.headerVersion,_that.dataEncryptionKey,_that.seq,_that.createdAt,_that.updatedAt,_that.body,_that.bodyVersion);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Artifact implements Artifact {
  const _Artifact({@JsonKey(fromJson: _asRequiredString) required this.id, @JsonKey(fromJson: _asRequiredString) required this.header, @JsonKey(fromJson: _asApiInt) required this.headerVersion, @JsonKey(fromJson: _asRequiredString) required this.dataEncryptionKey, @JsonKey(fromJson: _asApiInt) required this.seq, @JsonKey(fromJson: _asApiInt) required this.createdAt, @JsonKey(fromJson: _asApiInt) required this.updatedAt, this.body, @JsonKey(fromJson: _asApiIntNullable) this.bodyVersion});
  factory _Artifact.fromJson(Map<String, dynamic> json) => _$ArtifactFromJson(json);

@override@JsonKey(fromJson: _asRequiredString) final  String id;
// Base64 encoded encrypted JSON
@override@JsonKey(fromJson: _asRequiredString) final  String header;
@override@JsonKey(fromJson: _asApiInt) final  int headerVersion;
// Base64 encoded encryption key
@override@JsonKey(fromJson: _asRequiredString) final  String dataEncryptionKey;
@override@JsonKey(fromJson: _asApiInt) final  int seq;
@override@JsonKey(fromJson: _asApiInt) final  int createdAt;
@override@JsonKey(fromJson: _asApiInt) final  int updatedAt;
@override final  String? body;
// Base64 encoded encrypted JSON
@override@JsonKey(fromJson: _asApiIntNullable) final  int? bodyVersion;

/// Create a copy of Artifact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtifactCopyWith<_Artifact> get copyWith => __$ArtifactCopyWithImpl<_Artifact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtifactToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Artifact&&(identical(other.id, id) || other.id == id)&&(identical(other.header, header) || other.header == header)&&(identical(other.headerVersion, headerVersion) || other.headerVersion == headerVersion)&&(identical(other.dataEncryptionKey, dataEncryptionKey) || other.dataEncryptionKey == dataEncryptionKey)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.body, body) || other.body == body)&&(identical(other.bodyVersion, bodyVersion) || other.bodyVersion == bodyVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,header,headerVersion,dataEncryptionKey,seq,createdAt,updatedAt,body,bodyVersion);

@override
String toString() {
  return 'Artifact(id: $id, header: $header, headerVersion: $headerVersion, dataEncryptionKey: $dataEncryptionKey, seq: $seq, createdAt: $createdAt, updatedAt: $updatedAt, body: $body, bodyVersion: $bodyVersion)';
}


}

/// @nodoc
abstract mixin class _$ArtifactCopyWith<$Res> implements $ArtifactCopyWith<$Res> {
  factory _$ArtifactCopyWith(_Artifact value, $Res Function(_Artifact) _then) = __$ArtifactCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _asRequiredString) String id,@JsonKey(fromJson: _asRequiredString) String header,@JsonKey(fromJson: _asApiInt) int headerVersion,@JsonKey(fromJson: _asRequiredString) String dataEncryptionKey,@JsonKey(fromJson: _asApiInt) int seq,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiInt) int updatedAt, String? body,@JsonKey(fromJson: _asApiIntNullable) int? bodyVersion
});




}
/// @nodoc
class __$ArtifactCopyWithImpl<$Res>
    implements _$ArtifactCopyWith<$Res> {
  __$ArtifactCopyWithImpl(this._self, this._then);

  final _Artifact _self;
  final $Res Function(_Artifact) _then;

/// Create a copy of Artifact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? header = null,Object? headerVersion = null,Object? dataEncryptionKey = null,Object? seq = null,Object? createdAt = null,Object? updatedAt = null,Object? body = freezed,Object? bodyVersion = freezed,}) {
  return _then(_Artifact(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,headerVersion: null == headerVersion ? _self.headerVersion : headerVersion // ignore: cast_nullable_to_non_nullable
as int,dataEncryptionKey: null == dataEncryptionKey ? _self.dataEncryptionKey : dataEncryptionKey // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,bodyVersion: freezed == bodyVersion ? _self.bodyVersion : bodyVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$ArtifactHeader {

 String? get title;@JsonKey(fromJson: _stringListOrNull) List<String>? get sessions; bool? get draft;
/// Create a copy of ArtifactHeader
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtifactHeaderCopyWith<ArtifactHeader> get copyWith => _$ArtifactHeaderCopyWithImpl<ArtifactHeader>(this as ArtifactHeader, _$identity);

  /// Serializes this ArtifactHeader to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArtifactHeader&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.draft, draft) || other.draft == draft));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,const DeepCollectionEquality().hash(sessions),draft);

@override
String toString() {
  return 'ArtifactHeader(title: $title, sessions: $sessions, draft: $draft)';
}


}

/// @nodoc
abstract mixin class $ArtifactHeaderCopyWith<$Res>  {
  factory $ArtifactHeaderCopyWith(ArtifactHeader value, $Res Function(ArtifactHeader) _then) = _$ArtifactHeaderCopyWithImpl;
@useResult
$Res call({
 String? title,@JsonKey(fromJson: _stringListOrNull) List<String>? sessions, bool? draft
});




}
/// @nodoc
class _$ArtifactHeaderCopyWithImpl<$Res>
    implements $ArtifactHeaderCopyWith<$Res> {
  _$ArtifactHeaderCopyWithImpl(this._self, this._then);

  final ArtifactHeader _self;
  final $Res Function(ArtifactHeader) _then;

/// Create a copy of ArtifactHeader
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = freezed,Object? sessions = freezed,Object? draft = freezed,}) {
  return _then(_self.copyWith(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,sessions: freezed == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<String>?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [ArtifactHeader].
extension ArtifactHeaderPatterns on ArtifactHeader {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ArtifactHeader value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ArtifactHeader() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ArtifactHeader value)  $default,){
final _that = this;
switch (_that) {
case _ArtifactHeader():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ArtifactHeader value)?  $default,){
final _that = this;
switch (_that) {
case _ArtifactHeader() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? title, @JsonKey(fromJson: _stringListOrNull)  List<String>? sessions,  bool? draft)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ArtifactHeader() when $default != null:
return $default(_that.title,_that.sessions,_that.draft);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? title, @JsonKey(fromJson: _stringListOrNull)  List<String>? sessions,  bool? draft)  $default,) {final _that = this;
switch (_that) {
case _ArtifactHeader():
return $default(_that.title,_that.sessions,_that.draft);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? title, @JsonKey(fromJson: _stringListOrNull)  List<String>? sessions,  bool? draft)?  $default,) {final _that = this;
switch (_that) {
case _ArtifactHeader() when $default != null:
return $default(_that.title,_that.sessions,_that.draft);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ArtifactHeader implements ArtifactHeader {
  const _ArtifactHeader({this.title, @JsonKey(fromJson: _stringListOrNull) final  List<String>? sessions, this.draft}): _sessions = sessions;
  factory _ArtifactHeader.fromJson(Map<String, dynamic> json) => _$ArtifactHeaderFromJson(json);

@override final  String? title;
 final  List<String>? _sessions;
@override@JsonKey(fromJson: _stringListOrNull) List<String>? get sessions {
  final value = _sessions;
  if (value == null) return null;
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  bool? draft;

/// Create a copy of ArtifactHeader
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtifactHeaderCopyWith<_ArtifactHeader> get copyWith => __$ArtifactHeaderCopyWithImpl<_ArtifactHeader>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtifactHeaderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArtifactHeader&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.draft, draft) || other.draft == draft));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,const DeepCollectionEquality().hash(_sessions),draft);

@override
String toString() {
  return 'ArtifactHeader(title: $title, sessions: $sessions, draft: $draft)';
}


}

/// @nodoc
abstract mixin class _$ArtifactHeaderCopyWith<$Res> implements $ArtifactHeaderCopyWith<$Res> {
  factory _$ArtifactHeaderCopyWith(_ArtifactHeader value, $Res Function(_ArtifactHeader) _then) = __$ArtifactHeaderCopyWithImpl;
@override @useResult
$Res call({
 String? title,@JsonKey(fromJson: _stringListOrNull) List<String>? sessions, bool? draft
});




}
/// @nodoc
class __$ArtifactHeaderCopyWithImpl<$Res>
    implements _$ArtifactHeaderCopyWith<$Res> {
  __$ArtifactHeaderCopyWithImpl(this._self, this._then);

  final _ArtifactHeader _self;
  final $Res Function(_ArtifactHeader) _then;

/// Create a copy of ArtifactHeader
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = freezed,Object? sessions = freezed,Object? draft = freezed,}) {
  return _then(_ArtifactHeader(
title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,sessions: freezed == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<String>?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$ArtifactBody {

 String? get body;
/// Create a copy of ArtifactBody
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtifactBodyCopyWith<ArtifactBody> get copyWith => _$ArtifactBodyCopyWithImpl<ArtifactBody>(this as ArtifactBody, _$identity);

  /// Serializes this ArtifactBody to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArtifactBody&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,body);

@override
String toString() {
  return 'ArtifactBody(body: $body)';
}


}

/// @nodoc
abstract mixin class $ArtifactBodyCopyWith<$Res>  {
  factory $ArtifactBodyCopyWith(ArtifactBody value, $Res Function(ArtifactBody) _then) = _$ArtifactBodyCopyWithImpl;
@useResult
$Res call({
 String? body
});




}
/// @nodoc
class _$ArtifactBodyCopyWithImpl<$Res>
    implements $ArtifactBodyCopyWith<$Res> {
  _$ArtifactBodyCopyWithImpl(this._self, this._then);

  final ArtifactBody _self;
  final $Res Function(ArtifactBody) _then;

/// Create a copy of ArtifactBody
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? body = freezed,}) {
  return _then(_self.copyWith(
body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ArtifactBody].
extension ArtifactBodyPatterns on ArtifactBody {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ArtifactBody value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ArtifactBody() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ArtifactBody value)  $default,){
final _that = this;
switch (_that) {
case _ArtifactBody():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ArtifactBody value)?  $default,){
final _that = this;
switch (_that) {
case _ArtifactBody() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ArtifactBody() when $default != null:
return $default(_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? body)  $default,) {final _that = this;
switch (_that) {
case _ArtifactBody():
return $default(_that.body);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? body)?  $default,) {final _that = this;
switch (_that) {
case _ArtifactBody() when $default != null:
return $default(_that.body);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ArtifactBody implements ArtifactBody {
  const _ArtifactBody({this.body});
  factory _ArtifactBody.fromJson(Map<String, dynamic> json) => _$ArtifactBodyFromJson(json);

@override final  String? body;

/// Create a copy of ArtifactBody
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtifactBodyCopyWith<_ArtifactBody> get copyWith => __$ArtifactBodyCopyWithImpl<_ArtifactBody>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtifactBodyToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArtifactBody&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,body);

@override
String toString() {
  return 'ArtifactBody(body: $body)';
}


}

/// @nodoc
abstract mixin class _$ArtifactBodyCopyWith<$Res> implements $ArtifactBodyCopyWith<$Res> {
  factory _$ArtifactBodyCopyWith(_ArtifactBody value, $Res Function(_ArtifactBody) _then) = __$ArtifactBodyCopyWithImpl;
@override @useResult
$Res call({
 String? body
});




}
/// @nodoc
class __$ArtifactBodyCopyWithImpl<$Res>
    implements _$ArtifactBodyCopyWith<$Res> {
  __$ArtifactBodyCopyWithImpl(this._self, this._then);

  final _ArtifactBody _self;
  final $Res Function(_ArtifactBody) _then;

/// Create a copy of ArtifactBody
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? body = freezed,}) {
  return _then(_ArtifactBody(
body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DecryptedArtifact {

 String get id;@JsonKey(fromJson: _asApiInt) int get headerVersion;@JsonKey(fromJson: _asApiInt) int get seq;@JsonKey(fromJson: _asApiInt) int get createdAt;@JsonKey(fromJson: _asApiInt) int get updatedAt; String? get title;@JsonKey(fromJson: _stringListOrNull) List<String>? get sessions;// Optional array of session IDs
 bool? get draft;// Optional draft flag - hides artifact from list
 String? get body;// Only loaded when viewing full artifact
@JsonKey(fromJson: _asApiIntNullable) int? get bodyVersion; bool get isDecrypted;
/// Create a copy of DecryptedArtifact
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DecryptedArtifactCopyWith<DecryptedArtifact> get copyWith => _$DecryptedArtifactCopyWithImpl<DecryptedArtifact>(this as DecryptedArtifact, _$identity);

  /// Serializes this DecryptedArtifact to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DecryptedArtifact&&(identical(other.id, id) || other.id == id)&&(identical(other.headerVersion, headerVersion) || other.headerVersion == headerVersion)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.sessions, sessions)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.body, body) || other.body == body)&&(identical(other.bodyVersion, bodyVersion) || other.bodyVersion == bodyVersion)&&(identical(other.isDecrypted, isDecrypted) || other.isDecrypted == isDecrypted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,headerVersion,seq,createdAt,updatedAt,title,const DeepCollectionEquality().hash(sessions),draft,body,bodyVersion,isDecrypted);

@override
String toString() {
  return 'DecryptedArtifact(id: $id, headerVersion: $headerVersion, seq: $seq, createdAt: $createdAt, updatedAt: $updatedAt, title: $title, sessions: $sessions, draft: $draft, body: $body, bodyVersion: $bodyVersion, isDecrypted: $isDecrypted)';
}


}

/// @nodoc
abstract mixin class $DecryptedArtifactCopyWith<$Res>  {
  factory $DecryptedArtifactCopyWith(DecryptedArtifact value, $Res Function(DecryptedArtifact) _then) = _$DecryptedArtifactCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(fromJson: _asApiInt) int headerVersion,@JsonKey(fromJson: _asApiInt) int seq,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiInt) int updatedAt, String? title,@JsonKey(fromJson: _stringListOrNull) List<String>? sessions, bool? draft, String? body,@JsonKey(fromJson: _asApiIntNullable) int? bodyVersion, bool isDecrypted
});




}
/// @nodoc
class _$DecryptedArtifactCopyWithImpl<$Res>
    implements $DecryptedArtifactCopyWith<$Res> {
  _$DecryptedArtifactCopyWithImpl(this._self, this._then);

  final DecryptedArtifact _self;
  final $Res Function(DecryptedArtifact) _then;

/// Create a copy of DecryptedArtifact
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? headerVersion = null,Object? seq = null,Object? createdAt = null,Object? updatedAt = null,Object? title = freezed,Object? sessions = freezed,Object? draft = freezed,Object? body = freezed,Object? bodyVersion = freezed,Object? isDecrypted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,headerVersion: null == headerVersion ? _self.headerVersion : headerVersion // ignore: cast_nullable_to_non_nullable
as int,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,sessions: freezed == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<String>?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as bool?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,bodyVersion: freezed == bodyVersion ? _self.bodyVersion : bodyVersion // ignore: cast_nullable_to_non_nullable
as int?,isDecrypted: null == isDecrypted ? _self.isDecrypted : isDecrypted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DecryptedArtifact].
extension DecryptedArtifactPatterns on DecryptedArtifact {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DecryptedArtifact value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DecryptedArtifact() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DecryptedArtifact value)  $default,){
final _that = this;
switch (_that) {
case _DecryptedArtifact():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DecryptedArtifact value)?  $default,){
final _that = this;
switch (_that) {
case _DecryptedArtifact() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _asApiInt)  int headerVersion, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  String? title, @JsonKey(fromJson: _stringListOrNull)  List<String>? sessions,  bool? draft,  String? body, @JsonKey(fromJson: _asApiIntNullable)  int? bodyVersion,  bool isDecrypted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DecryptedArtifact() when $default != null:
return $default(_that.id,_that.headerVersion,_that.seq,_that.createdAt,_that.updatedAt,_that.title,_that.sessions,_that.draft,_that.body,_that.bodyVersion,_that.isDecrypted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(fromJson: _asApiInt)  int headerVersion, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  String? title, @JsonKey(fromJson: _stringListOrNull)  List<String>? sessions,  bool? draft,  String? body, @JsonKey(fromJson: _asApiIntNullable)  int? bodyVersion,  bool isDecrypted)  $default,) {final _that = this;
switch (_that) {
case _DecryptedArtifact():
return $default(_that.id,_that.headerVersion,_that.seq,_that.createdAt,_that.updatedAt,_that.title,_that.sessions,_that.draft,_that.body,_that.bodyVersion,_that.isDecrypted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(fromJson: _asApiInt)  int headerVersion, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  String? title, @JsonKey(fromJson: _stringListOrNull)  List<String>? sessions,  bool? draft,  String? body, @JsonKey(fromJson: _asApiIntNullable)  int? bodyVersion,  bool isDecrypted)?  $default,) {final _that = this;
switch (_that) {
case _DecryptedArtifact() when $default != null:
return $default(_that.id,_that.headerVersion,_that.seq,_that.createdAt,_that.updatedAt,_that.title,_that.sessions,_that.draft,_that.body,_that.bodyVersion,_that.isDecrypted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DecryptedArtifact implements DecryptedArtifact {
  const _DecryptedArtifact({required this.id, @JsonKey(fromJson: _asApiInt) required this.headerVersion, @JsonKey(fromJson: _asApiInt) required this.seq, @JsonKey(fromJson: _asApiInt) required this.createdAt, @JsonKey(fromJson: _asApiInt) required this.updatedAt, this.title, @JsonKey(fromJson: _stringListOrNull) final  List<String>? sessions, this.draft, this.body, @JsonKey(fromJson: _asApiIntNullable) this.bodyVersion, this.isDecrypted = true}): _sessions = sessions;
  factory _DecryptedArtifact.fromJson(Map<String, dynamic> json) => _$DecryptedArtifactFromJson(json);

@override final  String id;
@override@JsonKey(fromJson: _asApiInt) final  int headerVersion;
@override@JsonKey(fromJson: _asApiInt) final  int seq;
@override@JsonKey(fromJson: _asApiInt) final  int createdAt;
@override@JsonKey(fromJson: _asApiInt) final  int updatedAt;
@override final  String? title;
 final  List<String>? _sessions;
@override@JsonKey(fromJson: _stringListOrNull) List<String>? get sessions {
  final value = _sessions;
  if (value == null) return null;
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

// Optional array of session IDs
@override final  bool? draft;
// Optional draft flag - hides artifact from list
@override final  String? body;
// Only loaded when viewing full artifact
@override@JsonKey(fromJson: _asApiIntNullable) final  int? bodyVersion;
@override@JsonKey() final  bool isDecrypted;

/// Create a copy of DecryptedArtifact
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DecryptedArtifactCopyWith<_DecryptedArtifact> get copyWith => __$DecryptedArtifactCopyWithImpl<_DecryptedArtifact>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DecryptedArtifactToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DecryptedArtifact&&(identical(other.id, id) || other.id == id)&&(identical(other.headerVersion, headerVersion) || other.headerVersion == headerVersion)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.body, body) || other.body == body)&&(identical(other.bodyVersion, bodyVersion) || other.bodyVersion == bodyVersion)&&(identical(other.isDecrypted, isDecrypted) || other.isDecrypted == isDecrypted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,headerVersion,seq,createdAt,updatedAt,title,const DeepCollectionEquality().hash(_sessions),draft,body,bodyVersion,isDecrypted);

@override
String toString() {
  return 'DecryptedArtifact(id: $id, headerVersion: $headerVersion, seq: $seq, createdAt: $createdAt, updatedAt: $updatedAt, title: $title, sessions: $sessions, draft: $draft, body: $body, bodyVersion: $bodyVersion, isDecrypted: $isDecrypted)';
}


}

/// @nodoc
abstract mixin class _$DecryptedArtifactCopyWith<$Res> implements $DecryptedArtifactCopyWith<$Res> {
  factory _$DecryptedArtifactCopyWith(_DecryptedArtifact value, $Res Function(_DecryptedArtifact) _then) = __$DecryptedArtifactCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(fromJson: _asApiInt) int headerVersion,@JsonKey(fromJson: _asApiInt) int seq,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiInt) int updatedAt, String? title,@JsonKey(fromJson: _stringListOrNull) List<String>? sessions, bool? draft, String? body,@JsonKey(fromJson: _asApiIntNullable) int? bodyVersion, bool isDecrypted
});




}
/// @nodoc
class __$DecryptedArtifactCopyWithImpl<$Res>
    implements _$DecryptedArtifactCopyWith<$Res> {
  __$DecryptedArtifactCopyWithImpl(this._self, this._then);

  final _DecryptedArtifact _self;
  final $Res Function(_DecryptedArtifact) _then;

/// Create a copy of DecryptedArtifact
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? headerVersion = null,Object? seq = null,Object? createdAt = null,Object? updatedAt = null,Object? title = freezed,Object? sessions = freezed,Object? draft = freezed,Object? body = freezed,Object? bodyVersion = freezed,Object? isDecrypted = null,}) {
  return _then(_DecryptedArtifact(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,headerVersion: null == headerVersion ? _self.headerVersion : headerVersion // ignore: cast_nullable_to_non_nullable
as int,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,sessions: freezed == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<String>?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as bool?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,bodyVersion: freezed == bodyVersion ? _self.bodyVersion : bodyVersion // ignore: cast_nullable_to_non_nullable
as int?,isDecrypted: null == isDecrypted ? _self.isDecrypted : isDecrypted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ArtifactCreateRequest {

 String get id;// UUID generated client-side
 String get header;// Base64 encoded encrypted header
 String get body;// Base64 encoded encrypted body
 String get dataEncryptionKey;
/// Create a copy of ArtifactCreateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtifactCreateRequestCopyWith<ArtifactCreateRequest> get copyWith => _$ArtifactCreateRequestCopyWithImpl<ArtifactCreateRequest>(this as ArtifactCreateRequest, _$identity);

  /// Serializes this ArtifactCreateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArtifactCreateRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.header, header) || other.header == header)&&(identical(other.body, body) || other.body == body)&&(identical(other.dataEncryptionKey, dataEncryptionKey) || other.dataEncryptionKey == dataEncryptionKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,header,body,dataEncryptionKey);

@override
String toString() {
  return 'ArtifactCreateRequest(id: $id, header: $header, body: $body, dataEncryptionKey: $dataEncryptionKey)';
}


}

/// @nodoc
abstract mixin class $ArtifactCreateRequestCopyWith<$Res>  {
  factory $ArtifactCreateRequestCopyWith(ArtifactCreateRequest value, $Res Function(ArtifactCreateRequest) _then) = _$ArtifactCreateRequestCopyWithImpl;
@useResult
$Res call({
 String id, String header, String body, String dataEncryptionKey
});




}
/// @nodoc
class _$ArtifactCreateRequestCopyWithImpl<$Res>
    implements $ArtifactCreateRequestCopyWith<$Res> {
  _$ArtifactCreateRequestCopyWithImpl(this._self, this._then);

  final ArtifactCreateRequest _self;
  final $Res Function(ArtifactCreateRequest) _then;

/// Create a copy of ArtifactCreateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? header = null,Object? body = null,Object? dataEncryptionKey = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,dataEncryptionKey: null == dataEncryptionKey ? _self.dataEncryptionKey : dataEncryptionKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ArtifactCreateRequest].
extension ArtifactCreateRequestPatterns on ArtifactCreateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ArtifactCreateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ArtifactCreateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ArtifactCreateRequest value)  $default,){
final _that = this;
switch (_that) {
case _ArtifactCreateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ArtifactCreateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ArtifactCreateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String header,  String body,  String dataEncryptionKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ArtifactCreateRequest() when $default != null:
return $default(_that.id,_that.header,_that.body,_that.dataEncryptionKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String header,  String body,  String dataEncryptionKey)  $default,) {final _that = this;
switch (_that) {
case _ArtifactCreateRequest():
return $default(_that.id,_that.header,_that.body,_that.dataEncryptionKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String header,  String body,  String dataEncryptionKey)?  $default,) {final _that = this;
switch (_that) {
case _ArtifactCreateRequest() when $default != null:
return $default(_that.id,_that.header,_that.body,_that.dataEncryptionKey);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ArtifactCreateRequest implements ArtifactCreateRequest {
  const _ArtifactCreateRequest({required this.id, required this.header, required this.body, required this.dataEncryptionKey});
  factory _ArtifactCreateRequest.fromJson(Map<String, dynamic> json) => _$ArtifactCreateRequestFromJson(json);

@override final  String id;
// UUID generated client-side
@override final  String header;
// Base64 encoded encrypted header
@override final  String body;
// Base64 encoded encrypted body
@override final  String dataEncryptionKey;

/// Create a copy of ArtifactCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtifactCreateRequestCopyWith<_ArtifactCreateRequest> get copyWith => __$ArtifactCreateRequestCopyWithImpl<_ArtifactCreateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtifactCreateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArtifactCreateRequest&&(identical(other.id, id) || other.id == id)&&(identical(other.header, header) || other.header == header)&&(identical(other.body, body) || other.body == body)&&(identical(other.dataEncryptionKey, dataEncryptionKey) || other.dataEncryptionKey == dataEncryptionKey));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,header,body,dataEncryptionKey);

@override
String toString() {
  return 'ArtifactCreateRequest(id: $id, header: $header, body: $body, dataEncryptionKey: $dataEncryptionKey)';
}


}

/// @nodoc
abstract mixin class _$ArtifactCreateRequestCopyWith<$Res> implements $ArtifactCreateRequestCopyWith<$Res> {
  factory _$ArtifactCreateRequestCopyWith(_ArtifactCreateRequest value, $Res Function(_ArtifactCreateRequest) _then) = __$ArtifactCreateRequestCopyWithImpl;
@override @useResult
$Res call({
 String id, String header, String body, String dataEncryptionKey
});




}
/// @nodoc
class __$ArtifactCreateRequestCopyWithImpl<$Res>
    implements _$ArtifactCreateRequestCopyWith<$Res> {
  __$ArtifactCreateRequestCopyWithImpl(this._self, this._then);

  final _ArtifactCreateRequest _self;
  final $Res Function(_ArtifactCreateRequest) _then;

/// Create a copy of ArtifactCreateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? header = null,Object? body = null,Object? dataEncryptionKey = null,}) {
  return _then(_ArtifactCreateRequest(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,header: null == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,dataEncryptionKey: null == dataEncryptionKey ? _self.dataEncryptionKey : dataEncryptionKey // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ArtifactUpdateRequest {

 String? get header;// Base64 encoded encrypted header
 int? get expectedHeaderVersion; String? get body;// Base64 encoded encrypted body
 int? get expectedBodyVersion;
/// Create a copy of ArtifactUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtifactUpdateRequestCopyWith<ArtifactUpdateRequest> get copyWith => _$ArtifactUpdateRequestCopyWithImpl<ArtifactUpdateRequest>(this as ArtifactUpdateRequest, _$identity);

  /// Serializes this ArtifactUpdateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArtifactUpdateRequest&&(identical(other.header, header) || other.header == header)&&(identical(other.expectedHeaderVersion, expectedHeaderVersion) || other.expectedHeaderVersion == expectedHeaderVersion)&&(identical(other.body, body) || other.body == body)&&(identical(other.expectedBodyVersion, expectedBodyVersion) || other.expectedBodyVersion == expectedBodyVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,header,expectedHeaderVersion,body,expectedBodyVersion);

@override
String toString() {
  return 'ArtifactUpdateRequest(header: $header, expectedHeaderVersion: $expectedHeaderVersion, body: $body, expectedBodyVersion: $expectedBodyVersion)';
}


}

/// @nodoc
abstract mixin class $ArtifactUpdateRequestCopyWith<$Res>  {
  factory $ArtifactUpdateRequestCopyWith(ArtifactUpdateRequest value, $Res Function(ArtifactUpdateRequest) _then) = _$ArtifactUpdateRequestCopyWithImpl;
@useResult
$Res call({
 String? header, int? expectedHeaderVersion, String? body, int? expectedBodyVersion
});




}
/// @nodoc
class _$ArtifactUpdateRequestCopyWithImpl<$Res>
    implements $ArtifactUpdateRequestCopyWith<$Res> {
  _$ArtifactUpdateRequestCopyWithImpl(this._self, this._then);

  final ArtifactUpdateRequest _self;
  final $Res Function(ArtifactUpdateRequest) _then;

/// Create a copy of ArtifactUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? header = freezed,Object? expectedHeaderVersion = freezed,Object? body = freezed,Object? expectedBodyVersion = freezed,}) {
  return _then(_self.copyWith(
header: freezed == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String?,expectedHeaderVersion: freezed == expectedHeaderVersion ? _self.expectedHeaderVersion : expectedHeaderVersion // ignore: cast_nullable_to_non_nullable
as int?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,expectedBodyVersion: freezed == expectedBodyVersion ? _self.expectedBodyVersion : expectedBodyVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ArtifactUpdateRequest].
extension ArtifactUpdateRequestPatterns on ArtifactUpdateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ArtifactUpdateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ArtifactUpdateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ArtifactUpdateRequest value)  $default,){
final _that = this;
switch (_that) {
case _ArtifactUpdateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ArtifactUpdateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _ArtifactUpdateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? header,  int? expectedHeaderVersion,  String? body,  int? expectedBodyVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ArtifactUpdateRequest() when $default != null:
return $default(_that.header,_that.expectedHeaderVersion,_that.body,_that.expectedBodyVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? header,  int? expectedHeaderVersion,  String? body,  int? expectedBodyVersion)  $default,) {final _that = this;
switch (_that) {
case _ArtifactUpdateRequest():
return $default(_that.header,_that.expectedHeaderVersion,_that.body,_that.expectedBodyVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? header,  int? expectedHeaderVersion,  String? body,  int? expectedBodyVersion)?  $default,) {final _that = this;
switch (_that) {
case _ArtifactUpdateRequest() when $default != null:
return $default(_that.header,_that.expectedHeaderVersion,_that.body,_that.expectedBodyVersion);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _ArtifactUpdateRequest extends ArtifactUpdateRequest {
  const _ArtifactUpdateRequest({this.header, this.expectedHeaderVersion, this.body, this.expectedBodyVersion}): super._();
  factory _ArtifactUpdateRequest.fromJson(Map<String, dynamic> json) => _$ArtifactUpdateRequestFromJson(json);

@override final  String? header;
// Base64 encoded encrypted header
@override final  int? expectedHeaderVersion;
@override final  String? body;
// Base64 encoded encrypted body
@override final  int? expectedBodyVersion;

/// Create a copy of ArtifactUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtifactUpdateRequestCopyWith<_ArtifactUpdateRequest> get copyWith => __$ArtifactUpdateRequestCopyWithImpl<_ArtifactUpdateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtifactUpdateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArtifactUpdateRequest&&(identical(other.header, header) || other.header == header)&&(identical(other.expectedHeaderVersion, expectedHeaderVersion) || other.expectedHeaderVersion == expectedHeaderVersion)&&(identical(other.body, body) || other.body == body)&&(identical(other.expectedBodyVersion, expectedBodyVersion) || other.expectedBodyVersion == expectedBodyVersion));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,header,expectedHeaderVersion,body,expectedBodyVersion);

@override
String toString() {
  return 'ArtifactUpdateRequest(header: $header, expectedHeaderVersion: $expectedHeaderVersion, body: $body, expectedBodyVersion: $expectedBodyVersion)';
}


}

/// @nodoc
abstract mixin class _$ArtifactUpdateRequestCopyWith<$Res> implements $ArtifactUpdateRequestCopyWith<$Res> {
  factory _$ArtifactUpdateRequestCopyWith(_ArtifactUpdateRequest value, $Res Function(_ArtifactUpdateRequest) _then) = __$ArtifactUpdateRequestCopyWithImpl;
@override @useResult
$Res call({
 String? header, int? expectedHeaderVersion, String? body, int? expectedBodyVersion
});




}
/// @nodoc
class __$ArtifactUpdateRequestCopyWithImpl<$Res>
    implements _$ArtifactUpdateRequestCopyWith<$Res> {
  __$ArtifactUpdateRequestCopyWithImpl(this._self, this._then);

  final _ArtifactUpdateRequest _self;
  final $Res Function(_ArtifactUpdateRequest) _then;

/// Create a copy of ArtifactUpdateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? header = freezed,Object? expectedHeaderVersion = freezed,Object? body = freezed,Object? expectedBodyVersion = freezed,}) {
  return _then(_ArtifactUpdateRequest(
header: freezed == header ? _self.header : header // ignore: cast_nullable_to_non_nullable
as String?,expectedHeaderVersion: freezed == expectedHeaderVersion ? _self.expectedHeaderVersion : expectedHeaderVersion // ignore: cast_nullable_to_non_nullable
as int?,body: freezed == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String?,expectedBodyVersion: freezed == expectedBodyVersion ? _self.expectedBodyVersion : expectedBodyVersion // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$ArtifactUpdateResponse {

 bool get success; int? get headerVersion; int? get bodyVersion; String? get error; int? get currentHeaderVersion; int? get currentBodyVersion; String? get currentHeader; String? get currentBody;
/// Create a copy of ArtifactUpdateResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtifactUpdateResponseCopyWith<ArtifactUpdateResponse> get copyWith => _$ArtifactUpdateResponseCopyWithImpl<ArtifactUpdateResponse>(this as ArtifactUpdateResponse, _$identity);

  /// Serializes this ArtifactUpdateResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArtifactUpdateResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.headerVersion, headerVersion) || other.headerVersion == headerVersion)&&(identical(other.bodyVersion, bodyVersion) || other.bodyVersion == bodyVersion)&&(identical(other.error, error) || other.error == error)&&(identical(other.currentHeaderVersion, currentHeaderVersion) || other.currentHeaderVersion == currentHeaderVersion)&&(identical(other.currentBodyVersion, currentBodyVersion) || other.currentBodyVersion == currentBodyVersion)&&(identical(other.currentHeader, currentHeader) || other.currentHeader == currentHeader)&&(identical(other.currentBody, currentBody) || other.currentBody == currentBody));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,headerVersion,bodyVersion,error,currentHeaderVersion,currentBodyVersion,currentHeader,currentBody);

@override
String toString() {
  return 'ArtifactUpdateResponse(success: $success, headerVersion: $headerVersion, bodyVersion: $bodyVersion, error: $error, currentHeaderVersion: $currentHeaderVersion, currentBodyVersion: $currentBodyVersion, currentHeader: $currentHeader, currentBody: $currentBody)';
}


}

/// @nodoc
abstract mixin class $ArtifactUpdateResponseCopyWith<$Res>  {
  factory $ArtifactUpdateResponseCopyWith(ArtifactUpdateResponse value, $Res Function(ArtifactUpdateResponse) _then) = _$ArtifactUpdateResponseCopyWithImpl;
@useResult
$Res call({
 bool success, int? headerVersion, int? bodyVersion, String? error, int? currentHeaderVersion, int? currentBodyVersion, String? currentHeader, String? currentBody
});




}
/// @nodoc
class _$ArtifactUpdateResponseCopyWithImpl<$Res>
    implements $ArtifactUpdateResponseCopyWith<$Res> {
  _$ArtifactUpdateResponseCopyWithImpl(this._self, this._then);

  final ArtifactUpdateResponse _self;
  final $Res Function(ArtifactUpdateResponse) _then;

/// Create a copy of ArtifactUpdateResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? headerVersion = freezed,Object? bodyVersion = freezed,Object? error = freezed,Object? currentHeaderVersion = freezed,Object? currentBodyVersion = freezed,Object? currentHeader = freezed,Object? currentBody = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,headerVersion: freezed == headerVersion ? _self.headerVersion : headerVersion // ignore: cast_nullable_to_non_nullable
as int?,bodyVersion: freezed == bodyVersion ? _self.bodyVersion : bodyVersion // ignore: cast_nullable_to_non_nullable
as int?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,currentHeaderVersion: freezed == currentHeaderVersion ? _self.currentHeaderVersion : currentHeaderVersion // ignore: cast_nullable_to_non_nullable
as int?,currentBodyVersion: freezed == currentBodyVersion ? _self.currentBodyVersion : currentBodyVersion // ignore: cast_nullable_to_non_nullable
as int?,currentHeader: freezed == currentHeader ? _self.currentHeader : currentHeader // ignore: cast_nullable_to_non_nullable
as String?,currentBody: freezed == currentBody ? _self.currentBody : currentBody // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ArtifactUpdateResponse].
extension ArtifactUpdateResponsePatterns on ArtifactUpdateResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ArtifactUpdateResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ArtifactUpdateResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ArtifactUpdateResponse value)  $default,){
final _that = this;
switch (_that) {
case _ArtifactUpdateResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ArtifactUpdateResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ArtifactUpdateResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  int? headerVersion,  int? bodyVersion,  String? error,  int? currentHeaderVersion,  int? currentBodyVersion,  String? currentHeader,  String? currentBody)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ArtifactUpdateResponse() when $default != null:
return $default(_that.success,_that.headerVersion,_that.bodyVersion,_that.error,_that.currentHeaderVersion,_that.currentBodyVersion,_that.currentHeader,_that.currentBody);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  int? headerVersion,  int? bodyVersion,  String? error,  int? currentHeaderVersion,  int? currentBodyVersion,  String? currentHeader,  String? currentBody)  $default,) {final _that = this;
switch (_that) {
case _ArtifactUpdateResponse():
return $default(_that.success,_that.headerVersion,_that.bodyVersion,_that.error,_that.currentHeaderVersion,_that.currentBodyVersion,_that.currentHeader,_that.currentBody);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  int? headerVersion,  int? bodyVersion,  String? error,  int? currentHeaderVersion,  int? currentBodyVersion,  String? currentHeader,  String? currentBody)?  $default,) {final _that = this;
switch (_that) {
case _ArtifactUpdateResponse() when $default != null:
return $default(_that.success,_that.headerVersion,_that.bodyVersion,_that.error,_that.currentHeaderVersion,_that.currentBodyVersion,_that.currentHeader,_that.currentBody);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ArtifactUpdateResponse implements ArtifactUpdateResponse {
  const _ArtifactUpdateResponse({this.success = false, this.headerVersion, this.bodyVersion, this.error, this.currentHeaderVersion, this.currentBodyVersion, this.currentHeader, this.currentBody});
  factory _ArtifactUpdateResponse.fromJson(Map<String, dynamic> json) => _$ArtifactUpdateResponseFromJson(json);

@override@JsonKey() final  bool success;
@override final  int? headerVersion;
@override final  int? bodyVersion;
@override final  String? error;
@override final  int? currentHeaderVersion;
@override final  int? currentBodyVersion;
@override final  String? currentHeader;
@override final  String? currentBody;

/// Create a copy of ArtifactUpdateResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtifactUpdateResponseCopyWith<_ArtifactUpdateResponse> get copyWith => __$ArtifactUpdateResponseCopyWithImpl<_ArtifactUpdateResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtifactUpdateResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArtifactUpdateResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.headerVersion, headerVersion) || other.headerVersion == headerVersion)&&(identical(other.bodyVersion, bodyVersion) || other.bodyVersion == bodyVersion)&&(identical(other.error, error) || other.error == error)&&(identical(other.currentHeaderVersion, currentHeaderVersion) || other.currentHeaderVersion == currentHeaderVersion)&&(identical(other.currentBodyVersion, currentBodyVersion) || other.currentBodyVersion == currentBodyVersion)&&(identical(other.currentHeader, currentHeader) || other.currentHeader == currentHeader)&&(identical(other.currentBody, currentBody) || other.currentBody == currentBody));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,headerVersion,bodyVersion,error,currentHeaderVersion,currentBodyVersion,currentHeader,currentBody);

@override
String toString() {
  return 'ArtifactUpdateResponse(success: $success, headerVersion: $headerVersion, bodyVersion: $bodyVersion, error: $error, currentHeaderVersion: $currentHeaderVersion, currentBodyVersion: $currentBodyVersion, currentHeader: $currentHeader, currentBody: $currentBody)';
}


}

/// @nodoc
abstract mixin class _$ArtifactUpdateResponseCopyWith<$Res> implements $ArtifactUpdateResponseCopyWith<$Res> {
  factory _$ArtifactUpdateResponseCopyWith(_ArtifactUpdateResponse value, $Res Function(_ArtifactUpdateResponse) _then) = __$ArtifactUpdateResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, int? headerVersion, int? bodyVersion, String? error, int? currentHeaderVersion, int? currentBodyVersion, String? currentHeader, String? currentBody
});




}
/// @nodoc
class __$ArtifactUpdateResponseCopyWithImpl<$Res>
    implements _$ArtifactUpdateResponseCopyWith<$Res> {
  __$ArtifactUpdateResponseCopyWithImpl(this._self, this._then);

  final _ArtifactUpdateResponse _self;
  final $Res Function(_ArtifactUpdateResponse) _then;

/// Create a copy of ArtifactUpdateResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? headerVersion = freezed,Object? bodyVersion = freezed,Object? error = freezed,Object? currentHeaderVersion = freezed,Object? currentBodyVersion = freezed,Object? currentHeader = freezed,Object? currentBody = freezed,}) {
  return _then(_ArtifactUpdateResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,headerVersion: freezed == headerVersion ? _self.headerVersion : headerVersion // ignore: cast_nullable_to_non_nullable
as int?,bodyVersion: freezed == bodyVersion ? _self.bodyVersion : bodyVersion // ignore: cast_nullable_to_non_nullable
as int?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,currentHeaderVersion: freezed == currentHeaderVersion ? _self.currentHeaderVersion : currentHeaderVersion // ignore: cast_nullable_to_non_nullable
as int?,currentBodyVersion: freezed == currentBodyVersion ? _self.currentBodyVersion : currentBodyVersion // ignore: cast_nullable_to_non_nullable
as int?,currentHeader: freezed == currentHeader ? _self.currentHeader : currentHeader // ignore: cast_nullable_to_non_nullable
as String?,currentBody: freezed == currentBody ? _self.currentBody : currentBody // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ArtifactFolder {

@JsonKey(fromJson: _asRequiredString) String get id;@JsonKey(fromJson: _asRequiredString) String get sessionId;@JsonKey(fromJson: _asRequiredString) String get name; int get createdAt; int get updatedAt; String? get parentId;
/// Create a copy of ArtifactFolder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ArtifactFolderCopyWith<ArtifactFolder> get copyWith => _$ArtifactFolderCopyWithImpl<ArtifactFolder>(this as ArtifactFolder, _$identity);

  /// Serializes this ArtifactFolder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ArtifactFolder&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.parentId, parentId) || other.parentId == parentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionId,name,createdAt,updatedAt,parentId);

@override
String toString() {
  return 'ArtifactFolder(id: $id, sessionId: $sessionId, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, parentId: $parentId)';
}


}

/// @nodoc
abstract mixin class $ArtifactFolderCopyWith<$Res>  {
  factory $ArtifactFolderCopyWith(ArtifactFolder value, $Res Function(ArtifactFolder) _then) = _$ArtifactFolderCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _asRequiredString) String id,@JsonKey(fromJson: _asRequiredString) String sessionId,@JsonKey(fromJson: _asRequiredString) String name, int createdAt, int updatedAt, String? parentId
});




}
/// @nodoc
class _$ArtifactFolderCopyWithImpl<$Res>
    implements $ArtifactFolderCopyWith<$Res> {
  _$ArtifactFolderCopyWithImpl(this._self, this._then);

  final ArtifactFolder _self;
  final $Res Function(ArtifactFolder) _then;

/// Create a copy of ArtifactFolder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionId = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? parentId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ArtifactFolder].
extension ArtifactFolderPatterns on ArtifactFolder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ArtifactFolder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ArtifactFolder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ArtifactFolder value)  $default,){
final _that = this;
switch (_that) {
case _ArtifactFolder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ArtifactFolder value)?  $default,){
final _that = this;
switch (_that) {
case _ArtifactFolder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asRequiredString)  String id, @JsonKey(fromJson: _asRequiredString)  String sessionId, @JsonKey(fromJson: _asRequiredString)  String name,  int createdAt,  int updatedAt,  String? parentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ArtifactFolder() when $default != null:
return $default(_that.id,_that.sessionId,_that.name,_that.createdAt,_that.updatedAt,_that.parentId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asRequiredString)  String id, @JsonKey(fromJson: _asRequiredString)  String sessionId, @JsonKey(fromJson: _asRequiredString)  String name,  int createdAt,  int updatedAt,  String? parentId)  $default,) {final _that = this;
switch (_that) {
case _ArtifactFolder():
return $default(_that.id,_that.sessionId,_that.name,_that.createdAt,_that.updatedAt,_that.parentId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _asRequiredString)  String id, @JsonKey(fromJson: _asRequiredString)  String sessionId, @JsonKey(fromJson: _asRequiredString)  String name,  int createdAt,  int updatedAt,  String? parentId)?  $default,) {final _that = this;
switch (_that) {
case _ArtifactFolder() when $default != null:
return $default(_that.id,_that.sessionId,_that.name,_that.createdAt,_that.updatedAt,_that.parentId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ArtifactFolder implements ArtifactFolder {
  const _ArtifactFolder({@JsonKey(fromJson: _asRequiredString) required this.id, @JsonKey(fromJson: _asRequiredString) required this.sessionId, @JsonKey(fromJson: _asRequiredString) required this.name, required this.createdAt, required this.updatedAt, this.parentId});
  factory _ArtifactFolder.fromJson(Map<String, dynamic> json) => _$ArtifactFolderFromJson(json);

@override@JsonKey(fromJson: _asRequiredString) final  String id;
@override@JsonKey(fromJson: _asRequiredString) final  String sessionId;
@override@JsonKey(fromJson: _asRequiredString) final  String name;
@override final  int createdAt;
@override final  int updatedAt;
@override final  String? parentId;

/// Create a copy of ArtifactFolder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ArtifactFolderCopyWith<_ArtifactFolder> get copyWith => __$ArtifactFolderCopyWithImpl<_ArtifactFolder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ArtifactFolderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ArtifactFolder&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.parentId, parentId) || other.parentId == parentId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sessionId,name,createdAt,updatedAt,parentId);

@override
String toString() {
  return 'ArtifactFolder(id: $id, sessionId: $sessionId, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, parentId: $parentId)';
}


}

/// @nodoc
abstract mixin class _$ArtifactFolderCopyWith<$Res> implements $ArtifactFolderCopyWith<$Res> {
  factory _$ArtifactFolderCopyWith(_ArtifactFolder value, $Res Function(_ArtifactFolder) _then) = __$ArtifactFolderCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _asRequiredString) String id,@JsonKey(fromJson: _asRequiredString) String sessionId,@JsonKey(fromJson: _asRequiredString) String name, int createdAt, int updatedAt, String? parentId
});




}
/// @nodoc
class __$ArtifactFolderCopyWithImpl<$Res>
    implements _$ArtifactFolderCopyWith<$Res> {
  __$ArtifactFolderCopyWithImpl(this._self, this._then);

  final _ArtifactFolder _self;
  final $Res Function(_ArtifactFolder) _then;

/// Create a copy of ArtifactFolder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionId = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? parentId = freezed,}) {
  return _then(_ArtifactFolder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
