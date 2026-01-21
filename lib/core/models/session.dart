/// Session metadata from storage types
class Metadata {
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

  Metadata({
    this.path,
    required this.host,
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
  });

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      path: json['path'] as String?,
      host: json['host'] as String,
      version: json['version'] as String?,
      name: json['name'] as String?,
      os: json['os'] as String?,
      summary: json['summary'] != null ? Summary.fromJson(json['summary'] as Map<String, dynamic>) : null,
      machineId: json['machineId'] as String?,
      claudeSessionId: json['claudeSessionId'] as String?,
      tools: (json['tools'] as List<dynamic>?)?.map((e) => e as String).toList(),
      slashCommands: (json['slashCommands'] as List<dynamic>?)?.map((e) => e as String).toList(),
      homeDir: json['homeDir'] as String?,
      happyHomeDir: json['happyHomeDir'] as String?,
      hostPid: json['hostPid'] as int?,
      flavor: json['flavor'] as String?,
    );
  }

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
    };
  }
}

class Summary {
  final String text;
  final int updatedAt;

  Summary({required this.text, required this.updatedAt});

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      text: json['text'] as String,
      updatedAt: json['updatedAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'updatedAt': updatedAt};
  }
}

/// Agent state for a session
class AgentState {
  final bool? controlledByUser;
  final Map<String, RequestInfo>? requests;
  final Map<String, CompletedRequestInfo>? completedRequests;

  AgentState({this.controlledByUser, this.requests, this.completedRequests});

  factory AgentState.fromJson(Map<String, dynamic> json) {
    return AgentState(
      controlledByUser: json['controlledByUser'] as bool?,
      requests: (json['requests'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, RequestInfo.fromJson(v as Map<String, dynamic>)),
      ),
      completedRequests: (json['completedRequests'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, CompletedRequestInfo.fromJson(v as Map<String, dynamic>)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'controlledByUser': controlledByUser,
      'requests': requests?.map((k, v) => MapEntry(k, {'tool': v.tool, 'arguments': v.arguments, 'createdAt': v.createdAt})),
      'completedRequests': completedRequests?.map((k, v) => MapEntry(k, {
            'tool': v.tool,
            'arguments': v.arguments,
            'createdAt': v.createdAt,
            'completedAt': v.completedAt,
            'status': v.status,
            'reason': v.reason,
            'mode': v.mode,
            'allowedTools': v.allowedTools,
            'decision': v.decision,
          })),
    };
  }
}

class RequestInfo {
  final String tool;
  final dynamic arguments;
  final int? createdAt;

  RequestInfo({required this.tool, this.arguments, this.createdAt});

  factory RequestInfo.fromJson(Map<String, dynamic> json) {
    return RequestInfo(
      tool: json['tool'] as String,
      arguments: json['arguments'],
      createdAt: json['createdAt'] as int?,
    );
  }
}

class CompletedRequestInfo {
  final String tool;
  final dynamic arguments;
  final int? createdAt;
  final int? completedAt;
  final String status;
  final String? reason;
  final String? mode;
  final List<String>? allowedTools;
  final String? decision;

  CompletedRequestInfo({
    required this.tool,
    this.arguments,
    this.createdAt,
    this.completedAt,
    required this.status,
    this.reason,
    this.mode,
    this.allowedTools,
    this.decision,
  });

  factory CompletedRequestInfo.fromJson(Map<String, dynamic> json) {
    return CompletedRequestInfo(
      tool: json['tool'] as String,
      arguments: json['arguments'],
      createdAt: json['createdAt'] as int?,
      completedAt: json['completedAt'] as int?,
      status: json['status'] as String,
      reason: json['reason'] as String?,
      mode: json['mode'] as String?,
      allowedTools: (json['allowedTools'] as List<dynamic>?)?.map((e) => e as String).toList(),
      decision: json['decision'] as String?,
    );
  }
}

/// Main Session model
class Session {
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
  final String presence;
  final List<TodoItem>? todos;
  final String? draft;
  final String? permissionMode;
  final String? modelMode;
  final UsageData? latestUsage;

  Session({
    required this.id,
    required this.seq,
    required this.createdAt,
    required this.updatedAt,
    required this.active,
    required this.activeAt,
    this.metadata,
    required this.metadataVersion,
    this.agentState,
    required this.agentStateVersion,
    required this.thinking,
    this.thinkingAt,
    required this.presence,
    this.todos,
    this.draft,
    this.permissionMode,
    this.modelMode,
    this.latestUsage,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      seq: json['seq'] as int,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
      active: json['active'] as bool,
      activeAt: json['activeAt'] as int,
      metadata: json['metadata'] != null ? Metadata.fromJson(json['metadata'] as Map<String, dynamic>) : null,
      metadataVersion: json['metadataVersion'] as int,
      agentState: json['agentState'] != null ? AgentState.fromJson(json['agentState'] as Map<String, dynamic>) : null,
      agentStateVersion: json['agentStateVersion'] as int,
      thinking: json['thinking'] as bool,
      thinkingAt: json['thinkingAt'] as int?,
      presence: json['presence'] as String,
      todos: (json['todos'] as List<dynamic>?)?.map((e) => TodoItem.fromJson(e as Map<String, dynamic>)).toList(),
      draft: json['draft'] as String?,
      permissionMode: json['permissionMode'] as String?,
      modelMode: json['modelMode'] as String?,
      latestUsage: json['latestUsage'] != null ? UsageData.fromJson(json['latestUsage'] as Map<String, dynamic>) : null,
    );
  }

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
      todos: todos ?? this.todos,
      draft: draft ?? this.draft,
      permissionMode: permissionMode ?? this.permissionMode,
      modelMode: modelMode ?? this.modelMode,
      latestUsage: latestUsage ?? this.latestUsage,
    );
  }
}

class TodoItem {
  final String content;
  final String status;
  final String priority;
  final String id;

  TodoItem({required this.content, required this.status, required this.priority, required this.id});

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      content: json['content'] as String,
      status: json['status'] as String,
      priority: json['priority'] as String,
      id: json['id'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'content': content, 'status': status, 'priority': priority, 'id': id};
  }
}

class UsageData {
  final int inputTokens;
  final int outputTokens;
  final int cacheCreation;
  final int cacheRead;
  final int contextSize;
  final int timestamp;

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
      inputTokens: json['inputTokens'] as int,
      outputTokens: json['outputTokens'] as int,
      cacheCreation: json['cacheCreation'] as int,
      cacheRead: json['cacheRead'] as int,
      contextSize: json['contextSize'] as int,
      timestamp: json['timestamp'] as int,
    );
  }

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
