// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_usage_limits.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeUsageWindow {

@JsonKey(fromJson: _utilizationFromJson) double get utilization;@JsonKey(name: 'resets_at') String? get resetsAt;
/// Create a copy of ClaudeUsageWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<ClaudeUsageWindow> get copyWith => _$ClaudeUsageWindowCopyWithImpl<ClaudeUsageWindow>(this as ClaudeUsageWindow, _$identity);

  /// Serializes this ClaudeUsageWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeUsageWindow&&(identical(other.utilization, utilization) || other.utilization == utilization)&&(identical(other.resetsAt, resetsAt) || other.resetsAt == resetsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,utilization,resetsAt);

@override
String toString() {
  return 'ClaudeUsageWindow(utilization: $utilization, resetsAt: $resetsAt)';
}


}

/// @nodoc
abstract mixin class $ClaudeUsageWindowCopyWith<$Res>  {
  factory $ClaudeUsageWindowCopyWith(ClaudeUsageWindow value, $Res Function(ClaudeUsageWindow) _then) = _$ClaudeUsageWindowCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _utilizationFromJson) double utilization,@JsonKey(name: 'resets_at') String? resetsAt
});




}
/// @nodoc
class _$ClaudeUsageWindowCopyWithImpl<$Res>
    implements $ClaudeUsageWindowCopyWith<$Res> {
  _$ClaudeUsageWindowCopyWithImpl(this._self, this._then);

  final ClaudeUsageWindow _self;
  final $Res Function(ClaudeUsageWindow) _then;

/// Create a copy of ClaudeUsageWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? utilization = null,Object? resetsAt = freezed,}) {
  return _then(_self.copyWith(
utilization: null == utilization ? _self.utilization : utilization // ignore: cast_nullable_to_non_nullable
as double,resetsAt: freezed == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClaudeUsageWindow].
extension ClaudeUsageWindowPatterns on ClaudeUsageWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClaudeUsageWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClaudeUsageWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClaudeUsageWindow value)  $default,){
final _that = this;
switch (_that) {
case _ClaudeUsageWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClaudeUsageWindow value)?  $default,){
final _that = this;
switch (_that) {
case _ClaudeUsageWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _utilizationFromJson)  double utilization, @JsonKey(name: 'resets_at')  String? resetsAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClaudeUsageWindow() when $default != null:
return $default(_that.utilization,_that.resetsAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _utilizationFromJson)  double utilization, @JsonKey(name: 'resets_at')  String? resetsAt)  $default,) {final _that = this;
switch (_that) {
case _ClaudeUsageWindow():
return $default(_that.utilization,_that.resetsAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _utilizationFromJson)  double utilization, @JsonKey(name: 'resets_at')  String? resetsAt)?  $default,) {final _that = this;
switch (_that) {
case _ClaudeUsageWindow() when $default != null:
return $default(_that.utilization,_that.resetsAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClaudeUsageWindow extends ClaudeUsageWindow {
  const _ClaudeUsageWindow({@JsonKey(fromJson: _utilizationFromJson) this.utilization = 0.0, @JsonKey(name: 'resets_at') this.resetsAt}): super._();
  factory _ClaudeUsageWindow.fromJson(Map<String, dynamic> json) => _$ClaudeUsageWindowFromJson(json);

@override@JsonKey(fromJson: _utilizationFromJson) final  double utilization;
@override@JsonKey(name: 'resets_at') final  String? resetsAt;

/// Create a copy of ClaudeUsageWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeUsageWindowCopyWith<_ClaudeUsageWindow> get copyWith => __$ClaudeUsageWindowCopyWithImpl<_ClaudeUsageWindow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaudeUsageWindowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeUsageWindow&&(identical(other.utilization, utilization) || other.utilization == utilization)&&(identical(other.resetsAt, resetsAt) || other.resetsAt == resetsAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,utilization,resetsAt);

@override
String toString() {
  return 'ClaudeUsageWindow(utilization: $utilization, resetsAt: $resetsAt)';
}


}

/// @nodoc
abstract mixin class _$ClaudeUsageWindowCopyWith<$Res> implements $ClaudeUsageWindowCopyWith<$Res> {
  factory _$ClaudeUsageWindowCopyWith(_ClaudeUsageWindow value, $Res Function(_ClaudeUsageWindow) _then) = __$ClaudeUsageWindowCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _utilizationFromJson) double utilization,@JsonKey(name: 'resets_at') String? resetsAt
});




}
/// @nodoc
class __$ClaudeUsageWindowCopyWithImpl<$Res>
    implements _$ClaudeUsageWindowCopyWith<$Res> {
  __$ClaudeUsageWindowCopyWithImpl(this._self, this._then);

  final _ClaudeUsageWindow _self;
  final $Res Function(_ClaudeUsageWindow) _then;

/// Create a copy of ClaudeUsageWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? utilization = null,Object? resetsAt = freezed,}) {
  return _then(_ClaudeUsageWindow(
utilization: null == utilization ? _self.utilization : utilization // ignore: cast_nullable_to_non_nullable
as double,resetsAt: freezed == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ClaudeExtraUsage {

@JsonKey(name: 'is_enabled') bool get isEnabled;@JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson) double? get monthlyLimit;@JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson) double? get usedCredits;@JsonKey(fromJson: _optionalDoubleFromJson) double? get utilization;
/// Create a copy of ClaudeExtraUsage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeExtraUsageCopyWith<ClaudeExtraUsage> get copyWith => _$ClaudeExtraUsageCopyWithImpl<ClaudeExtraUsage>(this as ClaudeExtraUsage, _$identity);

  /// Serializes this ClaudeExtraUsage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeExtraUsage&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.monthlyLimit, monthlyLimit) || other.monthlyLimit == monthlyLimit)&&(identical(other.usedCredits, usedCredits) || other.usedCredits == usedCredits)&&(identical(other.utilization, utilization) || other.utilization == utilization));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isEnabled,monthlyLimit,usedCredits,utilization);

@override
String toString() {
  return 'ClaudeExtraUsage(isEnabled: $isEnabled, monthlyLimit: $monthlyLimit, usedCredits: $usedCredits, utilization: $utilization)';
}


}

/// @nodoc
abstract mixin class $ClaudeExtraUsageCopyWith<$Res>  {
  factory $ClaudeExtraUsageCopyWith(ClaudeExtraUsage value, $Res Function(ClaudeExtraUsage) _then) = _$ClaudeExtraUsageCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'is_enabled') bool isEnabled,@JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson) double? monthlyLimit,@JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson) double? usedCredits,@JsonKey(fromJson: _optionalDoubleFromJson) double? utilization
});




}
/// @nodoc
class _$ClaudeExtraUsageCopyWithImpl<$Res>
    implements $ClaudeExtraUsageCopyWith<$Res> {
  _$ClaudeExtraUsageCopyWithImpl(this._self, this._then);

  final ClaudeExtraUsage _self;
  final $Res Function(ClaudeExtraUsage) _then;

/// Create a copy of ClaudeExtraUsage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isEnabled = null,Object? monthlyLimit = freezed,Object? usedCredits = freezed,Object? utilization = freezed,}) {
  return _then(_self.copyWith(
isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,monthlyLimit: freezed == monthlyLimit ? _self.monthlyLimit : monthlyLimit // ignore: cast_nullable_to_non_nullable
as double?,usedCredits: freezed == usedCredits ? _self.usedCredits : usedCredits // ignore: cast_nullable_to_non_nullable
as double?,utilization: freezed == utilization ? _self.utilization : utilization // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClaudeExtraUsage].
extension ClaudeExtraUsagePatterns on ClaudeExtraUsage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClaudeExtraUsage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClaudeExtraUsage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClaudeExtraUsage value)  $default,){
final _that = this;
switch (_that) {
case _ClaudeExtraUsage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClaudeExtraUsage value)?  $default,){
final _that = this;
switch (_that) {
case _ClaudeExtraUsage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_enabled')  bool isEnabled, @JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson)  double? monthlyLimit, @JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson)  double? usedCredits, @JsonKey(fromJson: _optionalDoubleFromJson)  double? utilization)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClaudeExtraUsage() when $default != null:
return $default(_that.isEnabled,_that.monthlyLimit,_that.usedCredits,_that.utilization);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'is_enabled')  bool isEnabled, @JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson)  double? monthlyLimit, @JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson)  double? usedCredits, @JsonKey(fromJson: _optionalDoubleFromJson)  double? utilization)  $default,) {final _that = this;
switch (_that) {
case _ClaudeExtraUsage():
return $default(_that.isEnabled,_that.monthlyLimit,_that.usedCredits,_that.utilization);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'is_enabled')  bool isEnabled, @JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson)  double? monthlyLimit, @JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson)  double? usedCredits, @JsonKey(fromJson: _optionalDoubleFromJson)  double? utilization)?  $default,) {final _that = this;
switch (_that) {
case _ClaudeExtraUsage() when $default != null:
return $default(_that.isEnabled,_that.monthlyLimit,_that.usedCredits,_that.utilization);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClaudeExtraUsage implements ClaudeExtraUsage {
  const _ClaudeExtraUsage({@JsonKey(name: 'is_enabled') this.isEnabled = false, @JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson) this.monthlyLimit, @JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson) this.usedCredits, @JsonKey(fromJson: _optionalDoubleFromJson) this.utilization});
  factory _ClaudeExtraUsage.fromJson(Map<String, dynamic> json) => _$ClaudeExtraUsageFromJson(json);

@override@JsonKey(name: 'is_enabled') final  bool isEnabled;
@override@JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson) final  double? monthlyLimit;
@override@JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson) final  double? usedCredits;
@override@JsonKey(fromJson: _optionalDoubleFromJson) final  double? utilization;

