// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'machine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MachineMetadata {

@JsonKey(fromJson: _asApiStringNullable) String? get host;@JsonKey(fromJson: _asApiStringNullable) String? get platform;@JsonKey(fromJson: _asApiStringNullable) String? get happyCliVersion;@JsonKey(fromJson: _asApiStringNullable) String? get happyHomeDir;@JsonKey(fromJson: _asApiStringNullable) String? get homeDir;@JsonKey(fromJson: _asApiStringNullable) String? get username;@JsonKey(fromJson: _asApiStringNullable) String? get arch;@JsonKey(fromJson: _asApiStringNullable) String? get displayName;@JsonKey(fromJson: _asApiStringNullable) String? get daemonLastKnownStatus;@JsonKey(fromJson: _asApiIntNullable) int? get daemonLastKnownPid;@JsonKey(fromJson: _asApiIntNullable) int? get shutdownRequestedAt;@JsonKey(fromJson: _asApiStringNullable) String? get shutdownSource;
/// Create a copy of MachineMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MachineMetadataCopyWith<MachineMetadata> get copyWith => _$MachineMetadataCopyWithImpl<MachineMetadata>(this as MachineMetadata, _$identity);

  /// Serializes this MachineMetadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MachineMetadata&&(identical(other.host, host) || other.host == host)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.happyCliVersion, happyCliVersion) || other.happyCliVersion == happyCliVersion)&&(identical(other.happyHomeDir, happyHomeDir) || other.happyHomeDir == happyHomeDir)&&(identical(other.homeDir, homeDir) || other.homeDir == homeDir)&&(identical(other.username, username) || other.username == username)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.daemonLastKnownStatus, daemonLastKnownStatus) || other.daemonLastKnownStatus == daemonLastKnownStatus)&&(identical(other.daemonLastKnownPid, daemonLastKnownPid) || other.daemonLastKnownPid == daemonLastKnownPid)&&(identical(other.shutdownRequestedAt, shutdownRequestedAt) || other.shutdownRequestedAt == shutdownRequestedAt)&&(identical(other.shutdownSource, shutdownSource) || other.shutdownSource == shutdownSource));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,host,platform,happyCliVersion,happyHomeDir,homeDir,username,arch,displayName,daemonLastKnownStatus,daemonLastKnownPid,shutdownRequestedAt,shutdownSource);

@override
String toString() {
  return 'MachineMetadata(host: $host, platform: $platform, happyCliVersion: $happyCliVersion, happyHomeDir: $happyHomeDir, homeDir: $homeDir, username: $username, arch: $arch, displayName: $displayName, daemonLastKnownStatus: $daemonLastKnownStatus, daemonLastKnownPid: $daemonLastKnownPid, shutdownRequestedAt: $shutdownRequestedAt, shutdownSource: $shutdownSource)';
}


}

