import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

int _asApiInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

int? _asApiIntNullable(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

/// Canonical message role values.
///
/// These are the only valid `'role'` values in message maps stored in
/// [Sync.sessionMessages].  Always reference these constants instead
/// of raw strings to avoid mismatches (e.g. writing `'human'` when
/// the actual value is `'user'`).
abstract final class MessageRole {
  static const user = 'user';
  static const agent = 'agent';
  static const system = 'system';
  static const session = 'session';
}

ApiMessageContent _contentFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return ApiMessageContent.fromJson(value);
  }
  return const ApiMessageContent(t: '', c: '');
}

/// API message schema
@freezed
abstract class ApiMessage with _$ApiMessage {
  const factory ApiMessage({
    @JsonKey(fromJson: _contentFromJson) required ApiMessageContent content,
    @Default('') String id,
    @JsonKey(fromJson: _asApiInt) @Default(0) int seq,
    String? localId,
    @JsonKey(fromJson: _asApiInt) @Default(0) int createdAt,
    @JsonKey(fromJson: _asApiIntNullable) int? updatedAt,
  }) = _ApiMessage;

  factory ApiMessage.fromJson(Map<String, dynamic> json) =>
      _$ApiMessageFromJson(json);
}

@freezed
abstract class ApiMessageContent with _$ApiMessageContent {
  const factory ApiMessageContent({
    @Default('') String t,
    @Default('') String c,
  }) = _ApiMessageContent;

  factory ApiMessageContent.fromJson(Map<String, dynamic> json) =>
      _$ApiMessageContentFromJson(json);
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  return null;
}

Permission? _permissionOrNull(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Permission.fromJson(value);
  }
  return null;
}

/// Tool call information
@freezed
abstract class ToolCall with _$ToolCall {
  const factory ToolCall({
    required String name,
    required String state,
    required int createdAt,
    @JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? input,
    int? startedAt,
    int? completedAt,
    String? description,
    @JsonKey(fromJson: _mapOrNull) Map<String, dynamic>? result,
    @JsonKey(fromJson: _permissionOrNull) Permission? permission,
  }) = _ToolCall;

  factory ToolCall.fromJson(Map<String, dynamic> json) =>
      _$ToolCallFromJson(json);
}

List<String>? _stringListOrNull(dynamic value) {
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return null;
}

@freezed
abstract class Permission with _$Permission {
  const factory Permission({
    required String id,
    required String status,
    String? reason,
    String? mode,
    @JsonKey(fromJson: _stringListOrNull) List<String>? allowedTools,
    String? decision,
    int? date,
  }) = _Permission;

  factory Permission.fromJson(Map<String, dynamic> json) =>
      _$PermissionFromJson(json);
}

/// Message metadata
@JsonSerializable(includeIfNull: false)
@freezed
abstract class MessageMeta with _$MessageMeta {
  const factory MessageMeta({
    String? sentFrom,
    String? permissionMode,
    String? model,
    String? fallbackModel,
    String? customSystemPrompt,
    String? appendSystemPrompt,
    @JsonKey(fromJson: _stringListOrNull) List<String>? allowedTools,
    @JsonKey(fromJson: _stringListOrNull) List<String>? disallowedTools,
    String? displayText,
  }) = _MessageMeta;

  factory MessageMeta.fromJson(Map<String, dynamic> json) =>
      _$MessageMetaFromJson(json);
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
