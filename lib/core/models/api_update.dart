/// API update types for WebSocket messages
class ApiUpdateNewMessage {

  ApiUpdateNewMessage(
      {required this.t, required this.sid, required this.message});

  factory ApiUpdateNewMessage.fromJson(Map<String, dynamic> json) {
    return ApiUpdateNewMessage(
      t: json['t'] as String? ?? '',
      sid: json['sid'] as String? ?? '',
      message: json['message'] as Map<String, dynamic>? ?? {},
    );
  }
  final String t;
  final String sid;
  final Map<String, dynamic> message;
}

class ApiUpdateNewSession {

  ApiUpdateNewSession(
      {required this.t,
      required this.id,
      required this.createdAt,
      required this.updatedAt});

  factory ApiUpdateNewSession.fromJson(Map<String, dynamic> json) {
    return ApiUpdateNewSession(
      t: json['t'] as String? ?? '',
      id: json['id'] as String? ?? '',
      createdAt: _asInt(json['createdAt']) ?? 0,
      updatedAt: _asInt(json['updatedAt']) ?? 0,
    );
  }
  final String t;
  final String id;
  final int createdAt;
  final int updatedAt;
}

class ApiDeleteSession {

  ApiDeleteSession({required this.t, required this.sid});

  factory ApiDeleteSession.fromJson(Map<String, dynamic> json) {
    return ApiDeleteSession(
      t: json['t'] as String? ?? '',
      sid: json['sid'] as String? ?? '',
    );
  }
  final String t;
  final String sid;
}

class ApiUpdateSessionState {

  ApiUpdateSessionState(
      {required this.t, required this.id, this.agentState, this.metadata});

  factory ApiUpdateSessionState.fromJson(Map<String, dynamic> json) {
    return ApiUpdateSessionState(
      t: json['t'] as String? ?? '',
      id: json['id'] as String? ?? '',
      agentState: json['agentState'] is Map<String, dynamic>
          ? VersionedValue.fromJson(json['agentState'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] is Map<String, dynamic>
          ? VersionedValue.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }
  final String t;
  final String id;
  final VersionedValue? agentState;
  final VersionedValue? metadata;
}

class VersionedValue {

  VersionedValue({required this.version, this.value});

  factory VersionedValue.fromJson(Map<String, dynamic> json) {
    return VersionedValue(
      version: _asInt(json['version']) ?? 0,
      value: json['value'] as String? ?? '',
    );
  }
  final int version;

  /// The serialised value string, or `null` when the server sends a null
  /// value (e.g. for cleared agentState).
  final String? value;
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

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
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
