/// Session metadata from storage types
library;

import 'package:happy_flutter/core/models/todo.dart' show TodoItem;

String _asApiString(dynamic value, String fieldName) {
  if (value is String) return value;
  throw FormatException(
    'Expected String for $fieldName, got ${value.runtimeType}',
  );
}

int _asApiInt(dynamic value, String fieldName) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  throw FormatException(
    'Expected int for $fieldName, got ${value.runtimeType}',
  );
}

bool _asApiBool(dynamic value, String fieldName) {
  if (value is bool) return value;
  throw FormatException(
    'Expected bool for $fieldName, got ${value.runtimeType}',
  );
}

String? _asApiStringOptional(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return null;
}

int? _asApiIntOptional(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

bool? _asApiBoolOptional(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  return null;
}

List<String>? _asApiStringListOptional(dynamic value) {
  if (value is! List) return null;
  final strings = value.whereType<String>().toList();
  if (strings.isEmpty) return null;
  return strings;
}

Summary? _asSummaryOptional(dynamic value) {
  if (value is Map<String, dynamic>) {
    try {
      return Summary.fromJson(value);
    } catch (_) {
      return null;
    }
  }
  if (value is Map) {
    try {
      return Summary.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      return null;
    }
  }
  return null;
}

bool? _sandboxEnabledFromMetadata(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value['enabled'] == true;
  }
  if (value is Map) {
    return value['enabled'] == true;
  }
  return null;
}

class Metadata {
  Metadata({
    required this.host,
    this.path,
    this.version,
    this.name,
    this.os,
    this.summary,
    this.machineId,
    this.claudeSessionId,
    this.tools,
    this.slashCommands,
    this.homeDir,
    this.happyHomeDir,
    this.hostPid,
    this.flavor,
    this.lifecycleState,
    this.sandboxEnabled,
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      path: _asApiStringOptional(json['path']),
      // Keep sessions visible even if legacy metadata has no host.
      host: _asApiStringOptional(json['host']) ?? '',
      version: _asApiStringOptional(json['version']),
      name: _asApiStringOptional(json['name']),
      os: _asApiStringOptional(json['os']),
      summary: _asSummaryOptional(json['summary']),
      machineId: _asApiStringOptional(json['machineId']),
      claudeSessionId: _asApiStringOptional(json['claudeSessionId']),
      tools: _asApiStringListOptional(json['tools']),
      slashCommands: _asApiStringListOptional(json['slashCommands']),
      homeDir: _asApiStringOptional(json['homeDir']),
      happyHomeDir: _asApiStringOptional(json['happyHomeDir']),
      hostPid: _asApiIntOptional(json['hostPid']),
      flavor: _asApiStringOptional(json['flavor']),
      lifecycleState: _asApiStringOptional(json['lifecycleState']),
      sandboxEnabled: _sandboxEnabledFromMetadata(json['sandbox']),
    );
  }
  final String? path;
  final String host;
  final String? version;
  final String? name;
  final String? os;
  final Summary? summary;
  final String? machineId;
  final String? claudeSessionId;
  final List<String>? tools;
  final List<String>? slashCommands;
  final String? homeDir;
  final String? happyHomeDir;
  final int? hostPid;
  final String? flavor;
  final String? lifecycleState;
  final bool? sandboxEnabled;

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'host': host,
      'version': version,
      'name': name,
      'os': os,
      'summary': summary?.toJson(),
      'machineId': machineId,
      'claudeSessionId': claudeSessionId,
      'tools': tools,
      'slashCommands': slashCommands,
      'homeDir': homeDir,
      'happyHomeDir': happyHomeDir,
      'hostPid': hostPid,
      'flavor': flavor,
      'lifecycleState': lifecycleState,
      if (sandboxEnabled != null) 'sandbox': {'enabled': sandboxEnabled},
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Metadata &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          host == other.host &&
          version == other.version &&
          name == other.name &&
          os == other.os &&
          summary == other.summary &&
          machineId == other.machineId &&
          claudeSessionId == other.claudeSessionId &&
          tools == other.tools &&
          slashCommands == other.slashCommands &&
          homeDir == other.homeDir &&
          happyHomeDir == other.happyHomeDir &&
          hostPid == other.hostPid &&
          flavor == other.flavor &&
          lifecycleState == other.lifecycleState &&
          sandboxEnabled == other.sandboxEnabled;

