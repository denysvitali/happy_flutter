// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchases.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Purchases _$PurchasesFromJson(Map<String, dynamic> json) => _Purchases(
  activeSubscriptions:
      (json['activeSubscriptions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  entitlements:
      (json['entitlements'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as bool),
      ) ??
      const <String, bool>{},
);

Map<String, dynamic> _$PurchasesToJson(_Purchases instance) =>
    <String, dynamic>{
      'activeSubscriptions': instance.activeSubscriptions,
      'entitlements': instance.entitlements,
    };