/// @nodoc
abstract mixin class $MachineMetadataCopyWith<$Res>  {
  factory $MachineMetadataCopyWith(MachineMetadata value, $Res Function(MachineMetadata) _then) = _$MachineMetadataCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _asApiStringNullable) String? host,@JsonKey(fromJson: _asApiStringNullable) String? platform,@JsonKey(fromJson: _asApiStringNullable) String? happyCliVersion,@JsonKey(fromJson: _asApiStringNullable) String? happyHomeDir,@JsonKey(fromJson: _asApiStringNullable) String? homeDir,@JsonKey(fromJson: _asApiStringNullable) String? username,@JsonKey(fromJson: _asApiStringNullable) String? arch,@JsonKey(fromJson: _asApiStringNullable) String? displayName,@JsonKey(fromJson: _asApiStringNullable) String? daemonLastKnownStatus,@JsonKey(fromJson: _asApiIntNullable) int? daemonLastKnownPid,@JsonKey(fromJson: _asApiIntNullable) int? shutdownRequestedAt,@JsonKey(fromJson: _asApiStringNullable) String? shutdownSource
});




}
/// @nodoc
class _$MachineMetadataCopyWithImpl<$Res>
    implements $MachineMetadataCopyWith<$Res> {
  _$MachineMetadataCopyWithImpl(this._self, this._then);

  final MachineMetadata _self;
  final $Res Function(MachineMetadata) _then;

/// Create a copy of MachineMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? host = freezed,Object? platform = freezed,Object? happyCliVersion = freezed,Object? happyHomeDir = freezed,Object? homeDir = freezed,Object? username = freezed,Object? arch = freezed,Object? displayName = freezed,Object? daemonLastKnownStatus = freezed,Object? daemonLastKnownPid = freezed,Object? shutdownRequestedAt = freezed,Object? shutdownSource = freezed,}) {
  return _then(_self.copyWith(
host: freezed == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,happyCliVersion: freezed == happyCliVersion ? _self.happyCliVersion : happyCliVersion // ignore: cast_nullable_to_non_nullable
as String?,happyHomeDir: freezed == happyHomeDir ? _self.happyHomeDir : happyHomeDir // ignore: cast_nullable_to_non_nullable
as String?,homeDir: freezed == homeDir ? _self.homeDir : homeDir // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,arch: freezed == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,daemonLastKnownStatus: freezed == daemonLastKnownStatus ? _self.daemonLastKnownStatus : daemonLastKnownStatus // ignore: cast_nullable_to_non_nullable
as String?,daemonLastKnownPid: freezed == daemonLastKnownPid ? _self.daemonLastKnownPid : daemonLastKnownPid // ignore: cast_nullable_to_non_nullable
as int?,shutdownRequestedAt: freezed == shutdownRequestedAt ? _self.shutdownRequestedAt : shutdownRequestedAt // ignore: cast_nullable_to_non_nullable
as int?,shutdownSource: freezed == shutdownSource ? _self.shutdownSource : shutdownSource // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MachineMetadata].
extension MachineMetadataPatterns on MachineMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MachineMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MachineMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MachineMetadata value)  $default,){
final _that = this;
switch (_that) {
case _MachineMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MachineMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _MachineMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asApiStringNullable)  String? host, @JsonKey(fromJson: _asApiStringNullable)  String? platform, @JsonKey(fromJson: _asApiStringNullable)  String? happyCliVersion, @JsonKey(fromJson: _asApiStringNullable)  String? happyHomeDir, @JsonKey(fromJson: _asApiStringNullable)  String? homeDir, @JsonKey(fromJson: _asApiStringNullable)  String? username, @JsonKey(fromJson: _asApiStringNullable)  String? arch, @JsonKey(fromJson: _asApiStringNullable)  String? displayName, @JsonKey(fromJson: _asApiStringNullable)  String? daemonLastKnownStatus, @JsonKey(fromJson: _asApiIntNullable)  int? daemonLastKnownPid, @JsonKey(fromJson: _asApiIntNullable)  int? shutdownRequestedAt, @JsonKey(fromJson: _asApiStringNullable)  String? shutdownSource)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MachineMetadata() when $default != null:
return $default(_that.host,_that.platform,_that.happyCliVersion,_that.happyHomeDir,_that.homeDir,_that.username,_that.arch,_that.displayName,_that.daemonLastKnownStatus,_that.daemonLastKnownPid,_that.shutdownRequestedAt,_that.shutdownSource);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asApiStringNullable)  String? host, @JsonKey(fromJson: _asApiStringNullable)  String? platform, @JsonKey(fromJson: _asApiStringNullable)  String? happyCliVersion, @JsonKey(fromJson: _asApiStringNullable)  String? happyHomeDir, @JsonKey(fromJson: _asApiStringNullable)  String? homeDir, @JsonKey(fromJson: _asApiStringNullable)  String? username, @JsonKey(fromJson: _asApiStringNullable)  String? arch, @JsonKey(fromJson: _asApiStringNullable)  String? displayName, @JsonKey(fromJson: _asApiStringNullable)  String? daemonLastKnownStatus, @JsonKey(fromJson: _asApiIntNullable)  int? daemonLastKnownPid, @JsonKey(fromJson: _asApiIntNullable)  int? shutdownRequestedAt, @JsonKey(fromJson: _asApiStringNullable)  String? shutdownSource)  $default,) {final _that = this;
switch (_that) {
case _MachineMetadata():
return $default(_that.host,_that.platform,_that.happyCliVersion,_that.happyHomeDir,_that.homeDir,_that.username,_that.arch,_that.displayName,_that.daemonLastKnownStatus,_that.daemonLastKnownPid,_that.shutdownRequestedAt,_that.shutdownSource);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _asApiStringNullable)  String? host, @JsonKey(fromJson: _asApiStringNullable)  String? platform, @JsonKey(fromJson: _asApiStringNullable)  String? happyCliVersion, @JsonKey(fromJson: _asApiStringNullable)  String? happyHomeDir, @JsonKey(fromJson: _asApiStringNullable)  String? homeDir, @JsonKey(fromJson: _asApiStringNullable)  String? username, @JsonKey(fromJson: _asApiStringNullable)  String? arch, @JsonKey(fromJson: _asApiStringNullable)  String? displayName, @JsonKey(fromJson: _asApiStringNullable)  String? daemonLastKnownStatus, @JsonKey(fromJson: _asApiIntNullable)  int? daemonLastKnownPid, @JsonKey(fromJson: _asApiIntNullable)  int? shutdownRequestedAt, @JsonKey(fromJson: _asApiStringNullable)  String? shutdownSource)?  $default,) {final _that = this;
switch (_that) {
case _MachineMetadata() when $default != null:
return $default(_that.host,_that.platform,_that.happyCliVersion,_that.happyHomeDir,_that.homeDir,_that.username,_that.arch,_that.displayName,_that.daemonLastKnownStatus,_that.daemonLastKnownPid,_that.shutdownRequestedAt,_that.shutdownSource);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MachineMetadata implements MachineMetadata {
  const _MachineMetadata({@JsonKey(fromJson: _asApiStringNullable) this.host, @JsonKey(fromJson: _asApiStringNullable) this.platform, @JsonKey(fromJson: _asApiStringNullable) this.happyCliVersion, @JsonKey(fromJson: _asApiStringNullable) this.happyHomeDir, @JsonKey(fromJson: _asApiStringNullable) this.homeDir, @JsonKey(fromJson: _asApiStringNullable) this.username, @JsonKey(fromJson: _asApiStringNullable) this.arch, @JsonKey(fromJson: _asApiStringNullable) this.displayName, @JsonKey(fromJson: _asApiStringNullable) this.daemonLastKnownStatus, @JsonKey(fromJson: _asApiIntNullable) this.daemonLastKnownPid, @JsonKey(fromJson: _asApiIntNullable) this.shutdownRequestedAt, @JsonKey(fromJson: _asApiStringNullable) this.shutdownSource});
  factory _MachineMetadata.fromJson(Map<String, dynamic> json) => _$MachineMetadataFromJson(json);

@override@JsonKey(fromJson: _asApiStringNullable) final  String? host;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? platform;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? happyCliVersion;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? happyHomeDir;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? homeDir;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? username;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? arch;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? displayName;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? daemonLastKnownStatus;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? daemonLastKnownPid;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? shutdownRequestedAt;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? shutdownSource;

/// Create a copy of MachineMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MachineMetadataCopyWith<_MachineMetadata> get copyWith => __$MachineMetadataCopyWithImpl<_MachineMetadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MachineMetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MachineMetadata&&(identical(other.host, host) || other.host == host)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.happyCliVersion, happyCliVersion) || other.happyCliVersion == happyCliVersion)&&(identical(other.happyHomeDir, happyHomeDir) || other.happyHomeDir == happyHomeDir)&&(identical(other.homeDir, homeDir) || other.homeDir == homeDir)&&(identical(other.username, username) || other.username == username)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.daemonLastKnownStatus, daemonLastKnownStatus) || other.daemonLastKnownStatus == daemonLastKnownStatus)&&(identical(other.daemonLastKnownPid, daemonLastKnownPid) || other.daemonLastKnownPid == daemonLastKnownPid)&&(identical(other.shutdownRequestedAt, shutdownRequestedAt) || other.shutdownRequestedAt == shutdownRequestedAt)&&(identical(other.shutdownSource, shutdownSource) || other.shutdownSource == shutdownSource));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,host,platform,happyCliVersion,happyHomeDir,homeDir,username,arch,displayName,daemonLastKnownStatus,daemonLastKnownPid,shutdownRequestedAt,shutdownSource);

@override
String toString() {
  return 'MachineMetadata(host: $host, platform: $platform, happyCliVersion: $happyCliVersion, happyHomeDir: $happyHomeDir, homeDir: $homeDir, username: $username, arch: $arch, displayName: $displayName, daemonLastKnownStatus: $daemonLastKnownStatus, daemonLastKnownPid: $daemonLastKnownPid, shutdownRequestedAt: $shutdownRequestedAt, shutdownSource: $shutdownSource)';
}


}

/// @nodoc
abstract mixin class _$MachineMetadataCopyWith<$Res> implements $MachineMetadataCopyWith<$Res> {
  factory _$MachineMetadataCopyWith(_MachineMetadata value, $Res Function(_MachineMetadata) _then) = __$MachineMetadataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _asApiStringNullable) String? host,@JsonKey(fromJson: _asApiStringNullable) String? platform,@JsonKey(fromJson: _asApiStringNullable) String? happyCliVersion,@JsonKey(fromJson: _asApiStringNullable) String? happyHomeDir,@JsonKey(fromJson: _asApiStringNullable) String? homeDir,@JsonKey(fromJson: _asApiStringNullable) String? username,@JsonKey(fromJson: _asApiStringNullable) String? arch,@JsonKey(fromJson: _asApiStringNullable) String? displayName,@JsonKey(fromJson: _asApiStringNullable) String? daemonLastKnownStatus,@JsonKey(fromJson: _asApiIntNullable) int? daemonLastKnownPid,@JsonKey(fromJson: _asApiIntNullable) int? shutdownRequestedAt,@JsonKey(fromJson: _asApiStringNullable) String? shutdownSource
});




}
/// @nodoc
class __$MachineMetadataCopyWithImpl<$Res>
    implements _$MachineMetadataCopyWith<$Res> {
  __$MachineMetadataCopyWithImpl(this._self, this._then);

  final _MachineMetadata _self;
  final $Res Function(_MachineMetadata) _then;

/// Create a copy of MachineMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? host = freezed,Object? platform = freezed,Object? happyCliVersion = freezed,Object? happyHomeDir = freezed,Object? homeDir = freezed,Object? username = freezed,Object? arch = freezed,Object? displayName = freezed,Object? daemonLastKnownStatus = freezed,Object? daemonLastKnownPid = freezed,Object? shutdownRequestedAt = freezed,Object? shutdownSource = freezed,}) {
  return _then(_MachineMetadata(
host: freezed == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,happyCliVersion: freezed == happyCliVersion ? _self.happyCliVersion : happyCliVersion // ignore: cast_nullable_to_non_nullable
as String?,happyHomeDir: freezed == happyHomeDir ? _self.happyHomeDir : happyHomeDir // ignore: cast_nullable_to_non_nullable
as String?,homeDir: freezed == homeDir ? _self.homeDir : homeDir // ignore: cast_nullable_to_non_nullable
as String?,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,arch: freezed == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String?,displayName: freezed == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String?,daemonLastKnownStatus: freezed == daemonLastKnownStatus ? _self.daemonLastKnownStatus : daemonLastKnownStatus // ignore: cast_nullable_to_non_nullable
as String?,daemonLastKnownPid: freezed == daemonLastKnownPid ? _self.daemonLastKnownPid : daemonLastKnownPid // ignore: cast_nullable_to_non_nullable
as int?,shutdownRequestedAt: freezed == shutdownRequestedAt ? _self.shutdownRequestedAt : shutdownRequestedAt // ignore: cast_nullable_to_non_nullable
as int?,shutdownSource: freezed == shutdownSource ? _self.shutdownSource : shutdownSource // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Machine {

@JsonKey(fromJson: _machineIdFromJson) String get id;@JsonKey(fromJson: _asApiInt) int get seq;@JsonKey(fromJson: _asApiInt) int get createdAt;@JsonKey(fromJson: _asApiInt) int get updatedAt;@JsonKey(fromJson: _asBool) bool get active;@JsonKey(fromJson: _asApiInt) int get activeAt;@JsonKey(fromJson: _asApiInt) int get metadataVersion;@JsonKey(fromJson: _asApiInt) int get daemonStateVersion;@JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson) MachineMetadata? get metadata;@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? get daemonState;
/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MachineCopyWith<Machine> get copyWith => _$MachineCopyWithImpl<Machine>(this as Machine, _$identity);

  /// Serializes this Machine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Machine&&(identical(other.id, id) || other.id == id)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.active, active) || other.active == active)&&(identical(other.activeAt, activeAt) || other.activeAt == activeAt)&&(identical(other.metadataVersion, metadataVersion) || other.metadataVersion == metadataVersion)&&(identical(other.daemonStateVersion, daemonStateVersion) || other.daemonStateVersion == daemonStateVersion)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&const DeepCollectionEquality().equals(other.daemonState, daemonState));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,seq,createdAt,updatedAt,active,activeAt,metadataVersion,daemonStateVersion,metadata,const DeepCollectionEquality().hash(daemonState));

@override
String toString() {
  return 'Machine(id: $id, seq: $seq, createdAt: $createdAt, updatedAt: $updatedAt, active: $active, activeAt: $activeAt, metadataVersion: $metadataVersion, daemonStateVersion: $daemonStateVersion, metadata: $metadata, daemonState: $daemonState)';
}


}

/// @nodoc
abstract mixin class $MachineCopyWith<$Res>  {
  factory $MachineCopyWith(Machine value, $Res Function(Machine) _then) = _$MachineCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _machineIdFromJson) String id,@JsonKey(fromJson: _asApiInt) int seq,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiInt) int updatedAt,@JsonKey(fromJson: _asBool) bool active,@JsonKey(fromJson: _asApiInt) int activeAt,@JsonKey(fromJson: _asApiInt) int metadataVersion,@JsonKey(fromJson: _asApiInt) int daemonStateVersion,@JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson) MachineMetadata? metadata,@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? daemonState
});


$MachineMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$MachineCopyWithImpl<$Res>
    implements $MachineCopyWith<$Res> {
  _$MachineCopyWithImpl(this._self, this._then);

  final Machine _self;
  final $Res Function(Machine) _then;

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? seq = null,Object? createdAt = null,Object? updatedAt = null,Object? active = null,Object? activeAt = null,Object? metadataVersion = null,Object? daemonStateVersion = null,Object? metadata = freezed,Object? daemonState = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,activeAt: null == activeAt ? _self.activeAt : activeAt // ignore: cast_nullable_to_non_nullable
as int,metadataVersion: null == metadataVersion ? _self.metadataVersion : metadataVersion // ignore: cast_nullable_to_non_nullable
as int,daemonStateVersion: null == daemonStateVersion ? _self.daemonStateVersion : daemonStateVersion // ignore: cast_nullable_to_non_nullable
as int,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as MachineMetadata?,daemonState: freezed == daemonState ? _self.daemonState : daemonState // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MachineMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $MachineMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// Adds pattern-matching-related methods to [Machine].
extension MachinePatterns on Machine {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Machine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Machine() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Machine value)  $default,){
final _that = this;
switch (_that) {
case _Machine():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Machine value)?  $default,){
final _that = this;
switch (_that) {
case _Machine() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _machineIdFromJson)  String id, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt, @JsonKey(fromJson: _asBool)  bool active, @JsonKey(fromJson: _asApiInt)  int activeAt, @JsonKey(fromJson: _asApiInt)  int metadataVersion, @JsonKey(fromJson: _asApiInt)  int daemonStateVersion, @JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson)  MachineMetadata? metadata, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? daemonState)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that.id,_that.seq,_that.createdAt,_that.updatedAt,_that.active,_that.activeAt,_that.metadataVersion,_that.daemonStateVersion,_that.metadata,_that.daemonState);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _machineIdFromJson)  String id, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt, @JsonKey(fromJson: _asBool)  bool active, @JsonKey(fromJson: _asApiInt)  int activeAt, @JsonKey(fromJson: _asApiInt)  int metadataVersion, @JsonKey(fromJson: _asApiInt)  int daemonStateVersion, @JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson)  MachineMetadata? metadata, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? daemonState)  $default,) {final _that = this;
switch (_that) {
case _Machine():
return $default(_that.id,_that.seq,_that.createdAt,_that.updatedAt,_that.active,_that.activeAt,_that.metadataVersion,_that.daemonStateVersion,_that.metadata,_that.daemonState);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _machineIdFromJson)  String id, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt, @JsonKey(fromJson: _asBool)  bool active, @JsonKey(fromJson: _asApiInt)  int activeAt, @JsonKey(fromJson: _asApiInt)  int metadataVersion, @JsonKey(fromJson: _asApiInt)  int daemonStateVersion, @JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson)  MachineMetadata? metadata, @JsonKey(fromJson: _mapOrNull)  Map<String, dynamic>? daemonState)?  $default,) {final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that.id,_that.seq,_that.createdAt,_that.updatedAt,_that.active,_that.activeAt,_that.metadataVersion,_that.daemonStateVersion,_that.metadata,_that.daemonState);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Machine implements Machine {
  const _Machine({@JsonKey(fromJson: _machineIdFromJson) required this.id, @JsonKey(fromJson: _asApiInt) required this.seq, @JsonKey(fromJson: _asApiInt) required this.createdAt, @JsonKey(fromJson: _asApiInt) required this.updatedAt, @JsonKey(fromJson: _asBool) required this.active, @JsonKey(fromJson: _asApiInt) required this.activeAt, @JsonKey(fromJson: _asApiInt) required this.metadataVersion, @JsonKey(fromJson: _asApiInt) required this.daemonStateVersion, @JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson) this.metadata, @JsonKey(fromJson: _mapOrNull) final  Map<String, dynamic>? daemonState}): _daemonState = daemonState;
  factory _Machine.fromJson(Map<String, dynamic> json) => _$MachineFromJson(json);

