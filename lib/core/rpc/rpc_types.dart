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
    this.spawnBackend,
    this.repoUrl,
    this.repoRef,
    this.repoCommit,
    this.isRestore = false,
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
  final String? spawnBackend;
  final String? repoUrl;
  final String? repoRef;
  final String? repoCommit;
  final bool isRestore;

  Map<String, dynamic> toJson() => {
    'type': type,
    'directory': directory,
    if (sessionId != null) 'sessionId': sessionId,
    if (agent != null) 'agent': agent,
    'approvedNewDirectoryCreation': approvedNewDirectoryCreation,
    // Always send when non-null — even an empty map. Empty means
    // "explicit Default / no profile", which the daemon uses to clear
    // sticky providerRoutingEnv from a prior Qwen/custom profile. Omitting
    // the key left the previous env attached on restore.
    if (environmentVariables != null)
      'environmentVariables': environmentVariables,
    if (startupBashScript != null && startupBashScript!.isNotEmpty)
      'startupBashScript': startupBashScript,
    if (permissionMode != null) 'permissionMode': permissionMode,
    if (model != null) 'model': model,
    if (spawnBackend != null) 'spawnBackend': spawnBackend,
    if (repoUrl != null && repoUrl!.isNotEmpty) 'repoUrl': repoUrl,
    if (repoRef != null && repoRef!.isNotEmpty) 'repoRef': repoRef,
    if (repoCommit != null && repoCommit!.isNotEmpty) 'repoCommit': repoCommit,
    if (isRestore) 'isRestore': true,
  };
}

class SpawnSessionResponse {
  const SpawnSessionResponse({
    this.type,
    this.sessionId,
    this.errorMessage,
    this.directory,
    this.dataEncryptionKey,
    this.sandboxRequested,
    this.sandboxRequired,
    this.sandboxEnforced,
    this.sandboxBackend,
    this.sandboxReason,
    this.runtimeKind,
    this.podName,
    this.namespace,
    this.phase,
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
    sandboxRequested: json['sandboxRequested'] as bool?,
    sandboxRequired: json['sandboxRequired'] as bool?,
    sandboxEnforced: json['sandboxEnforced'] as bool?,
    sandboxBackend: json['sandboxBackend'] as String?,
    sandboxReason: json['sandboxReason'] as String?,
    runtimeKind: json['runtimeType'] as String?,
    podName: json['podName'] as String?,
    namespace: json['namespace'] as String?,
    phase: json['phase'] as String?,
  );
  final String? type;
  final String? sessionId;
  final String? errorMessage;
  final String? directory;
  final String? dataEncryptionKey;
  final bool? sandboxRequested;
  final bool? sandboxRequired;
  final bool? sandboxEnforced;
  final String? sandboxBackend;
  final String? sandboxReason;
  final String? runtimeKind;
  final String? podName;
  final String? namespace;
  final String? phase;
}

// ---------------------------------------------------------------------------
// get-codex-models
// ---------------------------------------------------------------------------

class CodexModelsResponse {
  const CodexModelsResponse({
    required this.success,
    required this.models,
    this.error,
  });

  factory CodexModelsResponse.fromJson(Map<String, dynamic> json) {
    final rawModels = json['models'];
    return CodexModelsResponse(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      models: rawModels is List
          ? rawModels
                .whereType<Map>()
                .map((model) => CodexModelInfo.fromJson(model))
                .toList()
          : const [],
    );
  }

  final bool success;
  final List<CodexModelInfo> models;
  final String? error;
}

class CodexModelInfo {
  const CodexModelInfo({
    required this.slug,
    required this.displayName,
    required this.supportedReasoningEfforts,
    this.defaultReasoningEffort,
  });

  factory CodexModelInfo.fromJson(Map<dynamic, dynamic> json) {
    final supportedRaw =
        json['supportedReasoningEfforts'] ?? json['supported_reasoning_levels'];
    return CodexModelInfo(
      slug: json['slug'] as String? ?? '',
      displayName:
          (json['displayName'] ?? json['display_name'] ?? json['slug'])
              as String? ??
          '',
      defaultReasoningEffort:
          (json['defaultReasoningEffort'] ?? json['default_reasoning_level'])
              as String?,
      supportedReasoningEfforts: _parseReasoningEfforts(supportedRaw),
    );
  }

