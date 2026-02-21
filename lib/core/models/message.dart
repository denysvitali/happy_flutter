int? _asApiInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

/// API message schema
class ApiMessage {

  ApiMessage(
      {required this.id,
      required this.seq,
      required this.content,
      required this.createdAt,
      this.localId,
      this.updatedAt});

  factory ApiMessage.fromJson(Map<String, dynamic> json) {
    final contentRaw = json['content'];
    final content = contentRaw is Map<String, dynamic>
        ? ApiMessageContent.fromJson(contentRaw)
        : ApiMessageContent(t: '', c: '');
    return ApiMessage(
      id: json['id'] as String? ?? '',
      seq: _asApiInt(json['seq']) ?? 0,
      localId: json['localId'] as String?,
      content: content,
      createdAt: _asApiInt(json['createdAt']) ?? 0,
      updatedAt: _asApiInt(json['updatedAt']),
    );
  }
  final String id;
  final int seq;
  final String? localId;
  final ApiMessageContent content;
  final int createdAt;
  final int? updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seq': seq,
      'localId': localId,
      'content': content.toJson(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

class ApiMessageContent {

  ApiMessageContent({required this.t, required this.c});

  factory ApiMessageContent.fromJson(Map<String, dynamic> json) {
    return ApiMessageContent(
      t: json['t'] as String? ?? '',
      c: json['c'] as String? ?? '',
    );
  }
  final String t;
  final String c;

  Map<String, dynamic> toJson() {
    return {'t': t, 'c': c};
  }
}

/// Tool call information
class ToolCall {

  ToolCall({
    required this.name,
    required this.state,
    required this.createdAt, this.input,
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
  final String name;
  final String state;
  final dynamic input;
  final int createdAt;
  final int? startedAt;
  final int? completedAt;
  final String? description;
  final dynamic result;
  final Permission? permission;
}

class Permission {

  Permission(
      {required this.id,
      required this.status,
      this.reason,
      this.mode,
      this.allowedTools,
      this.decision,
      this.date});

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as String,
      status: json['status'] as String,
      reason: json['reason'] as String?,
      mode: json['mode'] as String?,
      allowedTools: (json['allowedTools'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      decision: json['decision'] as String?,
      date: json['date'] as int?,
    );
  }
  final String id;
  final String status;
  final String? reason;
  final String? mode;
  final List<String>? allowedTools;
  final String? decision;
  final int? date;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      if (reason != null) 'reason': reason,
      if (mode != null) 'mode': mode,
      if (allowedTools != null) 'allowedTools': allowedTools,
      if (decision != null) 'decision': decision,
      if (date != null) 'date': date,
    };
  }

  Permission copyWith({
    String? id,
    String? status,
    String? reason,
    String? mode,
    List<String>? allowedTools,
    String? decision,
    int? date,
  }) {
    return Permission(
      id: id ?? this.id,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      mode: mode ?? this.mode,
      allowedTools: allowedTools != null
          ? List<String>.from(allowedTools)
          : (this.allowedTools != null
              ? List<String>.from(this.allowedTools!)
              : null),
      decision: decision ?? this.decision,
      date: date ?? this.date,
    );
  }
}

/// Message metadata
class MessageMeta {

  const MessageMeta({
    this.sentFrom,
    this.permissionMode,
    this.model,
    this.fallbackModel,
    this.customSystemPrompt,
    this.appendSystemPrompt,
    this.allowedTools,
    this.disallowedTools,
    this.displayText,
  });

  factory MessageMeta.fromJson(Map<String, dynamic> json) {
    return MessageMeta(
      sentFrom: json['sentFrom'] as String?,
      permissionMode: json['permissionMode'] as String?,
      model: json['model'] as String?,
      fallbackModel: json['fallbackModel'] as String?,
      customSystemPrompt: json['customSystemPrompt'] as String?,
      appendSystemPrompt: json['appendSystemPrompt'] as String?,
      allowedTools: (json['allowedTools'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      disallowedTools: (json['disallowedTools'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      displayText: json['displayText'] as String?,
    );
  }

  /// Who sent the message (e.g. 'user', 'agent').
  final String? sentFrom;

  /// Permission mode at time of send.
  final String? permissionMode;

  /// Model used for this message.
  final String? model;

  /// Fallback model, if any.
  final String? fallbackModel;

  /// Custom system prompt override.
  final String? customSystemPrompt;

  /// Appended system prompt.
  final String? appendSystemPrompt;

  /// Tools allowed for this request.
  final List<String>? allowedTools;

  /// Tools disallowed for this request.
  final List<String>? disallowedTools;

  /// Display text for the message.
  final String? displayText;

  Map<String, dynamic> toJson() {
    return {
      if (sentFrom != null) 'sentFrom': sentFrom,
      if (permissionMode != null) 'permissionMode': permissionMode,
      if (model != null) 'model': model,
      if (fallbackModel != null) 'fallbackModel': fallbackModel,
      if (customSystemPrompt != null)
        'customSystemPrompt': customSystemPrompt,
      if (appendSystemPrompt != null)
        'appendSystemPrompt': appendSystemPrompt,
      if (allowedTools != null) 'allowedTools': allowedTools,
      if (disallowedTools != null) 'disallowedTools': disallowedTools,
      if (displayText != null) 'displayText': displayText,
    };
  }
}

/// Agent event types - using sealed class pattern with implementations
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
        return UnknownEvent();
    }
  }
}

class SwitchEvent implements AgentEvent {
  SwitchEvent({required this.mode});
  final String mode;
}

class MessageEvent implements AgentEvent {
  MessageEvent({required this.message});
  final String message;
}

class LimitReached implements AgentEvent {
  LimitReached({required this.endsAt});
  final int endsAt;
}

class ReadyEvent implements AgentEvent {
  ReadyEvent();
}

class UnknownEvent implements AgentEvent {
  UnknownEvent();
}