  @override
  int get hashCode => Object.hash(
    path,
    host,
    version,
    name,
    os,
    summary,
    machineId,
    claudeSessionId,
    tools,
    slashCommands,
    homeDir,
    happyHomeDir,
    hostPid,
    flavor,
    lifecycleState,
    sandboxEnabled,
  );
}

class Summary {
  Summary({required this.text, required this.updatedAt});

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      text: _asApiString(json['text'], 'text'),
      updatedAt: _asApiInt(json['updatedAt'], 'updatedAt'),
    );
  }
  final String text;
  final int updatedAt;

  Map<String, dynamic> toJson() {
    return {'text': text, 'updatedAt': updatedAt};
  }
}

/// Agent state for a session
class AgentState {
  AgentState({this.controlledByUser, this.requests, this.completedRequests});

  factory AgentState.fromJson(Map<String, dynamic> json) {
    final requestsRaw = json['requests'];
    Map<String, RequestInfo>? requests;
    if (requestsRaw is Map) {
      final parsed = <String, RequestInfo>{};
      for (final entry in requestsRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        Map<String, dynamic>? mapValue;
        if (value is Map<String, dynamic>) {
          mapValue = value;
        } else if (value is Map) {
          try {
            mapValue = Map<String, dynamic>.from(value);
          } catch (_) {
            mapValue = null;
          }
        }
        if (mapValue == null) continue;
        try {
          parsed[key] = RequestInfo.fromJson(mapValue);
        } catch (_) {
          continue;
        }
      }
      if (parsed.isNotEmpty) {
        requests = parsed;
      }
    }

    final completedRequestsRaw = json['completedRequests'];
    Map<String, CompletedRequestInfo>? completedRequests;
    if (completedRequestsRaw is Map) {
      final parsed = <String, CompletedRequestInfo>{};
      for (final entry in completedRequestsRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        Map<String, dynamic>? mapValue;
        if (value is Map<String, dynamic>) {
          mapValue = value;
        } else if (value is Map) {
          try {
            mapValue = Map<String, dynamic>.from(value);
          } catch (_) {
            mapValue = null;
          }
        }
        if (mapValue == null) continue;
        try {
          parsed[key] = CompletedRequestInfo.fromJson(mapValue);
        } catch (_) {
          continue;
        }
      }
      if (parsed.isNotEmpty) {
        completedRequests = parsed;
      }
    }

    return AgentState(
      controlledByUser: _asApiBoolOptional(json['controlledByUser']),
      requests: requests,
      completedRequests: completedRequests,
    );
  }
  final bool? controlledByUser;
  final Map<String, RequestInfo>? requests;
  final Map<String, CompletedRequestInfo>? completedRequests;

  Map<String, dynamic> toJson() {
    return {
      'controlledByUser': controlledByUser,
      'requests': requests?.map(
        (k, v) => MapEntry(k, {
          'tool': v.tool,
          'arguments': v.arguments,
          'createdAt': v.createdAt,
        }),
      ),
      'completedRequests': completedRequests?.map(
        (k, v) => MapEntry(k, {
          'tool': v.tool,
          'arguments': v.arguments,
          'createdAt': v.createdAt,
          'completedAt': v.completedAt,
          'status': v.status,
          'reason': v.reason,
          'mode': v.mode,
          'allowedTools': v.allowedTools,
          'decision': v.decision,
        }),
      ),
    };
  }
}

class RequestInfo {
  RequestInfo({required this.tool, this.arguments, this.createdAt});

  factory RequestInfo.fromJson(Map<String, dynamic> json) {
    return RequestInfo(
      tool: _asApiString(json['tool'], 'tool'),
      arguments: json['arguments'],
      createdAt: _asApiIntOptional(json['createdAt']),
    );
  }
  final String tool;
  final dynamic arguments;
  final int? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequestInfo &&
          runtimeType == other.runtimeType &&
          tool == other.tool &&
          arguments == other.arguments &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(tool, arguments, createdAt);
}

