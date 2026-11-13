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
    this.additionalRepos = const [],
    this.isRestore = false,
    this.profileId,
    this.mcpServers,
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

  /// Further GitHub repositories (`owner/repo` or a URL) a Kubernetes session
  /// may fetch and push, cloned beside the primary checkout.
  final List<String> additionalRepos;
  final bool isRestore;

  /// The provider profile this spawn uses (`default` for no profile). When
  /// set, [environmentVariables] are that profile's complete provider
  /// routing, so the daemon never restores the session's previous provider
  /// (or its own active profile) for keys the profile leaves unset. Leave it
  /// null only when the profile is genuinely unknown.
  final String? profileId;

  /// The default MCP servers a Kubernetes session starts with. Null leaves
  /// the choice to the daemon: a new session gets every available server and
  /// a restore keeps its recorded selection. Empty is an explicit "none".
  final List<String>? mcpServers;

  /// This request without [profileId], for daemons that reject the field.
  /// Preserve MCP selection, including an explicit empty list.
  SpawnSessionRequest withoutProfileId() => SpawnSessionRequest(
    type: type,
    directory: directory,
    sessionId: sessionId,
    agent: agent,
    approvedNewDirectoryCreation: approvedNewDirectoryCreation,
    environmentVariables: environmentVariables,
    startupBashScript: startupBashScript,
    permissionMode: permissionMode,
    model: model,
    spawnBackend: spawnBackend,
    repoUrl: repoUrl,
    repoRef: repoRef,
    repoCommit: repoCommit,
    additionalRepos: additionalRepos,
    isRestore: isRestore,
    mcpServers: mcpServers,
  );

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
    if (additionalRepos.isNotEmpty) 'additionalRepos': additionalRepos,
    if (isRestore) 'isRestore': true,
    if (profileId != null && profileId!.isNotEmpty) 'profileId': profileId,
    // The daemon distinguishes "unset" from "none" by mcpServersSet.
    if (mcpServers != null) ...{
      'mcpServers': mcpServers,
      'mcpServersSet': true,
    },
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
    this.providerUnavailable = false,
  });

  factory CodexModelsResponse.fromJson(Map<String, dynamic> json) {
    final rawModels = json['models'];
    return CodexModelsResponse(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      providerUnavailable: json['providerUnavailable'] == true,
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

  /// The machine has no Codex executable; installing it enables this catalog.
  final bool providerUnavailable;
}

class CodexModelInfo {
  const CodexModelInfo({
    required this.slug,
    required this.displayName,
    required this.supportedReasoningEfforts,
    this.defaultReasoningEffort,
    this.isVisibleInPicker = true,
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
      isVisibleInPicker:
          json['visibility'] != 'hide' &&
          json['visibility'] != 'none' &&
          json['hidden'] != true &&
          json['showInPicker'] != false &&
          json['show_in_picker'] != false,
    );
  }

  final String slug;
  final String displayName;
  final List<String> supportedReasoningEfforts;
  final String? defaultReasoningEffort;
  final bool isVisibleInPicker;
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
    this.startedAtMs = 0,
    this.nodeName = '',
    this.restartCount = 0,
    this.cpuRequestMillicores = 0,
    this.cpuLimitMillicores = 0,
    this.memoryRequestBytes = 0,
    this.memoryLimitBytes = 0,
    this.metricsAvailable = false,
    this.cpuUsageMillicores = 0,
    this.memoryUsageBytes = 0,
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
    startedAtMs: _protoInt(json['startedAtMs']),
    nodeName: json['nodeName']?.toString() ?? '',
    restartCount: _protoInt(json['restartCount']),
    cpuRequestMillicores: _protoInt(json['cpuRequestMillicores']),
    cpuLimitMillicores: _protoInt(json['cpuLimitMillicores']),
    memoryRequestBytes: _protoInt(json['memoryRequestBytes']),
    memoryLimitBytes: _protoInt(json['memoryLimitBytes']),
    metricsAvailable: json['metricsAvailable'] == true,
    cpuUsageMillicores: _protoInt(json['cpuUsageMillicores']),
    memoryUsageBytes: _protoInt(json['memoryUsageBytes']),
  );

  /// protojson encodes int64 as a decimal string and int32 as a number.
  static int _protoInt(Object? value) => switch (value) {
    final int v => v,
    final num v => v.toInt(),
    final String v => int.tryParse(v) ?? 0,
    _ => 0,
  };

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

  /// Pod `status.startTime` in Unix milliseconds; 0 when unknown.
  final int startedAtMs;
  final String nodeName;

  /// Restarts summed over the app containers.
  final int restartCount;

  /// Requests and limits summed over the app containers; 0 means unset.
  final int cpuRequestMillicores;
  final int cpuLimitMillicores;
  final int memoryRequestBytes;
  final int memoryLimitBytes;

  /// False when the daemon has no metrics.k8s.io sample for this pod
  /// (no metrics-server, missing RBAC, older daemon, or a fresh pod).
  final bool metricsAvailable;
  final int cpuUsageMillicores;
  final int memoryUsageBytes;
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
// git-identity-get / git-identity-set
// ---------------------------------------------------------------------------

/// Where the daemon took a machine's git identity from.
enum GitIdentitySource {
  /// Set from the app and stored in the daemon's settings.
  settings,

  /// Daemon configuration fallback (`HAPPY_GIT_USER_NAME` / `_EMAIL`).
  config,

  /// Nothing configured: sessions without a git config cannot commit.
  none;

  static GitIdentitySource fromWire(Object? value) => switch (value) {
    'settings' => settings,
    'config' => config,
    _ => none,
  };
}

/// The author/committer identity a machine's sessions commit with.
/// Reply of the machine `repo-branches` RPC: what GitHub says about a
/// repository before a Kubernetes session is started from it.
class RepoBranchesResponse {
  const RepoBranchesResponse({
    required this.success,
    this.repo = '',
    this.defaultBranch = '',
    this.branches = const [],
    this.truncated = false,
    this.refExists,
    this.unavailable = false,
    this.notFound = false,
    this.error,
  });

  factory RepoBranchesResponse.fromJson(Map<String, dynamic> json) =>
      RepoBranchesResponse(
        success: json['success'] == true,
        repo: json['repo']?.toString() ?? '',
        defaultBranch: json['defaultBranch']?.toString() ?? '',
        branches: [
          if (json['branches'] case final List<dynamic> names)
            for (final name in names.whereType<String>())
              if (name.isNotEmpty) name,
        ],
        truncated: json['truncated'] == true,
        refExists: json['refExists'] is bool ? json['refExists'] as bool : null,
        unavailable: json['unavailable'] == true,
        notFound: json['notFound'] == true,
        error: json['error']?.toString(),
      );

  final bool success;

  /// Canonical `owner/repo`.
  final String repo;
  final String defaultBranch;

  /// Default branch first; at most one page when [truncated].
  final List<String> branches;
  final bool truncated;

  /// Whether the requested ref resolves; null when none was asked about or
  /// GitHub could not be asked.
  final bool? refExists;

  /// The machine has no way to read GitHub; nothing is known.
  final bool unavailable;

  /// GitHub does not show the repository to the machine's token.
  final bool notFound;
  final String? error;
}

class GitIdentityResponse {
  const GitIdentityResponse({
    required this.success,
    required this.name,
    required this.email,
    required this.source,
    this.updatedAt,
    this.error,
  });

  factory GitIdentityResponse.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    final email = json['email']?.toString().trim() ?? '';
    final source = GitIdentitySource.fromWire(json['source']);
    return GitIdentityResponse(
      success: json['success'] == true,
      name: name,
      email: email,
      // Half an identity cannot commit, so it is never reported as set.
      source: name.isEmpty || email.isEmpty ? GitIdentitySource.none : source,
      updatedAt: _parseInt64(json['updatedAt']),
      error: json['error']?.toString(),
    );
  }

  final bool success;
  final String name;
  final String email;
  final GitIdentitySource source;

  /// Millisecond epoch of the last app-side edit, when known.
  final int? updatedAt;
  final String? error;

  bool get isConfigured => source != GitIdentitySource.none;
}

/// Machine-owned instructions installed for newly created Kubernetes Pods.
class KubernetesClaudeMdResponse {
  const KubernetesClaudeMdResponse({
    required this.success,
    this.content = '',
    this.updatedAt,
    this.error,
  });

  factory KubernetesClaudeMdResponse.fromJson(Map<String, dynamic> json) =>
      KubernetesClaudeMdResponse(
        success: json['success'] == true,
        content: json['content'] is String ? json['content'] as String : '',
        updatedAt: _parseInt64(json['updatedAt']),
        error: json['error']?.toString(),
      );

  final bool success;

  /// Preserved verbatim, including leading spaces and trailing newlines.
  final String content;
  final int? updatedAt;
  final String? error;

  bool get isConfigured => content.isNotEmpty;
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
// set_model
// ---------------------------------------------------------------------------

class SetModelResponse {
  const SetModelResponse({required this.model});

  factory SetModelResponse.fromJson(Map<String, dynamic> json) =>
      SetModelResponse(model: json['model'] as String? ?? '');
  final String model;
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