/// Create a copy of ClaudeExtraUsage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeExtraUsageCopyWith<_ClaudeExtraUsage> get copyWith => __$ClaudeExtraUsageCopyWithImpl<_ClaudeExtraUsage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaudeExtraUsageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeExtraUsage&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&(identical(other.monthlyLimit, monthlyLimit) || other.monthlyLimit == monthlyLimit)&&(identical(other.usedCredits, usedCredits) || other.usedCredits == usedCredits)&&(identical(other.utilization, utilization) || other.utilization == utilization));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,isEnabled,monthlyLimit,usedCredits,utilization);

@override
String toString() {
  return 'ClaudeExtraUsage(isEnabled: $isEnabled, monthlyLimit: $monthlyLimit, usedCredits: $usedCredits, utilization: $utilization)';
}


}

/// @nodoc
abstract mixin class _$ClaudeExtraUsageCopyWith<$Res> implements $ClaudeExtraUsageCopyWith<$Res> {
  factory _$ClaudeExtraUsageCopyWith(_ClaudeExtraUsage value, $Res Function(_ClaudeExtraUsage) _then) = __$ClaudeExtraUsageCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'is_enabled') bool isEnabled,@JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson) double? monthlyLimit,@JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson) double? usedCredits,@JsonKey(fromJson: _optionalDoubleFromJson) double? utilization
});




}
/// @nodoc
class __$ClaudeExtraUsageCopyWithImpl<$Res>
    implements _$ClaudeExtraUsageCopyWith<$Res> {
  __$ClaudeExtraUsageCopyWithImpl(this._self, this._then);

  final _ClaudeExtraUsage _self;
  final $Res Function(_ClaudeExtraUsage) _then;

/// Create a copy of ClaudeExtraUsage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isEnabled = null,Object? monthlyLimit = freezed,Object? usedCredits = freezed,Object? utilization = freezed,}) {
  return _then(_ClaudeExtraUsage(
isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,monthlyLimit: freezed == monthlyLimit ? _self.monthlyLimit : monthlyLimit // ignore: cast_nullable_to_non_nullable
as double?,usedCredits: freezed == usedCredits ? _self.usedCredits : usedCredits // ignore: cast_nullable_to_non_nullable
as double?,utilization: freezed == utilization ? _self.utilization : utilization // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$ClaudeUsageLimit {

 String get group;@JsonKey(fromJson: _utilizationFromJson) double get percent;@JsonKey(name: 'resets_at') String? get resetsAt;@JsonKey(name: 'scope', fromJson: _scopeModelDisplayName) String? get modelDisplayName;
/// Create a copy of ClaudeUsageLimit
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeUsageLimitCopyWith<ClaudeUsageLimit> get copyWith => _$ClaudeUsageLimitCopyWithImpl<ClaudeUsageLimit>(this as ClaudeUsageLimit, _$identity);

  /// Serializes this ClaudeUsageLimit to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeUsageLimit&&(identical(other.group, group) || other.group == group)&&(identical(other.percent, percent) || other.percent == percent)&&(identical(other.resetsAt, resetsAt) || other.resetsAt == resetsAt)&&(identical(other.modelDisplayName, modelDisplayName) || other.modelDisplayName == modelDisplayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,group,percent,resetsAt,modelDisplayName);

@override
String toString() {
  return 'ClaudeUsageLimit(group: $group, percent: $percent, resetsAt: $resetsAt, modelDisplayName: $modelDisplayName)';
}


}

/// @nodoc
abstract mixin class $ClaudeUsageLimitCopyWith<$Res>  {
  factory $ClaudeUsageLimitCopyWith(ClaudeUsageLimit value, $Res Function(ClaudeUsageLimit) _then) = _$ClaudeUsageLimitCopyWithImpl;
@useResult
$Res call({
 String group,@JsonKey(fromJson: _utilizationFromJson) double percent,@JsonKey(name: 'resets_at') String? resetsAt,@JsonKey(name: 'scope', fromJson: _scopeModelDisplayName) String? modelDisplayName
});




}
/// @nodoc
class _$ClaudeUsageLimitCopyWithImpl<$Res>
    implements $ClaudeUsageLimitCopyWith<$Res> {
  _$ClaudeUsageLimitCopyWithImpl(this._self, this._then);

  final ClaudeUsageLimit _self;
  final $Res Function(ClaudeUsageLimit) _then;

/// Create a copy of ClaudeUsageLimit
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? group = null,Object? percent = null,Object? resetsAt = freezed,Object? modelDisplayName = freezed,}) {
  return _then(_self.copyWith(
group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double,resetsAt: freezed == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as String?,modelDisplayName: freezed == modelDisplayName ? _self.modelDisplayName : modelDisplayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClaudeUsageLimit].
extension ClaudeUsageLimitPatterns on ClaudeUsageLimit {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClaudeUsageLimit value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClaudeUsageLimit() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClaudeUsageLimit value)  $default,){
final _that = this;
switch (_that) {
case _ClaudeUsageLimit():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClaudeUsageLimit value)?  $default,){
final _that = this;
switch (_that) {
case _ClaudeUsageLimit() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String group, @JsonKey(fromJson: _utilizationFromJson)  double percent, @JsonKey(name: 'resets_at')  String? resetsAt, @JsonKey(name: 'scope', fromJson: _scopeModelDisplayName)  String? modelDisplayName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClaudeUsageLimit() when $default != null:
return $default(_that.group,_that.percent,_that.resetsAt,_that.modelDisplayName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String group, @JsonKey(fromJson: _utilizationFromJson)  double percent, @JsonKey(name: 'resets_at')  String? resetsAt, @JsonKey(name: 'scope', fromJson: _scopeModelDisplayName)  String? modelDisplayName)  $default,) {final _that = this;
switch (_that) {
case _ClaudeUsageLimit():
return $default(_that.group,_that.percent,_that.resetsAt,_that.modelDisplayName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String group, @JsonKey(fromJson: _utilizationFromJson)  double percent, @JsonKey(name: 'resets_at')  String? resetsAt, @JsonKey(name: 'scope', fromJson: _scopeModelDisplayName)  String? modelDisplayName)?  $default,) {final _that = this;
switch (_that) {
case _ClaudeUsageLimit() when $default != null:
return $default(_that.group,_that.percent,_that.resetsAt,_that.modelDisplayName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClaudeUsageLimit extends ClaudeUsageLimit {
  const _ClaudeUsageLimit({this.group = '', @JsonKey(fromJson: _utilizationFromJson) this.percent = 0.0, @JsonKey(name: 'resets_at') this.resetsAt, @JsonKey(name: 'scope', fromJson: _scopeModelDisplayName) this.modelDisplayName}): super._();
  factory _ClaudeUsageLimit.fromJson(Map<String, dynamic> json) => _$ClaudeUsageLimitFromJson(json);

@override@JsonKey() final  String group;
@override@JsonKey(fromJson: _utilizationFromJson) final  double percent;
@override@JsonKey(name: 'resets_at') final  String? resetsAt;
@override@JsonKey(name: 'scope', fromJson: _scopeModelDisplayName) final  String? modelDisplayName;

/// Create a copy of ClaudeUsageLimit
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeUsageLimitCopyWith<_ClaudeUsageLimit> get copyWith => __$ClaudeUsageLimitCopyWithImpl<_ClaudeUsageLimit>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaudeUsageLimitToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeUsageLimit&&(identical(other.group, group) || other.group == group)&&(identical(other.percent, percent) || other.percent == percent)&&(identical(other.resetsAt, resetsAt) || other.resetsAt == resetsAt)&&(identical(other.modelDisplayName, modelDisplayName) || other.modelDisplayName == modelDisplayName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,group,percent,resetsAt,modelDisplayName);

@override
String toString() {
  return 'ClaudeUsageLimit(group: $group, percent: $percent, resetsAt: $resetsAt, modelDisplayName: $modelDisplayName)';
}


}

/// @nodoc
abstract mixin class _$ClaudeUsageLimitCopyWith<$Res> implements $ClaudeUsageLimitCopyWith<$Res> {
  factory _$ClaudeUsageLimitCopyWith(_ClaudeUsageLimit value, $Res Function(_ClaudeUsageLimit) _then) = __$ClaudeUsageLimitCopyWithImpl;
@override @useResult
$Res call({
 String group,@JsonKey(fromJson: _utilizationFromJson) double percent,@JsonKey(name: 'resets_at') String? resetsAt,@JsonKey(name: 'scope', fromJson: _scopeModelDisplayName) String? modelDisplayName
});




}
/// @nodoc
class __$ClaudeUsageLimitCopyWithImpl<$Res>
    implements _$ClaudeUsageLimitCopyWith<$Res> {
  __$ClaudeUsageLimitCopyWithImpl(this._self, this._then);

  final _ClaudeUsageLimit _self;
  final $Res Function(_ClaudeUsageLimit) _then;

/// Create a copy of ClaudeUsageLimit
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? group = null,Object? percent = null,Object? resetsAt = freezed,Object? modelDisplayName = freezed,}) {
  return _then(_ClaudeUsageLimit(
group: null == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String,percent: null == percent ? _self.percent : percent // ignore: cast_nullable_to_non_nullable
as double,resetsAt: freezed == resetsAt ? _self.resetsAt : resetsAt // ignore: cast_nullable_to_non_nullable
as String?,modelDisplayName: freezed == modelDisplayName ? _self.modelDisplayName : modelDisplayName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ClaudeUsageLimits {

@JsonKey(name: 'five_hour', fromJson: _windowOrNull) ClaudeUsageWindow? get fiveHour;@JsonKey(name: 'seven_day', fromJson: _windowOrNull) ClaudeUsageWindow? get sevenDay;@JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull) ClaudeUsageWindow? get sevenDaySonnet;@JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull) ClaudeUsageWindow? get sevenDayOpus;@JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull) ClaudeUsageWindow? get sevenDayOauthApps;@JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull) ClaudeUsageWindow? get sevenDayCowork;@JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull) ClaudeUsageWindow? get iguanaNecktie;@JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson) ClaudeExtraUsage? get extraUsage;@JsonKey(fromJson: _limitsFromJson) List<ClaudeUsageLimit> get limits;
/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeUsageLimitsCopyWith<ClaudeUsageLimits> get copyWith => _$ClaudeUsageLimitsCopyWithImpl<ClaudeUsageLimits>(this as ClaudeUsageLimits, _$identity);

  /// Serializes this ClaudeUsageLimits to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeUsageLimits&&(identical(other.fiveHour, fiveHour) || other.fiveHour == fiveHour)&&(identical(other.sevenDay, sevenDay) || other.sevenDay == sevenDay)&&(identical(other.sevenDaySonnet, sevenDaySonnet) || other.sevenDaySonnet == sevenDaySonnet)&&(identical(other.sevenDayOpus, sevenDayOpus) || other.sevenDayOpus == sevenDayOpus)&&(identical(other.sevenDayOauthApps, sevenDayOauthApps) || other.sevenDayOauthApps == sevenDayOauthApps)&&(identical(other.sevenDayCowork, sevenDayCowork) || other.sevenDayCowork == sevenDayCowork)&&(identical(other.iguanaNecktie, iguanaNecktie) || other.iguanaNecktie == iguanaNecktie)&&(identical(other.extraUsage, extraUsage) || other.extraUsage == extraUsage)&&const DeepCollectionEquality().equals(other.limits, limits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fiveHour,sevenDay,sevenDaySonnet,sevenDayOpus,sevenDayOauthApps,sevenDayCowork,iguanaNecktie,extraUsage,const DeepCollectionEquality().hash(limits));

@override
String toString() {
  return 'ClaudeUsageLimits(fiveHour: $fiveHour, sevenDay: $sevenDay, sevenDaySonnet: $sevenDaySonnet, sevenDayOpus: $sevenDayOpus, sevenDayOauthApps: $sevenDayOauthApps, sevenDayCowork: $sevenDayCowork, iguanaNecktie: $iguanaNecktie, extraUsage: $extraUsage, limits: $limits)';
}


}

/// @nodoc
abstract mixin class $ClaudeUsageLimitsCopyWith<$Res>  {
  factory $ClaudeUsageLimitsCopyWith(ClaudeUsageLimits value, $Res Function(ClaudeUsageLimits) _then) = _$ClaudeUsageLimitsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'five_hour', fromJson: _windowOrNull) ClaudeUsageWindow? fiveHour,@JsonKey(name: 'seven_day', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDay,@JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDaySonnet,@JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDayOpus,@JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDayOauthApps,@JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDayCowork,@JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull) ClaudeUsageWindow? iguanaNecktie,@JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson) ClaudeExtraUsage? extraUsage,@JsonKey(fromJson: _limitsFromJson) List<ClaudeUsageLimit> limits
});