class CompletedRequestInfo {
  CompletedRequestInfo({
    required this.tool,
    required this.status,
    this.arguments,
    this.createdAt,
    this.completedAt,
    this.reason,
    this.mode,
    this.allowedTools,
    this.decision,
  });

  factory CompletedRequestInfo.fromJson(Map<String, dynamic> json) {
    return CompletedRequestInfo(
      tool: _asApiString(json['tool'], 'tool'),
      arguments: json['arguments'],
      createdAt: _asApiIntOptional(json['createdAt']),
      completedAt: _asApiIntOptional(json['completedAt']),
      status: _asApiString(json['status'], 'status'),
      reason: _asApiStringOptional(json['reason']),
      mode: _asApiStringOptional(json['mode']),
      allowedTools: _asApiStringListOptional(json['allowedTools']),
      decision: _asApiStringOptional(json['decision']),
    );
  }
  final String tool;
  final dynamic arguments;
  final int? createdAt;
  final int? completedAt;
  final String status;
  final String? reason;
  final String? mode;
  final List<String>? allowedTools;
  final String? decision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompletedRequestInfo &&
          runtimeType == other.runtimeType &&
          tool == other.tool &&
          arguments == other.arguments &&
          createdAt == other.createdAt &&
          completedAt == other.completedAt &&
          status == other.status &&
          reason == other.reason &&
          mode == other.mode &&
          allowedTools == other.allowedTools &&
          decision == other.decision;

  @override
  int get hashCode => Object.hash(
    tool,
    arguments,
    createdAt,
    completedAt,
    status,
    reason,
    mode,
    allowedTools,
    decision,
  );
}

/// Main Session model
class Session {
  Session({
    required this.id,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    required this.active,
    required this.activeAt,
    required this.metadataVersion,
    required this.agentStateVersion,
    required this.thinking,
    required this.presence,
    this.metadata,
    this.agentState,
    this.thinkingAt,
    this.todos,
    this.draft,
    this.permissionMode,
    this.modelMode,
    this.latestUsage,
    this.lastSeq,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: _asApiString(json['id'], 'id'),
      seq: _asApiInt(json['seq'], 'seq'),
      createdAt: _asApiInt(json['createdAt'], 'createdAt'),
      updatedAt: _asApiInt(json['updatedAt'], 'updatedAt'),
      active: _asApiBool(json['active'], 'active'),
      activeAt: _asApiInt(json['activeAt'], 'activeAt'),
      metadata: json['metadata'] != null
          ? Metadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      metadataVersion: _asApiInt(json['metadataVersion'], 'metadataVersion'),
      agentState: json['agentState'] != null
          ? AgentState.fromJson(json['agentState'] as Map<String, dynamic>)
          : null,
      agentStateVersion: _asApiInt(
        json['agentStateVersion'],
        'agentStateVersion',
      ),
      thinking: _asApiBool(json['thinking'], 'thinking'),
      thinkingAt: _asApiIntOptional(json['thinkingAt']),
      presence: json['presence'] is String
          ? json['presence'] as String
          : 'offline',
      todos: (json['todos'] as List<dynamic>?)
          ?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      draft: _asApiStringOptional(json['draft']),
      permissionMode: _asApiStringOptional(json['permissionMode']),
      modelMode: _asApiStringOptional(json['modelMode']),
      latestUsage: json['latestUsage'] != null
          ? UsageData.fromJson(json['latestUsage'] as Map<String, dynamic>)
          : null,
      lastSeq: _asApiIntOptional(json['lastSeq']),
    );
  }
  final String id;
  final int seq;
  final int createdAt;
  final int updatedAt;
  final bool active;
  final int activeAt;
  final Metadata? metadata;
  final int metadataVersion;
  final AgentState? agentState;
  final int agentStateVersion;
  final bool thinking;
  final int? thinkingAt;

  /// Either the string `'online'` or an integer timestamp of last seen.
  final String presence;
  final List<TodoItem>? todos;
  final String? draft;
  final String? permissionMode;
  final String? modelMode;
  final UsageData? latestUsage;

  /// The highest message seq number in the session, as reported by the
  /// server. Used for lazy tail-loading to avoid fetching all history.
  final int? lastSeq;

  /// Returns `true` when presence is the string `'online'`.
  bool get isPresenceOnline => presence == 'online';

