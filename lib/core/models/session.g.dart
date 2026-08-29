// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Metadata _$MetadataFromJson(Map<String, dynamic> json) => _Metadata(
  path: _asApiStringNullable(json['path']),
  host: json['host'] as String? ?? '',
  version: _asApiStringNullable(json['version']),
  name: _asApiStringNullable(json['name']),
  os: _asApiStringNullable(json['os']),
  summary: _summaryFromJson(json['summary']),
  machineId: _asApiStringNullable(json['machineId']),
  claudeSessionId: _asApiStringNullable(json['claudeSessionId']),
  tools: _asApiStringListNullable(json['tools']),
  slashCommands: _asApiStringListNullable(
    _readSlashCommands(json, 'slashCommands'),
  ),
  homeDir: _asApiStringNullable(json['homeDir']),
  happyHomeDir: _asApiStringNullable(json['happyHomeDir']),
  hostPid: _asApiIntNullable(json['hostPid']),
  flavor: _asApiStringNullable(json['flavor']),
  model: _asApiStringNullable(json['model']),
  lifecycleState: _asApiStringNullable(json['lifecycleState']),
  lifecycleStateError: _asApiStringNullable(json['lifecycleStateError']),
  lifecycleStateSince: _asApiIntNullable(json['lifecycleStateSince']),
  repoUrl: _asApiStringNullable(json['repoUrl']),
  repoRef: _asApiStringNullable(json['repoRef']),
  repoCommit: _asApiStringNullable(json['repoCommit']),
  runtimeKind: _asApiStringNullable(json['runtimeType']),
  podName: _asApiStringNullable(json['podName']),
  namespace: _asApiStringNullable(json['namespace']),
  podPhase: _asApiStringNullable(json['podPhase']),
  podStatus: _asApiStringNullable(json['podStatus']),
  podReady: _asApiBoolNullable(json['podReady']),
  podPaused: _asApiBoolNullable(json['podPaused']),
  sandboxEnabled: _sandboxEnabledFromJson(json['sandbox']),
  sandboxRequested: _asApiBoolNullable(json['sandboxRequested']),
  sandboxRequired: _asApiBoolNullable(json['sandboxRequired']),
  sandboxEnforced: _asApiBoolNullable(json['sandboxEnforced']),
  sandboxBackend: _asApiStringNullable(json['sandboxBackend']),
  sandboxReason: _asApiStringNullable(json['sandboxReason']),
);

Map<String, dynamic> _$MetadataToJson(_Metadata instance) => <String, dynamic>{
  'path': instance.path,
  'host': instance.host,
  'version': instance.version,
  'name': instance.name,
  'os': instance.os,
  'summary': instance.summary?.toJson(),
  'machineId': instance.machineId,
  'claudeSessionId': instance.claudeSessionId,
  'tools': instance.tools,
  'slashCommands': instance.slashCommands,
  'homeDir': instance.homeDir,
  'happyHomeDir': instance.happyHomeDir,
  'hostPid': instance.hostPid,
  'flavor': instance.flavor,
  'model': instance.model,
  'lifecycleState': instance.lifecycleState,
  'lifecycleStateError': instance.lifecycleStateError,
  'lifecycleStateSince': instance.lifecycleStateSince,
  'repoUrl': instance.repoUrl,
  'repoRef': instance.repoRef,
  'repoCommit': instance.repoCommit,
  'runtimeType': instance.runtimeKind,
  'podName': instance.podName,
  'namespace': instance.namespace,
  'podPhase': instance.podPhase,
  'podStatus': instance.podStatus,
  'podReady': instance.podReady,
  'podPaused': instance.podPaused,
  'sandbox': _sandboxEnabledToJson(instance.sandboxEnabled),
  'sandboxRequested': instance.sandboxRequested,
  'sandboxRequired': instance.sandboxRequired,
  'sandboxEnforced': instance.sandboxEnforced,
  'sandboxBackend': instance.sandboxBackend,
  'sandboxReason': instance.sandboxReason,
};

_Summary _$SummaryFromJson(Map<String, dynamic> json) => _Summary(
  text: json['text'] as String,
  updatedAt: _asApiInt(json['updatedAt']),
);

Map<String, dynamic> _$SummaryToJson(_Summary instance) => <String, dynamic>{
  'text': instance.text,
  'updatedAt': instance.updatedAt,
};

_RequestInfo _$RequestInfoFromJson(Map<String, dynamic> json) => _RequestInfo(
  tool: json['tool'] as String,
  arguments: json['arguments'],
  createdAt: _asApiIntNullable(json['createdAt']),
);

