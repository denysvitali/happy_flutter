// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'claude_local_usage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClaudeLongestSession {

 String get date;@JsonKey(name: 'messageCount') int get messageCount;
/// Create a copy of ClaudeLongestSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeLongestSessionCopyWith<ClaudeLongestSession> get copyWith => _$ClaudeLongestSessionCopyWithImpl<ClaudeLongestSession>(this as ClaudeLongestSession, _$identity);

  /// Serializes this ClaudeLongestSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeLongestSession&&(identical(other.date, date) || other.date == date)&&(identical(other.messageCount, messageCount) || other.messageCount == messageCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,messageCount);

@override
String toString() {
  return 'ClaudeLongestSession(date: $date, messageCount: $messageCount)';
}


}

/// @nodoc
abstract mixin class $ClaudeLongestSessionCopyWith<$Res>  {
  factory $ClaudeLongestSessionCopyWith(ClaudeLongestSession value, $Res Function(ClaudeLongestSession) _then) = _$ClaudeLongestSessionCopyWithImpl;
@useResult
$Res call({
 String date,@JsonKey(name: 'messageCount') int messageCount
});




}
/// @nodoc
class _$ClaudeLongestSessionCopyWithImpl<$Res>
    implements $ClaudeLongestSessionCopyWith<$Res> {
  _$ClaudeLongestSessionCopyWithImpl(this._self, this._then);

  final ClaudeLongestSession _self;
  final $Res Function(ClaudeLongestSession) _then;

/// Create a copy of ClaudeLongestSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? messageCount = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,messageCount: null == messageCount ? _self.messageCount : messageCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ClaudeLongestSession].
extension ClaudeLongestSessionPatterns on ClaudeLongestSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClaudeLongestSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClaudeLongestSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClaudeLongestSession value)  $default,){
final _that = this;
switch (_that) {
case _ClaudeLongestSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClaudeLongestSession value)?  $default,){
final _that = this;
switch (_that) {
case _ClaudeLongestSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date, @JsonKey(name: 'messageCount')  int messageCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClaudeLongestSession() when $default != null:
return $default(_that.date,_that.messageCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date, @JsonKey(name: 'messageCount')  int messageCount)  $default,) {final _that = this;
switch (_that) {
case _ClaudeLongestSession():
return $default(_that.date,_that.messageCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date, @JsonKey(name: 'messageCount')  int messageCount)?  $default,) {final _that = this;
switch (_that) {
case _ClaudeLongestSession() when $default != null:
return $default(_that.date,_that.messageCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClaudeLongestSession implements ClaudeLongestSession {
  const _ClaudeLongestSession({required this.date, @JsonKey(name: 'messageCount') required this.messageCount});
  factory _ClaudeLongestSession.fromJson(Map<String, dynamic> json) => _$ClaudeLongestSessionFromJson(json);

@override final  String date;
@override@JsonKey(name: 'messageCount') final  int messageCount;

/// Create a copy of ClaudeLongestSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeLongestSessionCopyWith<_ClaudeLongestSession> get copyWith => __$ClaudeLongestSessionCopyWithImpl<_ClaudeLongestSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaudeLongestSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeLongestSession&&(identical(other.date, date) || other.date == date)&&(identical(other.messageCount, messageCount) || other.messageCount == messageCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,messageCount);

@override
String toString() {
  return 'ClaudeLongestSession(date: $date, messageCount: $messageCount)';
}


}

/// @nodoc
abstract mixin class _$ClaudeLongestSessionCopyWith<$Res> implements $ClaudeLongestSessionCopyWith<$Res> {
  factory _$ClaudeLongestSessionCopyWith(_ClaudeLongestSession value, $Res Function(_ClaudeLongestSession) _then) = __$ClaudeLongestSessionCopyWithImpl;
@override @useResult
$Res call({
 String date,@JsonKey(name: 'messageCount') int messageCount
});




}
/// @nodoc
class __$ClaudeLongestSessionCopyWithImpl<$Res>
    implements _$ClaudeLongestSessionCopyWith<$Res> {
  __$ClaudeLongestSessionCopyWithImpl(this._self, this._then);

  final _ClaudeLongestSession _self;
  final $Res Function(_ClaudeLongestSession) _then;

/// Create a copy of ClaudeLongestSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? messageCount = null,}) {
  return _then(_ClaudeLongestSession(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,messageCount: null == messageCount ? _self.messageCount : messageCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ClaudeDailyModelTokens {

 String get date;@JsonKey(name: 'tokensByModel') Map<String, int> get tokensByModel;
/// Create a copy of ClaudeDailyModelTokens
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeDailyModelTokensCopyWith<ClaudeDailyModelTokens> get copyWith => _$ClaudeDailyModelTokensCopyWithImpl<ClaudeDailyModelTokens>(this as ClaudeDailyModelTokens, _$identity);

  /// Serializes this ClaudeDailyModelTokens to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeDailyModelTokens&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other.tokensByModel, tokensByModel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,const DeepCollectionEquality().hash(tokensByModel));

@override
String toString() {
  return 'ClaudeDailyModelTokens(date: $date, tokensByModel: $tokensByModel)';
}


}

/// @nodoc
abstract mixin class $ClaudeDailyModelTokensCopyWith<$Res>  {
  factory $ClaudeDailyModelTokensCopyWith(ClaudeDailyModelTokens value, $Res Function(ClaudeDailyModelTokens) _then) = _$ClaudeDailyModelTokensCopyWithImpl;
@useResult
$Res call({
 String date,@JsonKey(name: 'tokensByModel') Map<String, int> tokensByModel
});




}
/// @nodoc
class _$ClaudeDailyModelTokensCopyWithImpl<$Res>
    implements $ClaudeDailyModelTokensCopyWith<$Res> {
  _$ClaudeDailyModelTokensCopyWithImpl(this._self, this._then);

  final ClaudeDailyModelTokens _self;
  final $Res Function(ClaudeDailyModelTokens) _then;

/// Create a copy of ClaudeDailyModelTokens
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? tokensByModel = null,}) {
  return _then(_self.copyWith(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,tokensByModel: null == tokensByModel ? _self.tokensByModel : tokensByModel // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}

}


/// Adds pattern-matching-related methods to [ClaudeDailyModelTokens].
extension ClaudeDailyModelTokensPatterns on ClaudeDailyModelTokens {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClaudeDailyModelTokens value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClaudeDailyModelTokens() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClaudeDailyModelTokens value)  $default,){
final _that = this;
switch (_that) {
case _ClaudeDailyModelTokens():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClaudeDailyModelTokens value)?  $default,){
final _that = this;
switch (_that) {
case _ClaudeDailyModelTokens() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date, @JsonKey(name: 'tokensByModel')  Map<String, int> tokensByModel)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClaudeDailyModelTokens() when $default != null:
return $default(_that.date,_that.tokensByModel);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date, @JsonKey(name: 'tokensByModel')  Map<String, int> tokensByModel)  $default,) {final _that = this;
switch (_that) {
case _ClaudeDailyModelTokens():
return $default(_that.date,_that.tokensByModel);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date, @JsonKey(name: 'tokensByModel')  Map<String, int> tokensByModel)?  $default,) {final _that = this;
switch (_that) {
case _ClaudeDailyModelTokens() when $default != null:
return $default(_that.date,_that.tokensByModel);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClaudeDailyModelTokens implements ClaudeDailyModelTokens {
  const _ClaudeDailyModelTokens({required this.date, @JsonKey(name: 'tokensByModel') final  Map<String, int> tokensByModel = const <String, int>{}}): _tokensByModel = tokensByModel;
  factory _ClaudeDailyModelTokens.fromJson(Map<String, dynamic> json) => _$ClaudeDailyModelTokensFromJson(json);

@override final  String date;
 final  Map<String, int> _tokensByModel;
@override@JsonKey(name: 'tokensByModel') Map<String, int> get tokensByModel {
  if (_tokensByModel is EqualUnmodifiableMapView) return _tokensByModel;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_tokensByModel);
}


/// Create a copy of ClaudeDailyModelTokens
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeDailyModelTokensCopyWith<_ClaudeDailyModelTokens> get copyWith => __$ClaudeDailyModelTokensCopyWithImpl<_ClaudeDailyModelTokens>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaudeDailyModelTokensToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeDailyModelTokens&&(identical(other.date, date) || other.date == date)&&const DeepCollectionEquality().equals(other._tokensByModel, _tokensByModel));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,date,const DeepCollectionEquality().hash(_tokensByModel));

@override
String toString() {
  return 'ClaudeDailyModelTokens(date: $date, tokensByModel: $tokensByModel)';
}


}

/// @nodoc
abstract mixin class _$ClaudeDailyModelTokensCopyWith<$Res> implements $ClaudeDailyModelTokensCopyWith<$Res> {
  factory _$ClaudeDailyModelTokensCopyWith(_ClaudeDailyModelTokens value, $Res Function(_ClaudeDailyModelTokens) _then) = __$ClaudeDailyModelTokensCopyWithImpl;
@override @useResult
$Res call({
 String date,@JsonKey(name: 'tokensByModel') Map<String, int> tokensByModel
});




}
/// @nodoc
class __$ClaudeDailyModelTokensCopyWithImpl<$Res>
    implements _$ClaudeDailyModelTokensCopyWith<$Res> {
  __$ClaudeDailyModelTokensCopyWithImpl(this._self, this._then);

  final _ClaudeDailyModelTokens _self;
  final $Res Function(_ClaudeDailyModelTokens) _then;

/// Create a copy of ClaudeDailyModelTokens
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? tokensByModel = null,}) {
  return _then(_ClaudeDailyModelTokens(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,tokensByModel: null == tokensByModel ? _self._tokensByModel : tokensByModel // ignore: cast_nullable_to_non_nullable
as Map<String, int>,
  ));
}


}


/// @nodoc
mixin _$ClaudeLocalUsage {

 int get version;@JsonKey(name: 'lastComputedDate') String? get lastComputedDate;@JsonKey(name: 'totalTokens') int get totalTokens;@JsonKey(name: 'totalMessages') int get totalMessages;@JsonKey(name: 'totalSessions') int get totalSessions;@JsonKey(name: 'totalToolCalls') int get totalToolCalls;@JsonKey(name: 'tokensByModel') Map<String, int> get tokensByModel;@JsonKey(name: 'longestSession') ClaudeLongestSession? get longestSession;@JsonKey(name: 'dailyModelTokens') List<ClaudeDailyModelTokens> get dailyModelTokens;
/// Create a copy of ClaudeLocalUsage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClaudeLocalUsageCopyWith<ClaudeLocalUsage> get copyWith => _$ClaudeLocalUsageCopyWithImpl<ClaudeLocalUsage>(this as ClaudeLocalUsage, _$identity);

  /// Serializes this ClaudeLocalUsage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClaudeLocalUsage&&(identical(other.version, version) || other.version == version)&&(identical(other.lastComputedDate, lastComputedDate) || other.lastComputedDate == lastComputedDate)&&(identical(other.totalTokens, totalTokens) || other.totalTokens == totalTokens)&&(identical(other.totalMessages, totalMessages) || other.totalMessages == totalMessages)&&(identical(other.totalSessions, totalSessions) || other.totalSessions == totalSessions)&&(identical(other.totalToolCalls, totalToolCalls) || other.totalToolCalls == totalToolCalls)&&const DeepCollectionEquality().equals(other.tokensByModel, tokensByModel)&&(identical(other.longestSession, longestSession) || other.longestSession == longestSession)&&const DeepCollectionEquality().equals(other.dailyModelTokens, dailyModelTokens));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,lastComputedDate,totalTokens,totalMessages,totalSessions,totalToolCalls,const DeepCollectionEquality().hash(tokensByModel),longestSession,const DeepCollectionEquality().hash(dailyModelTokens));

@override
String toString() {
  return 'ClaudeLocalUsage(version: $version, lastComputedDate: $lastComputedDate, totalTokens: $totalTokens, totalMessages: $totalMessages, totalSessions: $totalSessions, totalToolCalls: $totalToolCalls, tokensByModel: $tokensByModel, longestSession: $longestSession, dailyModelTokens: $dailyModelTokens)';
}


}

/// @nodoc
abstract mixin class $ClaudeLocalUsageCopyWith<$Res>  {
  factory $ClaudeLocalUsageCopyWith(ClaudeLocalUsage value, $Res Function(ClaudeLocalUsage) _then) = _$ClaudeLocalUsageCopyWithImpl;
@useResult
$Res call({
 int version,@JsonKey(name: 'lastComputedDate') String? lastComputedDate,@JsonKey(name: 'totalTokens') int totalTokens,@JsonKey(name: 'totalMessages') int totalMessages,@JsonKey(name: 'totalSessions') int totalSessions,@JsonKey(name: 'totalToolCalls') int totalToolCalls,@JsonKey(name: 'tokensByModel') Map<String, int> tokensByModel,@JsonKey(name: 'longestSession') ClaudeLongestSession? longestSession,@JsonKey(name: 'dailyModelTokens') List<ClaudeDailyModelTokens> dailyModelTokens
});


$ClaudeLongestSessionCopyWith<$Res>? get longestSession;

}
/// @nodoc
class _$ClaudeLocalUsageCopyWithImpl<$Res>
    implements $ClaudeLocalUsageCopyWith<$Res> {
  _$ClaudeLocalUsageCopyWithImpl(this._self, this._then);

  final ClaudeLocalUsage _self;
  final $Res Function(ClaudeLocalUsage) _then;

/// Create a copy of ClaudeLocalUsage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? lastComputedDate = freezed,Object? totalTokens = null,Object? totalMessages = null,Object? totalSessions = null,Object? totalToolCalls = null,Object? tokensByModel = null,Object? longestSession = freezed,Object? dailyModelTokens = null,}) {
  return _then(_self.copyWith(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,lastComputedDate: freezed == lastComputedDate ? _self.lastComputedDate : lastComputedDate // ignore: cast_nullable_to_non_nullable
as String?,totalTokens: null == totalTokens ? _self.totalTokens : totalTokens // ignore: cast_nullable_to_non_nullable
as int,totalMessages: null == totalMessages ? _self.totalMessages : totalMessages // ignore: cast_nullable_to_non_nullable
as int,totalSessions: null == totalSessions ? _self.totalSessions : totalSessions // ignore: cast_nullable_to_non_nullable
as int,totalToolCalls: null == totalToolCalls ? _self.totalToolCalls : totalToolCalls // ignore: cast_nullable_to_non_nullable
as int,tokensByModel: null == tokensByModel ? _self.tokensByModel : tokensByModel // ignore: cast_nullable_to_non_nullable
as Map<String, int>,longestSession: freezed == longestSession ? _self.longestSession : longestSession // ignore: cast_nullable_to_non_nullable
as ClaudeLongestSession?,dailyModelTokens: null == dailyModelTokens ? _self.dailyModelTokens : dailyModelTokens // ignore: cast_nullable_to_non_nullable
as List<ClaudeDailyModelTokens>,
  ));
}
/// Create a copy of ClaudeLocalUsage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeLongestSessionCopyWith<$Res>? get longestSession {
    if (_self.longestSession == null) {
    return null;
  }

  return $ClaudeLongestSessionCopyWith<$Res>(_self.longestSession!, (value) {
    return _then(_self.copyWith(longestSession: value));
  });
}
}


/// Adds pattern-matching-related methods to [ClaudeLocalUsage].
extension ClaudeLocalUsagePatterns on ClaudeLocalUsage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClaudeLocalUsage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClaudeLocalUsage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClaudeLocalUsage value)  $default,){
final _that = this;
switch (_that) {
case _ClaudeLocalUsage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClaudeLocalUsage value)?  $default,){
final _that = this;
switch (_that) {
case _ClaudeLocalUsage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int version, @JsonKey(name: 'lastComputedDate')  String? lastComputedDate, @JsonKey(name: 'totalTokens')  int totalTokens, @JsonKey(name: 'totalMessages')  int totalMessages, @JsonKey(name: 'totalSessions')  int totalSessions, @JsonKey(name: 'totalToolCalls')  int totalToolCalls, @JsonKey(name: 'tokensByModel')  Map<String, int> tokensByModel, @JsonKey(name: 'longestSession')  ClaudeLongestSession? longestSession, @JsonKey(name: 'dailyModelTokens')  List<ClaudeDailyModelTokens> dailyModelTokens)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClaudeLocalUsage() when $default != null:
return $default(_that.version,_that.lastComputedDate,_that.totalTokens,_that.totalMessages,_that.totalSessions,_that.totalToolCalls,_that.tokensByModel,_that.longestSession,_that.dailyModelTokens);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int version, @JsonKey(name: 'lastComputedDate')  String? lastComputedDate, @JsonKey(name: 'totalTokens')  int totalTokens, @JsonKey(name: 'totalMessages')  int totalMessages, @JsonKey(name: 'totalSessions')  int totalSessions, @JsonKey(name: 'totalToolCalls')  int totalToolCalls, @JsonKey(name: 'tokensByModel')  Map<String, int> tokensByModel, @JsonKey(name: 'longestSession')  ClaudeLongestSession? longestSession, @JsonKey(name: 'dailyModelTokens')  List<ClaudeDailyModelTokens> dailyModelTokens)  $default,) {final _that = this;
switch (_that) {
case _ClaudeLocalUsage():
return $default(_that.version,_that.lastComputedDate,_that.totalTokens,_that.totalMessages,_that.totalSessions,_that.totalToolCalls,_that.tokensByModel,_that.longestSession,_that.dailyModelTokens);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int version, @JsonKey(name: 'lastComputedDate')  String? lastComputedDate, @JsonKey(name: 'totalTokens')  int totalTokens, @JsonKey(name: 'totalMessages')  int totalMessages, @JsonKey(name: 'totalSessions')  int totalSessions, @JsonKey(name: 'totalToolCalls')  int totalToolCalls, @JsonKey(name: 'tokensByModel')  Map<String, int> tokensByModel, @JsonKey(name: 'longestSession')  ClaudeLongestSession? longestSession, @JsonKey(name: 'dailyModelTokens')  List<ClaudeDailyModelTokens> dailyModelTokens)?  $default,) {final _that = this;
switch (_that) {
case _ClaudeLocalUsage() when $default != null:
return $default(_that.version,_that.lastComputedDate,_that.totalTokens,_that.totalMessages,_that.totalSessions,_that.totalToolCalls,_that.tokensByModel,_that.longestSession,_that.dailyModelTokens);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClaudeLocalUsage extends ClaudeLocalUsage {
  const _ClaudeLocalUsage({this.version = 0, @JsonKey(name: 'lastComputedDate') this.lastComputedDate, @JsonKey(name: 'totalTokens') this.totalTokens = 0, @JsonKey(name: 'totalMessages') this.totalMessages = 0, @JsonKey(name: 'totalSessions') this.totalSessions = 0, @JsonKey(name: 'totalToolCalls') this.totalToolCalls = 0, @JsonKey(name: 'tokensByModel') final  Map<String, int> tokensByModel = const <String, int>{}, @JsonKey(name: 'longestSession') this.longestSession, @JsonKey(name: 'dailyModelTokens') final  List<ClaudeDailyModelTokens> dailyModelTokens = const <ClaudeDailyModelTokens>[]}): _tokensByModel = tokensByModel,_dailyModelTokens = dailyModelTokens,super._();
  factory _ClaudeLocalUsage.fromJson(Map<String, dynamic> json) => _$ClaudeLocalUsageFromJson(json);

@override@JsonKey() final  int version;
@override@JsonKey(name: 'lastComputedDate') final  String? lastComputedDate;
@override@JsonKey(name: 'totalTokens') final  int totalTokens;
@override@JsonKey(name: 'totalMessages') final  int totalMessages;
@override@JsonKey(name: 'totalSessions') final  int totalSessions;
@override@JsonKey(name: 'totalToolCalls') final  int totalToolCalls;
 final  Map<String, int> _tokensByModel;
@override@JsonKey(name: 'tokensByModel') Map<String, int> get tokensByModel {
  if (_tokensByModel is EqualUnmodifiableMapView) return _tokensByModel;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_tokensByModel);
}

@override@JsonKey(name: 'longestSession') final  ClaudeLongestSession? longestSession;
 final  List<ClaudeDailyModelTokens> _dailyModelTokens;
@override@JsonKey(name: 'dailyModelTokens') List<ClaudeDailyModelTokens> get dailyModelTokens {
  if (_dailyModelTokens is EqualUnmodifiableListView) return _dailyModelTokens;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dailyModelTokens);
}


/// Create a copy of ClaudeLocalUsage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClaudeLocalUsageCopyWith<_ClaudeLocalUsage> get copyWith => __$ClaudeLocalUsageCopyWithImpl<_ClaudeLocalUsage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClaudeLocalUsageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClaudeLocalUsage&&(identical(other.version, version) || other.version == version)&&(identical(other.lastComputedDate, lastComputedDate) || other.lastComputedDate == lastComputedDate)&&(identical(other.totalTokens, totalTokens) || other.totalTokens == totalTokens)&&(identical(other.totalMessages, totalMessages) || other.totalMessages == totalMessages)&&(identical(other.totalSessions, totalSessions) || other.totalSessions == totalSessions)&&(identical(other.totalToolCalls, totalToolCalls) || other.totalToolCalls == totalToolCalls)&&const DeepCollectionEquality().equals(other._tokensByModel, _tokensByModel)&&(identical(other.longestSession, longestSession) || other.longestSession == longestSession)&&const DeepCollectionEquality().equals(other._dailyModelTokens, _dailyModelTokens));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,lastComputedDate,totalTokens,totalMessages,totalSessions,totalToolCalls,const DeepCollectionEquality().hash(_tokensByModel),longestSession,const DeepCollectionEquality().hash(_dailyModelTokens));

@override
String toString() {
  return 'ClaudeLocalUsage(version: $version, lastComputedDate: $lastComputedDate, totalTokens: $totalTokens, totalMessages: $totalMessages, totalSessions: $totalSessions, totalToolCalls: $totalToolCalls, tokensByModel: $tokensByModel, longestSession: $longestSession, dailyModelTokens: $dailyModelTokens)';
}


}

