// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UsageDataPoint _$UsageDataPointFromJson(Map<String, dynamic> json) =>
    _UsageDataPoint(
      timestamp: json['timestamp'] == null ? 0 : _asUsageInt(json['timestamp']),
      tokens: json['tokens'] == null
          ? const <String, int>{}
          : _tokensFromJson(json['tokens']),
      cost: json['cost'] == null
          ? const <String, double>{}
          : _costFromJson(json['cost']),
      reportCount: json['reportCount'] == null
          ? 0
          : _asUsageInt(json['reportCount']),
    );

Map<String, dynamic> _$UsageDataPointToJson(_UsageDataPoint instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'tokens': instance.tokens,
      'cost': instance.cost,
      'reportCount': instance.reportCount,
    };

_UsageResponse _$UsageResponseFromJson(Map<String, dynamic> json) =>
    _UsageResponse(
      usage: (json['usage'] as List<dynamic>)
          .map((e) => UsageDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UsageResponseToJson(_UsageResponse instance) =>
    <String, dynamic>{'usage': instance.usage.map((e) => e.toJson()).toList()};

_UsageQueryParams _$UsageQueryParamsFromJson(Map<String, dynamic> json) =>
    _UsageQueryParams(
      sessionId: json['sessionId'] as String?,
      startTime: (json['startTime'] as num?)?.toInt(),
      endTime: (json['endTime'] as num?)?.toInt(),
      groupBy: $enumDecodeNullable(_$UsageGroupByEnumMap, json['groupBy']),
    );

Map<String, dynamic> _$UsageQueryParamsToJson(_UsageQueryParams instance) {
  final json = <String, dynamic>{};
  if (instance.sessionId != null) json['sessionId'] = instance.sessionId;
  if (instance.startTime != null) json['startTime'] = instance.startTime;
  if (instance.endTime != null) json['endTime'] = instance.endTime;
  if (instance.groupBy != null) {
    json['groupBy'] = _$UsageGroupByEnumMap[instance.groupBy];
  }
  return json;
}

const _$UsageGroupByEnumMap = {
  UsageGroupBy.hour: 'hour',
  UsageGroupBy.day: 'day',
};
