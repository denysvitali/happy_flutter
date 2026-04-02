// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'kv.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$KvItem {

 String get key; String get value; int get version;
/// Create a copy of KvItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KvItemCopyWith<KvItem> get copyWith => _$KvItemCopyWithImpl<KvItem>(this as KvItem, _$identity);

  /// Serializes this KvItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KvItem&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,value,version);

@override
String toString() {
  return 'KvItem(key: $key, value: $value, version: $version)';
}


}

/// @nodoc
abstract mixin class $KvItemCopyWith<$Res>  {
  factory $KvItemCopyWith(KvItem value, $Res Function(KvItem) _then) = _$KvItemCopyWithImpl;
@useResult
$Res call({
 String key, String value, int version
});




}
/// @nodoc
class _$KvItemCopyWithImpl<$Res>
    implements $KvItemCopyWith<$Res> {
  _$KvItemCopyWithImpl(this._self, this._then);

  final KvItem _self;
  final $Res Function(KvItem) _then;

/// Create a copy of KvItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? value = null,Object? version = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [KvItem].
extension KvItemPatterns on KvItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KvItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KvItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KvItem value)  $default,){
final _that = this;
switch (_that) {
case _KvItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KvItem value)?  $default,){
final _that = this;
switch (_that) {
case _KvItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String value,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KvItem() when $default != null:
return $default(_that.key,_that.value,_that.version);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String value,  int version)  $default,) {final _that = this;
switch (_that) {
case _KvItem():
return $default(_that.key,_that.value,_that.version);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String value,  int version)?  $default,) {final _that = this;
switch (_that) {
case _KvItem() when $default != null:
return $default(_that.key,_that.value,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KvItem implements KvItem {
  const _KvItem({required this.key, required this.value, required this.version});
  factory _KvItem.fromJson(Map<String, dynamic> json) => _$KvItemFromJson(json);

@override final  String key;
@override final  String value;
@override final  int version;

/// Create a copy of KvItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KvItemCopyWith<_KvItem> get copyWith => __$KvItemCopyWithImpl<_KvItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KvItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KvItem&&(identical(other.key, key) || other.key == key)&&(identical(other.value, value) || other.value == value)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,value,version);

@override
String toString() {
  return 'KvItem(key: $key, value: $value, version: $version)';
}


}

/// @nodoc
abstract mixin class _$KvItemCopyWith<$Res> implements $KvItemCopyWith<$Res> {
  factory _$KvItemCopyWith(_KvItem value, $Res Function(_KvItem) _then) = __$KvItemCopyWithImpl;
@override @useResult
$Res call({
 String key, String value, int version
});




}
/// @nodoc
class __$KvItemCopyWithImpl<$Res>
    implements _$KvItemCopyWith<$Res> {
  __$KvItemCopyWithImpl(this._self, this._then);

  final _KvItem _self;
  final $Res Function(_KvItem) _then;

/// Create a copy of KvItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? value = null,Object? version = null,}) {
  return _then(_KvItem(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$KvListResponse {

 List<KvItem> get items;
/// Create a copy of KvListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KvListResponseCopyWith<KvListResponse> get copyWith => _$KvListResponseCopyWithImpl<KvListResponse>(this as KvListResponse, _$identity);

  /// Serializes this KvListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KvListResponse&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'KvListResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class $KvListResponseCopyWith<$Res>  {
  factory $KvListResponseCopyWith(KvListResponse value, $Res Function(KvListResponse) _then) = _$KvListResponseCopyWithImpl;
@useResult
$Res call({
 List<KvItem> items
});




}
/// @nodoc
class _$KvListResponseCopyWithImpl<$Res>
    implements $KvListResponseCopyWith<$Res> {
  _$KvListResponseCopyWithImpl(this._self, this._then);

  final KvListResponse _self;
  final $Res Function(KvListResponse) _then;

/// Create a copy of KvListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<KvItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [KvListResponse].
extension KvListResponsePatterns on KvListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KvListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KvListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KvListResponse value)  $default,){
final _that = this;
switch (_that) {
case _KvListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KvListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _KvListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<KvItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KvListResponse() when $default != null:
return $default(_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<KvItem> items)  $default,) {final _that = this;
switch (_that) {
case _KvListResponse():
return $default(_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<KvItem> items)?  $default,) {final _that = this;
switch (_that) {
case _KvListResponse() when $default != null:
return $default(_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KvListResponse implements KvListResponse {
  const _KvListResponse({required final  List<KvItem> items}): _items = items;
  factory _KvListResponse.fromJson(Map<String, dynamic> json) => _$KvListResponseFromJson(json);

 final  List<KvItem> _items;
@override List<KvItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


/// Create a copy of KvListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KvListResponseCopyWith<_KvListResponse> get copyWith => __$KvListResponseCopyWithImpl<_KvListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KvListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KvListResponse&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'KvListResponse(items: $items)';
}


}

/// @nodoc
abstract mixin class _$KvListResponseCopyWith<$Res> implements $KvListResponseCopyWith<$Res> {
  factory _$KvListResponseCopyWith(_KvListResponse value, $Res Function(_KvListResponse) _then) = __$KvListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<KvItem> items
});




}
/// @nodoc
class __$KvListResponseCopyWithImpl<$Res>
    implements _$KvListResponseCopyWith<$Res> {
  __$KvListResponseCopyWithImpl(this._self, this._then);

  final _KvListResponse _self;
  final $Res Function(_KvListResponse) _then;

/// Create a copy of KvListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,}) {
  return _then(_KvListResponse(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<KvItem>,
  ));
}


}


/// @nodoc
mixin _$KvBulkGetRequest {

 List<String> get keys;
/// Create a copy of KvBulkGetRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KvBulkGetRequestCopyWith<KvBulkGetRequest> get copyWith => _$KvBulkGetRequestCopyWithImpl<KvBulkGetRequest>(this as KvBulkGetRequest, _$identity);

  /// Serializes this KvBulkGetRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KvBulkGetRequest&&const DeepCollectionEquality().equals(other.keys, keys));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(keys));

@override
String toString() {
  return 'KvBulkGetRequest(keys: $keys)';
}


}

/// @nodoc
abstract mixin class $KvBulkGetRequestCopyWith<$Res>  {
  factory $KvBulkGetRequestCopyWith(KvBulkGetRequest value, $Res Function(KvBulkGetRequest) _then) = _$KvBulkGetRequestCopyWithImpl;
@useResult
$Res call({
 List<String> keys
});




}
/// @nodoc
class _$KvBulkGetRequestCopyWithImpl<$Res>
    implements $KvBulkGetRequestCopyWith<$Res> {
  _$KvBulkGetRequestCopyWithImpl(this._self, this._then);

  final KvBulkGetRequest _self;
  final $Res Function(KvBulkGetRequest) _then;

/// Create a copy of KvBulkGetRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? keys = null,}) {
  return _then(_self.copyWith(
keys: null == keys ? _self.keys : keys // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [KvBulkGetRequest].
extension KvBulkGetRequestPatterns on KvBulkGetRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KvBulkGetRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KvBulkGetRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KvBulkGetRequest value)  $default,){
final _that = this;
switch (_that) {
case _KvBulkGetRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KvBulkGetRequest value)?  $default,){
final _that = this;
switch (_that) {
case _KvBulkGetRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> keys)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KvBulkGetRequest() when $default != null:
return $default(_that.keys);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> keys)  $default,) {final _that = this;
switch (_that) {
case _KvBulkGetRequest():
return $default(_that.keys);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> keys)?  $default,) {final _that = this;
switch (_that) {
case _KvBulkGetRequest() when $default != null:
return $default(_that.keys);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KvBulkGetRequest implements KvBulkGetRequest {
  const _KvBulkGetRequest({required final  List<String> keys}): _keys = keys;
  factory _KvBulkGetRequest.fromJson(Map<String, dynamic> json) => _$KvBulkGetRequestFromJson(json);

 final  List<String> _keys;
@override List<String> get keys {
  if (_keys is EqualUnmodifiableListView) return _keys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_keys);
}


/// Create a copy of KvBulkGetRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KvBulkGetRequestCopyWith<_KvBulkGetRequest> get copyWith => __$KvBulkGetRequestCopyWithImpl<_KvBulkGetRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KvBulkGetRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KvBulkGetRequest&&const DeepCollectionEquality().equals(other._keys, _keys));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_keys));

@override
String toString() {
  return 'KvBulkGetRequest(keys: $keys)';
}


}

/// @nodoc
abstract mixin class _$KvBulkGetRequestCopyWith<$Res> implements $KvBulkGetRequestCopyWith<$Res> {
  factory _$KvBulkGetRequestCopyWith(_KvBulkGetRequest value, $Res Function(_KvBulkGetRequest) _then) = __$KvBulkGetRequestCopyWithImpl;
@override @useResult
$Res call({
 List<String> keys
});




}
/// @nodoc
class __$KvBulkGetRequestCopyWithImpl<$Res>
    implements _$KvBulkGetRequestCopyWith<$Res> {
  __$KvBulkGetRequestCopyWithImpl(this._self, this._then);

  final _KvBulkGetRequest _self;
  final $Res Function(_KvBulkGetRequest) _then;

/// Create a copy of KvBulkGetRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? keys = null,}) {
  return _then(_KvBulkGetRequest(
keys: null == keys ? _self._keys : keys // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}


/// @nodoc
mixin _$KvBulkGetResponse {

 List<KvItem> get values;
/// Create a copy of KvBulkGetResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KvBulkGetResponseCopyWith<KvBulkGetResponse> get copyWith => _$KvBulkGetResponseCopyWithImpl<KvBulkGetResponse>(this as KvBulkGetResponse, _$identity);

  /// Serializes this KvBulkGetResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KvBulkGetResponse&&const DeepCollectionEquality().equals(other.values, values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(values));

@override
String toString() {
  return 'KvBulkGetResponse(values: $values)';
}


}

/// @nodoc
abstract mixin class $KvBulkGetResponseCopyWith<$Res>  {
  factory $KvBulkGetResponseCopyWith(KvBulkGetResponse value, $Res Function(KvBulkGetResponse) _then) = _$KvBulkGetResponseCopyWithImpl;
@useResult
$Res call({
 List<KvItem> values
});




}
/// @nodoc
class _$KvBulkGetResponseCopyWithImpl<$Res>
    implements $KvBulkGetResponseCopyWith<$Res> {
  _$KvBulkGetResponseCopyWithImpl(this._self, this._then);

  final KvBulkGetResponse _self;
  final $Res Function(KvBulkGetResponse) _then;

/// Create a copy of KvBulkGetResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? values = null,}) {
  return _then(_self.copyWith(
values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as List<KvItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [KvBulkGetResponse].
extension KvBulkGetResponsePatterns on KvBulkGetResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KvBulkGetResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KvBulkGetResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KvBulkGetResponse value)  $default,){
final _that = this;
switch (_that) {
case _KvBulkGetResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KvBulkGetResponse value)?  $default,){
final _that = this;
switch (_that) {
case _KvBulkGetResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<KvItem> values)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KvBulkGetResponse() when $default != null:
return $default(_that.values);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<KvItem> values)  $default,) {final _that = this;
switch (_that) {
case _KvBulkGetResponse():
return $default(_that.values);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<KvItem> values)?  $default,) {final _that = this;
switch (_that) {
case _KvBulkGetResponse() when $default != null:
return $default(_that.values);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KvBulkGetResponse implements KvBulkGetResponse {
  const _KvBulkGetResponse({required final  List<KvItem> values}): _values = values;
  factory _KvBulkGetResponse.fromJson(Map<String, dynamic> json) => _$KvBulkGetResponseFromJson(json);

 final  List<KvItem> _values;
@override List<KvItem> get values {
  if (_values is EqualUnmodifiableListView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_values);
}


/// Create a copy of KvBulkGetResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KvBulkGetResponseCopyWith<_KvBulkGetResponse> get copyWith => __$KvBulkGetResponseCopyWithImpl<_KvBulkGetResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KvBulkGetResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KvBulkGetResponse&&const DeepCollectionEquality().equals(other._values, _values));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_values));

@override
String toString() {
  return 'KvBulkGetResponse(values: $values)';
}


}

/// @nodoc
abstract mixin class _$KvBulkGetResponseCopyWith<$Res> implements $KvBulkGetResponseCopyWith<$Res> {
  factory _$KvBulkGetResponseCopyWith(_KvBulkGetResponse value, $Res Function(_KvBulkGetResponse) _then) = __$KvBulkGetResponseCopyWithImpl;
@override @useResult
$Res call({
 List<KvItem> values
});




}
/// @nodoc
class __$KvBulkGetResponseCopyWithImpl<$Res>
    implements _$KvBulkGetResponseCopyWith<$Res> {
  __$KvBulkGetResponseCopyWithImpl(this._self, this._then);

  final _KvBulkGetResponse _self;
  final $Res Function(_KvBulkGetResponse) _then;

/// Create a copy of KvBulkGetResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? values = null,}) {
  return _then(_KvBulkGetResponse(
values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as List<KvItem>,
  ));
}


}


/// @nodoc
mixin _$KvMutation {

 String get key; int get version;// -1 for new keys
 String? get value;
/// Create a copy of KvMutation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KvMutationCopyWith<KvMutation> get copyWith => _$KvMutationCopyWithImpl<KvMutation>(this as KvMutation, _$identity);

  /// Serializes this KvMutation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KvMutation&&(identical(other.key, key) || other.key == key)&&(identical(other.version, version) || other.version == version)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,version,value);

@override
String toString() {
  return 'KvMutation(key: $key, version: $version, value: $value)';
}


}

/// @nodoc
abstract mixin class $KvMutationCopyWith<$Res>  {
  factory $KvMutationCopyWith(KvMutation value, $Res Function(KvMutation) _then) = _$KvMutationCopyWithImpl;
@useResult
$Res call({
 String key, int version, String? value
});




}
/// @nodoc
class _$KvMutationCopyWithImpl<$Res>
    implements $KvMutationCopyWith<$Res> {
  _$KvMutationCopyWithImpl(this._self, this._then);

  final KvMutation _self;
  final $Res Function(KvMutation) _then;

/// Create a copy of KvMutation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? version = null,Object? value = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [KvMutation].
extension KvMutationPatterns on KvMutation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KvMutation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KvMutation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KvMutation value)  $default,){
final _that = this;
switch (_that) {
case _KvMutation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KvMutation value)?  $default,){
final _that = this;
switch (_that) {
case _KvMutation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  int version,  String? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KvMutation() when $default != null:
return $default(_that.key,_that.version,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  int version,  String? value)  $default,) {final _that = this;
switch (_that) {
case _KvMutation():
return $default(_that.key,_that.version,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  int version,  String? value)?  $default,) {final _that = this;
switch (_that) {
case _KvMutation() when $default != null:
return $default(_that.key,_that.version,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KvMutation implements KvMutation {
  const _KvMutation({required this.key, required this.version, this.value});
  factory _KvMutation.fromJson(Map<String, dynamic> json) => _$KvMutationFromJson(json);

@override final  String key;
@override final  int version;
// -1 for new keys
@override final  String? value;

/// Create a copy of KvMutation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KvMutationCopyWith<_KvMutation> get copyWith => __$KvMutationCopyWithImpl<_KvMutation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KvMutationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KvMutation&&(identical(other.key, key) || other.key == key)&&(identical(other.version, version) || other.version == version)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,version,value);

@override
String toString() {
  return 'KvMutation(key: $key, version: $version, value: $value)';
}


}

/// @nodoc
abstract mixin class _$KvMutationCopyWith<$Res> implements $KvMutationCopyWith<$Res> {
  factory _$KvMutationCopyWith(_KvMutation value, $Res Function(_KvMutation) _then) = __$KvMutationCopyWithImpl;
@override @useResult
$Res call({
 String key, int version, String? value
});




}
/// @nodoc
class __$KvMutationCopyWithImpl<$Res>
    implements _$KvMutationCopyWith<$Res> {
  __$KvMutationCopyWithImpl(this._self, this._then);

  final _KvMutation _self;
  final $Res Function(_KvMutation) _then;

/// Create a copy of KvMutation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? version = null,Object? value = freezed,}) {
  return _then(_KvMutation(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$KvMutateRequest {

 List<KvMutation> get mutations;
/// Create a copy of KvMutateRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KvMutateRequestCopyWith<KvMutateRequest> get copyWith => _$KvMutateRequestCopyWithImpl<KvMutateRequest>(this as KvMutateRequest, _$identity);

  /// Serializes this KvMutateRequest to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KvMutateRequest&&const DeepCollectionEquality().equals(other.mutations, mutations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(mutations));

@override
String toString() {
  return 'KvMutateRequest(mutations: $mutations)';
}


}

/// @nodoc
abstract mixin class $KvMutateRequestCopyWith<$Res>  {
  factory $KvMutateRequestCopyWith(KvMutateRequest value, $Res Function(KvMutateRequest) _then) = _$KvMutateRequestCopyWithImpl;
@useResult
$Res call({
 List<KvMutation> mutations
});




}
/// @nodoc
class _$KvMutateRequestCopyWithImpl<$Res>
    implements $KvMutateRequestCopyWith<$Res> {
  _$KvMutateRequestCopyWithImpl(this._self, this._then);

  final KvMutateRequest _self;
  final $Res Function(KvMutateRequest) _then;

/// Create a copy of KvMutateRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mutations = null,}) {
  return _then(_self.copyWith(
mutations: null == mutations ? _self.mutations : mutations // ignore: cast_nullable_to_non_nullable
as List<KvMutation>,
  ));
}

}


/// Adds pattern-matching-related methods to [KvMutateRequest].
extension KvMutateRequestPatterns on KvMutateRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KvMutateRequest value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KvMutateRequest() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KvMutateRequest value)  $default,){
final _that = this;
switch (_that) {
case _KvMutateRequest():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KvMutateRequest value)?  $default,){
final _that = this;
switch (_that) {
case _KvMutateRequest() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<KvMutation> mutations)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KvMutateRequest() when $default != null:
return $default(_that.mutations);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<KvMutation> mutations)  $default,) {final _that = this;
switch (_that) {
case _KvMutateRequest():
return $default(_that.mutations);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<KvMutation> mutations)?  $default,) {final _that = this;
switch (_that) {
case _KvMutateRequest() when $default != null:
return $default(_that.mutations);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KvMutateRequest implements KvMutateRequest {
  const _KvMutateRequest({required final  List<KvMutation> mutations}): _mutations = mutations;
  factory _KvMutateRequest.fromJson(Map<String, dynamic> json) => _$KvMutateRequestFromJson(json);

 final  List<KvMutation> _mutations;
@override List<KvMutation> get mutations {
  if (_mutations is EqualUnmodifiableListView) return _mutations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mutations);
}


/// Create a copy of KvMutateRequest
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KvMutateRequestCopyWith<_KvMutateRequest> get copyWith => __$KvMutateRequestCopyWithImpl<_KvMutateRequest>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KvMutateRequestToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KvMutateRequest&&const DeepCollectionEquality().equals(other._mutations, _mutations));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_mutations));

@override
String toString() {
  return 'KvMutateRequest(mutations: $mutations)';
}


}

/// @nodoc
abstract mixin class _$KvMutateRequestCopyWith<$Res> implements $KvMutateRequestCopyWith<$Res> {
  factory _$KvMutateRequestCopyWith(_KvMutateRequest value, $Res Function(_KvMutateRequest) _then) = __$KvMutateRequestCopyWithImpl;
@override @useResult
$Res call({
 List<KvMutation> mutations
});




}
/// @nodoc
class __$KvMutateRequestCopyWithImpl<$Res>
    implements _$KvMutateRequestCopyWith<$Res> {
  __$KvMutateRequestCopyWithImpl(this._self, this._then);

  final _KvMutateRequest _self;
  final $Res Function(_KvMutateRequest) _then;

/// Create a copy of KvMutateRequest
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mutations = null,}) {
  return _then(_KvMutateRequest(
mutations: null == mutations ? _self._mutations : mutations // ignore: cast_nullable_to_non_nullable
as List<KvMutation>,
  ));
}


}


/// @nodoc
mixin _$KvMutateResult {

 String get key; int get version;
/// Create a copy of KvMutateResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KvMutateResultCopyWith<KvMutateResult> get copyWith => _$KvMutateResultCopyWithImpl<KvMutateResult>(this as KvMutateResult, _$identity);

  /// Serializes this KvMutateResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KvMutateResult&&(identical(other.key, key) || other.key == key)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,version);

@override
String toString() {
  return 'KvMutateResult(key: $key, version: $version)';
}


}

/// @nodoc
abstract mixin class $KvMutateResultCopyWith<$Res>  {
  factory $KvMutateResultCopyWith(KvMutateResult value, $Res Function(KvMutateResult) _then) = _$KvMutateResultCopyWithImpl;
@useResult
$Res call({
 String key, int version
});




}
/// @nodoc
class _$KvMutateResultCopyWithImpl<$Res>
    implements $KvMutateResultCopyWith<$Res> {
  _$KvMutateResultCopyWithImpl(this._self, this._then);

  final KvMutateResult _self;
  final $Res Function(KvMutateResult) _then;

/// Create a copy of KvMutateResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? version = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [KvMutateResult].
extension KvMutateResultPatterns on KvMutateResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KvMutateResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KvMutateResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KvMutateResult value)  $default,){
final _that = this;
switch (_that) {
case _KvMutateResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KvMutateResult value)?  $default,){
final _that = this;
switch (_that) {
case _KvMutateResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  int version)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KvMutateResult() when $default != null:
return $default(_that.key,_that.version);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  int version)  $default,) {final _that = this;
switch (_that) {
case _KvMutateResult():
return $default(_that.key,_that.version);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  int version)?  $default,) {final _that = this;
switch (_that) {
case _KvMutateResult() when $default != null:
return $default(_that.key,_that.version);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KvMutateResult implements KvMutateResult {
  const _KvMutateResult({required this.key, required this.version});
  factory _KvMutateResult.fromJson(Map<String, dynamic> json) => _$KvMutateResultFromJson(json);

@override final  String key;
@override final  int version;

/// Create a copy of KvMutateResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KvMutateResultCopyWith<_KvMutateResult> get copyWith => __$KvMutateResultCopyWithImpl<_KvMutateResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KvMutateResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KvMutateResult&&(identical(other.key, key) || other.key == key)&&(identical(other.version, version) || other.version == version));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,version);

@override
String toString() {
  return 'KvMutateResult(key: $key, version: $version)';
}


}

/// @nodoc
abstract mixin class _$KvMutateResultCopyWith<$Res> implements $KvMutateResultCopyWith<$Res> {
  factory _$KvMutateResultCopyWith(_KvMutateResult value, $Res Function(_KvMutateResult) _then) = __$KvMutateResultCopyWithImpl;
@override @useResult
$Res call({
 String key, int version
});




}
/// @nodoc
class __$KvMutateResultCopyWithImpl<$Res>
    implements _$KvMutateResultCopyWith<$Res> {
  __$KvMutateResultCopyWithImpl(this._self, this._then);

  final _KvMutateResult _self;
  final $Res Function(_KvMutateResult) _then;

/// Create a copy of KvMutateResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? version = null,}) {
  return _then(_KvMutateResult(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$KvMutateError {

 String get key; String get error;// 'version-mismatch'
 int get version; String? get value;
/// Create a copy of KvMutateError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$KvMutateErrorCopyWith<KvMutateError> get copyWith => _$KvMutateErrorCopyWithImpl<KvMutateError>(this as KvMutateError, _$identity);

  /// Serializes this KvMutateError to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is KvMutateError&&(identical(other.key, key) || other.key == key)&&(identical(other.error, error) || other.error == error)&&(identical(other.version, version) || other.version == version)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,error,version,value);

@override
String toString() {
  return 'KvMutateError(key: $key, error: $error, version: $version, value: $value)';
}


}

/// @nodoc
abstract mixin class $KvMutateErrorCopyWith<$Res>  {
  factory $KvMutateErrorCopyWith(KvMutateError value, $Res Function(KvMutateError) _then) = _$KvMutateErrorCopyWithImpl;
@useResult
$Res call({
 String key, String error, int version, String? value
});




}
/// @nodoc
class _$KvMutateErrorCopyWithImpl<$Res>
    implements $KvMutateErrorCopyWith<$Res> {
  _$KvMutateErrorCopyWithImpl(this._self, this._then);

  final KvMutateError _self;
  final $Res Function(KvMutateError) _then;

/// Create a copy of KvMutateError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? error = null,Object? version = null,Object? value = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [KvMutateError].
extension KvMutateErrorPatterns on KvMutateError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _KvMutateError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _KvMutateError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _KvMutateError value)  $default,){
final _that = this;
switch (_that) {
case _KvMutateError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _KvMutateError value)?  $default,){
final _that = this;
switch (_that) {
case _KvMutateError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String error,  int version,  String? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _KvMutateError() when $default != null:
return $default(_that.key,_that.error,_that.version,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String error,  int version,  String? value)  $default,) {final _that = this;
switch (_that) {
case _KvMutateError():
return $default(_that.key,_that.error,_that.version,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String error,  int version,  String? value)?  $default,) {final _that = this;
switch (_that) {
case _KvMutateError() when $default != null:
return $default(_that.key,_that.error,_that.version,_that.value);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _KvMutateError implements KvMutateError {
  const _KvMutateError({required this.key, required this.error, required this.version, this.value});
  factory _KvMutateError.fromJson(Map<String, dynamic> json) => _$KvMutateErrorFromJson(json);

@override final  String key;
@override final  String error;
// 'version-mismatch'
@override final  int version;
@override final  String? value;

/// Create a copy of KvMutateError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$KvMutateErrorCopyWith<_KvMutateError> get copyWith => __$KvMutateErrorCopyWithImpl<_KvMutateError>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$KvMutateErrorToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _KvMutateError&&(identical(other.key, key) || other.key == key)&&(identical(other.error, error) || other.error == error)&&(identical(other.version, version) || other.version == version)&&(identical(other.value, value) || other.value == value));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,error,version,value);

@override
String toString() {
  return 'KvMutateError(key: $key, error: $error, version: $version, value: $value)';
}


}

/// @nodoc
abstract mixin class _$KvMutateErrorCopyWith<$Res> implements $KvMutateErrorCopyWith<$Res> {
  factory _$KvMutateErrorCopyWith(_KvMutateError value, $Res Function(_KvMutateError) _then) = __$KvMutateErrorCopyWithImpl;
@override @useResult
$Res call({
 String key, String error, int version, String? value
});




}
/// @nodoc
class __$KvMutateErrorCopyWithImpl<$Res>
    implements _$KvMutateErrorCopyWith<$Res> {
  __$KvMutateErrorCopyWithImpl(this._self, this._then);

  final _KvMutateError _self;
  final $Res Function(_KvMutateError) _then;

/// Create a copy of KvMutateError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? error = null,Object? version = null,Object? value = freezed,}) {
  return _then(_KvMutateError(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,value: freezed == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
