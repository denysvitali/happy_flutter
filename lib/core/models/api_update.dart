// API update types for WebSocket messages
import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_update.freezed.dart';
part 'api_update.g.dart';

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

@freezed
abstract class ApiUpdateNewMessage with _$ApiUpdateNewMessage {
  const factory ApiUpdateNewMessage({
    @Default('') String t,
    @Default('') String sid,
    @Default(<String, dynamic>{}) Map<String, dynamic> message,
  }) = _ApiUpdateNewMessage;

  factory ApiUpdateNewMessage.fromJson(Map<String, dynamic> json) =>
      _$ApiUpdateNewMessageFromJson(json);
}

@freezed
abstract class ApiUpdateNewSession with _$ApiUpdateNewSession {
  const factory ApiUpdateNewSession({
    @Default('') String t,
    @Default('') String id,
    @JsonKey(fromJson: _asInt) @Default(0) int createdAt,
    @JsonKey(fromJson: _asInt) @Default(0) int updatedAt,
  }) = _ApiUpdateNewSession;

  factory ApiUpdateNewSession.fromJson(Map<String, dynamic> json) =>
      _$ApiUpdateNewSessionFromJson(json);
}

@freezed
abstract class ApiDeleteSession with _$ApiDeleteSession {
  const factory ApiDeleteSession({
    @Default('') String t,
    @Default('') String sid,
  }) = _ApiDeleteSession;

  factory ApiDeleteSession.fromJson(Map<String, dynamic> json) =>
      _$ApiDeleteSessionFromJson(json);
}

VersionedValue? _versionedValueFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return VersionedValue.fromJson(value);
  }
  return null;
}

@freezed
abstract class ApiUpdateSessionState with _$ApiUpdateSessionState {
  const factory ApiUpdateSessionState({
    @Default('') String t,
    @Default('') String id,
    @JsonKey(fromJson: _versionedValueFromJson) VersionedValue? agentState,
    @JsonKey(fromJson: _versionedValueFromJson) VersionedValue? metadata,
  }) = _ApiUpdateSessionState;

  factory ApiUpdateSessionState.fromJson(Map<String, dynamic> json) =>
      _$ApiUpdateSessionStateFromJson(json);
}

String _vvValueFromJson(dynamic value) {
  if (value is String) return value;
  return '';
}

@freezed
abstract class VersionedValue with _$VersionedValue {
  const factory VersionedValue({
    @JsonKey(fromJson: _asInt) @Default(0) int version,

    /// The serialised value string. Null on the wire is normalised to `''`.
    @JsonKey(fromJson: _vvValueFromJson) @Default('') String value,
  }) = _VersionedValue;

  factory VersionedValue.fromJson(Map<String, dynamic> json) =>
      _$VersionedValueFromJson(json);
}

// ── New payload classes for additional update types ──────────────────────────

/// `update-account` — profile / account data changed.
class ApiUpdateAccount {
  const ApiUpdateAccount({required this.data});
  final Map<String, dynamic> data;
}

/// `update-machine` — a machine's state changed.
class ApiUpdateMachine {
  const ApiUpdateMachine({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
}

/// `new-artifact` — a new artifact was created.
class ApiNewArtifact {
  const ApiNewArtifact({required this.data});
  final Map<String, dynamic> data;
}

/// `update-artifact` — an existing artifact was updated.
class ApiUpdateArtifact {
  const ApiUpdateArtifact({required this.data});
  final Map<String, dynamic> data;
}

/// `delete-artifact` — an artifact was deleted.
class ApiDeleteArtifact {
  const ApiDeleteArtifact({required this.id});
  final String id;
}

/// `relationship-updated` — a social relationship changed.
class ApiRelationshipUpdated {
  const ApiRelationshipUpdated({required this.data});
  final Map<String, dynamic> data;
}

/// `kv-batch-update` — one or more KV entries changed.
class ApiKvBatchUpdate {
  const ApiKvBatchUpdate({required this.data});
  final Map<String, dynamic> data;
}

/// API update type discriminator
class ApiUpdate {
  ApiUpdate({required this.type, required this.data});

  factory ApiUpdate.fromJson(Map<String, dynamic> json) {
    // Support two formats:
    // 1. Wrapped: { body: { t: '...', ... } }  (original server format)
    // 2. Flat:    { t: '...', ... }             (direct Socket.io event data)
    final body = json['body'];
    if (body is Map<String, dynamic>) {
      return ApiUpdate(
        type: body['t'] as String? ?? '',
        data: body,
      );
    }
    // Flat format - the json itself is the data
    return ApiUpdate(
      type: json['t'] as String? ?? '',
      data: json,
    );
  }
  final String type;
  final dynamic data;
}
