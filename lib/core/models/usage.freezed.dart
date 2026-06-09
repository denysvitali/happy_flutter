// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'usage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UsageDataPoint {

@JsonKey(fromJson: _asUsageInt) int get timestamp;@JsonKey(fromJson: _tokensFromJson) Map<String, int> get tokens;@JsonKey(fromJson: _costFromJson) Map<String, double> get cost;@JsonKey(fromJson: _asUsageInt) int get reportCount;
/// Create a copy of UsageDataPoint
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageDataPointCopyWith<UsageDataPoint> get copyWith => _$UsageDataPointCopyWithImpl<UsageDataPoint>(this as UsageDataPoint, _$identity);

  /// Serializes this UsageDataPoint to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageDataPoint&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&const DeepCollectionEquality().equals(other.tokens, tokens)&&const DeepCollectionEquality().equals(other.cost, cost)&&(identical(other.reportCount, reportCount) || other.reportCount == reportCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,const DeepCollectionEquality().hash(tokens),const DeepCollectionEquality().hash(cost),reportCount);

@override
String toString() {
  return 'UsageDataPoint(timestamp: $timestamp, tokens: $tokens, cost: $cost, reportCount: $reportCount)';
}


}

/// @nodoc
abstract mixin class $UsageDataPointCopyWith<$Res>  {
  factory $UsageDataPointCopyWith(UsageDataPoint value, $Res Function(UsageDataPoint) _then) = _$UsageDataPointCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _asUsageInt) int timestamp,@JsonKey(fromJson: _tokensFromJson) Map<String, int> tokens,@JsonKey(fromJson: _costFromJson) Map<String, double> cost,@JsonKey(fromJson: _asUsageInt) int reportCount
});




}
/// @nodoc
class _$UsageDataPointCopyWithImpl<$Res>
    implements $UsageDataPointCopyWith<$Res> {
  _$UsageDataPointCopyWithImpl(this._self, this._then);

  final UsageDataPoint _self;
  final $Res Function(UsageDataPoint) _then;

/// Create a copy of UsageDataPoint
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? tokens = null,Object? cost = null,Object? reportCount = null,}) {
  return _then(_self.copyWith(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,tokens: null == tokens ? _self.tokens : tokens // ignore: cast_nullable_to_non_nullable
as Map<String, int>,cost: null == cost ? _self.cost : cost // ignore: cast_nullable_to_non_nullable
as Map<String, double>,reportCount: null == reportCount ? _self.reportCount : reportCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageDataPoint].
extension UsageDataPointPatterns on UsageDataPoint {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageDataPoint value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageDataPoint() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageDataPoint value)  $default,){
final _that = this;
switch (_that) {
case _UsageDataPoint():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageDataPoint value)?  $default,){
final _that = this;
switch (_that) {
case _UsageDataPoint() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asUsageInt)  int timestamp, @JsonKey(fromJson: _tokensFromJson)  Map<String, int> tokens, @JsonKey(fromJson: _costFromJson)  Map<String, double> cost, @JsonKey(fromJson: _asUsageInt)  int reportCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageDataPoint() when $default != null:
return $default(_that.timestamp,_that.tokens,_that.cost,_that.reportCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _asUsageInt)  int timestamp, @JsonKey(fromJson: _tokensFromJson)  Map<String, int> tokens, @JsonKey(fromJson: _costFromJson)  Map<String, double> cost, @JsonKey(fromJson: _asUsageInt)  int reportCount)  $default,) {final _that = this;
switch (_that) {
case _UsageDataPoint():
return $default(_that.timestamp,_that.tokens,_that.cost,_that.reportCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _asUsageInt)  int timestamp, @JsonKey(fromJson: _tokensFromJson)  Map<String, int> tokens, @JsonKey(fromJson: _costFromJson)  Map<String, double> cost, @JsonKey(fromJson: _asUsageInt)  int reportCount)?  $default,) {final _that = this;
switch (_that) {
case _UsageDataPoint() when $default != null:
return $default(_that.timestamp,_that.tokens,_that.cost,_that.reportCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UsageDataPoint implements UsageDataPoint {
  const _UsageDataPoint({@JsonKey(fromJson: _asUsageInt) this.timestamp = 0, @JsonKey(fromJson: _tokensFromJson) final  Map<String, int> tokens = const <String, int>{}, @JsonKey(fromJson: _costFromJson) final  Map<String, double> cost = const <String, double>{}, @JsonKey(fromJson: _asUsageInt) this.reportCount = 0}): _tokens = tokens,_cost = cost;
  factory _UsageDataPoint.fromJson(Map<String, dynamic> json) => _$UsageDataPointFromJson(json);

@override@JsonKey(fromJson: _asUsageInt) final  int timestamp;
 final  Map<String, int> _tokens;
@override@JsonKey(fromJson: _tokensFromJson) Map<String, int> get tokens {
  if (_tokens is EqualUnmodifiableMapView) return _tokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_tokens);
}

 final  Map<String, double> _cost;
@override@JsonKey(fromJson: _costFromJson) Map<String, double> get cost {
  if (_cost is EqualUnmodifiableMapView) return _cost;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_cost);
}

@override@JsonKey(fromJson: _asUsageInt) final  int reportCount;

/// Create a copy of UsageDataPoint
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageDataPointCopyWith<_UsageDataPoint> get copyWith => __$UsageDataPointCopyWithImpl<_UsageDataPoint>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageDataPointToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageDataPoint&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&const DeepCollectionEquality().equals(other._tokens, _tokens)&&const DeepCollectionEquality().equals(other._cost, _cost)&&(identical(other.reportCount, reportCount) || other.reportCount == reportCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timestamp,const DeepCollectionEquality().hash(_tokens),const DeepCollectionEquality().hash(_cost),reportCount);

@override
String toString() {
  return 'UsageDataPoint(timestamp: $timestamp, tokens: $tokens, cost: $cost, reportCount: $reportCount)';
}


}

/// @nodoc
abstract mixin class _$UsageDataPointCopyWith<$Res> implements $UsageDataPointCopyWith<$Res> {
  factory _$UsageDataPointCopyWith(_UsageDataPoint value, $Res Function(_UsageDataPoint) _then) = __$UsageDataPointCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _asUsageInt) int timestamp,@JsonKey(fromJson: _tokensFromJson) Map<String, int> tokens,@JsonKey(fromJson: _costFromJson) Map<String, double> cost,@JsonKey(fromJson: _asUsageInt) int reportCount
});




}
/// @nodoc
class __$UsageDataPointCopyWithImpl<$Res>
    implements _$UsageDataPointCopyWith<$Res> {
  __$UsageDataPointCopyWithImpl(this._self, this._then);

  final _UsageDataPoint _self;
  final $Res Function(_UsageDataPoint) _then;

/// Create a copy of UsageDataPoint
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? tokens = null,Object? cost = null,Object? reportCount = null,}) {
  return _then(_UsageDataPoint(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as int,tokens: null == tokens ? _self._tokens : tokens // ignore: cast_nullable_to_non_nullable
as Map<String, int>,cost: null == cost ? _self._cost : cost // ignore: cast_nullable_to_non_nullable
as Map<String, double>,reportCount: null == reportCount ? _self.reportCount : reportCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$UsageResponse {

 List<UsageDataPoint> get usage;
/// Create a copy of UsageResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageResponseCopyWith<UsageResponse> get copyWith => _$UsageResponseCopyWithImpl<UsageResponse>(this as UsageResponse, _$identity);

  /// Serializes this UsageResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageResponse&&const DeepCollectionEquality().equals(other.usage, usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(usage));

@override
String toString() {
  return 'UsageResponse(usage: $usage)';
}


}

/// @nodoc
abstract mixin class $UsageResponseCopyWith<$Res>  {
  factory $UsageResponseCopyWith(UsageResponse value, $Res Function(UsageResponse) _then) = _$UsageResponseCopyWithImpl;
@useResult
$Res call({
 List<UsageDataPoint> usage
});




}
/// @nodoc
class _$UsageResponseCopyWithImpl<$Res>
    implements $UsageResponseCopyWith<$Res> {
  _$UsageResponseCopyWithImpl(this._self, this._then);

  final UsageResponse _self;
  final $Res Function(UsageResponse) _then;

/// Create a copy of UsageResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? usage = null,}) {
  return _then(_self.copyWith(
usage: null == usage ? _self.usage : usage // ignore: cast_nullable_to_non_nullable
as List<UsageDataPoint>,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageResponse].
extension UsageResponsePatterns on UsageResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageResponse value)  $default,){
final _that = this;
switch (_that) {
case _UsageResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageResponse value)?  $default,){
final _that = this;
switch (_that) {
case _UsageResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UsageDataPoint> usage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageResponse() when $default != null:
return $default(_that.usage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UsageDataPoint> usage)  $default,) {final _that = this;
switch (_that) {
case _UsageResponse():
return $default(_that.usage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UsageDataPoint> usage)?  $default,) {final _that = this;
switch (_that) {
case _UsageResponse() when $default != null:
return $default(_that.usage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UsageResponse implements UsageResponse {
  const _UsageResponse({required final  List<UsageDataPoint> usage}): _usage = usage;
  factory _UsageResponse.fromJson(Map<String, dynamic> json) => _$UsageResponseFromJson(json);

 final  List<UsageDataPoint> _usage;
@override List<UsageDataPoint> get usage {
  if (_usage is EqualUnmodifiableListView) return _usage;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_usage);
}


/// Create a copy of UsageResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageResponseCopyWith<_UsageResponse> get copyWith => __$UsageResponseCopyWithImpl<_UsageResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageResponse&&const DeepCollectionEquality().equals(other._usage, _usage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_usage));

@override
String toString() {
  return 'UsageResponse(usage: $usage)';
}


}

/// @nodoc
abstract mixin class _$UsageResponseCopyWith<$Res> implements $UsageResponseCopyWith<$Res> {
  factory _$UsageResponseCopyWith(_UsageResponse value, $Res Function(_UsageResponse) _then) = __$UsageResponseCopyWithImpl;
@override @useResult
$Res call({
 List<UsageDataPoint> usage
});




}
/// @nodoc
class __$UsageResponseCopyWithImpl<$Res>
    implements _$UsageResponseCopyWith<$Res> {
  __$UsageResponseCopyWithImpl(this._self, this._then);

  final _UsageResponse _self;
  final $Res Function(_UsageResponse) _then;

/// Create a copy of UsageResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? usage = null,}) {
  return _then(_UsageResponse(
usage: null == usage ? _self._usage : usage // ignore: cast_nullable_to_non_nullable
as List<UsageDataPoint>,
  ));
}


}


/// @nodoc
mixin _$UsageQueryParams {

 String? get sessionId; int? get startTime;// Unix timestamp in seconds
 int? get endTime;// Unix timestamp in seconds
 UsageGroupBy? get groupBy;
/// Create a copy of UsageQueryParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UsageQueryParamsCopyWith<UsageQueryParams> get copyWith => _$UsageQueryParamsCopyWithImpl<UsageQueryParams>(this as UsageQueryParams, _$identity);

  /// Serializes this UsageQueryParams to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UsageQueryParams&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.groupBy, groupBy) || other.groupBy == groupBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,startTime,endTime,groupBy);

@override
String toString() {
  return 'UsageQueryParams(sessionId: $sessionId, startTime: $startTime, endTime: $endTime, groupBy: $groupBy)';
}


}

/// @nodoc
abstract mixin class $UsageQueryParamsCopyWith<$Res>  {
  factory $UsageQueryParamsCopyWith(UsageQueryParams value, $Res Function(UsageQueryParams) _then) = _$UsageQueryParamsCopyWithImpl;
@useResult
$Res call({
 String? sessionId, int? startTime, int? endTime, UsageGroupBy? groupBy
});




}
/// @nodoc
class _$UsageQueryParamsCopyWithImpl<$Res>
    implements $UsageQueryParamsCopyWith<$Res> {
  _$UsageQueryParamsCopyWithImpl(this._self, this._then);

  final UsageQueryParams _self;
  final $Res Function(UsageQueryParams) _then;

/// Create a copy of UsageQueryParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessionId = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? groupBy = freezed,}) {
  return _then(_self.copyWith(
sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as int?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as int?,groupBy: freezed == groupBy ? _self.groupBy : groupBy // ignore: cast_nullable_to_non_nullable
as UsageGroupBy?,
  ));
}

}


/// Adds pattern-matching-related methods to [UsageQueryParams].
extension UsageQueryParamsPatterns on UsageQueryParams {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UsageQueryParams value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UsageQueryParams() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UsageQueryParams value)  $default,){
final _that = this;
switch (_that) {
case _UsageQueryParams():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UsageQueryParams value)?  $default,){
final _that = this;
switch (_that) {
case _UsageQueryParams() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? sessionId,  int? startTime,  int? endTime,  UsageGroupBy? groupBy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UsageQueryParams() when $default != null:
return $default(_that.sessionId,_that.startTime,_that.endTime,_that.groupBy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? sessionId,  int? startTime,  int? endTime,  UsageGroupBy? groupBy)  $default,) {final _that = this;
switch (_that) {
case _UsageQueryParams():
return $default(_that.sessionId,_that.startTime,_that.endTime,_that.groupBy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? sessionId,  int? startTime,  int? endTime,  UsageGroupBy? groupBy)?  $default,) {final _that = this;
switch (_that) {
case _UsageQueryParams() when $default != null:
return $default(_that.sessionId,_that.startTime,_that.endTime,_that.groupBy);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _UsageQueryParams extends UsageQueryParams {
  const _UsageQueryParams({this.sessionId, this.startTime, this.endTime, this.groupBy}): super._();
  factory _UsageQueryParams.fromJson(Map<String, dynamic> json) => _$UsageQueryParamsFromJson(json);

@override final  String? sessionId;
@override final  int? startTime;
// Unix timestamp in seconds
@override final  int? endTime;
// Unix timestamp in seconds
@override final  UsageGroupBy? groupBy;

/// Create a copy of UsageQueryParams
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UsageQueryParamsCopyWith<_UsageQueryParams> get copyWith => __$UsageQueryParamsCopyWithImpl<_UsageQueryParams>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UsageQueryParamsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UsageQueryParams&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.groupBy, groupBy) || other.groupBy == groupBy));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sessionId,startTime,endTime,groupBy);

@override
String toString() {
  return 'UsageQueryParams(sessionId: $sessionId, startTime: $startTime, endTime: $endTime, groupBy: $groupBy)';
}


}

/// @nodoc
abstract mixin class _$UsageQueryParamsCopyWith<$Res> implements $UsageQueryParamsCopyWith<$Res> {
  factory _$UsageQueryParamsCopyWith(_UsageQueryParams value, $Res Function(_UsageQueryParams) _then) = __$UsageQueryParamsCopyWithImpl;
@override @useResult
$Res call({
 String? sessionId, int? startTime, int? endTime, UsageGroupBy? groupBy
});




}
/// @nodoc
class __$UsageQueryParamsCopyWithImpl<$Res>
    implements _$UsageQueryParamsCopyWith<$Res> {
  __$UsageQueryParamsCopyWithImpl(this._self, this._then);

  final _UsageQueryParams _self;
  final $Res Function(_UsageQueryParams) _then;

/// Create a copy of UsageQueryParams
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessionId = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? groupBy = freezed,}) {
  return _then(_UsageQueryParams(
sessionId: freezed == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String?,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as int?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as int?,groupBy: freezed == groupBy ? _self.groupBy : groupBy // ignore: cast_nullable_to_non_nullable
as UsageGroupBy?,
  ));
}


}

// dart format on
