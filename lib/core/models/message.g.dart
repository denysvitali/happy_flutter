// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessageMeta _$MessageMetaFromJson(Map<String, dynamic> json) => MessageMeta();

Map<String, dynamic> _$MessageMetaToJson(MessageMeta instance) =>
    <String, dynamic>{};

_ApiMessage _$ApiMessageFromJson(Map<String, dynamic> json) => _ApiMessage(
  content: _contentFromJson(json['content']),
  id: json['id'] as String? ?? '',
  seq: json['seq'] == null ? 0 : _asApiInt(json['seq']),
  localId: json['localId'] as String?,
  createdAt: json['createdAt'] == null ? 0 : _asApiInt(json['createdAt']),
  updatedAt: _asApiIntNullable(json['updatedAt']),
);

Map<String, dynamic> _$ApiMessageToJson(_ApiMessage instance) =>
    <String, dynamic>{
      'content': instance.content.toJson(),
      'id': instance.id,
      'seq': instance.seq,
      'localId': instance.localId,
      'createdAt': instance.createdAt,
      'updatedAt': instance.updatedAt,
    };

_ApiMessageContent _$ApiMessageContentFromJson(Map<String, dynamic> json) =>
    _ApiMessageContent(
      t: json['t'] as String? ?? '',
      c: json['c'] as String? ?? '',
    );

Map<String, dynamic> _$ApiMessageContentToJson(_ApiMessageContent instance) =>
    <String, dynamic>{'t': instance.t, 'c': instance.c};

_ToolCall _$ToolCallFromJson(Map<String, dynamic> json) => _ToolCall(
  name: json['name'] as String,
  state: json['state'] as String,
  createdAt: (json['createdAt'] as num).toInt(),
  input: _mapOrNull(json['input']),
  startedAt: (json['startedAt'] as num?)?.toInt(),
  completedAt: (json['completedAt'] as num?)?.toInt(),
  description: json['description'] as String?,
  result: _mapOrNull(json['result']),
  permission: _permissionOrNull(json['permission']),
);

Map<String, dynamic> _$ToolCallToJson(_ToolCall instance) => <String, dynamic>{
  'name': instance.name,
  'state': instance.state,
  'createdAt': instance.createdAt,
  'input': instance.input,
  'startedAt': instance.startedAt,
  'completedAt': instance.completedAt,
  'description': instance.description,
  'result': instance.result,
  'permission': instance.permission?.toJson(),
};

_Permission _$PermissionFromJson(Map<String, dynamic> json) => _Permission(
  id: json['id'] as String,
  status: json['status'] as String,
  reason: json['reason'] as String?,
  mode: json['mode'] as String?,
  allowedTools: _stringListOrNull(json['allowedTools']),
  decision: json['decision'] as String?,
  date: (json['date'] as num?)?.toInt(),
);

Map<String, dynamic> _$PermissionToJson(_Permission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'reason': instance.reason,
      'mode': instance.mode,
      'allowedTools': instance.allowedTools,
      'decision': instance.decision,
      'date': instance.date,
    };

_MessageMeta _$MessageMetaFromJson(Map<String, dynamic> json) => _MessageMeta(
  sentFrom: json['sentFrom'] as String?,
  permissionMode: json['permissionMode'] as String?,
  model: json['model'] as String?,
  fallbackModel: json['fallbackModel'] as String?,
  customSystemPrompt: json['customSystemPrompt'] as String?,
  appendSystemPrompt: json['appendSystemPrompt'] as String?,
  allowedTools: _stringListOrNull(json['allowedTools']),
  disallowedTools: _stringListOrNull(json['disallowedTools']),
  displayText: json['displayText'] as String?,
);

Map<String, dynamic> _$MessageMetaToJson(_MessageMeta instance) =>
    <String, dynamic>{
      'sentFrom': instance.sentFrom,
      'permissionMode': instance.permissionMode,
      'model': instance.model,
      'fallbackModel': instance.fallbackModel,
      'customSystemPrompt': instance.customSystemPrompt,
      'appendSystemPrompt': instance.appendSystemPrompt,
      'allowedTools': instance.allowedTools,
      'disallowedTools': instance.disallowedTools,
      'displayText': instance.displayText,
    };