/// @nodoc
abstract mixin class _$ClaudeLocalUsageCopyWith<$Res> implements $ClaudeLocalUsageCopyWith<$Res> {
  factory _$ClaudeLocalUsageCopyWith(_ClaudeLocalUsage value, $Res Function(_ClaudeLocalUsage) _then) = __$ClaudeLocalUsageCopyWithImpl;
@override @useResult
$Res call({
 int version,@JsonKey(name: 'lastComputedDate') String? lastComputedDate,@JsonKey(name: 'totalTokens') int totalTokens,@JsonKey(name: 'totalMessages') int totalMessages,@JsonKey(name: 'totalSessions') int totalSessions,@JsonKey(name: 'totalToolCalls') int totalToolCalls,@JsonKey(name: 'tokensByModel') Map<String, int> tokensByModel,@JsonKey(name: 'longestSession') ClaudeLongestSession? longestSession,@JsonKey(name: 'dailyModelTokens') List<ClaudeDailyModelTokens> dailyModelTokens
});


@override $ClaudeLongestSessionCopyWith<$Res>? get longestSession;

}
/// @nodoc
class __$ClaudeLocalUsageCopyWithImpl<$Res>
    implements _$ClaudeLocalUsageCopyWith<$Res> {
  __$ClaudeLocalUsageCopyWithImpl(this._self, this._then);

  final _ClaudeLocalUsage _self;
  final $Res Function(_ClaudeLocalUsage) _then;

/// Create a copy of ClaudeLocalUsage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? lastComputedDate = freezed,Object? totalTokens = null,Object? totalMessages = null,Object? totalSessions = null,Object? totalToolCalls = null,Object? tokensByModel = null,Object? longestSession = freezed,Object? dailyModelTokens = null,}) {
  return _then(_ClaudeLocalUsage(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,lastComputedDate: freezed == lastComputedDate ? _self.lastComputedDate : lastComputedDate // ignore: cast_nullable_to_non_nullable
as String?,totalTokens: null == totalTokens ? _self.totalTokens : totalTokens // ignore: cast_nullable_to_non_nullable
as int,totalMessages: null == totalMessages ? _self.totalMessages : totalMessages // ignore: cast_nullable_to_non_nullable
as int,totalSessions: null == totalSessions ? _self.totalSessions : totalSessions // ignore: cast_nullable_to_non_nullable
as int,totalToolCalls: null == totalToolCalls ? _self.totalToolCalls : totalToolCalls // ignore: cast_nullable_to_non_nullable
as int,tokensByModel: null == tokensByModel ? _self._tokensByModel : tokensByModel // ignore: cast_nullable_to_non_nullable
as Map<String, int>,longestSession: freezed == longestSession ? _self.longestSession : longestSession // ignore: cast_nullable_to_non_nullable
as ClaudeLongestSession?,dailyModelTokens: null == dailyModelTokens ? _self._dailyModelTokens : dailyModelTokens // ignore: cast_nullable_to_non_nullable
as List<ClaudeDailyModelTokens>,
  ));
}

/// Create a copy of ClaudeLocalUsage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ClaudeLongestSessionCopyWith<$Res>? get longestSession {
    if (_self.longestSession == null) {
    return null;
  }

  return $ClaudeLongestSessionCopyWith<$Res>(_self.longestSession!, (value) {
    return _then(_self.copyWith(longestSession: value));
  });
}
}

// dart format on