@override@JsonKey(fromJson: _machineIdFromJson) final  String id;
@override@JsonKey(fromJson: _asApiInt) final  int seq;
@override@JsonKey(fromJson: _asApiInt) final  int createdAt;
@override@JsonKey(fromJson: _asApiInt) final  int updatedAt;
@override@JsonKey(fromJson: _asBool) final  bool active;
@override@JsonKey(fromJson: _asApiInt) final  int activeAt;
@override@JsonKey(fromJson: _asApiInt) final  int metadataVersion;
@override@JsonKey(fromJson: _asApiInt) final  int daemonStateVersion;
@override@JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson) final  MachineMetadata? metadata;
 final  Map<String, dynamic>? _daemonState;
@override@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? get daemonState {
  final value = _daemonState;
  if (value == null) return null;
  if (_daemonState is EqualUnmodifiableMapView) return _daemonState;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MachineCopyWith<_Machine> get copyWith => __$MachineCopyWithImpl<_Machine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MachineToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Machine&&(identical(other.id, id) || other.id == id)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.active, active) || other.active == active)&&(identical(other.activeAt, activeAt) || other.activeAt == activeAt)&&(identical(other.metadataVersion, metadataVersion) || other.metadataVersion == metadataVersion)&&(identical(other.daemonStateVersion, daemonStateVersion) || other.daemonStateVersion == daemonStateVersion)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&const DeepCollectionEquality().equals(other._daemonState, _daemonState));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,seq,createdAt,updatedAt,active,activeAt,metadataVersion,daemonStateVersion,metadata,const DeepCollectionEquality().hash(_daemonState));

