// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'provider_usage.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$KimiCredentials {

 String get apiKey; String get baseUrl; String? get accountName;
/// Create a copy of KimiCredentials
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KimiCredentialsCopyWith<KimiCredentials> get copyWith => _$KimiCredentialsCopyWithImpl<KimiCredentials>(this as KimiCredentials, _$identity);

  /// Serializes this KimiCredentials to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KimiCredentials&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.accountName, accountName) || other.accountName == accountName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKey,baseUrl,accountName);

@override
String toString() {
  return 'KimiCredentials(apiKey: $apiKey, baseUrl: $baseUrl, accountName: $accountName)';
}


}

/// @nodoc
abstract mixin class $KimiCredentialsCopyWith<$Res>  {
  factory $KimiCredentialsCopyWith(KimiCredentials value, $Res Function(KimiCredentials) _then) = _$KimiCredentialsCopyWithImpl;
@useResult
$Res call({
 String apiKey, String baseUrl, String? accountName
});




}
/// @nodoc
class _$KimiCredentialsCopyWithImpl<$Res>
    implements $KimiCredentialsCopyWith<$Res> {
  _$KimiCredentialsCopyWithImpl(this._self, this._then);

  final KimiCredentials _self;
  final $Res Function(KimiCredentials) _then;

/// Create a copy of KimiCredentials
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiKey = null,Object? baseUrl = null,Object? accountName = freezed,}) {
  return _then(_self.copyWith(
apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,accountName: freezed == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [KimiCredentials].
extension KimiCredentialsPatterns on KimiCredentials {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KimiCredentials value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KimiCredentials() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KimiCredentials value)  $default,){
final _that = this;
switch (_that) {
case _KimiCredentials():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KimiCredentials value)?  $default,){
final _that = this;
switch (_that) {
case _KimiCredentials() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apiKey,  String baseUrl,  String? accountName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KimiCredentials() when $default != null:
return $default(_that.apiKey,_that.baseUrl,_that.accountName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apiKey,  String baseUrl,  String? accountName)  $default,) {final _that = this;
switch (_that) {
case _KimiCredentials():
return $default(_that.apiKey,_that.baseUrl,_that.accountName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apiKey,  String baseUrl,  String? accountName)?  $default,) {final _that = this;
switch (_that) {
case _KimiCredentials() when $default != null:
return $default(_that.apiKey,_that.baseUrl,_that.accountName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KimiCredentials implements KimiCredentials {
  const _KimiCredentials({required this.apiKey, this.baseUrl = kimiDefaultBaseUrl, this.accountName});
  factory _KimiCredentials.fromJson(Map<String, dynamic> json) => _$KimiCredentialsFromJson(json);

@override final  String apiKey;
@override@JsonKey() final  String baseUrl;
@override final  String? accountName;

/// Create a copy of KimiCredentials
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KimiCredentialsCopyWith<_KimiCredentials> get copyWith => __$KimiCredentialsCopyWithImpl<_KimiCredentials>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KimiCredentialsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KimiCredentials&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.accountName, accountName) || other.accountName == accountName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKey,baseUrl,accountName);

@override
String toString() {
  return 'KimiCredentials(apiKey: $apiKey, baseUrl: $baseUrl, accountName: $accountName)';
}


}

/// @nodoc
abstract mixin class _$KimiCredentialsCopyWith<$Res> implements $KimiCredentialsCopyWith<$Res> {
  factory _$KimiCredentialsCopyWith(_KimiCredentials value, $Res Function(_KimiCredentials) _then) = __$KimiCredentialsCopyWithImpl;
@override @useResult
$Res call({
 String apiKey, String baseUrl, String? accountName
});




}
/// @nodoc
class __$KimiCredentialsCopyWithImpl<$Res>
    implements _$KimiCredentialsCopyWith<$Res> {
  __$KimiCredentialsCopyWithImpl(this._self, this._then);

  final _KimiCredentials _self;
  final $Res Function(_KimiCredentials) _then;

/// Create a copy of KimiCredentials
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiKey = null,Object? baseUrl = null,Object? accountName = freezed,}) {
  return _then(_KimiCredentials(
apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,accountName: freezed == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$MiniMaxCredentials {

 String get apiKey; String get cookie; String get groupId; String? get accountName;
/// Create a copy of MiniMaxCredentials
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MiniMaxCredentialsCopyWith<MiniMaxCredentials> get copyWith => _$MiniMaxCredentialsCopyWithImpl<MiniMaxCredentials>(this as MiniMaxCredentials, _$identity);

  /// Serializes this MiniMaxCredentials to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MiniMaxCredentials&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.cookie, cookie) || other.cookie == cookie)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.accountName, accountName) || other.accountName == accountName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKey,cookie,groupId,accountName);

@override
String toString() {
  return 'MiniMaxCredentials(apiKey: $apiKey, cookie: $cookie, groupId: $groupId, accountName: $accountName)';
}


}

/// @nodoc
abstract mixin class $MiniMaxCredentialsCopyWith<$Res>  {
  factory $MiniMaxCredentialsCopyWith(MiniMaxCredentials value, $Res Function(MiniMaxCredentials) _then) = _$MiniMaxCredentialsCopyWithImpl;
@useResult
$Res call({
 String apiKey, String cookie, String groupId, String? accountName
});




}
/// @nodoc
class _$MiniMaxCredentialsCopyWithImpl<$Res>
    implements $MiniMaxCredentialsCopyWith<$Res> {
  _$MiniMaxCredentialsCopyWithImpl(this._self, this._then);

  final MiniMaxCredentials _self;
  final $Res Function(MiniMaxCredentials) _then;

/// Create a copy of MiniMaxCredentials
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiKey = null,Object? cookie = null,Object? groupId = null,Object? accountName = freezed,}) {
  return _then(_self.copyWith(
apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,cookie: null == cookie ? _self.cookie : cookie // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,accountName: freezed == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MiniMaxCredentials].
extension MiniMaxCredentialsPatterns on MiniMaxCredentials {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MiniMaxCredentials value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MiniMaxCredentials() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MiniMaxCredentials value)  $default,){
final _that = this;
switch (_that) {
case _MiniMaxCredentials():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MiniMaxCredentials value)?  $default,){
final _that = this;
switch (_that) {
case _MiniMaxCredentials() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String apiKey,  String cookie,  String groupId,  String? accountName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MiniMaxCredentials() when $default != null:
return $default(_that.apiKey,_that.cookie,_that.groupId,_that.accountName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String apiKey,  String cookie,  String groupId,  String? accountName)  $default,) {final _that = this;
switch (_that) {
case _MiniMaxCredentials():
return $default(_that.apiKey,_that.cookie,_that.groupId,_that.accountName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String apiKey,  String cookie,  String groupId,  String? accountName)?  $default,) {final _that = this;
switch (_that) {
case _MiniMaxCredentials() when $default != null:
return $default(_that.apiKey,_that.cookie,_that.groupId,_that.accountName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MiniMaxCredentials implements MiniMaxCredentials {
  const _MiniMaxCredentials({this.apiKey = '', this.cookie = '', this.groupId = '', this.accountName});
  factory _MiniMaxCredentials.fromJson(Map<String, dynamic> json) => _$MiniMaxCredentialsFromJson(json);

@override@JsonKey() final  String apiKey;
@override@JsonKey() final  String cookie;
@override@JsonKey() final  String groupId;
@override final  String? accountName;

/// Create a copy of MiniMaxCredentials
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MiniMaxCredentialsCopyWith<_MiniMaxCredentials> get copyWith => __$MiniMaxCredentialsCopyWithImpl<_MiniMaxCredentials>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MiniMaxCredentialsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MiniMaxCredentials&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.cookie, cookie) || other.cookie == cookie)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.accountName, accountName) || other.accountName == accountName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,apiKey,cookie,groupId,accountName);

@override
String toString() {
  return 'MiniMaxCredentials(apiKey: $apiKey, cookie: $cookie, groupId: $groupId, accountName: $accountName)';
}


}

/// @nodoc
abstract mixin class _$MiniMaxCredentialsCopyWith<$Res> implements $MiniMaxCredentialsCopyWith<$Res> {
  factory _$MiniMaxCredentialsCopyWith(_MiniMaxCredentials value, $Res Function(_MiniMaxCredentials) _then) = __$MiniMaxCredentialsCopyWithImpl;
@override @useResult
$Res call({
 String apiKey, String cookie, String groupId, String? accountName
});




}
/// @nodoc
class __$MiniMaxCredentialsCopyWithImpl<$Res>
    implements _$MiniMaxCredentialsCopyWith<$Res> {
  __$MiniMaxCredentialsCopyWithImpl(this._self, this._then);

  final _MiniMaxCredentials _self;
  final $Res Function(_MiniMaxCredentials) _then;

/// Create a copy of MiniMaxCredentials
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiKey = null,Object? cookie = null,Object? groupId = null,Object? accountName = freezed,}) {
  return _then(_MiniMaxCredentials(
apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,cookie: null == cookie ? _self.cookie : cookie // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,accountName: freezed == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

ProviderCredentials _$ProviderCredentialsFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'kimi':
          return _ProviderCredentialsKimi.fromJson(
            json
          );
                case 'miniMax':
          return _ProviderCredentialsMiniMax.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'ProviderCredentials',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$ProviderCredentials {

 Object get credentials;

  /// Serializes this ProviderCredentials to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderCredentials&&const DeepCollectionEquality().equals(other.credentials, credentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(credentials));

@override
String toString() {
  return 'ProviderCredentials(credentials: $credentials)';
}


}

/// @nodoc
class $ProviderCredentialsCopyWith<$Res>  {
$ProviderCredentialsCopyWith(ProviderCredentials _, $Res Function(ProviderCredentials) __);
}


/// Adds pattern-matching-related methods to [ProviderCredentials].
extension ProviderCredentialsPatterns on ProviderCredentials {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _ProviderCredentialsKimi value)?  kimi,TResult Function( _ProviderCredentialsMiniMax value)?  miniMax,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderCredentialsKimi() when kimi != null:
return kimi(_that);case _ProviderCredentialsMiniMax() when miniMax != null:
return miniMax(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _ProviderCredentialsKimi value)  kimi,required TResult Function( _ProviderCredentialsMiniMax value)  miniMax,}){
final _that = this;
switch (_that) {
case _ProviderCredentialsKimi():
return kimi(_that);case _ProviderCredentialsMiniMax():
return miniMax(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _ProviderCredentialsKimi value)?  kimi,TResult? Function( _ProviderCredentialsMiniMax value)?  miniMax,}){
final _that = this;
switch (_that) {
case _ProviderCredentialsKimi() when kimi != null:
return kimi(_that);case _ProviderCredentialsMiniMax() when miniMax != null:
return miniMax(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( KimiCredentials credentials)?  kimi,TResult Function( MiniMaxCredentials credentials)?  miniMax,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderCredentialsKimi() when kimi != null:
return kimi(_that.credentials);case _ProviderCredentialsMiniMax() when miniMax != null:
return miniMax(_that.credentials);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( KimiCredentials credentials)  kimi,required TResult Function( MiniMaxCredentials credentials)  miniMax,}) {final _that = this;
switch (_that) {
case _ProviderCredentialsKimi():
return kimi(_that.credentials);case _ProviderCredentialsMiniMax():
return miniMax(_that.credentials);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( KimiCredentials credentials)?  kimi,TResult? Function( MiniMaxCredentials credentials)?  miniMax,}) {final _that = this;
switch (_that) {
case _ProviderCredentialsKimi() when kimi != null:
return kimi(_that.credentials);case _ProviderCredentialsMiniMax() when miniMax != null:
return miniMax(_that.credentials);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderCredentialsKimi implements ProviderCredentials {
  const _ProviderCredentialsKimi(this.credentials, {final  String? $type}): $type = $type ?? 'kimi';
  factory _ProviderCredentialsKimi.fromJson(Map<String, dynamic> json) => _$ProviderCredentialsKimiFromJson(json);

@override final  KimiCredentials credentials;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProviderCredentials
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderCredentialsKimiCopyWith<_ProviderCredentialsKimi> get copyWith => __$ProviderCredentialsKimiCopyWithImpl<_ProviderCredentialsKimi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderCredentialsKimiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderCredentialsKimi&&(identical(other.credentials, credentials) || other.credentials == credentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,credentials);

@override
String toString() {
  return 'ProviderCredentials.kimi(credentials: $credentials)';
}


}

/// @nodoc
abstract mixin class _$ProviderCredentialsKimiCopyWith<$Res> implements $ProviderCredentialsCopyWith<$Res> {
  factory _$ProviderCredentialsKimiCopyWith(_ProviderCredentialsKimi value, $Res Function(_ProviderCredentialsKimi) _then) = __$ProviderCredentialsKimiCopyWithImpl;
@useResult
$Res call({
 KimiCredentials credentials
});


$KimiCredentialsCopyWith<$Res> get credentials;

}
/// @nodoc
class __$ProviderCredentialsKimiCopyWithImpl<$Res>
    implements _$ProviderCredentialsKimiCopyWith<$Res> {
  __$ProviderCredentialsKimiCopyWithImpl(this._self, this._then);

  final _ProviderCredentialsKimi _self;
  final $Res Function(_ProviderCredentialsKimi) _then;

/// Create a copy of ProviderCredentials
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? credentials = null,}) {
  return _then(_ProviderCredentialsKimi(
null == credentials ? _self.credentials : credentials // ignore: cast_nullable_to_non_nullable
as KimiCredentials,
  ));
}

/// Create a copy of ProviderCredentials
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$KimiCredentialsCopyWith<$Res> get credentials {
  
  return $KimiCredentialsCopyWith<$Res>(_self.credentials, (value) {
    return _then(_self.copyWith(credentials: value));
  });
}
}

/// @nodoc
@JsonSerializable()

class _ProviderCredentialsMiniMax implements ProviderCredentials {
  const _ProviderCredentialsMiniMax(this.credentials, {final  String? $type}): $type = $type ?? 'miniMax';
  factory _ProviderCredentialsMiniMax.fromJson(Map<String, dynamic> json) => _$ProviderCredentialsMiniMaxFromJson(json);

@override final  MiniMaxCredentials credentials;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of ProviderCredentials
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderCredentialsMiniMaxCopyWith<_ProviderCredentialsMiniMax> get copyWith => __$ProviderCredentialsMiniMaxCopyWithImpl<_ProviderCredentialsMiniMax>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderCredentialsMiniMaxToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderCredentialsMiniMax&&(identical(other.credentials, credentials) || other.credentials == credentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,credentials);

@override
String toString() {
  return 'ProviderCredentials.miniMax(credentials: $credentials)';
}


}

/// @nodoc
abstract mixin class _$ProviderCredentialsMiniMaxCopyWith<$Res> implements $ProviderCredentialsCopyWith<$Res> {
  factory _$ProviderCredentialsMiniMaxCopyWith(_ProviderCredentialsMiniMax value, $Res Function(_ProviderCredentialsMiniMax) _then) = __$ProviderCredentialsMiniMaxCopyWithImpl;
@useResult
$Res call({
 MiniMaxCredentials credentials
});


$MiniMaxCredentialsCopyWith<$Res> get credentials;

}
/// @nodoc
class __$ProviderCredentialsMiniMaxCopyWithImpl<$Res>
    implements _$ProviderCredentialsMiniMaxCopyWith<$Res> {
  __$ProviderCredentialsMiniMaxCopyWithImpl(this._self, this._then);

  final _ProviderCredentialsMiniMax _self;
  final $Res Function(_ProviderCredentialsMiniMax) _then;

/// Create a copy of ProviderCredentials
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? credentials = null,}) {
  return _then(_ProviderCredentialsMiniMax(
null == credentials ? _self.credentials : credentials // ignore: cast_nullable_to_non_nullable
as MiniMaxCredentials,
  ));
}

/// Create a copy of ProviderCredentials
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MiniMaxCredentialsCopyWith<$Res> get credentials {
  
  return $MiniMaxCredentialsCopyWith<$Res>(_self.credentials, (value) {
    return _then(_self.copyWith(credentials: value));
  });
}
}


/// @nodoc
mixin _$ProviderAccount {

 String get id; String? get name; ProviderUsageType get type; ProviderCredentials get credentials;
/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderAccountCopyWith<ProviderAccount> get copyWith => _$ProviderAccountCopyWithImpl<ProviderAccount>(this as ProviderAccount, _$identity);

  /// Serializes this ProviderAccount to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderAccount&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.credentials, credentials) || other.credentials == credentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,credentials);

@override
String toString() {
  return 'ProviderAccount(id: $id, name: $name, type: $type, credentials: $credentials)';
}


}

/// @nodoc
abstract mixin class $ProviderAccountCopyWith<$Res>  {
  factory $ProviderAccountCopyWith(ProviderAccount value, $Res Function(ProviderAccount) _then) = _$ProviderAccountCopyWithImpl;
@useResult
$Res call({
 String id, String? name, ProviderUsageType type, ProviderCredentials credentials
});


$ProviderCredentialsCopyWith<$Res> get credentials;

}
/// @nodoc
class _$ProviderAccountCopyWithImpl<$Res>
    implements $ProviderAccountCopyWith<$Res> {
  _$ProviderAccountCopyWithImpl(this._self, this._then);

  final ProviderAccount _self;
  final $Res Function(ProviderAccount) _then;

/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? type = null,Object? credentials = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ProviderUsageType,credentials: null == credentials ? _self.credentials : credentials // ignore: cast_nullable_to_non_nullable
as ProviderCredentials,
  ));
}
/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderCredentialsCopyWith<$Res> get credentials {
  
  return $ProviderCredentialsCopyWith<$Res>(_self.credentials, (value) {
    return _then(_self.copyWith(credentials: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProviderAccount].
extension ProviderAccountPatterns on ProviderAccount {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderAccount value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderAccount() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderAccount value)  $default,){
final _that = this;
switch (_that) {
case _ProviderAccount():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderAccount value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderAccount() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? name,  ProviderUsageType type,  ProviderCredentials credentials)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderAccount() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.credentials);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? name,  ProviderUsageType type,  ProviderCredentials credentials)  $default,) {final _that = this;
switch (_that) {
case _ProviderAccount():
return $default(_that.id,_that.name,_that.type,_that.credentials);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? name,  ProviderUsageType type,  ProviderCredentials credentials)?  $default,) {final _that = this;
switch (_that) {
case _ProviderAccount() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.credentials);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderAccount implements ProviderAccount {
  const _ProviderAccount({required this.id, this.name, required this.type, required this.credentials});
  factory _ProviderAccount.fromJson(Map<String, dynamic> json) => _$ProviderAccountFromJson(json);

@override final  String id;
@override final  String? name;
@override final  ProviderUsageType type;
@override final  ProviderCredentials credentials;

/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderAccountCopyWith<_ProviderAccount> get copyWith => __$ProviderAccountCopyWithImpl<_ProviderAccount>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderAccountToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderAccount&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.credentials, credentials) || other.credentials == credentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,type,credentials);

@override
String toString() {
  return 'ProviderAccount(id: $id, name: $name, type: $type, credentials: $credentials)';
}


}

/// @nodoc
abstract mixin class _$ProviderAccountCopyWith<$Res> implements $ProviderAccountCopyWith<$Res> {
  factory _$ProviderAccountCopyWith(_ProviderAccount value, $Res Function(_ProviderAccount) _then) = __$ProviderAccountCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, ProviderUsageType type, ProviderCredentials credentials
});


@override $ProviderCredentialsCopyWith<$Res> get credentials;

}
/// @nodoc
class __$ProviderAccountCopyWithImpl<$Res>
    implements _$ProviderAccountCopyWith<$Res> {
  __$ProviderAccountCopyWithImpl(this._self, this._then);

  final _ProviderAccount _self;
  final $Res Function(_ProviderAccount) _then;

/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? type = null,Object? credentials = null,}) {
  return _then(_ProviderAccount(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ProviderUsageType,credentials: null == credentials ? _self.credentials : credentials // ignore: cast_nullable_to_non_nullable
as ProviderCredentials,
  ));
}

/// Create a copy of ProviderAccount
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProviderCredentialsCopyWith<$Res> get credentials {
  
  return $ProviderCredentialsCopyWith<$Res>(_self.credentials, (value) {
    return _then(_self.copyWith(credentials: value));
  });
}
}


/// @nodoc
mixin _$ProviderUsageWindow {

 String get label;/// Utilization as a percentage in the range 0-100.
 double get utilization;/// When this window resets, if known.
 int? get resetsAtMs;/// Usage limit for the window, if known.
 double? get limit;/// Amount used in the window, if known.
 double? get used;/// Amount remaining in the window, if known.
 double? get remaining;
/// Create a copy of ProviderUsageWindow
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderUsageWindowCopyWith<ProviderUsageWindow> get copyWith => _$ProviderUsageWindowCopyWithImpl<ProviderUsageWindow>(this as ProviderUsageWindow, _$identity);

  /// Serializes this ProviderUsageWindow to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderUsageWindow&&(identical(other.label, label) || other.label == label)&&(identical(other.utilization, utilization) || other.utilization == utilization)&&(identical(other.resetsAtMs, resetsAtMs) || other.resetsAtMs == resetsAtMs)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.used, used) || other.used == used)&&(identical(other.remaining, remaining) || other.remaining == remaining));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,utilization,resetsAtMs,limit,used,remaining);

@override
String toString() {
  return 'ProviderUsageWindow(label: $label, utilization: $utilization, resetsAtMs: $resetsAtMs, limit: $limit, used: $used, remaining: $remaining)';
}


}

/// @nodoc
abstract mixin class $ProviderUsageWindowCopyWith<$Res>  {
  factory $ProviderUsageWindowCopyWith(ProviderUsageWindow value, $Res Function(ProviderUsageWindow) _then) = _$ProviderUsageWindowCopyWithImpl;
@useResult
$Res call({
 String label, double utilization, int? resetsAtMs, double? limit, double? used, double? remaining
});




}
/// @nodoc
class _$ProviderUsageWindowCopyWithImpl<$Res>
    implements $ProviderUsageWindowCopyWith<$Res> {
  _$ProviderUsageWindowCopyWithImpl(this._self, this._then);

  final ProviderUsageWindow _self;
  final $Res Function(ProviderUsageWindow) _then;

/// Create a copy of ProviderUsageWindow
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? utilization = null,Object? resetsAtMs = freezed,Object? limit = freezed,Object? used = freezed,Object? remaining = freezed,}) {
  return _then(_self.copyWith(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,utilization: null == utilization ? _self.utilization : utilization // ignore: cast_nullable_to_non_nullable
as double,resetsAtMs: freezed == resetsAtMs ? _self.resetsAtMs : resetsAtMs // ignore: cast_nullable_to_non_nullable
as int?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as double?,used: freezed == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as double?,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderUsageWindow].
extension ProviderUsageWindowPatterns on ProviderUsageWindow {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderUsageWindow value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderUsageWindow() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderUsageWindow value)  $default,){
final _that = this;
switch (_that) {
case _ProviderUsageWindow():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderUsageWindow value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderUsageWindow() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  double utilization,  int? resetsAtMs,  double? limit,  double? used,  double? remaining)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderUsageWindow() when $default != null:
return $default(_that.label,_that.utilization,_that.resetsAtMs,_that.limit,_that.used,_that.remaining);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  double utilization,  int? resetsAtMs,  double? limit,  double? used,  double? remaining)  $default,) {final _that = this;
switch (_that) {
case _ProviderUsageWindow():
return $default(_that.label,_that.utilization,_that.resetsAtMs,_that.limit,_that.used,_that.remaining);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  double utilization,  int? resetsAtMs,  double? limit,  double? used,  double? remaining)?  $default,) {final _that = this;
switch (_that) {
case _ProviderUsageWindow() when $default != null:
return $default(_that.label,_that.utilization,_that.resetsAtMs,_that.limit,_that.used,_that.remaining);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderUsageWindow implements ProviderUsageWindow {
  const _ProviderUsageWindow({required this.label, this.utilization = 0.0, this.resetsAtMs, this.limit, this.used, this.remaining});
  factory _ProviderUsageWindow.fromJson(Map<String, dynamic> json) => _$ProviderUsageWindowFromJson(json);

@override final  String label;
/// Utilization as a percentage in the range 0-100.
@override@JsonKey() final  double utilization;
/// When this window resets, if known.
@override final  int? resetsAtMs;
/// Usage limit for the window, if known.
@override final  double? limit;
/// Amount used in the window, if known.
@override final  double? used;
/// Amount remaining in the window, if known.
@override final  double? remaining;

/// Create a copy of ProviderUsageWindow
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderUsageWindowCopyWith<_ProviderUsageWindow> get copyWith => __$ProviderUsageWindowCopyWithImpl<_ProviderUsageWindow>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderUsageWindowToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderUsageWindow&&(identical(other.label, label) || other.label == label)&&(identical(other.utilization, utilization) || other.utilization == utilization)&&(identical(other.resetsAtMs, resetsAtMs) || other.resetsAtMs == resetsAtMs)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.used, used) || other.used == used)&&(identical(other.remaining, remaining) || other.remaining == remaining));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,label,utilization,resetsAtMs,limit,used,remaining);