  final String slug;
  final String displayName;
  final List<String> supportedReasoningEfforts;
  final String? defaultReasoningEffort;
}

List<String> _parseReasoningEfforts(dynamic value) {
  if (value is! List) return const [];
  final efforts = <String>[];
  for (final item in value) {
    if (item is String && item.isNotEmpty) {
      efforts.add(item);
    } else if (item is Map) {
      final effort = item['effort'] as String?;
      if (effort != null && effort.isNotEmpty) {
        efforts.add(effort);
      }
    }
  }
  return efforts;
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
    this.stdoutTruncated = false,
    this.stderrTruncated = false,
    this.stdoutBytes,
    this.stderrBytes,
  });

  factory BashResponse.fromJson(Map<String, dynamic> json) => BashResponse(
    success: json['success'] as bool? ?? false,
    stdout: json['stdout'] as String? ?? '',
    stderr: json['stderr'] as String? ?? '',
    exitCode: json['exitCode'] as int? ?? -1,
    error: json['error'] as String?,
    stdoutTruncated: json['stdoutTruncated'] == true,
    stderrTruncated: json['stderrTruncated'] == true,
    stdoutBytes: _parseInt64(json['stdoutBytes']),
    stderrBytes: _parseInt64(json['stderrBytes']),
  );
  final bool success;
  final String stdout;
  final String stderr;
  final int exitCode;
  final String? error;

  /// Whether the machine retained only the bounded tail of stdout/stderr.
  final bool stdoutTruncated;
  final bool stderrTruncated;

  /// Pre-truncation byte totals reported by the machine, when available.
  final int? stdoutBytes;
  final int? stderrBytes;

  bool get outputTruncated => stdoutTruncated || stderrTruncated;

  int? get totalOriginalOutputBytes {
    final values = <int>[?stdoutBytes, ?stderrBytes];
    if (values.isEmpty) return null;
    return values.fold<int>(0, (total, value) => total + value);
  }
}