@override
String toString() {
  return 'Machine(id: $id, seq: $seq, createdAt: $createdAt, updatedAt: $updatedAt, active: $active, activeAt: $activeAt, metadataVersion: $metadataVersion, daemonStateVersion: $daemonStateVersion, metadata: $metadata, daemonState: $daemonState)';
}


}

/// @nodoc
abstract mixin class _$MachineCopyWith<$Res> implements $MachineCopyWith<$Res> {
  factory _$MachineCopyWith(_Machine value, $Res Function(_Machine) _then) = __$MachineCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _machineIdFromJson) String id,@JsonKey(fromJson: _asApiInt) int seq,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiInt) int updatedAt,@JsonKey(fromJson: _asBool) bool active,@JsonKey(fromJson: _asApiInt) int activeAt,@JsonKey(fromJson: _asApiInt) int metadataVersion,@JsonKey(fromJson: _asApiInt) int daemonStateVersion,@JsonKey(fromJson: _machineMetadataFromJson, toJson: _machineMetadataToJson) MachineMetadata? metadata,@JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? daemonState
});


@override $MachineMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class __$MachineCopyWithImpl<$Res>
    implements _$MachineCopyWith<$Res> {
  __$MachineCopyWithImpl(this._self, this._then);

  final _Machine _self;
  final $Res Function(_Machine) _then;

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? seq = null,Object? createdAt = null,Object? updatedAt = null,Object? active = null,Object? activeAt = null,Object? metadataVersion = null,Object? daemonStateVersion = null,Object? metadata = freezed,Object? daemonState = freezed,}) {
  return _then(_Machine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,activeAt: null == activeAt ? _self.activeAt : activeAt // ignore: cast_nullable_to_non_nullable
as int,metadataVersion: null == metadataVersion ? _self.metadataVersion : metadataVersion // ignore: cast_nullable_to_non_nullable
as int,daemonStateVersion: null == daemonStateVersion ? _self.daemonStateVersion : daemonStateVersion // ignore: cast_nullable_to_non_nullable
as int,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as MachineMetadata?,daemonState: freezed == daemonState ? _self._daemonState : daemonState // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MachineMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $MachineMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}


/// @nodoc
mixin _$GitStatus {

 bool get isDirty; int get modifiedCount; int get untrackedCount; int get stagedCount; int get lastUpdatedAt; String? get branch; int get stagedLinesAdded; int get stagedLinesRemoved; int get unstagedLinesAdded; int get unstagedLinesRemoved; int get linesAdded; int get linesRemoved; int get linesChanged; String? get upstreamBranch; int? get aheadCount; int? get behindCount; int? get stashCount;
/// Create a copy of GitStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GitStatusCopyWith<GitStatus> get copyWith => _$GitStatusCopyWithImpl<GitStatus>(this as GitStatus, _$identity);

  /// Serializes this GitStatus to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GitStatus&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.modifiedCount, modifiedCount) || other.modifiedCount == modifiedCount)&&(identical(other.untrackedCount, untrackedCount) || other.untrackedCount == untrackedCount)&&(identical(other.stagedCount, stagedCount) || other.stagedCount == stagedCount)&&(identical(other.lastUpdatedAt, lastUpdatedAt) || other.lastUpdatedAt == lastUpdatedAt)&&(identical(other.branch, branch) || other.branch == branch)&&(identical(other.stagedLinesAdded, stagedLinesAdded) || other.stagedLinesAdded == stagedLinesAdded)&&(identical(other.stagedLinesRemoved, stagedLinesRemoved) || other.stagedLinesRemoved == stagedLinesRemoved)&&(identical(other.unstagedLinesAdded, unstagedLinesAdded) || other.unstagedLinesAdded == unstagedLinesAdded)&&(identical(other.unstagedLinesRemoved, unstagedLinesRemoved) || other.unstagedLinesRemoved == unstagedLinesRemoved)&&(identical(other.linesAdded, linesAdded) || other.linesAdded == linesAdded)&&(identical(other.linesRemoved, linesRemoved) || other.linesRemoved == linesRemoved)&&(identical(other.linesChanged, linesChanged) || other.linesChanged == linesChanged)&&(identical(other.upstreamBranch, upstreamBranch) || other.upstreamBranch == upstreamBranch)&&(identical(other.aheadCount, aheadCount) || other.aheadCount == aheadCount)&&(identical(other.behindCount, behindCount) || other.behindCount == behindCount)&&(identical(other.stashCount, stashCount) || other.stashCount == stashCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isDirty,modifiedCount,untrackedCount,stagedCount,lastUpdatedAt,branch,stagedLinesAdded,stagedLinesRemoved,unstagedLinesAdded,unstagedLinesRemoved,linesAdded,linesRemoved,linesChanged,upstreamBranch,aheadCount,behindCount,stashCount);

@override
String toString() {
  return 'GitStatus(isDirty: $isDirty, modifiedCount: $modifiedCount, untrackedCount: $untrackedCount, stagedCount: $stagedCount, lastUpdatedAt: $lastUpdatedAt, branch: $branch, stagedLinesAdded: $stagedLinesAdded, stagedLinesRemoved: $stagedLinesRemoved, unstagedLinesAdded: $unstagedLinesAdded, unstagedLinesRemoved: $unstagedLinesRemoved, linesAdded: $linesAdded, linesRemoved: $linesRemoved, linesChanged: $linesChanged, upstreamBranch: $upstreamBranch, aheadCount: $aheadCount, behindCount: $behindCount, stashCount: $stashCount)';
}


}

/// @nodoc
abstract mixin class $GitStatusCopyWith<$Res>  {
  factory $GitStatusCopyWith(GitStatus value, $Res Function(GitStatus) _then) = _$GitStatusCopyWithImpl;
@useResult
$Res call({
 bool isDirty, int modifiedCount, int untrackedCount, int stagedCount, int lastUpdatedAt, String? branch, int stagedLinesAdded, int stagedLinesRemoved, int unstagedLinesAdded, int unstagedLinesRemoved, int linesAdded, int linesRemoved, int linesChanged, String? upstreamBranch, int? aheadCount, int? behindCount, int? stashCount
});




}
/// @nodoc
class _$GitStatusCopyWithImpl<$Res>
    implements $GitStatusCopyWith<$Res> {
  _$GitStatusCopyWithImpl(this._self, this._then);

  final GitStatus _self;
  final $Res Function(GitStatus) _then;

/// Create a copy of GitStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isDirty = null,Object? modifiedCount = null,Object? untrackedCount = null,Object? stagedCount = null,Object? lastUpdatedAt = null,Object? branch = freezed,Object? stagedLinesAdded = null,Object? stagedLinesRemoved = null,Object? unstagedLinesAdded = null,Object? unstagedLinesRemoved = null,Object? linesAdded = null,Object? linesRemoved = null,Object? linesChanged = null,Object? upstreamBranch = freezed,Object? aheadCount = freezed,Object? behindCount = freezed,Object? stashCount = freezed,}) {
  return _then(_self.copyWith(
isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,modifiedCount: null == modifiedCount ? _self.modifiedCount : modifiedCount // ignore: cast_nullable_to_non_nullable
as int,untrackedCount: null == untrackedCount ? _self.untrackedCount : untrackedCount // ignore: cast_nullable_to_non_nullable
as int,stagedCount: null == stagedCount ? _self.stagedCount : stagedCount // ignore: cast_nullable_to_non_nullable
as int,lastUpdatedAt: null == lastUpdatedAt ? _self.lastUpdatedAt : lastUpdatedAt // ignore: cast_nullable_to_non_nullable
as int,branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String?,stagedLinesAdded: null == stagedLinesAdded ? _self.stagedLinesAdded : stagedLinesAdded // ignore: cast_nullable_to_non_nullable
as int,stagedLinesRemoved: null == stagedLinesRemoved ? _self.stagedLinesRemoved : stagedLinesRemoved // ignore: cast_nullable_to_non_nullable
as int,unstagedLinesAdded: null == unstagedLinesAdded ? _self.unstagedLinesAdded : unstagedLinesAdded // ignore: cast_nullable_to_non_nullable
as int,unstagedLinesRemoved: null == unstagedLinesRemoved ? _self.unstagedLinesRemoved : unstagedLinesRemoved // ignore: cast_nullable_to_non_nullable
as int,linesAdded: null == linesAdded ? _self.linesAdded : linesAdded // ignore: cast_nullable_to_non_nullable
as int,linesRemoved: null == linesRemoved ? _self.linesRemoved : linesRemoved // ignore: cast_nullable_to_non_nullable
as int,linesChanged: null == linesChanged ? _self.linesChanged : linesChanged // ignore: cast_nullable_to_non_nullable
as int,upstreamBranch: freezed == upstreamBranch ? _self.upstreamBranch : upstreamBranch // ignore: cast_nullable_to_non_nullable
as String?,aheadCount: freezed == aheadCount ? _self.aheadCount : aheadCount // ignore: cast_nullable_to_non_nullable
as int?,behindCount: freezed == behindCount ? _self.behindCount : behindCount // ignore: cast_nullable_to_non_nullable
as int?,stashCount: freezed == stashCount ? _self.stashCount : stashCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [GitStatus].
extension GitStatusPatterns on GitStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GitStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GitStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GitStatus value)  $default,){
final _that = this;
switch (_that) {
case _GitStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GitStatus value)?  $default,){
final _that = this;
switch (_that) {
case _GitStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isDirty,  int modifiedCount,  int untrackedCount,  int stagedCount,  int lastUpdatedAt,  String? branch,  int stagedLinesAdded,  int stagedLinesRemoved,  int unstagedLinesAdded,  int unstagedLinesRemoved,  int linesAdded,  int linesRemoved,  int linesChanged,  String? upstreamBranch,  int? aheadCount,  int? behindCount,  int? stashCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GitStatus() when $default != null:
return $default(_that.isDirty,_that.modifiedCount,_that.untrackedCount,_that.stagedCount,_that.lastUpdatedAt,_that.branch,_that.stagedLinesAdded,_that.stagedLinesRemoved,_that.unstagedLinesAdded,_that.unstagedLinesRemoved,_that.linesAdded,_that.linesRemoved,_that.linesChanged,_that.upstreamBranch,_that.aheadCount,_that.behindCount,_that.stashCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isDirty,  int modifiedCount,  int untrackedCount,  int stagedCount,  int lastUpdatedAt,  String? branch,  int stagedLinesAdded,  int stagedLinesRemoved,  int unstagedLinesAdded,  int unstagedLinesRemoved,  int linesAdded,  int linesRemoved,  int linesChanged,  String? upstreamBranch,  int? aheadCount,  int? behindCount,  int? stashCount)  $default,) {final _that = this;
switch (_that) {
case _GitStatus():
return $default(_that.isDirty,_that.modifiedCount,_that.untrackedCount,_that.stagedCount,_that.lastUpdatedAt,_that.branch,_that.stagedLinesAdded,_that.stagedLinesRemoved,_that.unstagedLinesAdded,_that.unstagedLinesRemoved,_that.linesAdded,_that.linesRemoved,_that.linesChanged,_that.upstreamBranch,_that.aheadCount,_that.behindCount,_that.stashCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isDirty,  int modifiedCount,  int untrackedCount,  int stagedCount,  int lastUpdatedAt,  String? branch,  int stagedLinesAdded,  int stagedLinesRemoved,  int unstagedLinesAdded,  int unstagedLinesRemoved,  int linesAdded,  int linesRemoved,  int linesChanged,  String? upstreamBranch,  int? aheadCount,  int? behindCount,  int? stashCount)?  $default,) {final _that = this;
switch (_that) {
case _GitStatus() when $default != null:
return $default(_that.isDirty,_that.modifiedCount,_that.untrackedCount,_that.stagedCount,_that.lastUpdatedAt,_that.branch,_that.stagedLinesAdded,_that.stagedLinesRemoved,_that.unstagedLinesAdded,_that.unstagedLinesRemoved,_that.linesAdded,_that.linesRemoved,_that.linesChanged,_that.upstreamBranch,_that.aheadCount,_that.behindCount,_that.stashCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GitStatus implements GitStatus {
  const _GitStatus({required this.isDirty, required this.modifiedCount, required this.untrackedCount, required this.stagedCount, required this.lastUpdatedAt, this.branch, this.stagedLinesAdded = 0, this.stagedLinesRemoved = 0, this.unstagedLinesAdded = 0, this.unstagedLinesRemoved = 0, this.linesAdded = 0, this.linesRemoved = 0, this.linesChanged = 0, this.upstreamBranch, this.aheadCount, this.behindCount, this.stashCount});
  factory _GitStatus.fromJson(Map<String, dynamic> json) => _$GitStatusFromJson(json);

@override final  bool isDirty;
@override final  int modifiedCount;
@override final  int untrackedCount;
@override final  int stagedCount;
@override final  int lastUpdatedAt;
@override final  String? branch;
@override@JsonKey() final  int stagedLinesAdded;
@override@JsonKey() final  int stagedLinesRemoved;
@override@JsonKey() final  int unstagedLinesAdded;
@override@JsonKey() final  int unstagedLinesRemoved;
@override@JsonKey() final  int linesAdded;
@override@JsonKey() final  int linesRemoved;
@override@JsonKey() final  int linesChanged;
@override final  String? upstreamBranch;
@override final  int? aheadCount;
@override final  int? behindCount;
@override final  int? stashCount;

/// Create a copy of GitStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GitStatusCopyWith<_GitStatus> get copyWith => __$GitStatusCopyWithImpl<_GitStatus>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GitStatusToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GitStatus&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.modifiedCount, modifiedCount) || other.modifiedCount == modifiedCount)&&(identical(other.untrackedCount, untrackedCount) || other.untrackedCount == untrackedCount)&&(identical(other.stagedCount, stagedCount) || other.stagedCount == stagedCount)&&(identical(other.lastUpdatedAt, lastUpdatedAt) || other.lastUpdatedAt == lastUpdatedAt)&&(identical(other.branch, branch) || other.branch == branch)&&(identical(other.stagedLinesAdded, stagedLinesAdded) || other.stagedLinesAdded == stagedLinesAdded)&&(identical(other.stagedLinesRemoved, stagedLinesRemoved) || other.stagedLinesRemoved == stagedLinesRemoved)&&(identical(other.unstagedLinesAdded, unstagedLinesAdded) || other.unstagedLinesAdded == unstagedLinesAdded)&&(identical(other.unstagedLinesRemoved, unstagedLinesRemoved) || other.unstagedLinesRemoved == unstagedLinesRemoved)&&(identical(other.linesAdded, linesAdded) || other.linesAdded == linesAdded)&&(identical(other.linesRemoved, linesRemoved) || other.linesRemoved == linesRemoved)&&(identical(other.linesChanged, linesChanged) || other.linesChanged == linesChanged)&&(identical(other.upstreamBranch, upstreamBranch) || other.upstreamBranch == upstreamBranch)&&(identical(other.aheadCount, aheadCount) || other.aheadCount == aheadCount)&&(identical(other.behindCount, behindCount) || other.behindCount == behindCount)&&(identical(other.stashCount, stashCount) || other.stashCount == stashCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isDirty,modifiedCount,untrackedCount,stagedCount,lastUpdatedAt,branch,stagedLinesAdded,stagedLinesRemoved,unstagedLinesAdded,unstagedLinesRemoved,linesAdded,linesRemoved,linesChanged,upstreamBranch,aheadCount,behindCount,stashCount);

@override
String toString() {
  return 'GitStatus(isDirty: $isDirty, modifiedCount: $modifiedCount, untrackedCount: $untrackedCount, stagedCount: $stagedCount, lastUpdatedAt: $lastUpdatedAt, branch: $branch, stagedLinesAdded: $stagedLinesAdded, stagedLinesRemoved: $stagedLinesRemoved, unstagedLinesAdded: $unstagedLinesAdded, unstagedLinesRemoved: $unstagedLinesRemoved, linesAdded: $linesAdded, linesRemoved: $linesRemoved, linesChanged: $linesChanged, upstreamBranch: $upstreamBranch, aheadCount: $aheadCount, behindCount: $behindCount, stashCount: $stashCount)';
}


}

/// @nodoc
abstract mixin class _$GitStatusCopyWith<$Res> implements $GitStatusCopyWith<$Res> {
  factory _$GitStatusCopyWith(_GitStatus value, $Res Function(_GitStatus) _then) = __$GitStatusCopyWithImpl;
@override @useResult
$Res call({
 bool isDirty, int modifiedCount, int untrackedCount, int stagedCount, int lastUpdatedAt, String? branch, int stagedLinesAdded, int stagedLinesRemoved, int unstagedLinesAdded, int unstagedLinesRemoved, int linesAdded, int linesRemoved, int linesChanged, String? upstreamBranch, int? aheadCount, int? behindCount, int? stashCount
});




}
/// @nodoc
class __$GitStatusCopyWithImpl<$Res>
    implements _$GitStatusCopyWith<$Res> {
  __$GitStatusCopyWithImpl(this._self, this._then);

  final _GitStatus _self;
  final $Res Function(_GitStatus) _then;

/// Create a copy of GitStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isDirty = null,Object? modifiedCount = null,Object? untrackedCount = null,Object? stagedCount = null,Object? lastUpdatedAt = null,Object? branch = freezed,Object? stagedLinesAdded = null,Object? stagedLinesRemoved = null,Object? unstagedLinesAdded = null,Object? unstagedLinesRemoved = null,Object? linesAdded = null,Object? linesRemoved = null,Object? linesChanged = null,Object? upstreamBranch = freezed,Object? aheadCount = freezed,Object? behindCount = freezed,Object? stashCount = freezed,}) {
  return _then(_GitStatus(
isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,modifiedCount: null == modifiedCount ? _self.modifiedCount : modifiedCount // ignore: cast_nullable_to_non_nullable
as int,untrackedCount: null == untrackedCount ? _self.untrackedCount : untrackedCount // ignore: cast_nullable_to_non_nullable
as int,stagedCount: null == stagedCount ? _self.stagedCount : stagedCount // ignore: cast_nullable_to_non_nullable
as int,lastUpdatedAt: null == lastUpdatedAt ? _self.lastUpdatedAt : lastUpdatedAt // ignore: cast_nullable_to_non_nullable
as int,branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as String?,stagedLinesAdded: null == stagedLinesAdded ? _self.stagedLinesAdded : stagedLinesAdded // ignore: cast_nullable_to_non_nullable
as int,stagedLinesRemoved: null == stagedLinesRemoved ? _self.stagedLinesRemoved : stagedLinesRemoved // ignore: cast_nullable_to_non_nullable
as int,unstagedLinesAdded: null == unstagedLinesAdded ? _self.unstagedLinesAdded : unstagedLinesAdded // ignore: cast_nullable_to_non_nullable
as int,unstagedLinesRemoved: null == unstagedLinesRemoved ? _self.unstagedLinesRemoved : unstagedLinesRemoved // ignore: cast_nullable_to_non_nullable
as int,linesAdded: null == linesAdded ? _self.linesAdded : linesAdded // ignore: cast_nullable_to_non_nullable
as int,linesRemoved: null == linesRemoved ? _self.linesRemoved : linesRemoved // ignore: cast_nullable_to_non_nullable
as int,linesChanged: null == linesChanged ? _self.linesChanged : linesChanged // ignore: cast_nullable_to_non_nullable
as int,upstreamBranch: freezed == upstreamBranch ? _self.upstreamBranch : upstreamBranch // ignore: cast_nullable_to_non_nullable
as String?,aheadCount: freezed == aheadCount ? _self.aheadCount : aheadCount // ignore: cast_nullable_to_non_nullable
as int?,behindCount: freezed == behindCount ? _self.behindCount : behindCount // ignore: cast_nullable_to_non_nullable
as int?,stashCount: freezed == stashCount ? _self.stashCount : stashCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
