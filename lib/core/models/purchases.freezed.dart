// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'purchases.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Purchases {

 List<String> get activeSubscriptions; Map<String, bool> get entitlements;
/// Create a copy of Purchases
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PurchasesCopyWith<Purchases> get copyWith => _$PurchasesCopyWithImpl<Purchases>(this as Purchases, _$identity);

  /// Serializes this Purchases to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Purchases&&const DeepCollectionEquality().equals(other.activeSubscriptions, activeSubscriptions)&&const DeepCollectionEquality().equals(other.entitlements, entitlements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(activeSubscriptions),const DeepCollectionEquality().hash(entitlements));

@override
String toString() {
  return 'Purchases(activeSubscriptions: $activeSubscriptions, entitlements: $entitlements)';
}


}

/// @nodoc
abstract mixin class $PurchasesCopyWith<$Res>  {
  factory $PurchasesCopyWith(Purchases value, $Res Function(Purchases) _then) = _$PurchasesCopyWithImpl;
@useResult
$Res call({
 List<String> activeSubscriptions, Map<String, bool> entitlements
});




}
/// @nodoc
class _$PurchasesCopyWithImpl<$Res>
    implements $PurchasesCopyWith<$Res> {
  _$PurchasesCopyWithImpl(this._self, this._then);

  final Purchases _self;
  final $Res Function(Purchases) _then;

/// Create a copy of Purchases
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? activeSubscriptions = null,Object? entitlements = null,}) {
  return _then(_self.copyWith(
activeSubscriptions: null == activeSubscriptions ? _self.activeSubscriptions : activeSubscriptions // ignore: cast_nullable_to_non_nullable
as List<String>,entitlements: null == entitlements ? _self.entitlements : entitlements // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,
  ));
}

}


/// Adds pattern-matching-related methods to [Purchases].
extension PurchasesPatterns on Purchases {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Purchases value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Purchases() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Purchases value)  $default,){
final _that = this;
switch (_that) {
case _Purchases():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Purchases value)?  $default,){
final _that = this;
switch (_that) {
case _Purchases() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> activeSubscriptions,  Map<String, bool> entitlements)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Purchases() when $default != null:
return $default(_that.activeSubscriptions,_that.entitlements);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> activeSubscriptions,  Map<String, bool> entitlements)  $default,) {final _that = this;
switch (_that) {
case _Purchases():
return $default(_that.activeSubscriptions,_that.entitlements);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> activeSubscriptions,  Map<String, bool> entitlements)?  $default,) {final _that = this;
switch (_that) {
case _Purchases() when $default != null:
return $default(_that.activeSubscriptions,_that.entitlements);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Purchases extends Purchases {
  const _Purchases({final  List<String> activeSubscriptions = const <String>[], final  Map<String, bool> entitlements = const <String, bool>{}}): _activeSubscriptions = activeSubscriptions,_entitlements = entitlements,super._();
  factory _Purchases.fromJson(Map<String, dynamic> json) => _$PurchasesFromJson(json);

 final  List<String> _activeSubscriptions;
@override@JsonKey() List<String> get activeSubscriptions {
  if (_activeSubscriptions is EqualUnmodifiableListView) return _activeSubscriptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_activeSubscriptions);
}

 final  Map<String, bool> _entitlements;
@override@JsonKey() Map<String, bool> get entitlements {
  if (_entitlements is EqualUnmodifiableMapView) return _entitlements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_entitlements);
}


/// Create a copy of Purchases
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PurchasesCopyWith<_Purchases> get copyWith => __$PurchasesCopyWithImpl<_Purchases>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PurchasesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Purchases&&const DeepCollectionEquality().equals(other._activeSubscriptions, _activeSubscriptions)&&const DeepCollectionEquality().equals(other._entitlements, _entitlements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_activeSubscriptions),const DeepCollectionEquality().hash(_entitlements));

@override
String toString() {
  return 'Purchases(activeSubscriptions: $activeSubscriptions, entitlements: $entitlements)';
}


}

/// @nodoc
abstract mixin class _$PurchasesCopyWith<$Res> implements $PurchasesCopyWith<$Res> {
  factory _$PurchasesCopyWith(_Purchases value, $Res Function(_Purchases) _then) = __$PurchasesCopyWithImpl;
@override @useResult
$Res call({
 List<String> activeSubscriptions, Map<String, bool> entitlements
});




}
/// @nodoc
class __$PurchasesCopyWithImpl<$Res>
    implements _$PurchasesCopyWith<$Res> {
  __$PurchasesCopyWithImpl(this._self, this._then);

  final _Purchases _self;
  final $Res Function(_Purchases) _then;

/// Create a copy of Purchases
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? activeSubscriptions = null,Object? entitlements = null,}) {
  return _then(_Purchases(
activeSubscriptions: null == activeSubscriptions ? _self._activeSubscriptions : activeSubscriptions // ignore: cast_nullable_to_non_nullable
as List<String>,entitlements: null == entitlements ? _self._entitlements : entitlements // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,
  ));
}


}

// dart format on