Map<String, dynamic> _$RequestInfoToJson(_RequestInfo instance) =>
    <String, dynamic>{
      'tool': instance.tool,
      'arguments': instance.arguments,
      'createdAt': instance.createdAt,
    };

_CompletedRequestInfo _$CompletedRequestInfoFromJson(
  Map<String, dynamic> json,
) => _CompletedRequestInfo(
  tool: json['tool'] as String,
  status: json['status'] as String,
  arguments: json['arguments'],
  createdAt: _asApiIntNullable(json['createdAt']),
  completedAt: _asApiIntNullable(json['completedAt']),
  reason: _asApiStringNullable(json['reason']),
  mode: _asApiStringNullable(json['mode']),
  allowedTools: _stringListNullable(json['allowedTools']),
  decision: _asApiStringNullable(json['decision']),
);

Map<String, dynamic> _$CompletedRequestInfoToJson(
  _CompletedRequestInfo instance,
) => <String, dynamic>{
  'tool': instance.tool,
  'status': instance.status,
  'arguments': instance.arguments,
  'createdAt': instance.createdAt,
  'completedAt': instance.completedAt,
  'reason': instance.reason,
  'mode': instance.mode,
  'allowedTools': instance.allowedTools,
  'decision': instance.decision,
};

_Session _$SessionFromJson(Map<String, dynamic> json) => _Session(
  id: _sessionIdFromJson(json['id']),
  seq: _asApiInt(json['seq']),
  createdAt: _asApiInt(json['createdAt']),
  updatedAt: _asApiInt(json['updatedAt']),
  active: json['active'] as bool,
  activeAt: _asApiInt(json['activeAt']),
  metadataVersion: _asApiInt(json['metadataVersion']),
  agentStateVersion: _asApiInt(json['agentStateVersion']),
  thinking: json['thinking'] as bool,
  archived: json['archived'] as bool? ?? false,
  metadata: _metadataFromJson(json['metadata']),
  agentState: _agentStateFromJson(json['agentState']),
  thinkingAt: _asApiIntNullable(json['thinkingAt']),
  presence: json['presence'] == null
      ? 'offline'
      : _presenceFromJson(json['presence']),
  todos: _todoListFromJson(json['todos']),
  draft: _asApiStringNullable(json['draft']),
  permissionMode: _asApiStringNullable(json['permissionMode']),
  modelMode: _asApiStringNullable(json['modelMode']),
  latestUsage: _usageDataFromJson(json['latestUsage']),
  lifecycleStateCleartext: json['lifecycleStateCleartext'] == null
      ? ''
      : _asApiStringOrEmpty(json['lifecycleStateCleartext']),
  lastSeq: _asApiIntNullable(json['lastSeq']),
  lastMessageAt: _lastMessageAtFromJson(json['lastMessage']),
);

Map<String, dynamic> _$SessionToJson(_Session instance) => <String, dynamic>{
  'id': instance.id,
  'seq': instance.seq,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'active': instance.active,
  'activeAt': instance.activeAt,
  'metadataVersion': instance.metadataVersion,
  'agentStateVersion': instance.agentStateVersion,
  'thinking': instance.thinking,
  'archived': instance.archived,
  'metadata': instance.metadata?.toJson(),
  'agentState': instance.agentState?.toJson(),
  'thinkingAt': instance.thinkingAt,
  'presence': instance.presence,
  'todos': instance.todos?.map((e) => e.toJson()).toList(),
  'draft': instance.draft,
  'permissionMode': instance.permissionMode,
  'modelMode': instance.modelMode,
  'latestUsage': instance.latestUsage?.toJson(),
  'lifecycleStateCleartext': instance.lifecycleStateCleartext,
  'lastSeq': instance.lastSeq,
  'lastMessage': instance.lastMessageAt,
};

_UsageData _$UsageDataFromJson(Map<String, dynamic> json) => _UsageData(
  inputTokens: _asApiInt(json['inputTokens']),
  outputTokens: _asApiInt(json['outputTokens']),
  cacheCreation: _asApiInt(json['cacheCreation']),
  cacheRead: _asApiInt(json['cacheRead']),
  contextSize: _asApiInt(json['contextSize']),
  timestamp: _asApiInt(json['timestamp']),
);

Map<String, dynamic> _$UsageDataToJson(_UsageData instance) =>
    <String, dynamic>{
      'inputTokens': instance.inputTokens,
      'outputTokens': instance.outputTokens,
      'cacheCreation': instance.cacheCreation,
      'cacheRead': instance.cacheRead,
      'contextSize': instance.contextSize,
      'timestamp': instance.timestamp,
    };