@override
String toString() {
  return 'ProviderUsageWindow(label: $label, utilization: $utilization, resetsAtMs: $resetsAtMs, limit: $limit, used: $used, remaining: $remaining)';
}


}

/// @nodoc
abstract mixin class _$ProviderUsageWindowCopyWith<$Res> implements $ProviderUsageWindowCopyWith<$Res> {
  factory _$ProviderUsageWindowCopyWith(_ProviderUsageWindow value, $Res Function(_ProviderUsageWindow) _then) = __$ProviderUsageWindowCopyWithImpl;
@override @useResult
$Res call({
 String label, double utilization, int? resetsAtMs, double? limit, double? used, double? remaining
});




}
/// @nodoc
class __$ProviderUsageWindowCopyWithImpl<$Res>
    implements _$ProviderUsageWindowCopyWith<$Res> {
  __$ProviderUsageWindowCopyWithImpl(this._self, this._then);

  final _ProviderUsageWindow _self;
  final $Res Function(_ProviderUsageWindow) _then;

/// Create a copy of ProviderUsageWindow
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? utilization = null,Object? resetsAtMs = freezed,Object? limit = freezed,Object? used = freezed,Object? remaining = freezed,}) {
  return _then(_ProviderUsageWindow(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,utilization: null == utilization ? _self.utilization : utilization // ignore: cast_nullable_to_non_nullable
as double,resetsAtMs: freezed == resetsAtMs ? _self.resetsAtMs : resetsAtMs // ignore: cast_nullable_to_non_nullable
as int?,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as double?,used: freezed == used ? _self.used : used // ignore: cast_nullable_to_non_nullable
as double?,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}


/// @nodoc
mixin _$ProviderUsage {

 String get accountId; ProviderUsageType get type; String? get accountName; List<ProviderUsageWindow> get windows;/// Provider-specific extra data (subscription info, feature quotas, ...).
 Map<String, dynamic> get extra;/// Error message if fetching usage failed for this account.
 String? get error;
/// Create a copy of ProviderUsage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderUsageCopyWith<ProviderUsage> get copyWith => _$ProviderUsageCopyWithImpl<ProviderUsage>(this as ProviderUsage, _$identity);

  /// Serializes this ProviderUsage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderUsage&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.type, type) || other.type == type)&&(identical(other.accountName, accountName) || other.accountName == accountName)&&const DeepCollectionEquality().equals(other.windows, windows)&&const DeepCollectionEquality().equals(other.extra, extra)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,type,accountName,const DeepCollectionEquality().hash(windows),const DeepCollectionEquality().hash(extra),error);

@override
String toString() {
  return 'ProviderUsage(accountId: $accountId, type: $type, accountName: $accountName, windows: $windows, extra: $extra, error: $error)';
}


}

/// @nodoc
abstract mixin class $ProviderUsageCopyWith<$Res>  {
  factory $ProviderUsageCopyWith(ProviderUsage value, $Res Function(ProviderUsage) _then) = _$ProviderUsageCopyWithImpl;
@useResult
$Res call({
 String accountId, ProviderUsageType type, String? accountName, List<ProviderUsageWindow> windows, Map<String, dynamic> extra, String? error
});




}
/// @nodoc
class _$ProviderUsageCopyWithImpl<$Res>
    implements $ProviderUsageCopyWith<$Res> {
  _$ProviderUsageCopyWithImpl(this._self, this._then);

  final ProviderUsage _self;
  final $Res Function(ProviderUsage) _then;

/// Create a copy of ProviderUsage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accountId = null,Object? type = null,Object? accountName = freezed,Object? windows = null,Object? extra = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ProviderUsageType,accountName: freezed == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String?,windows: null == windows ? _self.windows : windows // ignore: cast_nullable_to_non_nullable
as List<ProviderUsageWindow>,extra: null == extra ? _self.extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderUsage].
extension ProviderUsagePatterns on ProviderUsage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderUsage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderUsage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderUsage value)  $default,){
final _that = this;
switch (_that) {
case _ProviderUsage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderUsage value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderUsage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accountId,  ProviderUsageType type,  String? accountName,  List<ProviderUsageWindow> windows,  Map<String, dynamic> extra,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderUsage() when $default != null:
return $default(_that.accountId,_that.type,_that.accountName,_that.windows,_that.extra,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accountId,  ProviderUsageType type,  String? accountName,  List<ProviderUsageWindow> windows,  Map<String, dynamic> extra,  String? error)  $default,) {final _that = this;
switch (_that) {
case _ProviderUsage():
return $default(_that.accountId,_that.type,_that.accountName,_that.windows,_that.extra,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accountId,  ProviderUsageType type,  String? accountName,  List<ProviderUsageWindow> windows,  Map<String, dynamic> extra,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _ProviderUsage() when $default != null:
return $default(_that.accountId,_that.type,_that.accountName,_that.windows,_that.extra,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderUsage implements ProviderUsage {
  const _ProviderUsage({required this.accountId, required this.type, this.accountName, final  List<ProviderUsageWindow> windows = const <ProviderUsageWindow>[], final  Map<String, dynamic> extra = const <String, dynamic>{}, this.error}): _windows = windows,_extra = extra;
  factory _ProviderUsage.fromJson(Map<String, dynamic> json) => _$ProviderUsageFromJson(json);

@override final  String accountId;
@override final  ProviderUsageType type;
@override final  String? accountName;
 final  List<ProviderUsageWindow> _windows;
@override@JsonKey() List<ProviderUsageWindow> get windows {
  if (_windows is EqualUnmodifiableListView) return _windows;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_windows);
}

/// Provider-specific extra data (subscription info, feature quotas, ...).
 final  Map<String, dynamic> _extra;
/// Provider-specific extra data (subscription info, feature quotas, ...).
@override@JsonKey() Map<String, dynamic> get extra {
  if (_extra is EqualUnmodifiableMapView) return _extra;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_extra);
}

/// Error message if fetching usage failed for this account.
@override final  String? error;

/// Create a copy of ProviderUsage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderUsageCopyWith<_ProviderUsage> get copyWith => __$ProviderUsageCopyWithImpl<_ProviderUsage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderUsageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderUsage&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.type, type) || other.type == type)&&(identical(other.accountName, accountName) || other.accountName == accountName)&&const DeepCollectionEquality().equals(other._windows, _windows)&&const DeepCollectionEquality().equals(other._extra, _extra)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,accountId,type,accountName,const DeepCollectionEquality().hash(_windows),const DeepCollectionEquality().hash(_extra),error);

@override
String toString() {
  return 'ProviderUsage(accountId: $accountId, type: $type, accountName: $accountName, windows: $windows, extra: $extra, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ProviderUsageCopyWith<$Res> implements $ProviderUsageCopyWith<$Res> {
  factory _$ProviderUsageCopyWith(_ProviderUsage value, $Res Function(_ProviderUsage) _then) = __$ProviderUsageCopyWithImpl;
@override @useResult
$Res call({
 String accountId, ProviderUsageType type, String? accountName, List<ProviderUsageWindow> windows, Map<String, dynamic> extra, String? error
});




}
/// @nodoc
class __$ProviderUsageCopyWithImpl<$Res>
    implements _$ProviderUsageCopyWith<$Res> {
  __$ProviderUsageCopyWithImpl(this._self, this._then);

  final _ProviderUsage _self;
  final $Res Function(_ProviderUsage) _then;

/// Create a copy of ProviderUsage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accountId = null,Object? type = null,Object? accountName = freezed,Object? windows = null,Object? extra = null,Object? error = freezed,}) {
  return _then(_ProviderUsage(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ProviderUsageType,accountName: freezed == accountName ? _self.accountName : accountName // ignore: cast_nullable_to_non_nullable
as String?,windows: null == windows ? _self._windows : windows // ignore: cast_nullable_to_non_nullable
as List<ProviderUsageWindow>,extra: null == extra ? _self._extra : extra // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProviderUsageSummary {

 List<ProviderUsage> get usages; bool get isLoading; String? get globalError;
/// Create a copy of ProviderUsageSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProviderUsageSummaryCopyWith<ProviderUsageSummary> get copyWith => _$ProviderUsageSummaryCopyWithImpl<ProviderUsageSummary>(this as ProviderUsageSummary, _$identity);

  /// Serializes this ProviderUsageSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProviderUsageSummary&&const DeepCollectionEquality().equals(other.usages, usages)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.globalError, globalError) || other.globalError == globalError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(usages),isLoading,globalError);

@override
String toString() {
  return 'ProviderUsageSummary(usages: $usages, isLoading: $isLoading, globalError: $globalError)';
}


}

/// @nodoc
abstract mixin class $ProviderUsageSummaryCopyWith<$Res>  {
  factory $ProviderUsageSummaryCopyWith(ProviderUsageSummary value, $Res Function(ProviderUsageSummary) _then) = _$ProviderUsageSummaryCopyWithImpl;
@useResult
$Res call({
 List<ProviderUsage> usages, bool isLoading, String? globalError
});




}
/// @nodoc
class _$ProviderUsageSummaryCopyWithImpl<$Res>
    implements $ProviderUsageSummaryCopyWith<$Res> {
  _$ProviderUsageSummaryCopyWithImpl(this._self, this._then);

  final ProviderUsageSummary _self;
  final $Res Function(ProviderUsageSummary) _then;

/// Create a copy of ProviderUsageSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? usages = null,Object? isLoading = null,Object? globalError = freezed,}) {
  return _then(_self.copyWith(
usages: null == usages ? _self.usages : usages // ignore: cast_nullable_to_non_nullable
as List<ProviderUsage>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,globalError: freezed == globalError ? _self.globalError : globalError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProviderUsageSummary].
extension ProviderUsageSummaryPatterns on ProviderUsageSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProviderUsageSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProviderUsageSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProviderUsageSummary value)  $default,){
final _that = this;
switch (_that) {
case _ProviderUsageSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProviderUsageSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ProviderUsageSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ProviderUsage> usages,  bool isLoading,  String? globalError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProviderUsageSummary() when $default != null:
return $default(_that.usages,_that.isLoading,_that.globalError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ProviderUsage> usages,  bool isLoading,  String? globalError)  $default,) {final _that = this;
switch (_that) {
case _ProviderUsageSummary():
return $default(_that.usages,_that.isLoading,_that.globalError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ProviderUsage> usages,  bool isLoading,  String? globalError)?  $default,) {final _that = this;
switch (_that) {
case _ProviderUsageSummary() when $default != null:
return $default(_that.usages,_that.isLoading,_that.globalError);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProviderUsageSummary implements ProviderUsageSummary {
  const _ProviderUsageSummary({final  List<ProviderUsage> usages = const <ProviderUsage>[], this.isLoading = false, this.globalError}): _usages = usages;
  factory _ProviderUsageSummary.fromJson(Map<String, dynamic> json) => _$ProviderUsageSummaryFromJson(json);

 final  List<ProviderUsage> _usages;
@override@JsonKey() List<ProviderUsage> get usages {
  if (_usages is EqualUnmodifiableListView) return _usages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_usages);
}

@override@JsonKey() final  bool isLoading;
@override final  String? globalError;

/// Create a copy of ProviderUsageSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProviderUsageSummaryCopyWith<_ProviderUsageSummary> get copyWith => __$ProviderUsageSummaryCopyWithImpl<_ProviderUsageSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProviderUsageSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProviderUsageSummary&&const DeepCollectionEquality().equals(other._usages, _usages)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.globalError, globalError) || other.globalError == globalError));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_usages),isLoading,globalError);

@override
String toString() {
  return 'ProviderUsageSummary(usages: $usages, isLoading: $isLoading, globalError: $globalError)';
}


}

/// @nodoc
abstract mixin class _$ProviderUsageSummaryCopyWith<$Res> implements $ProviderUsageSummaryCopyWith<$Res> {
  factory _$ProviderUsageSummaryCopyWith(_ProviderUsageSummary value, $Res Function(_ProviderUsageSummary) _then) = __$ProviderUsageSummaryCopyWithImpl;
@override @useResult
$Res call({
 List<ProviderUsage> usages, bool isLoading, String? globalError
});




}
/// @nodoc
class __$ProviderUsageSummaryCopyWithImpl<$Res>
    implements _$ProviderUsageSummaryCopyWith<$Res> {
  __$ProviderUsageSummaryCopyWithImpl(this._self, this._then);

  final _ProviderUsageSummary _self;
  final $Res Function(_ProviderUsageSummary) _then;

/// Create a copy of ProviderUsageSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? usages = null,Object? isLoading = null,Object? globalError = freezed,}) {
  return _then(_ProviderUsageSummary(
usages: null == usages ? _self._usages : usages // ignore: cast_nullable_to_non_nullable
as List<ProviderUsage>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,globalError: freezed == globalError ? _self.globalError : globalError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