int? _parseInt64(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
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
  const PermissionResponse({
    required this.success,
    this.error,
    this.requestId,
    this.decision,
    this.scope,
    this.allowTools = const <String>[],
    this.mode,
  });

  factory PermissionResponse.fromJson(Map<String, dynamic> json) =>
      PermissionResponse(
        success: json['success'] as bool? ?? false,
        error: json['error'] as String?,
        requestId: json['requestId']?.toString(),
        decision: json['decision']?.toString(),
        scope: json['scope']?.toString(),
        allowTools: (json['allowTools'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        mode: json['mode']?.toString(),
      );
  final bool success;
  final String? error;
  final String? requestId;
  final String? decision;
  final String? scope;
  final List<String> allowTools;
  final String? mode;
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
// stop-session (machine-scoped, process/pod termination)
// ---------------------------------------------------------------------------

class StopSessionResponse {
  const StopSessionResponse({required this.message});

  factory StopSessionResponse.fromJson(Map<String, dynamic> json) =>
      StopSessionResponse(message: json['message']?.toString() ?? '');

  final String message;
}

// ---------------------------------------------------------------------------
// Kubernetes session pods
// ---------------------------------------------------------------------------

class SessionPod {
  const SessionPod({
    required this.sessionId,
    required this.podName,
    required this.namespace,
    required this.status,
    required this.phase,
    required this.reason,
    required this.message,
    required this.ready,
    required this.paused,
    required this.archived,
    required this.repoUrl,
    required this.repoRef,
  });

  factory SessionPod.fromJson(Map<dynamic, dynamic> json) => SessionPod(
    sessionId: json['sessionId']?.toString() ?? '',
    podName: json['podName']?.toString() ?? '',
    namespace: json['namespace']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    phase: json['phase']?.toString() ?? '',
    reason: json['reason']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    ready: json['ready'] == true,
    paused: json['paused'] == true,
    archived: json['archived'] == true,
    repoUrl: json['repoUrl']?.toString() ?? '',
    repoRef: json['repoRef']?.toString() ?? '',
  );

  final String sessionId;
  final String podName;
  final String namespace;
  final String status;
  final String phase;
  final String reason;
  final String message;
  final bool ready;
  final bool paused;
  final bool archived;
  final String repoUrl;
  final String repoRef;
}

class SessionPodsResponse {
  const SessionPodsResponse({required this.pods});

  factory SessionPodsResponse.fromJson(Map<String, dynamic> json) =>
      SessionPodsResponse(
        pods: (json['pods'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(SessionPod.fromJson)
            .toList(growable: false),
      );

  final List<SessionPod> pods;
}

class SessionPodResponse {
  const SessionPodResponse({required this.pod});

  factory SessionPodResponse.fromJson(Map<String, dynamic> json) {
    final rawPod = json['pod'];
    return SessionPodResponse(
      pod: rawPod is Map ? SessionPod.fromJson(rawPod) : null,
    );
  }

  final SessionPod? pod;
}

class SessionPodLogsResponse {
  const SessionPodLogsResponse({
    required this.podName,
    required this.content,
    required this.truncated,
  });

  factory SessionPodLogsResponse.fromJson(Map<String, dynamic> json) =>
      SessionPodLogsResponse(
        podName: json['podName']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        truncated: json['truncated'] == true,
      );

  final String podName;
  final String content;
  final bool truncated;
}

class SessionPodActionResponse {
  const SessionPodActionResponse({
    required this.success,
    required this.message,
    this.pod,
  });

  factory SessionPodActionResponse.fromJson(Map<String, dynamic> json) {
    final rawPod = json['pod'];
    return SessionPodActionResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      pod: rawPod is Map ? SessionPod.fromJson(rawPod) : null,
    );
  }

  final bool success;
  final String message;
  final SessionPod? pod;
}

// ---------------------------------------------------------------------------
// Shared Claude Code authentication
// ---------------------------------------------------------------------------

class ClaudeAuthBeginResponse {
  const ClaudeAuthBeginResponse({
    required this.flowId,
    required this.authorizationUrl,
    required this.expiresAt,
    required this.status,
  });

  factory ClaudeAuthBeginResponse.fromJson(Map<String, dynamic> json) =>
      ClaudeAuthBeginResponse(
        flowId: json['flowId']?.toString() ?? '',
        authorizationUrl: json['authorizationUrl']?.toString() ?? '',
        expiresAt: _parseInt64(json['expiresAt']) ?? 0,
        status: json['status']?.toString() ?? '',
      );

  final String flowId;
  final String authorizationUrl;
  final int expiresAt;
  final String status;
}

class ClaudeAuthStatusResponse {
  const ClaudeAuthStatusResponse({
    required this.flowId,
    required this.status,
    required this.success,
    required this.authenticated,
    required this.error,
  });

  factory ClaudeAuthStatusResponse.fromJson(Map<String, dynamic> json) =>
      ClaudeAuthStatusResponse(
        flowId: json['flowId']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        success: json['success'] == true,
        authenticated: json['authenticated'] == true,
        error: json['error']?.toString() ?? '',
      );

  final String flowId;
  final String status;
  final bool success;
  final bool authenticated;
  final String error;
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

// ---------------------------------------------------------------------------
// getClaudeUsageLimits
// ---------------------------------------------------------------------------

class ClaudeUsageLimitsResponse {
  const ClaudeUsageLimitsResponse({
    required this.success,
    this.data,
    this.error,
  });

  factory ClaudeUsageLimitsResponse.fromJson(Map<String, dynamic> json) =>
      ClaudeUsageLimitsResponse(
        success: json['success'] as bool? ?? false,
        data: json['data'] as String?,
        error: json['error'] as String?,
      );
  final bool success;

  /// JSON-encoded usage limits payload from Anthropic.
  final String? data;
  final String? error;
}

// ---------------------------------------------------------------------------
// getClaudeLocalUsage
// ---------------------------------------------------------------------------

class ClaudeLocalUsageResponse {
  const ClaudeLocalUsageResponse({
    required this.success,
    this.data,
    this.error,
  });

  factory ClaudeLocalUsageResponse.fromJson(Map<String, dynamic> json) =>
      ClaudeLocalUsageResponse(
        success: json['success'] as bool? ?? false,
        data: json['data'] as String?,
        error: json['error'] as String?,
      );
  final bool success;

  /// JSON-encoded ClaudeLocalUsage payload scraped from
  /// `~/.claude/stats-cache.json` by the daemon.
  final String? data;
  final String? error;
}
