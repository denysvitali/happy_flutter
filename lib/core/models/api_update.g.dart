// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApiUpdateNewMessage _$ApiUpdateNewMessageFromJson(Map<String, dynamic> json) =>
    _ApiUpdateNewMessage(
      t: json['t'] as String? ?? '',
      sid: json['sid'] as String? ?? '',
      message:
          json['message'] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

Map<String, dynamic> _$ApiUpdateNewMessageToJson(
  _ApiUpdateNewMessage instance,
) => <String, dynamic>{
  't': instance.t,
  'sid': instance.sid,
  'message': instance.message,
};

_ApiUpdateNewSession _$ApiUpdateNewSessionFromJson(Map<String, dynamic> json) =>
    _ApiUpdateNewSession(
      t: json['t'] as String? ?? '',
      id: json['id'] as String? ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$ApiUpdateNewSessionToJson(
  _ApiUpdateNewSession instance,
) => <String, dynamic>{
  't': instance.t,
  'id': instance.id,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};

_ApiDeleteSession _$ApiDeleteSessionFromJson(Map<String, dynamic> json) =>
    _ApiDeleteSession(
      t: json['t'] as String? ?? '',
      sid: json['sid'] as String? ?? '',
    );

Map<String, dynamic> _$ApiDeleteSessionToJson(_ApiDeleteSession instance) =>
    <String, dynamic>{'t': instance.t, 'sid': instance.sid};

_ApiUpdateSessionState _$ApiUpdateSessionStateFromJson(
  Map<String, dynamic> json,
) => _ApiUpdateSessionState(
  t: json['t'] as String? ?? '',
  id: json['id'] as String? ?? '',
  agentState: json['agentState'] == null
      ? null
      : VersionedValue.fromJson(json['agentState'] as Map<String, dynamic>),
  metadata: json['metadata'] == null
      ? null
      : VersionedValue.fromJson(json['metadata'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ApiUpdateSessionStateToJson(
  _ApiUpdateSessionState instance,
) => <String, dynamic>{
  't': instance.t,
  'id': instance.id,
  'agentState': instance.agentState?.toJson(),
  'metadata': instance.metadata?.toJson(),
};

_VersionedValue _$VersionedValueFromJson(Map<String, dynamic> json) =>
    _VersionedValue(
      version: (json['version'] as num?)?.toInt() ?? 0,
      value: json['value'] as String? ?? '',
    );

Map<String, dynamic> _$VersionedValueToJson(_VersionedValue instance) =>
    <String, dynamic>{'version': instance.version, 'value': instance.value};
