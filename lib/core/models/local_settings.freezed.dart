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
mixin _$AutoArchiveSettings {

/// Archive sessions older than N days. Null = disabled.
 int? get autoArchiveAfterDays;/// Archive sessions with no messages for the configured idle duration.
///
/// Positive values are legacy day-based values. Negative values encode
/// minute-based durations, e.g. -120 means 2 hours. Null = disabled.
 int? get autoArchiveIdleAfterDays;/// Whether to archive sessions when the app closes.
 bool get autoArchiveOnAppClose;
/// Create a copy of AutoArchiveSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AutoArchiveSettingsCopyWith<AutoArchiveSettings> get copyWith => _$AutoArchiveSettingsCopyWithImpl<AutoArchiveSettings>(this as AutoArchiveSettings, _$identity);

  /// Serializes this AutoArchiveSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AutoArchiveSettings&&(identical(other.autoArchiveAfterDays, autoArchiveAfterDays) || other.autoArchiveAfterDays == autoArchiveAfterDays)&&(identical(other.autoArchiveIdleAfterDays, autoArchiveIdleAfterDays) || other.autoArchiveIdleAfterDays == autoArchiveIdleAfterDays)&&(identical(other.autoArchiveOnAppClose, autoArchiveOnAppClose) || other.autoArchiveOnAppClose == autoArchiveOnAppClose));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,autoArchiveAfterDays,autoArchiveIdleAfterDays,autoArchiveOnAppClose);

@override
String toString() {
  return 'AutoArchiveSettings(autoArchiveAfterDays: $autoArchiveAfterDays, autoArchiveIdleAfterDays: $autoArchiveIdleAfterDays, autoArchiveOnAppClose: $autoArchiveOnAppClose)';
}


}

