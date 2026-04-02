// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'local_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LocalSettings {

 bool get debugMode; bool get devModeEnabled; bool get commandPaletteEnabled; String get themePreference; bool get markdownCopyV2; Map<String, String> get acknowledgedCliVersions;
/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalSettingsCopyWith<LocalSettings> get copyWith => _$LocalSettingsCopyWithImpl<LocalSettings>(this as LocalSettings, _$identity);

  /// Serializes this LocalSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalSettings&&(identical(other.debugMode, debugMode) || other.debugMode == debugMode)&&(identical(other.devModeEnabled, devModeEnabled) || other.devModeEnabled == devModeEnabled)&&(identical(other.commandPaletteEnabled, commandPaletteEnabled) || other.commandPaletteEnabled == commandPaletteEnabled)&&(identical(other.themePreference, themePreference) || other.themePreference == themePreference)&&(identical(other.markdownCopyV2, markdownCopyV2) || other.markdownCopyV2 == markdownCopyV2)&&const DeepCollectionEquality().equals(other.acknowledgedCliVersions, acknowledgedCliVersions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,debugMode,devModeEnabled,commandPaletteEnabled,themePreference,markdownCopyV2,const DeepCollectionEquality().hash(acknowledgedCliVersions));

@override
String toString() {
  return 'LocalSettings(debugMode: $debugMode, devModeEnabled: $devModeEnabled, commandPaletteEnabled: $commandPaletteEnabled, themePreference: $themePreference, markdownCopyV2: $markdownCopyV2, acknowledgedCliVersions: $acknowledgedCliVersions)';
}


}