$ClaudeUsageWindowCopyWith<$Res>? get fiveHour;$ClaudeUsageWindowCopyWith<$Res>? get sevenDay;$ClaudeUsageWindowCopyWith<$Res>? get sevenDaySonnet;$ClaudeUsageWindowCopyWith<$Res>? get sevenDayOpus;$ClaudeUsageWindowCopyWith<$Res>? get sevenDayOauthApps;$ClaudeUsageWindowCopyWith<$Res>? get sevenDayCowork;$ClaudeUsageWindowCopyWith<$Res>? get iguanaNecktie;$ClaudeExtraUsageCopyWith<$Res>? get extraUsage;

}
/// @nodoc
class _$ClaudeUsageLimitsCopyWithImpl<$Res>
    implements $ClaudeUsageLimitsCopyWith<$Res> {
  _$ClaudeUsageLimitsCopyWithImpl(this._self, this._then);

  final ClaudeUsageLimits _self;
  final $Res Function(ClaudeUsageLimits) _then;

/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fiveHour = freezed,Object? sevenDay = freezed,Object? sevenDaySonnet = freezed,Object? sevenDayOpus = freezed,Object? sevenDayOauthApps = freezed,Object? sevenDayCowork = freezed,Object? iguanaNecktie = freezed,Object? extraUsage = freezed,Object? limits = null,}) {
  return _then(_self.copyWith(
fiveHour: freezed == fiveHour ? _self.fiveHour : fiveHour // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDay: freezed == sevenDay ? _self.sevenDay : sevenDay // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDaySonnet: freezed == sevenDaySonnet ? _self.sevenDaySonnet : sevenDaySonnet // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDayOpus: freezed == sevenDayOpus ? _self.sevenDayOpus : sevenDayOpus // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDayOauthApps: freezed == sevenDayOauthApps ? _self.sevenDayOauthApps : sevenDayOauthApps // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDayCowork: freezed == sevenDayCowork ? _self.sevenDayCowork : sevenDayCowork // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,iguanaNecktie: freezed == iguanaNecktie ? _self.iguanaNecktie : iguanaNecktie // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,extraUsage: freezed == extraUsage ? _self.extraUsage : extraUsage // ignore: cast_nullable_to_non_nullable
as ClaudeExtraUsage?,limits: null == limits ? _self.limits : limits // ignore: cast_nullable_to_non_nullable
as List<ClaudeUsageLimit>,
  ));
}
/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get fiveHour {
    if (_self.fiveHour == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.fiveHour!, (value) {
    return _then(_self.copyWith(fiveHour: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDay {
    if (_self.sevenDay == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDay!, (value) {
    return _then(_self.copyWith(sevenDay: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDaySonnet {
    if (_self.sevenDaySonnet == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDaySonnet!, (value) {
    return _then(_self.copyWith(sevenDaySonnet: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDayOpus {
    if (_self.sevenDayOpus == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDayOpus!, (value) {
    return _then(_self.copyWith(sevenDayOpus: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDayOauthApps {
    if (_self.sevenDayOauthApps == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDayOauthApps!, (value) {
    return _then(_self.copyWith(sevenDayOauthApps: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDayCowork {
    if (_self.sevenDayCowork == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDayCowork!, (value) {
    return _then(_self.copyWith(sevenDayCowork: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get iguanaNecktie {
    if (_self.iguanaNecktie == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.iguanaNecktie!, (value) {
    return _then(_self.copyWith(iguanaNecktie: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeExtraUsageCopyWith<$Res>? get extraUsage {
    if (_self.extraUsage == null) {
    return null;
  }

  return $ClaudeExtraUsageCopyWith<$Res>(_self.extraUsage!, (value) {
    return _then(_self.copyWith(extraUsage: value));
  });
}
}


/// Adds pattern-matching-related methods to [ClaudeUsageLimits].
extension ClaudeUsageLimitsPatterns on ClaudeUsageLimits {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClaudeUsageLimits value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClaudeUsageLimits() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClaudeUsageLimits value)  $default,){
final _that = this;
switch (_that) {
case _ClaudeUsageLimits():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClaudeUsageLimits value)?  $default,){
final _that = this;
switch (_that) {
case _ClaudeUsageLimits() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'five_hour', fromJson: _windowOrNull)  ClaudeUsageWindow? fiveHour, @JsonKey(name: 'seven_day', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDay, @JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDaySonnet, @JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayOpus, @JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayOauthApps, @JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayCowork, @JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull)  ClaudeUsageWindow? iguanaNecktie, @JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson)  ClaudeExtraUsage? extraUsage, @JsonKey(fromJson: _limitsFromJson)  List<ClaudeUsageLimit> limits)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClaudeUsageLimits() when $default != null:
return $default(_that.fiveHour,_that.sevenDay,_that.sevenDaySonnet,_that.sevenDayOpus,_that.sevenDayOauthApps,_that.sevenDayCowork,_that.iguanaNecktie,_that.extraUsage,_that.limits);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'five_hour', fromJson: _windowOrNull)  ClaudeUsageWindow? fiveHour, @JsonKey(name: 'seven_day', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDay, @JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDaySonnet, @JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayOpus, @JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayOauthApps, @JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayCowork, @JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull)  ClaudeUsageWindow? iguanaNecktie, @JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson)  ClaudeExtraUsage? extraUsage, @JsonKey(fromJson: _limitsFromJson)  List<ClaudeUsageLimit> limits)  $default,) {final _that = this;
switch (_that) {
case _ClaudeUsageLimits():
return $default(_that.fiveHour,_that.sevenDay,_that.sevenDaySonnet,_that.sevenDayOpus,_that.sevenDayOauthApps,_that.sevenDayCowork,_that.iguanaNecktie,_that.extraUsage,_that.limits);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'five_hour', fromJson: _windowOrNull)  ClaudeUsageWindow? fiveHour, @JsonKey(name: 'seven_day', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDay, @JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDaySonnet, @JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayOpus, @JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayOauthApps, @JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull)  ClaudeUsageWindow? sevenDayCowork, @JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull)  ClaudeUsageWindow? iguanaNecktie, @JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson)  ClaudeExtraUsage? extraUsage, @JsonKey(fromJson: _limitsFromJson)  List<ClaudeUsageLimit> limits)?  $default,) {final _that = this;
switch (_that) {
case _ClaudeUsageLimits() when $default != null:
return $default(_that.fiveHour,_that.sevenDay,_that.sevenDaySonnet,_that.sevenDayOpus,_that.sevenDayOauthApps,_that.sevenDayCowork,_that.iguanaNecktie,_that.extraUsage,_that.limits);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClaudeUsageLimits extends ClaudeUsageLimits {
  const _ClaudeUsageLimits({@JsonKey(name: 'five_hour', fromJson: _windowOrNull) this.fiveHour, @JsonKey(name: 'seven_day', fromJson: _windowOrNull) this.sevenDay, @JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull) this.sevenDaySonnet, @JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull) this.sevenDayOpus, @JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull) this.sevenDayOauthApps, @JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull) this.sevenDayCowork, @JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull) this.iguanaNecktie, @JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson) this.extraUsage, @JsonKey(fromJson: _limitsFromJson) final  List<ClaudeUsageLimit> limits = const <ClaudeUsageLimit>[]}): _limits = limits,super._();
  factory _ClaudeUsageLimits.fromJson(Map<String, dynamic> json) => _$ClaudeUsageLimitsFromJson(json);

@override@JsonKey(name: 'five_hour', fromJson: _windowOrNull) final  ClaudeUsageWindow? fiveHour;
@override@JsonKey(name: 'seven_day', fromJson: _windowOrNull) final  ClaudeUsageWindow? sevenDay;
@override@JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull) final  ClaudeUsageWindow? sevenDaySonnet;
@override@JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull) final  ClaudeUsageWindow? sevenDayOpus;
@override@JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull) final  ClaudeUsageWindow? sevenDayOauthApps;
@override@JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull) final  ClaudeUsageWindow? sevenDayCowork;
@override@JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull) final  ClaudeUsageWindow? iguanaNecktie;
@override@JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson) final  ClaudeExtraUsage? extraUsage;
 final  List<ClaudeUsageLimit> _limits;
@override@JsonKey(fromJson: _limitsFromJson) List<ClaudeUsageLimit> get limits {
  if (_limits is EqualUnmodifiableListView) return _limits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_limits);
}


/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeUsageLimitsCopyWith<_ClaudeUsageLimits> get copyWith => __$ClaudeUsageLimitsCopyWithImpl<_ClaudeUsageLimits>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaudeUsageLimitsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeUsageLimits&&(identical(other.fiveHour, fiveHour) || other.fiveHour == fiveHour)&&(identical(other.sevenDay, sevenDay) || other.sevenDay == sevenDay)&&(identical(other.sevenDaySonnet, sevenDaySonnet) || other.sevenDaySonnet == sevenDaySonnet)&&(identical(other.sevenDayOpus, sevenDayOpus) || other.sevenDayOpus == sevenDayOpus)&&(identical(other.sevenDayOauthApps, sevenDayOauthApps) || other.sevenDayOauthApps == sevenDayOauthApps)&&(identical(other.sevenDayCowork, sevenDayCowork) || other.sevenDayCowork == sevenDayCowork)&&(identical(other.iguanaNecktie, iguanaNecktie) || other.iguanaNecktie == iguanaNecktie)&&(identical(other.extraUsage, extraUsage) || other.extraUsage == extraUsage)&&const DeepCollectionEquality().equals(other._limits, _limits));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fiveHour,sevenDay,sevenDaySonnet,sevenDayOpus,sevenDayOauthApps,sevenDayCowork,iguanaNecktie,extraUsage,const DeepCollectionEquality().hash(_limits));

@override
String toString() {
  return 'ClaudeUsageLimits(fiveHour: $fiveHour, sevenDay: $sevenDay, sevenDaySonnet: $sevenDaySonnet, sevenDayOpus: $sevenDayOpus, sevenDayOauthApps: $sevenDayOauthApps, sevenDayCowork: $sevenDayCowork, iguanaNecktie: $iguanaNecktie, extraUsage: $extraUsage, limits: $limits)';
}


}

/// @nodoc
abstract mixin class _$ClaudeUsageLimitsCopyWith<$Res> implements $ClaudeUsageLimitsCopyWith<$Res> {
  factory _$ClaudeUsageLimitsCopyWith(_ClaudeUsageLimits value, $Res Function(_ClaudeUsageLimits) _then) = __$ClaudeUsageLimitsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'five_hour', fromJson: _windowOrNull) ClaudeUsageWindow? fiveHour,@JsonKey(name: 'seven_day', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDay,@JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDaySonnet,@JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDayOpus,@JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDayOauthApps,@JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull) ClaudeUsageWindow? sevenDayCowork,@JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull) ClaudeUsageWindow? iguanaNecktie,@JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson) ClaudeExtraUsage? extraUsage,@JsonKey(fromJson: _limitsFromJson) List<ClaudeUsageLimit> limits
});


@override $ClaudeUsageWindowCopyWith<$Res>? get fiveHour;@override $ClaudeUsageWindowCopyWith<$Res>? get sevenDay;@override $ClaudeUsageWindowCopyWith<$Res>? get sevenDaySonnet;@override $ClaudeUsageWindowCopyWith<$Res>? get sevenDayOpus;@override $ClaudeUsageWindowCopyWith<$Res>? get sevenDayOauthApps;@override $ClaudeUsageWindowCopyWith<$Res>? get sevenDayCowork;@override $ClaudeUsageWindowCopyWith<$Res>? get iguanaNecktie;@override $ClaudeExtraUsageCopyWith<$Res>? get extraUsage;

}
/// @nodoc
class __$ClaudeUsageLimitsCopyWithImpl<$Res>
    implements _$ClaudeUsageLimitsCopyWith<$Res> {
  __$ClaudeUsageLimitsCopyWithImpl(this._self, this._then);

  final _ClaudeUsageLimits _self;
  final $Res Function(_ClaudeUsageLimits) _then;

/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fiveHour = freezed,Object? sevenDay = freezed,Object? sevenDaySonnet = freezed,Object? sevenDayOpus = freezed,Object? sevenDayOauthApps = freezed,Object? sevenDayCowork = freezed,Object? iguanaNecktie = freezed,Object? extraUsage = freezed,Object? limits = null,}) {
  return _then(_ClaudeUsageLimits(
fiveHour: freezed == fiveHour ? _self.fiveHour : fiveHour // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDay: freezed == sevenDay ? _self.sevenDay : sevenDay // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDaySonnet: freezed == sevenDaySonnet ? _self.sevenDaySonnet : sevenDaySonnet // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDayOpus: freezed == sevenDayOpus ? _self.sevenDayOpus : sevenDayOpus // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDayOauthApps: freezed == sevenDayOauthApps ? _self.sevenDayOauthApps : sevenDayOauthApps // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,sevenDayCowork: freezed == sevenDayCowork ? _self.sevenDayCowork : sevenDayCowork // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,iguanaNecktie: freezed == iguanaNecktie ? _self.iguanaNecktie : iguanaNecktie // ignore: cast_nullable_to_non_nullable
as ClaudeUsageWindow?,extraUsage: freezed == extraUsage ? _self.extraUsage : extraUsage // ignore: cast_nullable_to_non_nullable
as ClaudeExtraUsage?,limits: null == limits ? _self._limits : limits // ignore: cast_nullable_to_non_nullable
as List<ClaudeUsageLimit>,
  ));
}

/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get fiveHour {
    if (_self.fiveHour == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.fiveHour!, (value) {
    return _then(_self.copyWith(fiveHour: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDay {
    if (_self.sevenDay == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDay!, (value) {
    return _then(_self.copyWith(sevenDay: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDaySonnet {
    if (_self.sevenDaySonnet == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDaySonnet!, (value) {
    return _then(_self.copyWith(sevenDaySonnet: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDayOpus {
    if (_self.sevenDayOpus == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDayOpus!, (value) {
    return _then(_self.copyWith(sevenDayOpus: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDayOauthApps {
    if (_self.sevenDayOauthApps == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDayOauthApps!, (value) {
    return _then(_self.copyWith(sevenDayOauthApps: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get sevenDayCowork {
    if (_self.sevenDayCowork == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.sevenDayCowork!, (value) {
    return _then(_self.copyWith(sevenDayCowork: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeUsageWindowCopyWith<$Res>? get iguanaNecktie {
    if (_self.iguanaNecktie == null) {
    return null;
  }

  return $ClaudeUsageWindowCopyWith<$Res>(_self.iguanaNecktie!, (value) {
    return _then(_self.copyWith(iguanaNecktie: value));
  });
}/// Create a copy of ClaudeUsageLimits
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeExtraUsageCopyWith<$Res>? get extraUsage {
    if (_self.extraUsage == null) {
    return null;
  }

  return $ClaudeExtraUsageCopyWith<$Res>(_self.extraUsage!, (value) {
    return _then(_self.copyWith(extraUsage: value));
  });
}
}

// dart format on
