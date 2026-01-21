/// API update types for WebSocket messages
class ApiUpdateNewMessage {
  final String t;
  final String sid;
  final Map<String, dynamic> message;

  ApiUpdateNewMessage({required this.t, required this.sid, required this.message});

  factory ApiUpdateNewMessage.fromJson(Map<String, dynamic> json) {
    return ApiUpdateNewMessage(
      t: json['t'] as String,
      sid: json['sid'] as String,
      message: json['message'] as Map<String, dynamic>,
    );
  }
}

class ApiUpdateNewSession {
  final String t;
  final String id;
  final int createdAt;
  final int updatedAt;

  ApiUpdateNewSession({required this.t, required this.id, required this.createdAt, required this.updatedAt});

  factory ApiUpdateNewSession.fromJson(Map<String, dynamic> json) {
    return ApiUpdateNewSession(
      t: json['t'] as String,
      id: json['id'] as String,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int,
    );
  }
}

class ApiDeleteSession {
  final String t;
  final String sid;

  ApiDeleteSession({required this.t, required this.sid});

  factory ApiDeleteSession.fromJson(Map<String, dynamic> json) {
    return ApiDeleteSession(t: json['t'] as String, sid: json['sid'] as String);
  }
}

class ApiUpdateSessionState {
  final String t;
  final String id;
  final VersionedValue? agentState;
  final VersionedValue? metadata;

  ApiUpdateSessionState({required this.t, required this.id, this.agentState, this.metadata});

  factory ApiUpdateSessionState.fromJson(Map<String, dynamic> json) {
    return ApiUpdateSessionState(
      t: json['t'] as String,
      id: json['id'] as String,
      agentState: json['agentState'] != null
          ? VersionedValue.fromJson(json['agentState'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] != null
          ? VersionedValue.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }
}

class VersionedValue {
  final int version;
  final String value;

  VersionedValue({required this.version, required this.value});

  factory VersionedValue.fromJson(Map<String, dynamic> json) {
    return VersionedValue(version: json['version'] as int, value: json['value'] as String);
  }
}

/// Discriminated union for all API updates
sealed class ApiUpdate {
  factory ApiUpdate.fromJson(Map<String, dynamic> json) {
    final t = json['t'] as String;
    switch (t) {
      case 'new-message':
        return ApiUpdateNewMessage.fromJson(json);
      case 'new-session':
        return ApiUpdateNewSession.fromJson(json);
      case 'delete-session':
        return ApiDeleteSession.fromJson(json);
      case 'update-session':
        return ApiUpdateSessionState.fromJson(json);
      default:
        throw ArgumentError('Unknown update type: $t');
    }
  }
}
