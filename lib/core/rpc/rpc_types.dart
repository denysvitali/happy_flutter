/// Typed request/response classes for RPC methods.
///
/// Field names use camelCase to match the `protojson` wire format produced by
/// the Go CLI's `MakeTypedHandler` (which serialises proto messages via
/// `protojson.MarshalOptions{UseProtoNames: false}`).
library;

// ---------------------------------------------------------------------------
// spawn-happy-session
// ---------------------------------------------------------------------------

class SpawnSessionRequest {
  const SpawnSessionRequest({
    required this.type,
    required this.directory,
    this.sessionId,
    this.agent,
    this.approvedNewDirectoryCreation = false,
    this.environmentVariables,
    this.startupBashScript,
    this.permissionMode,
    this.model,
  });
  final String type;
  final String directory;
  final String? sessionId;
  final String? agent;
  final bool approvedNewDirectoryCreation;
  final Map<String, String>? environmentVariables;
  final String? startupBashScript;
  final String? permissionMode;
  final String? model;

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
    if (model != null) 'model': model,
  };
}

class SpawnSessionResponse {
  const SpawnSessionResponse({
    this.type,
    this.sessionId,
    this.errorMessage,
    this.directory,
    this.dataEncryptionKey,
  });

  factory SpawnSessionResponse.fromJson(
    Map<String, dynamic> json,
  ) => SpawnSessionResponse(
    // The daemon's RpcHandlerManager catches handler exceptions and returns
    // { error: '...' } instead of { type: 'error', errorMessage: '...' }.
    // Fall back to treating a bare 'error' key as type='error'.
    type: json['type'] as String? ?? (json['error'] != null ? 'error' : null),
    sessionId: (json['sessionId'] ?? json['session_id']) as String?,
    // Also check the bare 'error' key used by the daemon's catch block.
    errorMessage:
        (json['errorMessage'] ?? json['error_message'] ?? json['error'])
            as String?,
    directory: json['directory'] as String?,
    dataEncryptionKey:
        (json['dataEncryptionKey'] ?? json['data_encryption_key']) as String?,
  );
  final String? type;
  final String? sessionId;
  final String? errorMessage;
  final String? directory;
  final String? dataEncryptionKey;
}

// ---------------------------------------------------------------------------
// bash
// ---------------------------------------------------------------------------

class BashRequest {
  const BashRequest({required this.command, required this.cwd});
  final String command;
  final String cwd;

  Map<String, dynamic> toJson() => {'command': command, 'cwd': cwd};
}

class BashResponse {
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
  final bool success;
  final String stdout;
  final String stderr;
  final int exitCode;
  final String? error;
}

// ---------------------------------------------------------------------------
// permission
// ---------------------------------------------------------------------------

class PermissionRequest {
  const PermissionRequest({
    required this.id,
    required this.approved,
    this.mode,
    this.allowTools,
    this.decision,
    this.updatedInput,
  });
  final String id;
  final bool approved;
  final String? mode;
  final List<String>? allowTools;
  final String? decision;
  final Map<String, dynamic>? updatedInput;

  Map<String, dynamic> toJson() => {
    'id': id,
    'approved': approved,
    if (mode != null) 'mode': mode,
    if (allowTools != null) 'allowTools': allowTools,
    if (decision != null) 'decision': decision,
    if (updatedInput != null) 'updatedInput': updatedInput,
  };
}

class PermissionResponse {
  const PermissionResponse({required this.success, this.error});

  factory PermissionResponse.fromJson(Map<String, dynamic> json) =>
      PermissionResponse(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
      );
  final bool success;
  final String? error;
}

// ---------------------------------------------------------------------------
// killSession
// ---------------------------------------------------------------------------

class KillSessionResponse {
  const KillSessionResponse({required this.success, this.message});

  factory KillSessionResponse.fromJson(Map<String, dynamic> json) =>
      KillSessionResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String?,
      );
  final bool success;
  final String? message;
}

// ---------------------------------------------------------------------------
// abort
// ---------------------------------------------------------------------------

class AbortResponse {
  const AbortResponse({required this.success, this.message});

  factory AbortResponse.fromJson(Map<String, dynamic> json) => AbortResponse(
    success: json['success'] as bool? ?? false,
    message: json['message'] as String?,
  );
  final bool success;
  final String? message;
}

// ---------------------------------------------------------------------------
// readFile
// ---------------------------------------------------------------------------

class ReadFileRequest {
  const ReadFileRequest({required this.path});
  final String path;

  Map<String, dynamic> toJson() => {'path': path};
}

class ReadFileResponse {
  const ReadFileResponse({
    required this.success,
    this.content = '',
    this.error,
  });

  factory ReadFileResponse.fromJson(Map<String, dynamic> json) =>
      ReadFileResponse(
        success: json['success'] as bool? ?? false,
        content: json['content'] as String? ?? '',
        error: json['error'] as String?,
      );
  final bool success;
  final String content;
  final String? error;
}
