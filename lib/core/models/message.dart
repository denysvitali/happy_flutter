/// API message schema
class ApiMessage {
  final String id;
  final int seq;
  final String? localId;
  final ApiMessageContent content;
  final int createdAt;

  ApiMessage({required this.id, required this.seq, this.localId, required this.content, required this.createdAt});

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    return ApiMessage(
      id: json['id'] as String,
      seq: json['seq'] as int,
      localId: json['localId'] as String?,
      content: ApiMessageContent.fromJson(json['content'] as Map<String, dynamic>),
      createdAt: json['createdAt'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seq': seq,
      'localId': localId,
      'content': content.toJson(),
      'createdAt': createdAt,
    };
  }
}

class ApiMessageContent {
  final String t;
  final String c;

  ApiMessageContent({required this.t, required this.c});

  factory ApiMessageContent.fromJson(Map<String, dynamic> json) {
    return ApiMessageContent(t: json['t'] as String, c: json['c'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'t': t, 'c': c};
  }
}

/// Tool call information
class ToolCall {
  final String name;
  final String state;
  final dynamic input;
  final int createdAt;
  final int? startedAt;
  final int? completedAt;
  final String? description;
  final dynamic result;
  final Permission? permission;

  ToolCall({
    required this.name,
    required this.state,
    this.input,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.description,
    this.result,
    this.permission,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      name: json['name'] as String,
      state: json['state'] as String,
      input: json['input'],
      createdAt: json['createdAt'] as int,
      startedAt: json['startedAt'] as int?,
      completedAt: json['completedAt'] as int?,
      description: json['description'] as String?,
      result: json['result'],
      permission: json['permission'] != null
          ? Permission.fromJson(json['permission'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Permission {
  final String id;
  final String status;
  final String? reason;
  final String? mode;
  final List<String>? allowedTools;
  final String? decision;
  final int? date;

  Permission({required this.id, required this.status, this.reason, this.mode, this.allowedTools, this.decision, this.date});

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as String,
      status: json['status'] as String,
      reason: json['reason'] as String?,
      mode: json['mode'] as String?,
      allowedTools: (json['allowedTools'] as List<dynamic>?)?.map((e) => e as String).toList(),
      decision: json['decision'] as String?,
      date: json['date'] as int?,
    );
  }
}

/// Message metadata
class MessageMeta {
  final String? role;
  final String? cwd;
  final String? sessionId;
  final String? version;
  final String? gitBranch;
  final String? slug;
  final String? requestId;
  final int? timestamp;

  MessageMeta({this.role, this.cwd, this.sessionId, this.version, this.gitBranch, this.slug, this.requestId, this.timestamp});

  factory MessageMeta.fromJson(Map<String, dynamic> json) {
    return MessageMeta(
      role: json['role'] as String?,
      cwd: json['cwd'] as String?,
      sessionId: json['sessionId'] as String?,
      version: json['version'] as String?,
      gitBranch: json['gitBranch'] as String?,
      slug: json['slug'] as String?,
      requestId: json['requestId'] as String?,
      timestamp: json['timestamp'] as int?,
    );
  }
}

/// Agent event types
sealed class AgentEvent {
  factory AgentEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'switch':
        return SwitchEvent(mode: json['mode'] as String);
      case 'message':
        return MessageEvent(message: json['message'] as String);
      case 'limit-reached':
        return LimitReached(endsAt: json['endsAt'] as int);
      case 'ready':
        return ReadyEvent();
      default:
        throw ArgumentError('Unknown event type: $type');
    }
  }
}

class SwitchEvent extends AgentEvent {
  final String mode;
  SwitchEvent({required this.mode});
}

class MessageEvent extends AgentEvent {
  final String message;
  MessageEvent({required this.message});
}

class LimitReached extends AgentEvent {
  final int endsAt;
  LimitReached({required this.endsAt});
}

class ReadyEvent extends AgentEvent {
  ReadyEvent();
}
