// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Metadata {

@JsonKey(fromJson: _asApiStringNullable) String? get path; String get host;@JsonKey(fromJson: _asApiStringNullable) String? get version;@JsonKey(fromJson: _asApiStringNullable) String? get name;@JsonKey(fromJson: _asApiStringNullable) String? get os;@JsonKey(fromJson: _summaryFromJson) Summary? get summary;@JsonKey(fromJson: _asApiStringNullable) String? get machineId;@JsonKey(fromJson: _asApiStringNullable) String? get claudeSessionId;@JsonKey(fromJson: _asApiStringListNullable) List<String>? get tools;@JsonKey(fromJson: _asApiStringListNullable) List<String>? get slashCommands;@JsonKey(fromJson: _asApiStringNullable) String? get homeDir;@JsonKey(fromJson: _asApiStringNullable) String? get happyHomeDir;@JsonKey(fromJson: _asApiIntNullable) int? get hostPid;@JsonKey(fromJson: _asApiStringNullable) String? get flavor;@JsonKey(fromJson: _asApiStringNullable) String? get lifecycleState;@JsonKey(fromJson: _asApiStringNullable) String? get lifecycleStateError;@JsonKey(fromJson: _asApiIntNullable) int? get lifecycleStateSince;// sandbox field is stored as {enabled: bool} but we keep bool? in model
@JsonKey(name: 'sandbox', fromJson: _sandboxEnabledFromJson, toJson: _sandboxEnabledToJson) bool? get sandboxEnabled;
/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MetadataCopyWith<Metadata> get copyWith => _$MetadataCopyWithImpl<Metadata>(this as Metadata, _$identity);

  /// Serializes this Metadata to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Metadata&&(identical(other.path, path) || other.path == path)&&(identical(other.host, host) || other.host == host)&&(identical(other.version, version) || other.version == version)&&(identical(other.name, name) || other.name == name)&&(identical(other.os, os) || other.os == os)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.machineId, machineId) || other.machineId == machineId)&&(identical(other.claudeSessionId, claudeSessionId) || other.claudeSessionId == claudeSessionId)&&const DeepCollectionEquality().equals(other.tools, tools)&&const DeepCollectionEquality().equals(other.slashCommands, slashCommands)&&(identical(other.homeDir, homeDir) || other.homeDir == homeDir)&&(identical(other.happyHomeDir, happyHomeDir) || other.happyHomeDir == happyHomeDir)&&(identical(other.hostPid, hostPid) || other.hostPid == hostPid)&&(identical(other.flavor, flavor) || other.flavor == flavor)&&(identical(other.lifecycleState, lifecycleState) || other.lifecycleState == lifecycleState)&&(identical(other.lifecycleStateError, lifecycleStateError) || other.lifecycleStateError == lifecycleStateError)&&(identical(other.lifecycleStateSince, lifecycleStateSince) || other.lifecycleStateSince == lifecycleStateSince)&&(identical(other.sandboxEnabled, sandboxEnabled) || other.sandboxEnabled == sandboxEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,host,version,name,os,summary,machineId,claudeSessionId,const DeepCollectionEquality().hash(tools),const DeepCollectionEquality().hash(slashCommands),homeDir,happyHomeDir,hostPid,flavor,lifecycleState,lifecycleStateError,lifecycleStateSince,sandboxEnabled);

@override
String toString() {
  return 'Metadata(path: $path, host: $host, version: $version, name: $name, os: $os, summary: $summary, machineId: $machineId, claudeSessionId: $claudeSessionId, tools: $tools, slashCommands: $slashCommands, homeDir: $homeDir, happyHomeDir: $happyHomeDir, hostPid: $hostPid, flavor: $flavor, lifecycleState: $lifecycleState, lifecycleStateError: $lifecycleStateError, lifecycleStateSince: $lifecycleStateSince, sandboxEnabled: $sandboxEnabled)';
}


}

/// @nodoc
abstract mixin class $MetadataCopyWith<$Res>  {
  factory $MetadataCopyWith(Metadata value, $Res Function(Metadata) _then) = _$MetadataCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _asApiStringNullable) String? path, String host,@JsonKey(fromJson: _asApiStringNullable) String? version,@JsonKey(fromJson: _asApiStringNullable) String? name,@JsonKey(fromJson: _asApiStringNullable) String? os,@JsonKey(fromJson: _summaryFromJson) Summary? summary,@JsonKey(fromJson: _asApiStringNullable) String? machineId,@JsonKey(fromJson: _asApiStringNullable) String? claudeSessionId,@JsonKey(fromJson: _asApiStringListNullable) List<String>? tools,@JsonKey(fromJson: _asApiStringListNullable) List<String>? slashCommands,@JsonKey(fromJson: _asApiStringNullable) String? homeDir,@JsonKey(fromJson: _asApiStringNullable) String? happyHomeDir,@JsonKey(fromJson: _asApiIntNullable) int? hostPid,@JsonKey(fromJson: _asApiStringNullable) String? flavor,@JsonKey(fromJson: _asApiStringNullable) String? lifecycleState,@JsonKey(fromJson: _asApiStringNullable) String? lifecycleStateError,@JsonKey(fromJson: _asApiIntNullable) int? lifecycleStateSince,@JsonKey(name: 'sandbox', fromJson: _sandboxEnabledFromJson, toJson: _sandboxEnabledToJson) bool? sandboxEnabled
});


