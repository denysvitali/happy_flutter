// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kv.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_KvItem _$KvItemFromJson(Map<String, dynamic> json) => _KvItem(
  key: json['key'] as String,
  value: json['value'] as String,
  version: (json['version'] as num).toInt(),
);

Map<String, dynamic> _$KvItemToJson(_KvItem instance) => <String, dynamic>{
  'key': instance.key,
  'value': instance.value,
  'version': instance.version,
};

_KvListResponse _$KvListResponseFromJson(Map<String, dynamic> json) =>
    _KvListResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => KvItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$KvListResponseToJson(_KvListResponse instance) =>
    <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};

_KvBulkGetRequest _$KvBulkGetRequestFromJson(Map<String, dynamic> json) =>
    _KvBulkGetRequest(
      keys: (json['keys'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$KvBulkGetRequestToJson(_KvBulkGetRequest instance) =>
    <String, dynamic>{'keys': instance.keys};

_KvBulkGetResponse _$KvBulkGetResponseFromJson(Map<String, dynamic> json) =>
    _KvBulkGetResponse(
      values: (json['values'] as List<dynamic>)
          .map((e) => KvItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$KvBulkGetResponseToJson(_KvBulkGetResponse instance) =>
    <String, dynamic>{
      'values': instance.values.map((e) => e.toJson()).toList(),
    };

_KvMutation _$KvMutationFromJson(Map<String, dynamic> json) => _KvMutation(
  key: json['key'] as String,
  version: (json['version'] as num).toInt(),
  value: json['value'] as String?,
);

Map<String, dynamic> _$KvMutationToJson(_KvMutation instance) =>
    <String, dynamic>{
      'key': instance.key,
      'version': instance.version,
      'value': instance.value,
    };

_KvMutateRequest _$KvMutateRequestFromJson(Map<String, dynamic> json) =>
    _KvMutateRequest(
      mutations: (json['mutations'] as List<dynamic>)
          .map((e) => KvMutation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$KvMutateRequestToJson(_KvMutateRequest instance) =>
    <String, dynamic>{
      'mutations': instance.mutations.map((e) => e.toJson()).toList(),
    };

_KvMutateResult _$KvMutateResultFromJson(Map<String, dynamic> json) =>
    _KvMutateResult(
      key: json['key'] as String,
      version: (json['version'] as num).toInt(),
    );

Map<String, dynamic> _$KvMutateResultToJson(_KvMutateResult instance) =>
    <String, dynamic>{'key': instance.key, 'version': instance.version};

_KvMutateError _$KvMutateErrorFromJson(Map<String, dynamic> json) =>
    _KvMutateError(
      key: json['key'] as String,
      error: json['error'] as String,
      version: (json['version'] as num).toInt(),
      value: json['value'] as String?,
    );

Map<String, dynamic> _$KvMutateErrorToJson(_KvMutateError instance) =>
    <String, dynamic>{
      'key': instance.key,
      'error': instance.error,
      'version': instance.version,
      'value': instance.value,
    };
