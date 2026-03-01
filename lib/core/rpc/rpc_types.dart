/// Typed request/response classes for RPC methods.
///
/// Field names use camelCase to match the `protojson` wire format produced by
/// the Go CLI's `MakeTypedHandler` (which serialises proto messages via
/// `protojson.MarshalOptions{UseProtoNames: false}`).

// ---------------------------------------------------------------------------
// spawn-happy-session
// ---------------------------------------------------------------------------

class SpawnSessionRequest {
  final String type;
  final String directory;
  final String? sessionId;
  final String? agent;
  final bool approvedNewDirectoryCreation;
  final Map<String, String>? environmentVariables;
  final String? startupBashScript;
  final String? permissionMode;

  const SpawnSessionRequest({
    required this.type,
    required this.directory,
    this.sessionId,
    this.agent,
    this.approvedNewDirectoryCreation = false,
    this.environmentVariables,
    this.startupBashScript,
    this.permissionMode,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'directory': directory,
        if (sessionId != null) 'sessionId': sessionId,
        if (agent != null) 'agent': agent,
        'approvedNewDirectoryCreation': approvedNewDirectoryCreation,
        if (environmentVariables != null && environmentVariables!.isNotEmpty)
          'environmentVariables': environmentVariables,
        if (startupBashScript != null && startupBashScript!.isNotEmpty)
          'startupBashScript': startupBashScript,
        if (permissionMode != null) 'permissionMode': permissionMode,
      };
}

class SpawnSessionResponse {
  final String? type;
  final String? sessionId;
  final String? errorMessage;
  final String? directory;
  final String? dataEncryptionKey;

  const SpawnSessionResponse({
    this.type,
    this.sessionId,
    this.errorMessage,
    this.directory,
    this.dataEncryptionKey,
  });

  factory SpawnSessionResponse.fromJson(Map<String, dynamic> json) =>
      SpawnSessionResponse(
        type: json['type'] as String?,
        sessionId: json['sessionId'] as String?,
        errorMessage: json['errorMessage'] as String?,
        directory: json['directory'] as String?,
        dataEncryptionKey: json['dataEncryptionKey'] as String?,
      );
}

// ---------------------------------------------------------------------------
// bash
// ---------------------------------------------------------------------------

class BashRequest {
  final String command;
  final String cwd;

  const BashRequest({required this.command, required this.cwd});

  Map<String, dynamic> toJson() => {
        'command': command,
        'cwd': cwd,
      };
}

class BashResponse {
  final bool success;
  final String stdout;
  final String stderr;
  final int exitCode;
  final String? error;

  const BashResponse({
    required this.success,
    this.stdout = '',
    this.stderr = '',
    this.exitCode = -1,
    this.error,
  });

  factory BashResponse.fromJson(Map<String, dynamic> json) => BashResponse(
        success: json['success'] as bool? ?? false,
        stdout: json['stdout'] as String? ?? '',
        stderr: json['stderr'] as String? ?? '',
        exitCode: json['exitCode'] as int? ?? -1,
        error: json['error'] as String?,
      );
}

// ---------------------------------------------------------------------------
// permission
// ---------------------------------------------------------------------------

class PermissionRequest {
  final String id;
  final bool approved;
  final String? mode;
  final List<String>? allowTools;
  final String? decision;

  const PermissionRequest({
    required this.id,
    required this.approved,
    this.mode,
    this.allowTools,
    this.decision,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'approved': approved,
        if (mode != null) 'mode': mode,
        if (allowTools != null) 'allowTools': allowTools,
        if (decision != null) 'decision': decision,
      };
}

class PermissionResponse {
  final bool success;
  final String? error;

  const PermissionResponse({required this.success, this.error});

  factory PermissionResponse.fromJson(Map<String, dynamic> json) =>
      PermissionResponse(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      );
}

// ---------------------------------------------------------------------------
// killSession
// ---------------------------------------------------------------------------

class KillSessionResponse {
  final bool success;
  final String? message;

  const KillSessionResponse({required this.success, this.message});

  factory KillSessionResponse.fromJson(Map<String, dynamic> json) =>
      KillSessionResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String?,
      );
}

// ---------------------------------------------------------------------------
// abort
// ---------------------------------------------------------------------------

class AbortResponse {
  final bool success;
  final String? message;

  const AbortResponse({required this.success, this.message});

  factory AbortResponse.fromJson(Map<String, dynamic> json) => AbortResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String?,
      );
}