/// @nodoc
abstract mixin class $AutoArchiveSettingsCopyWith<$Res>  {
  factory $AutoArchiveSettingsCopyWith(AutoArchiveSettings value, $Res Function(AutoArchiveSettings) _then) = _$AutoArchiveSettingsCopyWithImpl;
@useResult
$Res call({
 int? autoArchiveAfterDays, int? autoArchiveIdleAfterDays, bool autoArchiveOnAppClose
});




}
/// @nodoc
class _$AutoArchiveSettingsCopyWithImpl<$Res>
    implements $AutoArchiveSettingsCopyWith<$Res> {
  _$AutoArchiveSettingsCopyWithImpl(this._self, this._then);

  final AutoArchiveSettings _self;
  final $Res Function(AutoArchiveSettings) _then;

/// Create a copy of AutoArchiveSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? autoArchiveAfterDays = freezed,Object? autoArchiveIdleAfterDays = freezed,Object? autoArchiveOnAppClose = null,}) {
  return _then(_self.copyWith(
autoArchiveAfterDays: freezed == autoArchiveAfterDays ? _self.autoArchiveAfterDays : autoArchiveAfterDays // ignore: cast_nullable_to_non_nullable
as int?,autoArchiveIdleAfterDays: freezed == autoArchiveIdleAfterDays ? _self.autoArchiveIdleAfterDays : autoArchiveIdleAfterDays // ignore: cast_nullable_to_non_nullable
as int?,autoArchiveOnAppClose: null == autoArchiveOnAppClose ? _self.autoArchiveOnAppClose : autoArchiveOnAppClose // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AutoArchiveSettings].
extension AutoArchiveSettingsPatterns on AutoArchiveSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AutoArchiveSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AutoArchiveSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AutoArchiveSettings value)  $default,){
final _that = this;
switch (_that) {
case _AutoArchiveSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AutoArchiveSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AutoArchiveSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? autoArchiveAfterDays,  int? autoArchiveIdleAfterDays,  bool autoArchiveOnAppClose)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AutoArchiveSettings() when $default != null:
return $default(_that.autoArchiveAfterDays,_that.autoArchiveIdleAfterDays,_that.autoArchiveOnAppClose);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? autoArchiveAfterDays,  int? autoArchiveIdleAfterDays,  bool autoArchiveOnAppClose)  $default,) {final _that = this;
switch (_that) {
case _AutoArchiveSettings():
return $default(_that.autoArchiveAfterDays,_that.autoArchiveIdleAfterDays,_that.autoArchiveOnAppClose);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? autoArchiveAfterDays,  int? autoArchiveIdleAfterDays,  bool autoArchiveOnAppClose)?  $default,) {final _that = this;
switch (_that) {
case _AutoArchiveSettings() when $default != null:
return $default(_that.autoArchiveAfterDays,_that.autoArchiveIdleAfterDays,_that.autoArchiveOnAppClose);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AutoArchiveSettings implements AutoArchiveSettings {
  const _AutoArchiveSettings({this.autoArchiveAfterDays, this.autoArchiveIdleAfterDays, this.autoArchiveOnAppClose = false});
  factory _AutoArchiveSettings.fromJson(Map<String, dynamic> json) => _$AutoArchiveSettingsFromJson(json);

/// Archive sessions older than N days. Null = disabled.
@override final  int? autoArchiveAfterDays;
/// Archive sessions with no messages for the configured idle duration.
///
/// Positive values are legacy day-based values. Negative values encode
/// minute-based durations, e.g. -120 means 2 hours. Null = disabled.
@override final  int? autoArchiveIdleAfterDays;
/// Whether to archive sessions when the app closes.
@override@JsonKey() final  bool autoArchiveOnAppClose;

/// Create a copy of AutoArchiveSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AutoArchiveSettingsCopyWith<_AutoArchiveSettings> get copyWith => __$AutoArchiveSettingsCopyWithImpl<_AutoArchiveSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AutoArchiveSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AutoArchiveSettings&&(identical(other.autoArchiveAfterDays, autoArchiveAfterDays) || other.autoArchiveAfterDays == autoArchiveAfterDays)&&(identical(other.autoArchiveIdleAfterDays, autoArchiveIdleAfterDays) || other.autoArchiveIdleAfterDays == autoArchiveIdleAfterDays)&&(identical(other.autoArchiveOnAppClose, autoArchiveOnAppClose) || other.autoArchiveOnAppClose == autoArchiveOnAppClose));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,autoArchiveAfterDays,autoArchiveIdleAfterDays,autoArchiveOnAppClose);

@override
String toString() {
  return 'AutoArchiveSettings(autoArchiveAfterDays: $autoArchiveAfterDays, autoArchiveIdleAfterDays: $autoArchiveIdleAfterDays, autoArchiveOnAppClose: $autoArchiveOnAppClose)';
}


}

/// @nodoc
abstract mixin class _$AutoArchiveSettingsCopyWith<$Res> implements $AutoArchiveSettingsCopyWith<$Res> {
  factory _$AutoArchiveSettingsCopyWith(_AutoArchiveSettings value, $Res Function(_AutoArchiveSettings) _then) = __$AutoArchiveSettingsCopyWithImpl;
@override @useResult
$Res call({
 int? autoArchiveAfterDays, int? autoArchiveIdleAfterDays, bool autoArchiveOnAppClose
});




}
/// @nodoc
class __$AutoArchiveSettingsCopyWithImpl<$Res>
    implements _$AutoArchiveSettingsCopyWith<$Res> {
  __$AutoArchiveSettingsCopyWithImpl(this._self, this._then);

  final _AutoArchiveSettings _self;
  final $Res Function(_AutoArchiveSettings) _then;

/// Create a copy of AutoArchiveSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? autoArchiveAfterDays = freezed,Object? autoArchiveIdleAfterDays = freezed,Object? autoArchiveOnAppClose = null,}) {
  return _then(_AutoArchiveSettings(
autoArchiveAfterDays: freezed == autoArchiveAfterDays ? _self.autoArchiveAfterDays : autoArchiveAfterDays // ignore: cast_nullable_to_non_nullable
as int?,autoArchiveIdleAfterDays: freezed == autoArchiveIdleAfterDays ? _self.autoArchiveIdleAfterDays : autoArchiveIdleAfterDays // ignore: cast_nullable_to_non_nullable
as int?,autoArchiveOnAppClose: null == autoArchiveOnAppClose ? _self.autoArchiveOnAppClose : autoArchiveOnAppClose // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$LocalSettings {

 bool get debugMode; bool get devModeEnabled; bool get commandPaletteEnabled; String get themePreference; bool get markdownCopyV2; Map<String, String> get acknowledgedCliVersions; AutoArchiveSettings? get autoArchiveSettings;
/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalSettingsCopyWith<LocalSettings> get copyWith => _$LocalSettingsCopyWithImpl<LocalSettings>(this as LocalSettings, _$identity);

  /// Serializes this LocalSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalSettings&&(identical(other.debugMode, debugMode) || other.debugMode == debugMode)&&(identical(other.devModeEnabled, devModeEnabled) || other.devModeEnabled == devModeEnabled)&&(identical(other.commandPaletteEnabled, commandPaletteEnabled) || other.commandPaletteEnabled == commandPaletteEnabled)&&(identical(other.themePreference, themePreference) || other.themePreference == themePreference)&&(identical(other.markdownCopyV2, markdownCopyV2) || other.markdownCopyV2 == markdownCopyV2)&&const DeepCollectionEquality().equals(other.acknowledgedCliVersions, acknowledgedCliVersions)&&(identical(other.autoArchiveSettings, autoArchiveSettings) || other.autoArchiveSettings == autoArchiveSettings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,debugMode,devModeEnabled,commandPaletteEnabled,themePreference,markdownCopyV2,const DeepCollectionEquality().hash(acknowledgedCliVersions),autoArchiveSettings);

@override
String toString() {
  return 'LocalSettings(debugMode: $debugMode, devModeEnabled: $devModeEnabled, commandPaletteEnabled: $commandPaletteEnabled, themePreference: $themePreference, markdownCopyV2: $markdownCopyV2, acknowledgedCliVersions: $acknowledgedCliVersions, autoArchiveSettings: $autoArchiveSettings)';
}


}

/// @nodoc
abstract mixin class $LocalSettingsCopyWith<$Res>  {
  factory $LocalSettingsCopyWith(LocalSettings value, $Res Function(LocalSettings) _then) = _$LocalSettingsCopyWithImpl;
@useResult
$Res call({
 bool debugMode, bool devModeEnabled, bool commandPaletteEnabled, String themePreference, bool markdownCopyV2, Map<String, String> acknowledgedCliVersions, AutoArchiveSettings? autoArchiveSettings
});


$AutoArchiveSettingsCopyWith<$Res>? get autoArchiveSettings;

}
/// @nodoc
class _$LocalSettingsCopyWithImpl<$Res>
    implements $LocalSettingsCopyWith<$Res> {
  _$LocalSettingsCopyWithImpl(this._self, this._then);

  final LocalSettings _self;
  final $Res Function(LocalSettings) _then;

/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? debugMode = null,Object? devModeEnabled = null,Object? commandPaletteEnabled = null,Object? themePreference = null,Object? markdownCopyV2 = null,Object? acknowledgedCliVersions = null,Object? autoArchiveSettings = freezed,}) {
  return _then(_self.copyWith(
debugMode: null == debugMode ? _self.debugMode : debugMode // ignore: cast_nullable_to_non_nullable
as bool,devModeEnabled: null == devModeEnabled ? _self.devModeEnabled : devModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,commandPaletteEnabled: null == commandPaletteEnabled ? _self.commandPaletteEnabled : commandPaletteEnabled // ignore: cast_nullable_to_non_nullable
as bool,themePreference: null == themePreference ? _self.themePreference : themePreference // ignore: cast_nullable_to_non_nullable
as String,markdownCopyV2: null == markdownCopyV2 ? _self.markdownCopyV2 : markdownCopyV2 // ignore: cast_nullable_to_non_nullable
as bool,acknowledgedCliVersions: null == acknowledgedCliVersions ? _self.acknowledgedCliVersions : acknowledgedCliVersions // ignore: cast_nullable_to_non_nullable
as Map<String, String>,autoArchiveSettings: freezed == autoArchiveSettings ? _self.autoArchiveSettings : autoArchiveSettings // ignore: cast_nullable_to_non_nullable
as AutoArchiveSettings?,
  ));
}
/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AutoArchiveSettingsCopyWith<$Res>? get autoArchiveSettings {
    if (_self.autoArchiveSettings == null) {
    return null;
  }

  return $AutoArchiveSettingsCopyWith<$Res>(_self.autoArchiveSettings!, (value) {
    return _then(_self.copyWith(autoArchiveSettings: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool debugMode,  bool devModeEnabled,  bool commandPaletteEnabled,  String themePreference,  bool markdownCopyV2,  Map<String, String> acknowledgedCliVersions,  AutoArchiveSettings? autoArchiveSettings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocalSettings() when $default != null:
return $default(_that.debugMode,_that.devModeEnabled,_that.commandPaletteEnabled,_that.themePreference,_that.markdownCopyV2,_that.acknowledgedCliVersions,_that.autoArchiveSettings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool debugMode,  bool devModeEnabled,  bool commandPaletteEnabled,  String themePreference,  bool markdownCopyV2,  Map<String, String> acknowledgedCliVersions,  AutoArchiveSettings? autoArchiveSettings)  $default,) {final _that = this;
switch (_that) {
case _LocalSettings():
return $default(_that.debugMode,_that.devModeEnabled,_that.commandPaletteEnabled,_that.themePreference,_that.markdownCopyV2,_that.acknowledgedCliVersions,_that.autoArchiveSettings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool debugMode,  bool devModeEnabled,  bool commandPaletteEnabled,  String themePreference,  bool markdownCopyV2,  Map<String, String> acknowledgedCliVersions,  AutoArchiveSettings? autoArchiveSettings)?  $default,) {final _that = this;
switch (_that) {
case _LocalSettings() when $default != null:
return $default(_that.debugMode,_that.devModeEnabled,_that.commandPaletteEnabled,_that.themePreference,_that.markdownCopyV2,_that.acknowledgedCliVersions,_that.autoArchiveSettings);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LocalSettings extends LocalSettings {
  const _LocalSettings({this.debugMode = false, this.devModeEnabled = false, this.commandPaletteEnabled = false, this.themePreference = 'adaptive', this.markdownCopyV2 = false, final  Map<String, String> acknowledgedCliVersions = const <String, String>{}, this.autoArchiveSettings}): _acknowledgedCliVersions = acknowledgedCliVersions,super._();
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

@override final  AutoArchiveSettings? autoArchiveSettings;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocalSettings&&(identical(other.debugMode, debugMode) || other.debugMode == debugMode)&&(identical(other.devModeEnabled, devModeEnabled) || other.devModeEnabled == devModeEnabled)&&(identical(other.commandPaletteEnabled, commandPaletteEnabled) || other.commandPaletteEnabled == commandPaletteEnabled)&&(identical(other.themePreference, themePreference) || other.themePreference == themePreference)&&(identical(other.markdownCopyV2, markdownCopyV2) || other.markdownCopyV2 == markdownCopyV2)&&const DeepCollectionEquality().equals(other._acknowledgedCliVersions, _acknowledgedCliVersions)&&(identical(other.autoArchiveSettings, autoArchiveSettings) || other.autoArchiveSettings == autoArchiveSettings));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,debugMode,devModeEnabled,commandPaletteEnabled,themePreference,markdownCopyV2,const DeepCollectionEquality().hash(_acknowledgedCliVersions),autoArchiveSettings);

@override
String toString() {
  return 'LocalSettings(debugMode: $debugMode, devModeEnabled: $devModeEnabled, commandPaletteEnabled: $commandPaletteEnabled, themePreference: $themePreference, markdownCopyV2: $markdownCopyV2, acknowledgedCliVersions: $acknowledgedCliVersions, autoArchiveSettings: $autoArchiveSettings)';
}


}

/// @nodoc
abstract mixin class _$LocalSettingsCopyWith<$Res> implements $LocalSettingsCopyWith<$Res> {
  factory _$LocalSettingsCopyWith(_LocalSettings value, $Res Function(_LocalSettings) _then) = __$LocalSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool debugMode, bool devModeEnabled, bool commandPaletteEnabled, String themePreference, bool markdownCopyV2, Map<String, String> acknowledgedCliVersions, AutoArchiveSettings? autoArchiveSettings
});


@override $AutoArchiveSettingsCopyWith<$Res>? get autoArchiveSettings;

}
/// @nodoc
class __$LocalSettingsCopyWithImpl<$Res>
    implements _$LocalSettingsCopyWith<$Res> {
  __$LocalSettingsCopyWithImpl(this._self, this._then);

  final _LocalSettings _self;
  final $Res Function(_LocalSettings) _then;

/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? debugMode = null,Object? devModeEnabled = null,Object? commandPaletteEnabled = null,Object? themePreference = null,Object? markdownCopyV2 = null,Object? acknowledgedCliVersions = null,Object? autoArchiveSettings = freezed,}) {
  return _then(_LocalSettings(
debugMode: null == debugMode ? _self.debugMode : debugMode // ignore: cast_nullable_to_non_nullable
as bool,devModeEnabled: null == devModeEnabled ? _self.devModeEnabled : devModeEnabled // ignore: cast_nullable_to_non_nullable
as bool,commandPaletteEnabled: null == commandPaletteEnabled ? _self.commandPaletteEnabled : commandPaletteEnabled // ignore: cast_nullable_to_non_nullable
as bool,themePreference: null == themePreference ? _self.themePreference : themePreference // ignore: cast_nullable_to_non_nullable
as String,markdownCopyV2: null == markdownCopyV2 ? _self.markdownCopyV2 : markdownCopyV2 // ignore: cast_nullable_to_non_nullable
as bool,acknowledgedCliVersions: null == acknowledgedCliVersions ? _self._acknowledgedCliVersions : acknowledgedCliVersions // ignore: cast_nullable_to_non_nullable
as Map<String, String>,autoArchiveSettings: freezed == autoArchiveSettings ? _self.autoArchiveSettings : autoArchiveSettings // ignore: cast_nullable_to_non_nullable
as AutoArchiveSettings?,
  ));
}

/// Create a copy of LocalSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AutoArchiveSettingsCopyWith<$Res>? get autoArchiveSettings {
    if (_self.autoArchiveSettings == null) {
    return null;
  }

  return $AutoArchiveSettingsCopyWith<$Res>(_self.autoArchiveSettings!, (value) {
    return _then(_self.copyWith(autoArchiveSettings: value));
  });
}
}

// dart format on