  /// Returns `true` when presence is the string `'online'`.
  bool get isOnline => presence == 'online';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seq': seq,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'active': active,
      'activeAt': activeAt,
      'metadata': metadata?.toJson(),
      'metadataVersion': metadataVersion,
      'agentState': agentState?.toJson(),
      'agentStateVersion': agentStateVersion,
      'thinking': thinking,
      'thinkingAt': thinkingAt,
      'presence': presence,
      'todos': todos?.map((e) => e.toJson()).toList(),
      'draft': draft,
      'permissionMode': permissionMode,
      'modelMode': modelMode,
      'latestUsage': latestUsage?.toJson(),
      'lastSeq': lastSeq,
    };
  }

  Session copyWith({
    String? id,
    int? seq,
    int? createdAt,
    int? updatedAt,
    bool? active,
    int? activeAt,
    Metadata? metadata,
    int? metadataVersion,
    AgentState? agentState,
    int? agentStateVersion,
    bool? thinking,
    int? thinkingAt,
    String? presence,
    List<TodoItem>? todos,
    String? draft,
    String? permissionMode,
    String? modelMode,
    UsageData? latestUsage,
    int? lastSeq,
  }) {
    return Session(
      id: id ?? this.id,
      seq: seq ?? this.seq,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      active: active ?? this.active,
      activeAt: activeAt ?? this.activeAt,
      metadata: metadata ?? this.metadata,
      metadataVersion: metadataVersion ?? this.metadataVersion,
      agentState: agentState ?? this.agentState,
      agentStateVersion: agentStateVersion ?? this.agentStateVersion,
      thinking: thinking ?? this.thinking,
      thinkingAt: thinkingAt ?? this.thinkingAt,
      presence: presence ?? this.presence,
      todos: todos != null ? List<TodoItem>.from(todos) : this.todos,
      draft: draft ?? this.draft,
      permissionMode: permissionMode ?? this.permissionMode,
      modelMode: modelMode ?? this.modelMode,
      latestUsage: latestUsage ?? this.latestUsage,
      lastSeq: lastSeq ?? this.lastSeq,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Session &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          seq == other.seq &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          active == other.active &&
          activeAt == other.activeAt &&
          metadata == other.metadata &&
          metadataVersion == other.metadataVersion &&
          agentState == other.agentState &&
          agentStateVersion == other.agentStateVersion &&
          thinking == other.thinking &&
          thinkingAt == other.thinkingAt &&
          presence == other.presence &&
          todos == other.todos &&
          draft == other.draft &&
          permissionMode == other.permissionMode &&
          modelMode == other.modelMode &&
          latestUsage == other.latestUsage &&
          lastSeq == other.lastSeq;

  @override
  int get hashCode => Object.hash(
    id,
    seq,
    createdAt,
    updatedAt,
    active,
    activeAt,
    metadata,
    metadataVersion,
    agentState,
    agentStateVersion,
    thinking,
    thinkingAt,
    presence,
    todos,
    draft,
    permissionMode,
    modelMode,
    latestUsage,
    lastSeq,
  );
}

class UsageData {
  UsageData({
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheCreation,
    required this.cacheRead,
    required this.contextSize,
    required this.timestamp,
  });

  factory UsageData.fromJson(Map<String, dynamic> json) {
    return UsageData(
      inputTokens: _asApiInt(json['inputTokens'], 'inputTokens'),
      outputTokens: _asApiInt(json['outputTokens'], 'outputTokens'),
      cacheCreation: _asApiInt(json['cacheCreation'], 'cacheCreation'),
      cacheRead: _asApiInt(json['cacheRead'], 'cacheRead'),
      contextSize: _asApiInt(json['contextSize'], 'contextSize'),
      timestamp: _asApiInt(json['timestamp'], 'timestamp'),
    );
  }
  final int inputTokens;
  final int outputTokens;
  final int cacheCreation;
  final int cacheRead;
  final int contextSize;
  final int timestamp;

  Map<String, dynamic> toJson() {
    return {
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'cacheCreation': cacheCreation,
      'cacheRead': cacheRead,
      'contextSize': contextSize,
      'timestamp': timestamp,
    };
  }
}