$SummaryCopyWith<$Res>? get summary;

}
/// @nodoc
class _$MetadataCopyWithImpl<$Res>
    implements $MetadataCopyWith<$Res> {
  _$MetadataCopyWithImpl(this._self, this._then);

  final Metadata _self;
  final $Res Function(Metadata) _then;

/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = freezed,Object? host = null,Object? version = freezed,Object? name = freezed,Object? os = freezed,Object? summary = freezed,Object? machineId = freezed,Object? claudeSessionId = freezed,Object? tools = freezed,Object? slashCommands = freezed,Object? homeDir = freezed,Object? happyHomeDir = freezed,Object? hostPid = freezed,Object? flavor = freezed,Object? lifecycleState = freezed,Object? lifecycleStateError = freezed,Object? lifecycleStateSince = freezed,Object? sandboxEnabled = freezed,}) {
  return _then(_self.copyWith(
path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,os: freezed == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as Summary?,machineId: freezed == machineId ? _self.machineId : machineId // ignore: cast_nullable_to_non_nullable
as String?,claudeSessionId: freezed == claudeSessionId ? _self.claudeSessionId : claudeSessionId // ignore: cast_nullable_to_non_nullable
as String?,tools: freezed == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<String>?,slashCommands: freezed == slashCommands ? _self.slashCommands : slashCommands // ignore: cast_nullable_to_non_nullable
as List<String>?,homeDir: freezed == homeDir ? _self.homeDir : homeDir // ignore: cast_nullable_to_non_nullable
as String?,happyHomeDir: freezed == happyHomeDir ? _self.happyHomeDir : happyHomeDir // ignore: cast_nullable_to_non_nullable
as String?,hostPid: freezed == hostPid ? _self.hostPid : hostPid // ignore: cast_nullable_to_non_nullable
as int?,flavor: freezed == flavor ? _self.flavor : flavor // ignore: cast_nullable_to_non_nullable
as String?,lifecycleState: freezed == lifecycleState ? _self.lifecycleState : lifecycleState // ignore: cast_nullable_to_non_nullable
as String?,lifecycleStateError: freezed == lifecycleStateError ? _self.lifecycleStateError : lifecycleStateError // ignore: cast_nullable_to_non_nullable
as String?,lifecycleStateSince: freezed == lifecycleStateSince ? _self.lifecycleStateSince : lifecycleStateSince // ignore: cast_nullable_to_non_nullable
as int?,sandboxEnabled: freezed == sandboxEnabled ? _self.sandboxEnabled : sandboxEnabled // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $SummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}


/// Adds pattern-matching-related methods to [Metadata].
extension MetadataPatterns on Metadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Metadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Metadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Metadata value)  $default,){
final _that = this;
switch (_that) {
case _Metadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Metadata value)?  $default,){
final _that = this;
switch (_that) {
case _Metadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asApiStringNullable)  String? path,  String host, @JsonKey(fromJson: _asApiStringNullable)  String? version, @JsonKey(fromJson: _asApiStringNullable)  String? name, @JsonKey(fromJson: _asApiStringNullable)  String? os, @JsonKey(fromJson: _summaryFromJson)  Summary? summary, @JsonKey(fromJson: _asApiStringNullable)  String? machineId, @JsonKey(fromJson: _asApiStringNullable)  String? claudeSessionId, @JsonKey(fromJson: _asApiStringListNullable)  List<String>? tools, @JsonKey(fromJson: _asApiStringListNullable)  List<String>? slashCommands, @JsonKey(fromJson: _asApiStringNullable)  String? homeDir, @JsonKey(fromJson: _asApiStringNullable)  String? happyHomeDir, @JsonKey(fromJson: _asApiIntNullable)  int? hostPid, @JsonKey(fromJson: _asApiStringNullable)  String? flavor, @JsonKey(fromJson: _asApiStringNullable)  String? lifecycleState, @JsonKey(fromJson: _asApiStringNullable)  String? lifecycleStateError, @JsonKey(fromJson: _asApiIntNullable)  int? lifecycleStateSince, @JsonKey(name: 'sandbox', fromJson: _sandboxEnabledFromJson, toJson: _sandboxEnabledToJson)  bool? sandboxEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Metadata() when $default != null:
return $default(_that.path,_that.host,_that.version,_that.name,_that.os,_that.summary,_that.machineId,_that.claudeSessionId,_that.tools,_that.slashCommands,_that.homeDir,_that.happyHomeDir,_that.hostPid,_that.flavor,_that.lifecycleState,_that.lifecycleStateError,_that.lifecycleStateSince,_that.sandboxEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asApiStringNullable)  String? path,  String host, @JsonKey(fromJson: _asApiStringNullable)  String? version, @JsonKey(fromJson: _asApiStringNullable)  String? name, @JsonKey(fromJson: _asApiStringNullable)  String? os, @JsonKey(fromJson: _summaryFromJson)  Summary? summary, @JsonKey(fromJson: _asApiStringNullable)  String? machineId, @JsonKey(fromJson: _asApiStringNullable)  String? claudeSessionId, @JsonKey(fromJson: _asApiStringListNullable)  List<String>? tools, @JsonKey(fromJson: _asApiStringListNullable)  List<String>? slashCommands, @JsonKey(fromJson: _asApiStringNullable)  String? homeDir, @JsonKey(fromJson: _asApiStringNullable)  String? happyHomeDir, @JsonKey(fromJson: _asApiIntNullable)  int? hostPid, @JsonKey(fromJson: _asApiStringNullable)  String? flavor, @JsonKey(fromJson: _asApiStringNullable)  String? lifecycleState, @JsonKey(fromJson: _asApiStringNullable)  String? lifecycleStateError, @JsonKey(fromJson: _asApiIntNullable)  int? lifecycleStateSince, @JsonKey(name: 'sandbox', fromJson: _sandboxEnabledFromJson, toJson: _sandboxEnabledToJson)  bool? sandboxEnabled)  $default,) {final _that = this;
switch (_that) {
case _Metadata():
return $default(_that.path,_that.host,_that.version,_that.name,_that.os,_that.summary,_that.machineId,_that.claudeSessionId,_that.tools,_that.slashCommands,_that.homeDir,_that.happyHomeDir,_that.hostPid,_that.flavor,_that.lifecycleState,_that.lifecycleStateError,_that.lifecycleStateSince,_that.sandboxEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _asApiStringNullable)  String? path,  String host, @JsonKey(fromJson: _asApiStringNullable)  String? version, @JsonKey(fromJson: _asApiStringNullable)  String? name, @JsonKey(fromJson: _asApiStringNullable)  String? os, @JsonKey(fromJson: _summaryFromJson)  Summary? summary, @JsonKey(fromJson: _asApiStringNullable)  String? machineId, @JsonKey(fromJson: _asApiStringNullable)  String? claudeSessionId, @JsonKey(fromJson: _asApiStringListNullable)  List<String>? tools, @JsonKey(fromJson: _asApiStringListNullable)  List<String>? slashCommands, @JsonKey(fromJson: _asApiStringNullable)  String? homeDir, @JsonKey(fromJson: _asApiStringNullable)  String? happyHomeDir, @JsonKey(fromJson: _asApiIntNullable)  int? hostPid, @JsonKey(fromJson: _asApiStringNullable)  String? flavor, @JsonKey(fromJson: _asApiStringNullable)  String? lifecycleState, @JsonKey(fromJson: _asApiStringNullable)  String? lifecycleStateError, @JsonKey(fromJson: _asApiIntNullable)  int? lifecycleStateSince, @JsonKey(name: 'sandbox', fromJson: _sandboxEnabledFromJson, toJson: _sandboxEnabledToJson)  bool? sandboxEnabled)?  $default,) {final _that = this;
switch (_that) {
case _Metadata() when $default != null:
return $default(_that.path,_that.host,_that.version,_that.name,_that.os,_that.summary,_that.machineId,_that.claudeSessionId,_that.tools,_that.slashCommands,_that.homeDir,_that.happyHomeDir,_that.hostPid,_that.flavor,_that.lifecycleState,_that.lifecycleStateError,_that.lifecycleStateSince,_that.sandboxEnabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Metadata implements Metadata {
  const _Metadata({@JsonKey(fromJson: _asApiStringNullable) this.path, this.host = '', @JsonKey(fromJson: _asApiStringNullable) this.version, @JsonKey(fromJson: _asApiStringNullable) this.name, @JsonKey(fromJson: _asApiStringNullable) this.os, @JsonKey(fromJson: _summaryFromJson) this.summary, @JsonKey(fromJson: _asApiStringNullable) this.machineId, @JsonKey(fromJson: _asApiStringNullable) this.claudeSessionId, @JsonKey(fromJson: _asApiStringListNullable) final  List<String>? tools, @JsonKey(fromJson: _asApiStringListNullable) final  List<String>? slashCommands, @JsonKey(fromJson: _asApiStringNullable) this.homeDir, @JsonKey(fromJson: _asApiStringNullable) this.happyHomeDir, @JsonKey(fromJson: _asApiIntNullable) this.hostPid, @JsonKey(fromJson: _asApiStringNullable) this.flavor, @JsonKey(fromJson: _asApiStringNullable) this.lifecycleState, @JsonKey(fromJson: _asApiStringNullable) this.lifecycleStateError, @JsonKey(fromJson: _asApiIntNullable) this.lifecycleStateSince, @JsonKey(name: 'sandbox', fromJson: _sandboxEnabledFromJson, toJson: _sandboxEnabledToJson) this.sandboxEnabled}): _tools = tools,_slashCommands = slashCommands;
  factory _Metadata.fromJson(Map<String, dynamic> json) => _$MetadataFromJson(json);

@override@JsonKey(fromJson: _asApiStringNullable) final  String? path;
@override@JsonKey() final  String host;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? version;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? name;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? os;
@override@JsonKey(fromJson: _summaryFromJson) final  Summary? summary;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? machineId;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? claudeSessionId;
 final  List<String>? _tools;
@override@JsonKey(fromJson: _asApiStringListNullable) List<String>? get tools {
  final value = _tools;
  if (value == null) return null;
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String>? _slashCommands;
@override@JsonKey(fromJson: _asApiStringListNullable) List<String>? get slashCommands {
  final value = _slashCommands;
  if (value == null) return null;
  if (_slashCommands is EqualUnmodifiableListView) return _slashCommands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(fromJson: _asApiStringNullable) final  String? homeDir;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? happyHomeDir;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? hostPid;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? flavor;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? lifecycleState;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? lifecycleStateError;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? lifecycleStateSince;
// sandbox field is stored as {enabled: bool} but we keep bool? in model
@override@JsonKey(name: 'sandbox', fromJson: _sandboxEnabledFromJson, toJson: _sandboxEnabledToJson) final  bool? sandboxEnabled;

/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MetadataCopyWith<_Metadata> get copyWith => __$MetadataCopyWithImpl<_Metadata>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MetadataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Metadata&&(identical(other.path, path) || other.path == path)&&(identical(other.host, host) || other.host == host)&&(identical(other.version, version) || other.version == version)&&(identical(other.name, name) || other.name == name)&&(identical(other.os, os) || other.os == os)&&(identical(other.summary, summary) || other.summary == summary)&&(identical(other.machineId, machineId) || other.machineId == machineId)&&(identical(other.claudeSessionId, claudeSessionId) || other.claudeSessionId == claudeSessionId)&&const DeepCollectionEquality().equals(other._tools, _tools)&&const DeepCollectionEquality().equals(other._slashCommands, _slashCommands)&&(identical(other.homeDir, homeDir) || other.homeDir == homeDir)&&(identical(other.happyHomeDir, happyHomeDir) || other.happyHomeDir == happyHomeDir)&&(identical(other.hostPid, hostPid) || other.hostPid == hostPid)&&(identical(other.flavor, flavor) || other.flavor == flavor)&&(identical(other.lifecycleState, lifecycleState) || other.lifecycleState == lifecycleState)&&(identical(other.lifecycleStateError, lifecycleStateError) || other.lifecycleStateError == lifecycleStateError)&&(identical(other.lifecycleStateSince, lifecycleStateSince) || other.lifecycleStateSince == lifecycleStateSince)&&(identical(other.sandboxEnabled, sandboxEnabled) || other.sandboxEnabled == sandboxEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,path,host,version,name,os,summary,machineId,claudeSessionId,const DeepCollectionEquality().hash(_tools),const DeepCollectionEquality().hash(_slashCommands),homeDir,happyHomeDir,hostPid,flavor,lifecycleState,lifecycleStateError,lifecycleStateSince,sandboxEnabled);

@override
String toString() {
  return 'Metadata(path: $path, host: $host, version: $version, name: $name, os: $os, summary: $summary, machineId: $machineId, claudeSessionId: $claudeSessionId, tools: $tools, slashCommands: $slashCommands, homeDir: $homeDir, happyHomeDir: $happyHomeDir, hostPid: $hostPid, flavor: $flavor, lifecycleState: $lifecycleState, lifecycleStateError: $lifecycleStateError, lifecycleStateSince: $lifecycleStateSince, sandboxEnabled: $sandboxEnabled)';
}


}

/// @nodoc
abstract mixin class _$MetadataCopyWith<$Res> implements $MetadataCopyWith<$Res> {
  factory _$MetadataCopyWith(_Metadata value, $Res Function(_Metadata) _then) = __$MetadataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _asApiStringNullable) String? path, String host,@JsonKey(fromJson: _asApiStringNullable) String? version,@JsonKey(fromJson: _asApiStringNullable) String? name,@JsonKey(fromJson: _asApiStringNullable) String? os,@JsonKey(fromJson: _summaryFromJson) Summary? summary,@JsonKey(fromJson: _asApiStringNullable) String? machineId,@JsonKey(fromJson: _asApiStringNullable) String? claudeSessionId,@JsonKey(fromJson: _asApiStringListNullable) List<String>? tools,@JsonKey(fromJson: _asApiStringListNullable) List<String>? slashCommands,@JsonKey(fromJson: _asApiStringNullable) String? homeDir,@JsonKey(fromJson: _asApiStringNullable) String? happyHomeDir,@JsonKey(fromJson: _asApiIntNullable) int? hostPid,@JsonKey(fromJson: _asApiStringNullable) String? flavor,@JsonKey(fromJson: _asApiStringNullable) String? lifecycleState,@JsonKey(fromJson: _asApiStringNullable) String? lifecycleStateError,@JsonKey(fromJson: _asApiIntNullable) int? lifecycleStateSince,@JsonKey(name: 'sandbox', fromJson: _sandboxEnabledFromJson, toJson: _sandboxEnabledToJson) bool? sandboxEnabled
});


@override $SummaryCopyWith<$Res>? get summary;

}
/// @nodoc
class __$MetadataCopyWithImpl<$Res>
    implements _$MetadataCopyWith<$Res> {
  __$MetadataCopyWithImpl(this._self, this._then);

  final _Metadata _self;
  final $Res Function(_Metadata) _then;

/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = freezed,Object? host = null,Object? version = freezed,Object? name = freezed,Object? os = freezed,Object? summary = freezed,Object? machineId = freezed,Object? claudeSessionId = freezed,Object? tools = freezed,Object? slashCommands = freezed,Object? homeDir = freezed,Object? happyHomeDir = freezed,Object? hostPid = freezed,Object? flavor = freezed,Object? lifecycleState = freezed,Object? lifecycleStateError = freezed,Object? lifecycleStateSince = freezed,Object? sandboxEnabled = freezed,}) {
  return _then(_Metadata(
path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,version: freezed == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,os: freezed == os ? _self.os : os // ignore: cast_nullable_to_non_nullable
as String?,summary: freezed == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as Summary?,machineId: freezed == machineId ? _self.machineId : machineId // ignore: cast_nullable_to_non_nullable
as String?,claudeSessionId: freezed == claudeSessionId ? _self.claudeSessionId : claudeSessionId // ignore: cast_nullable_to_non_nullable
as String?,tools: freezed == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<String>?,slashCommands: freezed == slashCommands ? _self._slashCommands : slashCommands // ignore: cast_nullable_to_non_nullable
as List<String>?,homeDir: freezed == homeDir ? _self.homeDir : homeDir // ignore: cast_nullable_to_non_nullable
as String?,happyHomeDir: freezed == happyHomeDir ? _self.happyHomeDir : happyHomeDir // ignore: cast_nullable_to_non_nullable
as String?,hostPid: freezed == hostPid ? _self.hostPid : hostPid // ignore: cast_nullable_to_non_nullable
as int?,flavor: freezed == flavor ? _self.flavor : flavor // ignore: cast_nullable_to_non_nullable
as String?,lifecycleState: freezed == lifecycleState ? _self.lifecycleState : lifecycleState // ignore: cast_nullable_to_non_nullable
as String?,lifecycleStateError: freezed == lifecycleStateError ? _self.lifecycleStateError : lifecycleStateError // ignore: cast_nullable_to_non_nullable
as String?,lifecycleStateSince: freezed == lifecycleStateSince ? _self.lifecycleStateSince : lifecycleStateSince // ignore: cast_nullable_to_non_nullable
as int?,sandboxEnabled: freezed == sandboxEnabled ? _self.sandboxEnabled : sandboxEnabled // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of Metadata
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SummaryCopyWith<$Res>? get summary {
    if (_self.summary == null) {
    return null;
  }

  return $SummaryCopyWith<$Res>(_self.summary!, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}


/// @nodoc
mixin _$Summary {

 String get text;@JsonKey(fromJson: _asApiInt) int get updatedAt;
/// Create a copy of Summary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SummaryCopyWith<Summary> get copyWith => _$SummaryCopyWithImpl<Summary>(this as Summary, _$identity);

  /// Serializes this Summary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Summary&&(identical(other.text, text) || other.text == text)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,updatedAt);

@override
String toString() {
  return 'Summary(text: $text, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SummaryCopyWith<$Res>  {
  factory $SummaryCopyWith(Summary value, $Res Function(Summary) _then) = _$SummaryCopyWithImpl;
@useResult
$Res call({
 String text,@JsonKey(fromJson: _asApiInt) int updatedAt
});




}
/// @nodoc
class _$SummaryCopyWithImpl<$Res>
    implements $SummaryCopyWith<$Res> {
  _$SummaryCopyWithImpl(this._self, this._then);

  final Summary _self;
  final $Res Function(Summary) _then;

/// Create a copy of Summary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Summary].
extension SummaryPatterns on Summary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Summary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Summary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Summary value)  $default,){
final _that = this;
switch (_that) {
case _Summary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Summary value)?  $default,){
final _that = this;
switch (_that) {
case _Summary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text, @JsonKey(fromJson: _asApiInt)  int updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Summary() when $default != null:
return $default(_that.text,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text, @JsonKey(fromJson: _asApiInt)  int updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Summary():
return $default(_that.text,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text, @JsonKey(fromJson: _asApiInt)  int updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Summary() when $default != null:
return $default(_that.text,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Summary implements Summary {
  const _Summary({required this.text, @JsonKey(fromJson: _asApiInt) required this.updatedAt});
  factory _Summary.fromJson(Map<String, dynamic> json) => _$SummaryFromJson(json);

@override final  String text;
@override@JsonKey(fromJson: _asApiInt) final  int updatedAt;

/// Create a copy of Summary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SummaryCopyWith<_Summary> get copyWith => __$SummaryCopyWithImpl<_Summary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Summary&&(identical(other.text, text) || other.text == text)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,text,updatedAt);

@override
String toString() {
  return 'Summary(text: $text, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SummaryCopyWith<$Res> implements $SummaryCopyWith<$Res> {
  factory _$SummaryCopyWith(_Summary value, $Res Function(_Summary) _then) = __$SummaryCopyWithImpl;
@override @useResult
$Res call({
 String text,@JsonKey(fromJson: _asApiInt) int updatedAt
});




}
/// @nodoc
class __$SummaryCopyWithImpl<$Res>
    implements _$SummaryCopyWith<$Res> {
  __$SummaryCopyWithImpl(this._self, this._then);

  final _Summary _self;
  final $Res Function(_Summary) _then;

/// Create a copy of Summary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? updatedAt = null,}) {
  return _then(_Summary(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$RequestInfo {

 String get tool;@JsonKey(includeFromJson: true, includeToJson: true) dynamic get arguments;@JsonKey(fromJson: _asApiIntNullable) int? get createdAt;
/// Create a copy of RequestInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RequestInfoCopyWith<RequestInfo> get copyWith => _$RequestInfoCopyWithImpl<RequestInfo>(this as RequestInfo, _$identity);

  /// Serializes this RequestInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RequestInfo&&(identical(other.tool, tool) || other.tool == tool)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tool,const DeepCollectionEquality().hash(arguments),createdAt);

@override
String toString() {
  return 'RequestInfo(tool: $tool, arguments: $arguments, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RequestInfoCopyWith<$Res>  {
  factory $RequestInfoCopyWith(RequestInfo value, $Res Function(RequestInfo) _then) = _$RequestInfoCopyWithImpl;
@useResult
$Res call({
 String tool,@JsonKey(includeFromJson: true, includeToJson: true) dynamic arguments,@JsonKey(fromJson: _asApiIntNullable) int? createdAt
});




}
/// @nodoc
class _$RequestInfoCopyWithImpl<$Res>
    implements $RequestInfoCopyWith<$Res> {
  _$RequestInfoCopyWithImpl(this._self, this._then);

  final RequestInfo _self;
  final $Res Function(RequestInfo) _then;

/// Create a copy of RequestInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tool = null,Object? arguments = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as dynamic,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RequestInfo].
extension RequestInfoPatterns on RequestInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RequestInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RequestInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RequestInfo value)  $default,){
final _that = this;
switch (_that) {
case _RequestInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RequestInfo value)?  $default,){
final _that = this;
switch (_that) {
case _RequestInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tool, @JsonKey(includeFromJson: true, includeToJson: true)  dynamic arguments, @JsonKey(fromJson: _asApiIntNullable)  int? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RequestInfo() when $default != null:
return $default(_that.tool,_that.arguments,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tool, @JsonKey(includeFromJson: true, includeToJson: true)  dynamic arguments, @JsonKey(fromJson: _asApiIntNullable)  int? createdAt)  $default,) {final _that = this;
switch (_that) {
case _RequestInfo():
return $default(_that.tool,_that.arguments,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tool, @JsonKey(includeFromJson: true, includeToJson: true)  dynamic arguments, @JsonKey(fromJson: _asApiIntNullable)  int? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _RequestInfo() when $default != null:
return $default(_that.tool,_that.arguments,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RequestInfo implements RequestInfo {
  const _RequestInfo({required this.tool, @JsonKey(includeFromJson: true, includeToJson: true) this.arguments, @JsonKey(fromJson: _asApiIntNullable) this.createdAt});
  factory _RequestInfo.fromJson(Map<String, dynamic> json) => _$RequestInfoFromJson(json);

@override final  String tool;
@override@JsonKey(includeFromJson: true, includeToJson: true) final  dynamic arguments;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? createdAt;

/// Create a copy of RequestInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestInfoCopyWith<_RequestInfo> get copyWith => __$RequestInfoCopyWithImpl<_RequestInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RequestInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestInfo&&(identical(other.tool, tool) || other.tool == tool)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tool,const DeepCollectionEquality().hash(arguments),createdAt);

@override
String toString() {
  return 'RequestInfo(tool: $tool, arguments: $arguments, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RequestInfoCopyWith<$Res> implements $RequestInfoCopyWith<$Res> {
  factory _$RequestInfoCopyWith(_RequestInfo value, $Res Function(_RequestInfo) _then) = __$RequestInfoCopyWithImpl;
@override @useResult
$Res call({
 String tool,@JsonKey(includeFromJson: true, includeToJson: true) dynamic arguments,@JsonKey(fromJson: _asApiIntNullable) int? createdAt
});




}
/// @nodoc
class __$RequestInfoCopyWithImpl<$Res>
    implements _$RequestInfoCopyWith<$Res> {
  __$RequestInfoCopyWithImpl(this._self, this._then);

  final _RequestInfo _self;
  final $Res Function(_RequestInfo) _then;

/// Create a copy of RequestInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tool = null,Object? arguments = freezed,Object? createdAt = freezed,}) {
  return _then(_RequestInfo(
tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as dynamic,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$CompletedRequestInfo {

 String get tool; String get status;@JsonKey(includeFromJson: true, includeToJson: true) dynamic get arguments;@JsonKey(fromJson: _asApiIntNullable) int? get createdAt;@JsonKey(fromJson: _asApiIntNullable) int? get completedAt;@JsonKey(fromJson: _asApiStringNullable) String? get reason;@JsonKey(fromJson: _asApiStringNullable) String? get mode;@JsonKey(fromJson: _stringListNullable) List<String>? get allowedTools;@JsonKey(fromJson: _asApiStringNullable) String? get decision;
/// Create a copy of CompletedRequestInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompletedRequestInfoCopyWith<CompletedRequestInfo> get copyWith => _$CompletedRequestInfoCopyWithImpl<CompletedRequestInfo>(this as CompletedRequestInfo, _$identity);

  /// Serializes this CompletedRequestInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompletedRequestInfo&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other.allowedTools, allowedTools)&&(identical(other.decision, decision) || other.decision == decision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tool,status,const DeepCollectionEquality().hash(arguments),createdAt,completedAt,reason,mode,const DeepCollectionEquality().hash(allowedTools),decision);

@override
String toString() {
  return 'CompletedRequestInfo(tool: $tool, status: $status, arguments: $arguments, createdAt: $createdAt, completedAt: $completedAt, reason: $reason, mode: $mode, allowedTools: $allowedTools, decision: $decision)';
}


}

/// @nodoc
abstract mixin class $CompletedRequestInfoCopyWith<$Res>  {
  factory $CompletedRequestInfoCopyWith(CompletedRequestInfo value, $Res Function(CompletedRequestInfo) _then) = _$CompletedRequestInfoCopyWithImpl;
@useResult
$Res call({
 String tool, String status,@JsonKey(includeFromJson: true, includeToJson: true) dynamic arguments,@JsonKey(fromJson: _asApiIntNullable) int? createdAt,@JsonKey(fromJson: _asApiIntNullable) int? completedAt,@JsonKey(fromJson: _asApiStringNullable) String? reason,@JsonKey(fromJson: _asApiStringNullable) String? mode,@JsonKey(fromJson: _stringListNullable) List<String>? allowedTools,@JsonKey(fromJson: _asApiStringNullable) String? decision
});




}
/// @nodoc
class _$CompletedRequestInfoCopyWithImpl<$Res>
    implements $CompletedRequestInfoCopyWith<$Res> {
  _$CompletedRequestInfoCopyWithImpl(this._self, this._then);

  final CompletedRequestInfo _self;
  final $Res Function(CompletedRequestInfo) _then;

/// Create a copy of CompletedRequestInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? tool = null,Object? status = null,Object? arguments = freezed,Object? createdAt = freezed,Object? completedAt = freezed,Object? reason = freezed,Object? mode = freezed,Object? allowedTools = freezed,Object? decision = freezed,}) {
  return _then(_self.copyWith(
tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as dynamic,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as int?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,allowedTools: freezed == allowedTools ? _self.allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>?,decision: freezed == decision ? _self.decision : decision // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CompletedRequestInfo].
extension CompletedRequestInfoPatterns on CompletedRequestInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompletedRequestInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompletedRequestInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompletedRequestInfo value)  $default,){
final _that = this;
switch (_that) {
case _CompletedRequestInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompletedRequestInfo value)?  $default,){
final _that = this;
switch (_that) {
case _CompletedRequestInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String tool,  String status, @JsonKey(includeFromJson: true, includeToJson: true)  dynamic arguments, @JsonKey(fromJson: _asApiIntNullable)  int? createdAt, @JsonKey(fromJson: _asApiIntNullable)  int? completedAt, @JsonKey(fromJson: _asApiStringNullable)  String? reason, @JsonKey(fromJson: _asApiStringNullable)  String? mode, @JsonKey(fromJson: _stringListNullable)  List<String>? allowedTools, @JsonKey(fromJson: _asApiStringNullable)  String? decision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompletedRequestInfo() when $default != null:
return $default(_that.tool,_that.status,_that.arguments,_that.createdAt,_that.completedAt,_that.reason,_that.mode,_that.allowedTools,_that.decision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String tool,  String status, @JsonKey(includeFromJson: true, includeToJson: true)  dynamic arguments, @JsonKey(fromJson: _asApiIntNullable)  int? createdAt, @JsonKey(fromJson: _asApiIntNullable)  int? completedAt, @JsonKey(fromJson: _asApiStringNullable)  String? reason, @JsonKey(fromJson: _asApiStringNullable)  String? mode, @JsonKey(fromJson: _stringListNullable)  List<String>? allowedTools, @JsonKey(fromJson: _asApiStringNullable)  String? decision)  $default,) {final _that = this;
switch (_that) {
case _CompletedRequestInfo():
return $default(_that.tool,_that.status,_that.arguments,_that.createdAt,_that.completedAt,_that.reason,_that.mode,_that.allowedTools,_that.decision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String tool,  String status, @JsonKey(includeFromJson: true, includeToJson: true)  dynamic arguments, @JsonKey(fromJson: _asApiIntNullable)  int? createdAt, @JsonKey(fromJson: _asApiIntNullable)  int? completedAt, @JsonKey(fromJson: _asApiStringNullable)  String? reason, @JsonKey(fromJson: _asApiStringNullable)  String? mode, @JsonKey(fromJson: _stringListNullable)  List<String>? allowedTools, @JsonKey(fromJson: _asApiStringNullable)  String? decision)?  $default,) {final _that = this;
switch (_that) {
case _CompletedRequestInfo() when $default != null:
return $default(_that.tool,_that.status,_that.arguments,_that.createdAt,_that.completedAt,_that.reason,_that.mode,_that.allowedTools,_that.decision);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompletedRequestInfo implements CompletedRequestInfo {
  const _CompletedRequestInfo({required this.tool, required this.status, @JsonKey(includeFromJson: true, includeToJson: true) this.arguments, @JsonKey(fromJson: _asApiIntNullable) this.createdAt, @JsonKey(fromJson: _asApiIntNullable) this.completedAt, @JsonKey(fromJson: _asApiStringNullable) this.reason, @JsonKey(fromJson: _asApiStringNullable) this.mode, @JsonKey(fromJson: _stringListNullable) final  List<String>? allowedTools, @JsonKey(fromJson: _asApiStringNullable) this.decision}): _allowedTools = allowedTools;
  factory _CompletedRequestInfo.fromJson(Map<String, dynamic> json) => _$CompletedRequestInfoFromJson(json);

@override final  String tool;
@override final  String status;
@override@JsonKey(includeFromJson: true, includeToJson: true) final  dynamic arguments;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? createdAt;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? completedAt;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? reason;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? mode;
 final  List<String>? _allowedTools;
@override@JsonKey(fromJson: _stringListNullable) List<String>? get allowedTools {
  final value = _allowedTools;
  if (value == null) return null;
  if (_allowedTools is EqualUnmodifiableListView) return _allowedTools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(fromJson: _asApiStringNullable) final  String? decision;

/// Create a copy of CompletedRequestInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompletedRequestInfoCopyWith<_CompletedRequestInfo> get copyWith => __$CompletedRequestInfoCopyWithImpl<_CompletedRequestInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompletedRequestInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompletedRequestInfo&&(identical(other.tool, tool) || other.tool == tool)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.arguments, arguments)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.mode, mode) || other.mode == mode)&&const DeepCollectionEquality().equals(other._allowedTools, _allowedTools)&&(identical(other.decision, decision) || other.decision == decision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,tool,status,const DeepCollectionEquality().hash(arguments),createdAt,completedAt,reason,mode,const DeepCollectionEquality().hash(_allowedTools),decision);

@override
String toString() {
  return 'CompletedRequestInfo(tool: $tool, status: $status, arguments: $arguments, createdAt: $createdAt, completedAt: $completedAt, reason: $reason, mode: $mode, allowedTools: $allowedTools, decision: $decision)';
}


}

/// @nodoc
abstract mixin class _$CompletedRequestInfoCopyWith<$Res> implements $CompletedRequestInfoCopyWith<$Res> {
  factory _$CompletedRequestInfoCopyWith(_CompletedRequestInfo value, $Res Function(_CompletedRequestInfo) _then) = __$CompletedRequestInfoCopyWithImpl;
@override @useResult
$Res call({
 String tool, String status,@JsonKey(includeFromJson: true, includeToJson: true) dynamic arguments,@JsonKey(fromJson: _asApiIntNullable) int? createdAt,@JsonKey(fromJson: _asApiIntNullable) int? completedAt,@JsonKey(fromJson: _asApiStringNullable) String? reason,@JsonKey(fromJson: _asApiStringNullable) String? mode,@JsonKey(fromJson: _stringListNullable) List<String>? allowedTools,@JsonKey(fromJson: _asApiStringNullable) String? decision
});




}
/// @nodoc
class __$CompletedRequestInfoCopyWithImpl<$Res>
    implements _$CompletedRequestInfoCopyWith<$Res> {
  __$CompletedRequestInfoCopyWithImpl(this._self, this._then);

  final _CompletedRequestInfo _self;
  final $Res Function(_CompletedRequestInfo) _then;

/// Create a copy of CompletedRequestInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? tool = null,Object? status = null,Object? arguments = freezed,Object? createdAt = freezed,Object? completedAt = freezed,Object? reason = freezed,Object? mode = freezed,Object? allowedTools = freezed,Object? decision = freezed,}) {
  return _then(_CompletedRequestInfo(
tool: null == tool ? _self.tool : tool // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,arguments: freezed == arguments ? _self.arguments : arguments // ignore: cast_nullable_to_non_nullable
as dynamic,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as int?,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,allowedTools: freezed == allowedTools ? _self._allowedTools : allowedTools // ignore: cast_nullable_to_non_nullable
as List<String>?,decision: freezed == decision ? _self.decision : decision // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Session {

@JsonKey(fromJson: _sessionIdFromJson) String get id;@JsonKey(fromJson: _asApiInt) int get seq;@JsonKey(fromJson: _asApiInt) int get createdAt;@JsonKey(fromJson: _asApiInt) int get updatedAt; bool get active;@JsonKey(fromJson: _asApiInt) int get activeAt;@JsonKey(fromJson: _asApiInt) int get metadataVersion;@JsonKey(fromJson: _asApiInt) int get agentStateVersion; bool get thinking; bool get archived;@JsonKey(fromJson: _metadataFromJson) Metadata? get metadata;@JsonKey(fromJson: _agentStateFromJson) AgentState? get agentState;@JsonKey(fromJson: _asApiIntNullable) int? get thinkingAt;/// Either the string `'online'` or an integer timestamp of last seen.
@JsonKey(fromJson: _presenceFromJson) String get presence;@JsonKey(fromJson: _todoListFromJson) List<TodoItem>? get todos;@JsonKey(fromJson: _asApiStringNullable) String? get draft;@JsonKey(fromJson: _asApiStringNullable) String? get permissionMode;@JsonKey(fromJson: _asApiStringNullable) String? get modelMode;@JsonKey(fromJson: _usageDataFromJson) UsageData? get latestUsage;/// Server-owned cleartext mirror of [Metadata.lifecycleState]. The
/// server flips this to `'running'` the moment it accepts a user
/// message (with a conditional UPDATE so a live daemon's write
/// always wins), so a client that has been seeing `'errored'` from
/// a stale encrypted metadata blob can clear the "Session process
/// stopped" banner immediately on first send. Empty string on older
/// servers; check [hasLifecycleError] rather than reading this
/// directly.
@JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty) String get lifecycleStateCleartext;/// The highest message seq number in the session, as reported by the
/// server. Used for lazy tail-loading to avoid fetching all history.
@JsonKey(fromJson: _asApiIntNullable) int? get lastSeq;/// `createdAt` of the most recent message, taken from the
/// server-provided `lastMessage` field on the session response.
/// Used as a fallback for inbox sorting / grouping / time display
/// when the local message cache is empty (session not yet opened).
@JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson) int? get lastMessageAt;/// Local-only: whether this session is pinned for quick access.
/// Not synced to the server.
@JsonKey(includeFromJson: false, includeToJson: false) bool get pinned;/// Local-only: the folder this session belongs to.
/// Not synced to the server.
@JsonKey(includeFromJson: false, includeToJson: false) String? get folder;
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionCopyWith<Session> get copyWith => _$SessionCopyWithImpl<Session>(this as Session, _$identity);

  /// Serializes this Session to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Session&&(identical(other.id, id) || other.id == id)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.active, active) || other.active == active)&&(identical(other.activeAt, activeAt) || other.activeAt == activeAt)&&(identical(other.metadataVersion, metadataVersion) || other.metadataVersion == metadataVersion)&&(identical(other.agentStateVersion, agentStateVersion) || other.agentStateVersion == agentStateVersion)&&(identical(other.thinking, thinking) || other.thinking == thinking)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.agentState, agentState) || other.agentState == agentState)&&(identical(other.thinkingAt, thinkingAt) || other.thinkingAt == thinkingAt)&&(identical(other.presence, presence) || other.presence == presence)&&const DeepCollectionEquality().equals(other.todos, todos)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode)&&(identical(other.modelMode, modelMode) || other.modelMode == modelMode)&&(identical(other.latestUsage, latestUsage) || other.latestUsage == latestUsage)&&(identical(other.lifecycleStateCleartext, lifecycleStateCleartext) || other.lifecycleStateCleartext == lifecycleStateCleartext)&&(identical(other.lastSeq, lastSeq) || other.lastSeq == lastSeq)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.folder, folder) || other.folder == folder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,seq,createdAt,updatedAt,active,activeAt,metadataVersion,agentStateVersion,thinking,archived,metadata,agentState,thinkingAt,presence,const DeepCollectionEquality().hash(todos),draft,permissionMode,modelMode,latestUsage,lifecycleStateCleartext,lastSeq,lastMessageAt,pinned,folder]);

@override
String toString() {
  return 'Session(id: $id, seq: $seq, createdAt: $createdAt, updatedAt: $updatedAt, active: $active, activeAt: $activeAt, metadataVersion: $metadataVersion, agentStateVersion: $agentStateVersion, thinking: $thinking, archived: $archived, metadata: $metadata, agentState: $agentState, thinkingAt: $thinkingAt, presence: $presence, todos: $todos, draft: $draft, permissionMode: $permissionMode, modelMode: $modelMode, latestUsage: $latestUsage, lifecycleStateCleartext: $lifecycleStateCleartext, lastSeq: $lastSeq, lastMessageAt: $lastMessageAt, pinned: $pinned, folder: $folder)';
}


}

/// @nodoc
abstract mixin class $SessionCopyWith<$Res>  {
  factory $SessionCopyWith(Session value, $Res Function(Session) _then) = _$SessionCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _sessionIdFromJson) String id,@JsonKey(fromJson: _asApiInt) int seq,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiInt) int updatedAt, bool active,@JsonKey(fromJson: _asApiInt) int activeAt,@JsonKey(fromJson: _asApiInt) int metadataVersion,@JsonKey(fromJson: _asApiInt) int agentStateVersion, bool thinking, bool archived,@JsonKey(fromJson: _metadataFromJson) Metadata? metadata,@JsonKey(fromJson: _agentStateFromJson) AgentState? agentState,@JsonKey(fromJson: _asApiIntNullable) int? thinkingAt,@JsonKey(fromJson: _presenceFromJson) String presence,@JsonKey(fromJson: _todoListFromJson) List<TodoItem>? todos,@JsonKey(fromJson: _asApiStringNullable) String? draft,@JsonKey(fromJson: _asApiStringNullable) String? permissionMode,@JsonKey(fromJson: _asApiStringNullable) String? modelMode,@JsonKey(fromJson: _usageDataFromJson) UsageData? latestUsage,@JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty) String lifecycleStateCleartext,@JsonKey(fromJson: _asApiIntNullable) int? lastSeq,@JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson) int? lastMessageAt,@JsonKey(includeFromJson: false, includeToJson: false) bool pinned,@JsonKey(includeFromJson: false, includeToJson: false) String? folder
});


$MetadataCopyWith<$Res>? get metadata;$UsageDataCopyWith<$Res>? get latestUsage;

}
/// @nodoc
class _$SessionCopyWithImpl<$Res>
    implements $SessionCopyWith<$Res> {
  _$SessionCopyWithImpl(this._self, this._then);

  final Session _self;
  final $Res Function(Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? seq = null,Object? createdAt = null,Object? updatedAt = null,Object? active = null,Object? activeAt = null,Object? metadataVersion = null,Object? agentStateVersion = null,Object? thinking = null,Object? archived = null,Object? metadata = freezed,Object? agentState = freezed,Object? thinkingAt = freezed,Object? presence = null,Object? todos = freezed,Object? draft = freezed,Object? permissionMode = freezed,Object? modelMode = freezed,Object? latestUsage = freezed,Object? lifecycleStateCleartext = null,Object? lastSeq = freezed,Object? lastMessageAt = freezed,Object? pinned = null,Object? folder = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,activeAt: null == activeAt ? _self.activeAt : activeAt // ignore: cast_nullable_to_non_nullable
as int,metadataVersion: null == metadataVersion ? _self.metadataVersion : metadataVersion // ignore: cast_nullable_to_non_nullable
as int,agentStateVersion: null == agentStateVersion ? _self.agentStateVersion : agentStateVersion // ignore: cast_nullable_to_non_nullable
as int,thinking: null == thinking ? _self.thinking : thinking // ignore: cast_nullable_to_non_nullable
as bool,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Metadata?,agentState: freezed == agentState ? _self.agentState : agentState // ignore: cast_nullable_to_non_nullable
as AgentState?,thinkingAt: freezed == thinkingAt ? _self.thinkingAt : thinkingAt // ignore: cast_nullable_to_non_nullable
as int?,presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as String,todos: freezed == todos ? _self.todos : todos // ignore: cast_nullable_to_non_nullable
as List<TodoItem>?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as String?,permissionMode: freezed == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as String?,modelMode: freezed == modelMode ? _self.modelMode : modelMode // ignore: cast_nullable_to_non_nullable
as String?,latestUsage: freezed == latestUsage ? _self.latestUsage : latestUsage // ignore: cast_nullable_to_non_nullable
as UsageData?,lifecycleStateCleartext: null == lifecycleStateCleartext ? _self.lifecycleStateCleartext : lifecycleStateCleartext // ignore: cast_nullable_to_non_nullable
as String,lastSeq: freezed == lastSeq ? _self.lastSeq : lastSeq // ignore: cast_nullable_to_non_nullable
as int?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as int?,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,folder: freezed == folder ? _self.folder : folder // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $MetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UsageDataCopyWith<$Res>? get latestUsage {
    if (_self.latestUsage == null) {
    return null;
  }

  return $UsageDataCopyWith<$Res>(_self.latestUsage!, (value) {
    return _then(_self.copyWith(latestUsage: value));
  });
}
}


/// Adds pattern-matching-related methods to [Session].
extension SessionPatterns on Session {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Session value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Session value)  $default,){
final _that = this;
switch (_that) {
case _Session():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Session value)?  $default,){
final _that = this;
switch (_that) {
case _Session() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _sessionIdFromJson)  String id, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  bool active, @JsonKey(fromJson: _asApiInt)  int activeAt, @JsonKey(fromJson: _asApiInt)  int metadataVersion, @JsonKey(fromJson: _asApiInt)  int agentStateVersion,  bool thinking,  bool archived, @JsonKey(fromJson: _metadataFromJson)  Metadata? metadata, @JsonKey(fromJson: _agentStateFromJson)  AgentState? agentState, @JsonKey(fromJson: _asApiIntNullable)  int? thinkingAt, @JsonKey(fromJson: _presenceFromJson)  String presence, @JsonKey(fromJson: _todoListFromJson)  List<TodoItem>? todos, @JsonKey(fromJson: _asApiStringNullable)  String? draft, @JsonKey(fromJson: _asApiStringNullable)  String? permissionMode, @JsonKey(fromJson: _asApiStringNullable)  String? modelMode, @JsonKey(fromJson: _usageDataFromJson)  UsageData? latestUsage, @JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty)  String lifecycleStateCleartext, @JsonKey(fromJson: _asApiIntNullable)  int? lastSeq, @JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson)  int? lastMessageAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool pinned, @JsonKey(includeFromJson: false, includeToJson: false)  String? folder)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.seq,_that.createdAt,_that.updatedAt,_that.active,_that.activeAt,_that.metadataVersion,_that.agentStateVersion,_that.thinking,_that.archived,_that.metadata,_that.agentState,_that.thinkingAt,_that.presence,_that.todos,_that.draft,_that.permissionMode,_that.modelMode,_that.latestUsage,_that.lifecycleStateCleartext,_that.lastSeq,_that.lastMessageAt,_that.pinned,_that.folder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _sessionIdFromJson)  String id, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  bool active, @JsonKey(fromJson: _asApiInt)  int activeAt, @JsonKey(fromJson: _asApiInt)  int metadataVersion, @JsonKey(fromJson: _asApiInt)  int agentStateVersion,  bool thinking,  bool archived, @JsonKey(fromJson: _metadataFromJson)  Metadata? metadata, @JsonKey(fromJson: _agentStateFromJson)  AgentState? agentState, @JsonKey(fromJson: _asApiIntNullable)  int? thinkingAt, @JsonKey(fromJson: _presenceFromJson)  String presence, @JsonKey(fromJson: _todoListFromJson)  List<TodoItem>? todos, @JsonKey(fromJson: _asApiStringNullable)  String? draft, @JsonKey(fromJson: _asApiStringNullable)  String? permissionMode, @JsonKey(fromJson: _asApiStringNullable)  String? modelMode, @JsonKey(fromJson: _usageDataFromJson)  UsageData? latestUsage, @JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty)  String lifecycleStateCleartext, @JsonKey(fromJson: _asApiIntNullable)  int? lastSeq, @JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson)  int? lastMessageAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool pinned, @JsonKey(includeFromJson: false, includeToJson: false)  String? folder)  $default,) {final _that = this;
switch (_that) {
case _Session():
return $default(_that.id,_that.seq,_that.createdAt,_that.updatedAt,_that.active,_that.activeAt,_that.metadataVersion,_that.agentStateVersion,_that.thinking,_that.archived,_that.metadata,_that.agentState,_that.thinkingAt,_that.presence,_that.todos,_that.draft,_that.permissionMode,_that.modelMode,_that.latestUsage,_that.lifecycleStateCleartext,_that.lastSeq,_that.lastMessageAt,_that.pinned,_that.folder);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _sessionIdFromJson)  String id, @JsonKey(fromJson: _asApiInt)  int seq, @JsonKey(fromJson: _asApiInt)  int createdAt, @JsonKey(fromJson: _asApiInt)  int updatedAt,  bool active, @JsonKey(fromJson: _asApiInt)  int activeAt, @JsonKey(fromJson: _asApiInt)  int metadataVersion, @JsonKey(fromJson: _asApiInt)  int agentStateVersion,  bool thinking,  bool archived, @JsonKey(fromJson: _metadataFromJson)  Metadata? metadata, @JsonKey(fromJson: _agentStateFromJson)  AgentState? agentState, @JsonKey(fromJson: _asApiIntNullable)  int? thinkingAt, @JsonKey(fromJson: _presenceFromJson)  String presence, @JsonKey(fromJson: _todoListFromJson)  List<TodoItem>? todos, @JsonKey(fromJson: _asApiStringNullable)  String? draft, @JsonKey(fromJson: _asApiStringNullable)  String? permissionMode, @JsonKey(fromJson: _asApiStringNullable)  String? modelMode, @JsonKey(fromJson: _usageDataFromJson)  UsageData? latestUsage, @JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty)  String lifecycleStateCleartext, @JsonKey(fromJson: _asApiIntNullable)  int? lastSeq, @JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson)  int? lastMessageAt, @JsonKey(includeFromJson: false, includeToJson: false)  bool pinned, @JsonKey(includeFromJson: false, includeToJson: false)  String? folder)?  $default,) {final _that = this;
switch (_that) {
case _Session() when $default != null:
return $default(_that.id,_that.seq,_that.createdAt,_that.updatedAt,_that.active,_that.activeAt,_that.metadataVersion,_that.agentStateVersion,_that.thinking,_that.archived,_that.metadata,_that.agentState,_that.thinkingAt,_that.presence,_that.todos,_that.draft,_that.permissionMode,_that.modelMode,_that.latestUsage,_that.lifecycleStateCleartext,_that.lastSeq,_that.lastMessageAt,_that.pinned,_that.folder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Session extends Session {
  const _Session({@JsonKey(fromJson: _sessionIdFromJson) required this.id, @JsonKey(fromJson: _asApiInt) required this.seq, @JsonKey(fromJson: _asApiInt) required this.createdAt, @JsonKey(fromJson: _asApiInt) required this.updatedAt, required this.active, @JsonKey(fromJson: _asApiInt) required this.activeAt, @JsonKey(fromJson: _asApiInt) required this.metadataVersion, @JsonKey(fromJson: _asApiInt) required this.agentStateVersion, required this.thinking, this.archived = false, @JsonKey(fromJson: _metadataFromJson) this.metadata, @JsonKey(fromJson: _agentStateFromJson) this.agentState, @JsonKey(fromJson: _asApiIntNullable) this.thinkingAt, @JsonKey(fromJson: _presenceFromJson) this.presence = 'offline', @JsonKey(fromJson: _todoListFromJson) final  List<TodoItem>? todos, @JsonKey(fromJson: _asApiStringNullable) this.draft, @JsonKey(fromJson: _asApiStringNullable) this.permissionMode, @JsonKey(fromJson: _asApiStringNullable) this.modelMode, @JsonKey(fromJson: _usageDataFromJson) this.latestUsage, @JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty) this.lifecycleStateCleartext = '', @JsonKey(fromJson: _asApiIntNullable) this.lastSeq, @JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson) this.lastMessageAt, @JsonKey(includeFromJson: false, includeToJson: false) this.pinned = false, @JsonKey(includeFromJson: false, includeToJson: false) this.folder}): _todos = todos,super._();
  factory _Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);

@override@JsonKey(fromJson: _sessionIdFromJson) final  String id;
@override@JsonKey(fromJson: _asApiInt) final  int seq;
@override@JsonKey(fromJson: _asApiInt) final  int createdAt;
@override@JsonKey(fromJson: _asApiInt) final  int updatedAt;
@override final  bool active;
@override@JsonKey(fromJson: _asApiInt) final  int activeAt;
@override@JsonKey(fromJson: _asApiInt) final  int metadataVersion;
@override@JsonKey(fromJson: _asApiInt) final  int agentStateVersion;
@override final  bool thinking;
@override@JsonKey() final  bool archived;
@override@JsonKey(fromJson: _metadataFromJson) final  Metadata? metadata;
@override@JsonKey(fromJson: _agentStateFromJson) final  AgentState? agentState;
@override@JsonKey(fromJson: _asApiIntNullable) final  int? thinkingAt;
/// Either the string `'online'` or an integer timestamp of last seen.
@override@JsonKey(fromJson: _presenceFromJson) final  String presence;
 final  List<TodoItem>? _todos;
@override@JsonKey(fromJson: _todoListFromJson) List<TodoItem>? get todos {
  final value = _todos;
  if (value == null) return null;
  if (_todos is EqualUnmodifiableListView) return _todos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(fromJson: _asApiStringNullable) final  String? draft;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? permissionMode;
@override@JsonKey(fromJson: _asApiStringNullable) final  String? modelMode;
@override@JsonKey(fromJson: _usageDataFromJson) final  UsageData? latestUsage;
/// Server-owned cleartext mirror of [Metadata.lifecycleState]. The
/// server flips this to `'running'` the moment it accepts a user
/// message (with a conditional UPDATE so a live daemon's write
/// always wins), so a client that has been seeing `'errored'` from
/// a stale encrypted metadata blob can clear the "Session process
/// stopped" banner immediately on first send. Empty string on older
/// servers; check [hasLifecycleError] rather than reading this
/// directly.
@override@JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty) final  String lifecycleStateCleartext;
/// The highest message seq number in the session, as reported by the
/// server. Used for lazy tail-loading to avoid fetching all history.
@override@JsonKey(fromJson: _asApiIntNullable) final  int? lastSeq;
/// `createdAt` of the most recent message, taken from the
/// server-provided `lastMessage` field on the session response.
/// Used as a fallback for inbox sorting / grouping / time display
/// when the local message cache is empty (session not yet opened).
@override@JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson) final  int? lastMessageAt;
/// Local-only: whether this session is pinned for quick access.
/// Not synced to the server.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  bool pinned;
/// Local-only: the folder this session belongs to.
/// Not synced to the server.
@override@JsonKey(includeFromJson: false, includeToJson: false) final  String? folder;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionCopyWith<_Session> get copyWith => __$SessionCopyWithImpl<_Session>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Session&&(identical(other.id, id) || other.id == id)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.active, active) || other.active == active)&&(identical(other.activeAt, activeAt) || other.activeAt == activeAt)&&(identical(other.metadataVersion, metadataVersion) || other.metadataVersion == metadataVersion)&&(identical(other.agentStateVersion, agentStateVersion) || other.agentStateVersion == agentStateVersion)&&(identical(other.thinking, thinking) || other.thinking == thinking)&&(identical(other.archived, archived) || other.archived == archived)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.agentState, agentState) || other.agentState == agentState)&&(identical(other.thinkingAt, thinkingAt) || other.thinkingAt == thinkingAt)&&(identical(other.presence, presence) || other.presence == presence)&&const DeepCollectionEquality().equals(other._todos, _todos)&&(identical(other.draft, draft) || other.draft == draft)&&(identical(other.permissionMode, permissionMode) || other.permissionMode == permissionMode)&&(identical(other.modelMode, modelMode) || other.modelMode == modelMode)&&(identical(other.latestUsage, latestUsage) || other.latestUsage == latestUsage)&&(identical(other.lifecycleStateCleartext, lifecycleStateCleartext) || other.lifecycleStateCleartext == lifecycleStateCleartext)&&(identical(other.lastSeq, lastSeq) || other.lastSeq == lastSeq)&&(identical(other.lastMessageAt, lastMessageAt) || other.lastMessageAt == lastMessageAt)&&(identical(other.pinned, pinned) || other.pinned == pinned)&&(identical(other.folder, folder) || other.folder == folder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,seq,createdAt,updatedAt,active,activeAt,metadataVersion,agentStateVersion,thinking,archived,metadata,agentState,thinkingAt,presence,const DeepCollectionEquality().hash(_todos),draft,permissionMode,modelMode,latestUsage,lifecycleStateCleartext,lastSeq,lastMessageAt,pinned,folder]);

@override
String toString() {
  return 'Session(id: $id, seq: $seq, createdAt: $createdAt, updatedAt: $updatedAt, active: $active, activeAt: $activeAt, metadataVersion: $metadataVersion, agentStateVersion: $agentStateVersion, thinking: $thinking, archived: $archived, metadata: $metadata, agentState: $agentState, thinkingAt: $thinkingAt, presence: $presence, todos: $todos, draft: $draft, permissionMode: $permissionMode, modelMode: $modelMode, latestUsage: $latestUsage, lifecycleStateCleartext: $lifecycleStateCleartext, lastSeq: $lastSeq, lastMessageAt: $lastMessageAt, pinned: $pinned, folder: $folder)';
}


}

/// @nodoc
abstract mixin class _$SessionCopyWith<$Res> implements $SessionCopyWith<$Res> {
  factory _$SessionCopyWith(_Session value, $Res Function(_Session) _then) = __$SessionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _sessionIdFromJson) String id,@JsonKey(fromJson: _asApiInt) int seq,@JsonKey(fromJson: _asApiInt) int createdAt,@JsonKey(fromJson: _asApiInt) int updatedAt, bool active,@JsonKey(fromJson: _asApiInt) int activeAt,@JsonKey(fromJson: _asApiInt) int metadataVersion,@JsonKey(fromJson: _asApiInt) int agentStateVersion, bool thinking, bool archived,@JsonKey(fromJson: _metadataFromJson) Metadata? metadata,@JsonKey(fromJson: _agentStateFromJson) AgentState? agentState,@JsonKey(fromJson: _asApiIntNullable) int? thinkingAt,@JsonKey(fromJson: _presenceFromJson) String presence,@JsonKey(fromJson: _todoListFromJson) List<TodoItem>? todos,@JsonKey(fromJson: _asApiStringNullable) String? draft,@JsonKey(fromJson: _asApiStringNullable) String? permissionMode,@JsonKey(fromJson: _asApiStringNullable) String? modelMode,@JsonKey(fromJson: _usageDataFromJson) UsageData? latestUsage,@JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty) String lifecycleStateCleartext,@JsonKey(fromJson: _asApiIntNullable) int? lastSeq,@JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson) int? lastMessageAt,@JsonKey(includeFromJson: false, includeToJson: false) bool pinned,@JsonKey(includeFromJson: false, includeToJson: false) String? folder
});


@override $MetadataCopyWith<$Res>? get metadata;@override $UsageDataCopyWith<$Res>? get latestUsage;

}
/// @nodoc
class __$SessionCopyWithImpl<$Res>
    implements _$SessionCopyWith<$Res> {
  __$SessionCopyWithImpl(this._self, this._then);

  final _Session _self;
  final $Res Function(_Session) _then;

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? seq = null,Object? createdAt = null,Object? updatedAt = null,Object? active = null,Object? activeAt = null,Object? metadataVersion = null,Object? agentStateVersion = null,Object? thinking = null,Object? archived = null,Object? metadata = freezed,Object? agentState = freezed,Object? thinkingAt = freezed,Object? presence = null,Object? todos = freezed,Object? draft = freezed,Object? permissionMode = freezed,Object? modelMode = freezed,Object? latestUsage = freezed,Object? lifecycleStateCleartext = null,Object? lastSeq = freezed,Object? lastMessageAt = freezed,Object? pinned = null,Object? folder = freezed,}) {
  return _then(_Session(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,activeAt: null == activeAt ? _self.activeAt : activeAt // ignore: cast_nullable_to_non_nullable
as int,metadataVersion: null == metadataVersion ? _self.metadataVersion : metadataVersion // ignore: cast_nullable_to_non_nullable
as int,agentStateVersion: null == agentStateVersion ? _self.agentStateVersion : agentStateVersion // ignore: cast_nullable_to_non_nullable
as int,thinking: null == thinking ? _self.thinking : thinking // ignore: cast_nullable_to_non_nullable
as bool,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Metadata?,agentState: freezed == agentState ? _self.agentState : agentState // ignore: cast_nullable_to_non_nullable
as AgentState?,thinkingAt: freezed == thinkingAt ? _self.thinkingAt : thinkingAt // ignore: cast_nullable_to_non_nullable
as int?,presence: null == presence ? _self.presence : presence // ignore: cast_nullable_to_non_nullable
as String,todos: freezed == todos ? _self._todos : todos // ignore: cast_nullable_to_non_nullable
as List<TodoItem>?,draft: freezed == draft ? _self.draft : draft // ignore: cast_nullable_to_non_nullable
as String?,permissionMode: freezed == permissionMode ? _self.permissionMode : permissionMode // ignore: cast_nullable_to_non_nullable
as String?,modelMode: freezed == modelMode ? _self.modelMode : modelMode // ignore: cast_nullable_to_non_nullable
as String?,latestUsage: freezed == latestUsage ? _self.latestUsage : latestUsage // ignore: cast_nullable_to_non_nullable
as UsageData?,lifecycleStateCleartext: null == lifecycleStateCleartext ? _self.lifecycleStateCleartext : lifecycleStateCleartext // ignore: cast_nullable_to_non_nullable
as String,lastSeq: freezed == lastSeq ? _self.lastSeq : lastSeq // ignore: cast_nullable_to_non_nullable
as int?,lastMessageAt: freezed == lastMessageAt ? _self.lastMessageAt : lastMessageAt // ignore: cast_nullable_to_non_nullable
as int?,pinned: null == pinned ? _self.pinned : pinned // ignore: cast_nullable_to_non_nullable
as bool,folder: freezed == folder ? _self.folder : folder // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $MetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}/// Create a copy of Session
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UsageDataCopyWith<$Res>? get latestUsage {
    if (_self.latestUsage == null) {
    return null;
  }

  return $UsageDataCopyWith<$Res>(_self.latestUsage!, (value) {
    return _then(_self.copyWith(latestUsage: value));
  });
}
}


/// @nodoc
mixin _$UsageData {

@JsonKey(fromJson: _asApiInt) int get inputTokens;@JsonKey(fromJson: _asApiInt) int get outputTokens;@JsonKey(fromJson: _asApiInt) int get cacheCreation;@JsonKey(fromJson: _asApiInt) int get cacheRead;@JsonKey(fromJson: _asApiInt) int get contextSize;@JsonKey(fromJson: _asApiInt) int get timestamp;
/// Create a copy of UsageData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageDataCopyWith<UsageData> get copyWith => _$UsageDataCopyWithImpl<UsageData>(this as UsageData, _$identity);

  /// Serializes this UsageData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageData&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.cacheCreation, cacheCreation) || other.cacheCreation == cacheCreation)&&(identical(other.cacheRead, cacheRead) || other.cacheRead == cacheRead)&&(identical(other.contextSize, contextSize) || other.contextSize == contextSize)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,inputTokens,outputTokens,cacheCreation,cacheRead,contextSize,timestamp);

@override
String toString() {
  return 'UsageData(inputTokens: $inputTokens, outputTokens: $outputTokens, cacheCreation: $cacheCreation, cacheRead: $cacheRead, contextSize: $contextSize, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $UsageDataCopyWith<$Res>  {
  factory $UsageDataCopyWith(UsageData value, $Res Function(UsageData) _then) = _$UsageDataCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _asApiInt) int inputTokens,@JsonKey(fromJson: _asApiInt) int outputTokens,@JsonKey(fromJson: _asApiInt) int cacheCreation,@JsonKey(fromJson: _asApiInt) int cacheRead,@JsonKey(fromJson: _asApiInt) int contextSize,@JsonKey(fromJson: _asApiInt) int timestamp
});




}
/// @nodoc
class _$UsageDataCopyWithImpl<$Res>
    implements $UsageDataCopyWith<$Res> {
  _$UsageDataCopyWithImpl(this._self, this._then);

  final UsageData _self;
  final $Res Function(UsageData) _then;

/// Create a copy of UsageData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? inputTokens = null,Object? outputTokens = null,Object? cacheCreation = null,Object? cacheRead = null,Object? contextSize = null,Object? timestamp = null,}) {
  return _then(_self.copyWith(
inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,cacheCreation: null == cacheCreation ? _self.cacheCreation : cacheCreation // ignore: cast_nullable_to_non_nullable
as int,cacheRead: null == cacheRead ? _self.cacheRead : cacheRead // ignore: cast_nullable_to_non_nullable
as int,contextSize: null == contextSize ? _self.contextSize : contextSize // ignore: cast_nullable_to_non_nullable
as int,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageData].
extension UsageDataPatterns on UsageData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageData value)  $default,){
final _that = this;
switch (_that) {
case _UsageData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageData value)?  $default,){
final _that = this;
switch (_that) {
case _UsageData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asApiInt)  int inputTokens, @JsonKey(fromJson: _asApiInt)  int outputTokens, @JsonKey(fromJson: _asApiInt)  int cacheCreation, @JsonKey(fromJson: _asApiInt)  int cacheRead, @JsonKey(fromJson: _asApiInt)  int contextSize, @JsonKey(fromJson: _asApiInt)  int timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageData() when $default != null:
return $default(_that.inputTokens,_that.outputTokens,_that.cacheCreation,_that.cacheRead,_that.contextSize,_that.timestamp);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asApiInt)  int inputTokens, @JsonKey(fromJson: _asApiInt)  int outputTokens, @JsonKey(fromJson: _asApiInt)  int cacheCreation, @JsonKey(fromJson: _asApiInt)  int cacheRead, @JsonKey(fromJson: _asApiInt)  int contextSize, @JsonKey(fromJson: _asApiInt)  int timestamp)  $default,) {final _that = this;
switch (_that) {
case _UsageData():
return $default(_that.inputTokens,_that.outputTokens,_that.cacheCreation,_that.cacheRead,_that.contextSize,_that.timestamp);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _asApiInt)  int inputTokens, @JsonKey(fromJson: _asApiInt)  int outputTokens, @JsonKey(fromJson: _asApiInt)  int cacheCreation, @JsonKey(fromJson: _asApiInt)  int cacheRead, @JsonKey(fromJson: _asApiInt)  int contextSize, @JsonKey(fromJson: _asApiInt)  int timestamp)?  $default,) {final _that = this;
switch (_that) {
case _UsageData() when $default != null:
return $default(_that.inputTokens,_that.outputTokens,_that.cacheCreation,_that.cacheRead,_that.contextSize,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UsageData implements UsageData {
  const _UsageData({@JsonKey(fromJson: _asApiInt) required this.inputTokens, @JsonKey(fromJson: _asApiInt) required this.outputTokens, @JsonKey(fromJson: _asApiInt) required this.cacheCreation, @JsonKey(fromJson: _asApiInt) required this.cacheRead, @JsonKey(fromJson: _asApiInt) required this.contextSize, @JsonKey(fromJson: _asApiInt) required this.timestamp});
  factory _UsageData.fromJson(Map<String, dynamic> json) => _$UsageDataFromJson(json);

@override@JsonKey(fromJson: _asApiInt) final  int inputTokens;
@override@JsonKey(fromJson: _asApiInt) final  int outputTokens;
@override@JsonKey(fromJson: _asApiInt) final  int cacheCreation;
@override@JsonKey(fromJson: _asApiInt) final  int cacheRead;
@override@JsonKey(fromJson: _asApiInt) final  int contextSize;
@override@JsonKey(fromJson: _asApiInt) final  int timestamp;

/// Create a copy of UsageData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageDataCopyWith<_UsageData> get copyWith => __$UsageDataCopyWithImpl<_UsageData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageData&&(identical(other.inputTokens, inputTokens) || other.inputTokens == inputTokens)&&(identical(other.outputTokens, outputTokens) || other.outputTokens == outputTokens)&&(identical(other.cacheCreation, cacheCreation) || other.cacheCreation == cacheCreation)&&(identical(other.cacheRead, cacheRead) || other.cacheRead == cacheRead)&&(identical(other.contextSize, contextSize) || other.contextSize == contextSize)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,inputTokens,outputTokens,cacheCreation,cacheRead,contextSize,timestamp);

@override
String toString() {
  return 'UsageData(inputTokens: $inputTokens, outputTokens: $outputTokens, cacheCreation: $cacheCreation, cacheRead: $cacheRead, contextSize: $contextSize, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$UsageDataCopyWith<$Res> implements $UsageDataCopyWith<$Res> {
  factory _$UsageDataCopyWith(_UsageData value, $Res Function(_UsageData) _then) = __$UsageDataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _asApiInt) int inputTokens,@JsonKey(fromJson: _asApiInt) int outputTokens,@JsonKey(fromJson: _asApiInt) int cacheCreation,@JsonKey(fromJson: _asApiInt) int cacheRead,@JsonKey(fromJson: _asApiInt) int contextSize,@JsonKey(fromJson: _asApiInt) int timestamp
});




}
/// @nodoc
class __$UsageDataCopyWithImpl<$Res>
    implements _$UsageDataCopyWith<$Res> {
  __$UsageDataCopyWithImpl(this._self, this._then);

  final _UsageData _self;
  final $Res Function(_UsageData) _then;

/// Create a copy of UsageData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? inputTokens = null,Object? outputTokens = null,Object? cacheCreation = null,Object? cacheRead = null,Object? contextSize = null,Object? timestamp = null,}) {
  return _then(_UsageData(
inputTokens: null == inputTokens ? _self.inputTokens : inputTokens // ignore: cast_nullable_to_non_nullable
as int,outputTokens: null == outputTokens ? _self.outputTokens : outputTokens // ignore: cast_nullable_to_non_nullable
as int,cacheCreation: null == cacheCreation ? _self.cacheCreation : cacheCreation // ignore: cast_nullable_to_non_nullable
as int,cacheRead: null == cacheRead ? _self.cacheRead : cacheRead // ignore: cast_nullable_to_non_nullable
as int,contextSize: null == contextSize ? _self.contextSize : contextSize // ignore: cast_nullable_to_non_nullable
as int,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