/// @nodoc
abstract mixin class $LocalSettingsCopyWith<$Res>  {
  factory $LocalSettingsCopyWith(LocalSettings value, $Res Function(LocalSettings) _then) = _$LocalSettingsCopyWithImpl;
@useResult
$Res call({
 bool debugMode, bool devModeEnabled, bool commandPaletteEnabled, String themePreference, bool markdownCopyV2, Map<String, String> acknowledgedCliVersions
});




}
/// @nodoc
class _$LocalSettingsCopyWithImpl<$Res>
    implements $LocalSettingsCopyWith<$Res> {
  _$LocalSettingsCopyWithImpl(this._self, this._then);

  final LocalSettings _self;
  final $Res Function(LocalSettings) _then;

/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? debugMode = null,Object? devModeEnabled = null,Object? commandPaletteEnabled = null,Object? themePreference = null,Object? markdownCopyV2 = null,Object? acknowledgedCliVersions = null,}) {
  return _then(_self.copyWith(
debugMode: null == debugMode ? _self.debugMode : debugMode // ignore: cast_nullable_to_non_nullable
as bool,devModeEnabled: null == devModeEnabled ? _self.devModeEnabled : devModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,commandPaletteEnabled: null == commandPaletteEnabled ? _self.commandPaletteEnabled : commandPaletteEnabled // ignore: cast_nullable_to_non_nullable
as bool,themePreference: null == themePreference ? _self.themePreference : themePreference // ignore: cast_nullable_to_non_nullable
as String,markdownCopyV2: null == markdownCopyV2 ? _self.markdownCopyV2 : markdownCopyV2 // ignore: cast_nullable_to_non_nullable
as bool,acknowledgedCliVersions: null == acknowledgedCliVersions ? _self.acknowledgedCliVersions : acknowledgedCliVersions // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [LocalSettings].
extension LocalSettingsPatterns on LocalSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocalSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocalSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocalSettings value)  $default,){
final _that = this;
switch (_that) {
case _LocalSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocalSettings value)?  $default,){
final _that = this;
switch (_that) {
case _LocalSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool debugMode,  bool devModeEnabled,  bool commandPaletteEnabled,  String themePreference,  bool markdownCopyV2,  Map<String, String> acknowledgedCliVersions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocalSettings() when $default != null:
return $default(_that.debugMode,_that.devModeEnabled,_that.commandPaletteEnabled,_that.themePreference,_that.markdownCopyV2,_that.acknowledgedCliVersions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool debugMode,  bool devModeEnabled,  bool commandPaletteEnabled,  String themePreference,  bool markdownCopyV2,  Map<String, String> acknowledgedCliVersions)  $default,) {final _that = this;
switch (_that) {
case _LocalSettings():
return $default(_that.debugMode,_that.devModeEnabled,_that.commandPaletteEnabled,_that.themePreference,_that.markdownCopyV2,_that.acknowledgedCliVersions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool debugMode,  bool devModeEnabled,  bool commandPaletteEnabled,  String themePreference,  bool markdownCopyV2,  Map<String, String> acknowledgedCliVersions)?  $default,) {final _that = this;
switch (_that) {
case _LocalSettings() when $default != null:
return $default(_that.debugMode,_that.devModeEnabled,_that.commandPaletteEnabled,_that.themePreference,_that.markdownCopyV2,_that.acknowledgedCliVersions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LocalSettings extends LocalSettings {
  const _LocalSettings({this.debugMode = false, this.devModeEnabled = false, this.commandPaletteEnabled = false, this.themePreference = 'adaptive', this.markdownCopyV2 = false, final  Map<String, String> acknowledgedCliVersions = const <String, String>{}}): _acknowledgedCliVersions = acknowledgedCliVersions,super._();
  factory _LocalSettings.fromJson(Map<String, dynamic> json) => _$LocalSettingsFromJson(json);

@override@JsonKey() final  bool debugMode;
@override@JsonKey() final  bool devModeEnabled;
@override@JsonKey() final  bool commandPaletteEnabled;
@override@JsonKey() final  String themePreference;
@override@JsonKey() final  bool markdownCopyV2;
 final  Map<String, String> _acknowledgedCliVersions;
@override@JsonKey() Map<String, String> get acknowledgedCliVersions {
  if (_acknowledgedCliVersions is EqualUnmodifiableMapView) return _acknowledgedCliVersions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_acknowledgedCliVersions);
}


/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocalSettingsCopyWith<_LocalSettings> get copyWith => __$LocalSettingsCopyWithImpl<_LocalSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocalSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocalSettings&&(identical(other.debugMode, debugMode) || other.debugMode == debugMode)&&(identical(other.devModeEnabled, devModeEnabled) || other.devModeEnabled == devModeEnabled)&&(identical(other.commandPaletteEnabled, commandPaletteEnabled) || other.commandPaletteEnabled == commandPaletteEnabled)&&(identical(other.themePreference, themePreference) || other.themePreference == themePreference)&&(identical(other.markdownCopyV2, markdownCopyV2) || other.markdownCopyV2 == markdownCopyV2)&&const DeepCollectionEquality().equals(other._acknowledgedCliVersions, _acknowledgedCliVersions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,debugMode,devModeEnabled,commandPaletteEnabled,themePreference,markdownCopyV2,const DeepCollectionEquality().hash(_acknowledgedCliVersions));

@override
String toString() {
  return 'LocalSettings(debugMode: $debugMode, devModeEnabled: $devModeEnabled, commandPaletteEnabled: $commandPaletteEnabled, themePreference: $themePreference, markdownCopyV2: $markdownCopyV2, acknowledgedCliVersions: $acknowledgedCliVersions)';
}


}

/// @nodoc
abstract mixin class _$LocalSettingsCopyWith<$Res> implements $LocalSettingsCopyWith<$Res> {
  factory _$LocalSettingsCopyWith(_LocalSettings value, $Res Function(_LocalSettings) _then) = __$LocalSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool debugMode, bool devModeEnabled, bool commandPaletteEnabled, String themePreference, bool markdownCopyV2, Map<String, String> acknowledgedCliVersions
});




}
/// @nodoc
class __$LocalSettingsCopyWithImpl<$Res>
    implements _$LocalSettingsCopyWith<$Res> {
  __$LocalSettingsCopyWithImpl(this._self, this._then);

  final _LocalSettings _self;
  final $Res Function(_LocalSettings) _then;

/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? debugMode = null,Object? devModeEnabled = null,Object? commandPaletteEnabled = null,Object? themePreference = null,Object? markdownCopyV2 = null,Object? acknowledgedCliVersions = null,}) {
  return _then(_LocalSettings(
debugMode: null == debugMode ? _self.debugMode : debugMode // ignore: cast_nullable_to_non_nullable
as bool,devModeEnabled: null == devModeEnabled ? _self.devModeEnabled : devModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,commandPaletteEnabled: null == commandPaletteEnabled ? _self.commandPaletteEnabled : commandPaletteEnabled // ignore: cast_nullable_to_non_nullable
as bool,themePreference: null == themePreference ? _self.themePreference : themePreference // ignore: cast_nullable_to_non_nullable
as String,markdownCopyV2: null == markdownCopyV2 ? _self.markdownCopyV2 : markdownCopyV2 // ignore: cast_nullable_to_non_nullable
as bool,acknowledgedCliVersions: null == acknowledgedCliVersions ? _self._acknowledgedCliVersions : acknowledgedCliVersions // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
