/// Session metadata from storage types
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:happy_flutter/core/models/todo.dart' show TodoItem;

part 'session.freezed.dart';
part 'session.g.dart';

int _asApiInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

int? _asApiIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

String? _asApiStringNullable(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return null;
}

String _asApiStringOrEmpty(dynamic value) {
  if (value is String) return value;
  return '';
}

bool? _asApiBoolNullable(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  return null;
}

List<String>? _asApiStringListNullable(dynamic value) {
  if (value is! List) return null;
  final strings = value.whereType<String>().toList();
  if (strings.isEmpty) return null;
  return strings;
}

Object? _readSlashCommands(Map<dynamic, dynamic> json, String key) {
  return json[key] ?? json['slash_commands'];
}

Summary? _summaryFromJson(dynamic value) {
  if (value is String) {
    if (value.isEmpty) return null;
    return Summary(text: value, updatedAt: 0);
  }

  Map<String, dynamic>? map;
  if (value is Map<String, dynamic>) {
    map = value;
  } else if (value is Map) {
    try {
      map = Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  } else {
    return null;
  }
  // Require updatedAt to be numeric — reject string values like 'invalid-int'
  final updatedAt = map['updatedAt'];
  if (updatedAt != null && updatedAt is! num) return null;
  try {
    return Summary.fromJson(map);
  } catch (_) {
    return null;
  }
}

CodexGoal? _codexGoalFromJson(dynamic value) {
  Map<String, dynamic>? map;
  if (value is Map<String, dynamic>) {
    map = value;
  } else if (value is Map) {
    try {
      map = Map<String, dynamic>.from(value);
    } catch (_) {
      return null;
    }
  }
  if (map == null) return null;
  return CodexGoal.fromJson(map);
}

bool? _sandboxEnabledFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value['enabled'] == true;
  }
  if (value is Map) {
    return value['enabled'] == true;
  }
  return null;
}

/// Serialize sandboxEnabled back to `{enabled: bool}` format or null
dynamic _sandboxEnabledToJson(bool? sandboxEnabled) {
  if (sandboxEnabled == null) return null;
  return {'enabled': sandboxEnabled};
}

Metadata? _metadataFromJson(dynamic value) {
  if (value is Map<String, dynamic>) return Metadata.fromJson(value);
  return null;
}

/// Extracts the `createdAt` of the last message embedded in a session
/// list response (`lastMessage: { createdAt, ... }`).
///
/// The server-side `/v2/sessions` endpoint includes the most recent
/// message for every session, so the inbox knows the true last-activity
/// time even before the chat is opened and its message cache is
/// populated. Without this the inbox would fall back to
/// `session.updatedAt`, which can lag behind during agent streaming
/// (the activity flush is throttled per session) and look wrong until
/// the user opens the chat and triggers a refetch.
int? _lastMessageAtFromJson(dynamic value) {
  // Wire format from /v2/sessions: { id, createdAt, ... }.
  if (value is Map) {
    final created = value is Map<String, dynamic>
        ? value['createdAt']
        : value['createdAt'];
    return _asApiIntNullable(created);
  }
  // Roundtrip from our own toJson: a plain int.
  return _asApiIntNullable(value);
}

AgentState? _agentStateFromJson(dynamic value) {
  if (value is Map<String, dynamic>) return AgentState.fromJson(value);
  return null;
}

List<TodoItem>? _todoListFromJson(dynamic value) =>
    TodoItem.listFromJson(value);

String _presenceFromJson(dynamic value) {
  if (value is String) return value;
  return 'offline';
}

UsageData? _usageDataFromJson(dynamic value) {
  if (value is Map<String, dynamic>) return UsageData.fromJson(value);
  return null;
}

@freezed
abstract class Metadata with _$Metadata {
  const factory Metadata({
    @JsonKey(fromJson: _asApiStringNullable) String? path,
    @Default('') String host,
    @JsonKey(fromJson: _asApiStringNullable) String? version,
    @JsonKey(fromJson: _asApiStringNullable) String? name,
    @JsonKey(fromJson: _asApiStringNullable) String? os,
    @JsonKey(fromJson: _summaryFromJson) Summary? summary,
    @JsonKey(fromJson: _asApiStringNullable) String? machineId,
    @JsonKey(fromJson: _asApiStringNullable) String? claudeSessionId,
    @JsonKey(fromJson: _asApiStringListNullable) List<String>? tools,
    @JsonKey(readValue: _readSlashCommands, fromJson: _asApiStringListNullable)
    List<String>? slashCommands,
    @JsonKey(fromJson: _asApiStringNullable) String? homeDir,
    @JsonKey(fromJson: _asApiStringNullable) String? happyHomeDir,
    @JsonKey(fromJson: _asApiIntNullable) int? hostPid,
    @JsonKey(fromJson: _asApiStringNullable) String? flavor,
    @JsonKey(fromJson: _asApiStringNullable) String? model,
    @JsonKey(fromJson: _asApiStringNullable) String? lifecycleState,
    @JsonKey(fromJson: _asApiStringNullable) String? lifecycleStateError,
    @JsonKey(fromJson: _asApiIntNullable) int? lifecycleStateSince,
    @JsonKey(fromJson: _asApiStringNullable) String? repoUrl,
    @JsonKey(fromJson: _asApiStringNullable) String? repoRef,
    @JsonKey(fromJson: _asApiStringNullable) String? repoCommit,
    @JsonKey(name: 'runtimeType', fromJson: _asApiStringNullable)
    String? runtimeKind,
    @JsonKey(fromJson: _asApiStringNullable) String? podName,
    @JsonKey(fromJson: _asApiStringNullable) String? namespace,
    @JsonKey(fromJson: _asApiStringNullable) String? podPhase,
    @JsonKey(fromJson: _asApiStringNullable) String? podStatus,
    @JsonKey(fromJson: _asApiBoolNullable) bool? podReady,
    @JsonKey(fromJson: _asApiBoolNullable) bool? podPaused,
    // sandbox field is stored as {enabled: bool} but we keep bool? in model
    @JsonKey(
      name: 'sandbox',
      fromJson: _sandboxEnabledFromJson,
      toJson: _sandboxEnabledToJson,
    )
    bool? sandboxEnabled,
    @JsonKey(fromJson: _asApiBoolNullable) bool? sandboxRequested,
    @JsonKey(fromJson: _asApiBoolNullable) bool? sandboxRequired,
    @JsonKey(fromJson: _asApiBoolNullable) bool? sandboxEnforced,
    @JsonKey(fromJson: _asApiStringNullable) String? sandboxBackend,
    @JsonKey(fromJson: _asApiStringNullable) String? sandboxReason,
  }) = _Metadata;

  factory Metadata.fromJson(Map<String, dynamic> json) =>
      _$MetadataFromJson(json);
}

enum SessionPodDisplayState { scheduling, ready, paused, archived, failed }

extension SessionPodMetadata on Session {
  bool get isKubernetesSession =>
      metadata?.runtimeKind?.toLowerCase() == 'kubernetes' ||
      (metadata?.podName?.isNotEmpty ?? false);

  SessionPodDisplayState get podDisplayState {
    if (archived || effectiveLifecycleState == 'archived') {
      return SessionPodDisplayState.archived;
    }
    final metadata = this.metadata;
    if (metadata?.podPaused == true ||
        metadata?.podStatus?.toLowerCase() == 'paused') {
      return SessionPodDisplayState.paused;
    }
    final phase = metadata?.podPhase?.toLowerCase() ?? '';
    final lifecycle = effectiveLifecycleState?.toLowerCase() ?? '';
    if (phase == 'failed' || lifecycle == 'errored') {
      return SessionPodDisplayState.failed;
    }
    if (metadata?.podReady == true ||
        phase == 'running' ||
        lifecycle == 'running') {
      return SessionPodDisplayState.ready;
    }
    return SessionPodDisplayState.scheduling;
  }
}

@freezed
abstract class Summary with _$Summary {
  const factory Summary({
    required String text,
    @JsonKey(fromJson: _asApiInt) required int updatedAt,
  }) = _Summary;

  factory Summary.fromJson(Map<String, dynamic> json) =>
      _$SummaryFromJson(json);
}

/// Current Codex goal persisted by happy-cli-go in session agent state.
class CodexGoal {
  const CodexGoal({
    required this.objective,
    this.status = 'active',
    this.updatedAt,
  });

  factory CodexGoal.fromJson(Map<String, dynamic> json) {
    final objective =
        _asApiStringNullable(json['objective']) ??
        _asApiStringNullable(json['text']) ??
        '';
    return CodexGoal(
      objective: objective.trim(),
      status: _asApiStringNullable(json['status']) ?? 'active',
      updatedAt: _asApiIntNullable(json['updatedAt']),
    );
  }

  final String objective;
  final String status;
  final int? updatedAt;

  bool get isVisible => objective.trim().isNotEmpty && status != 'cleared';

  Map<String, dynamic> toJson() {
    return {'objective': objective, 'status': status, 'updatedAt': updatedAt};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodexGoal &&
          runtimeType == other.runtimeType &&
          objective == other.objective &&
          status == other.status &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(objective, status, updatedAt);
}

/// Agent state for a session
class AgentState {
  AgentState({
    this.controlledByUser,
    this.requests,
    this.completedRequests,
    this.goal,
  });

  factory AgentState.fromJson(Map<String, dynamic> json) {
    final requestsRaw = json['requests'];
    Map<String, RequestInfo>? requests;
    if (requestsRaw is Map) {
      final parsed = <String, RequestInfo>{};
      for (final entry in requestsRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        Map<String, dynamic>? mapValue;
        if (value is Map<String, dynamic>) {
          mapValue = value;
        } else if (value is Map) {
          try {
            mapValue = Map<String, dynamic>.from(value);
          } catch (_) {
            mapValue = null;
          }
        }
        if (mapValue == null) continue;
        try {
          parsed[key] = RequestInfo.fromJson(mapValue);
        } catch (_) {
          continue;
        }
      }
      if (parsed.isNotEmpty) {
        requests = parsed;
      }
    }

    final completedRequestsRaw = json['completedRequests'];
    Map<String, CompletedRequestInfo>? completedRequests;
    if (completedRequestsRaw is Map) {
      final parsed = <String, CompletedRequestInfo>{};
      for (final entry in completedRequestsRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        Map<String, dynamic>? mapValue;
        if (value is Map<String, dynamic>) {
          mapValue = value;
        } else if (value is Map) {
          try {
            mapValue = Map<String, dynamic>.from(value);
          } catch (_) {
            mapValue = null;
          }
        }
        if (mapValue == null) continue;
        try {
          parsed[key] = CompletedRequestInfo.fromJson(mapValue);
        } catch (_) {
          continue;
        }
      }
      if (parsed.isNotEmpty) {
        completedRequests = parsed;
      }
    }

    return AgentState(
      controlledByUser: _asApiBoolNullable(json['controlledByUser']),
      requests: requests,
      completedRequests: completedRequests,
      goal: _codexGoalFromJson(json['goal']),
    );
  }

  final bool? controlledByUser;
  final Map<String, RequestInfo>? requests;
  final Map<String, CompletedRequestInfo>? completedRequests;
  final CodexGoal? goal;

  Map<String, dynamic> toJson() {
    return {
      'controlledByUser': controlledByUser,
      'requests': requests?.map(
        (k, v) => MapEntry(k, {
          'tool': v.tool,
          'arguments': v.arguments,
          'createdAt': v.createdAt,
        }),
      ),
      'completedRequests': completedRequests?.map(
        (k, v) => MapEntry(k, {
          'tool': v.tool,
          'arguments': v.arguments,
          'createdAt': v.createdAt,
          'completedAt': v.completedAt,
          'status': v.status,
          'reason': v.reason,
          'mode': v.mode,
          'allowedTools': v.allowedTools,
          'decision': v.decision,
        }),
      ),
      'goal': goal?.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentState &&
          runtimeType == other.runtimeType &&
          controlledByUser == other.controlledByUser &&
          requests == other.requests &&
          completedRequests == other.completedRequests &&
          goal == other.goal;

  @override
  int get hashCode =>
      Object.hash(controlledByUser, requests, completedRequests, goal);
}

@freezed
abstract class RequestInfo with _$RequestInfo {
  const factory RequestInfo({
    required String tool,
    @JsonKey(includeFromJson: true, includeToJson: true) dynamic arguments,
    @JsonKey(fromJson: _asApiIntNullable) int? createdAt,
  }) = _RequestInfo;

  factory RequestInfo.fromJson(Map<String, dynamic> json) =>
      _$RequestInfoFromJson(json);
}

List<String>? _stringListNullable(dynamic value) {
  if (value is List) {
    final list = value.whereType<String>().toList();
    return list.isEmpty ? null : list;
  }
  return null;
}

@freezed
abstract class CompletedRequestInfo with _$CompletedRequestInfo {
  const factory CompletedRequestInfo({
    required String tool,
    required String status,
    @JsonKey(includeFromJson: true, includeToJson: true) dynamic arguments,
    @JsonKey(fromJson: _asApiIntNullable) int? createdAt,
    @JsonKey(fromJson: _asApiIntNullable) int? completedAt,
    @JsonKey(fromJson: _asApiStringNullable) String? reason,
    @JsonKey(fromJson: _asApiStringNullable) String? mode,
    @JsonKey(fromJson: _stringListNullable) List<String>? allowedTools,
    @JsonKey(fromJson: _asApiStringNullable) String? decision,
  }) = _CompletedRequestInfo;

  factory CompletedRequestInfo.fromJson(Map<String, dynamic> json) =>
      _$CompletedRequestInfoFromJson(json);
}

/// Main Session model
@freezed
abstract class Session with _$Session {
  const factory Session({
    @JsonKey(fromJson: _sessionIdFromJson) required String id,
    @JsonKey(fromJson: _asApiInt) required int seq,
    @JsonKey(fromJson: _asApiInt) required int createdAt,
    @JsonKey(fromJson: _asApiInt) required int updatedAt,
    required bool active,
    @JsonKey(fromJson: _asApiInt) required int activeAt,
    @JsonKey(fromJson: _asApiInt) required int metadataVersion,
    @JsonKey(fromJson: _asApiInt) required int agentStateVersion,
    required bool thinking,
    @Default(false) bool archived,
    @JsonKey(fromJson: _metadataFromJson) Metadata? metadata,
    @JsonKey(fromJson: _agentStateFromJson) AgentState? agentState,
    @JsonKey(fromJson: _asApiIntNullable) int? thinkingAt,

    /// Either the string `'online'` or an integer timestamp of last seen.
    @JsonKey(fromJson: _presenceFromJson) @Default('offline') String presence,
    @JsonKey(fromJson: _todoListFromJson) List<TodoItem>? todos,
    @JsonKey(fromJson: _asApiStringNullable) String? draft,
    @JsonKey(fromJson: _asApiStringNullable) String? permissionMode,
    @JsonKey(fromJson: _asApiStringNullable) String? modelMode,
    @JsonKey(fromJson: _usageDataFromJson) UsageData? latestUsage,

    /// Server-owned cleartext mirror of [Metadata.lifecycleState]. The
    /// server flips this to `'running'` the moment it accepts a user
    /// message (with a conditional UPDATE so a live daemon's write
    /// always wins), so a client that has been seeing `'errored'` from
    /// a stale encrypted metadata blob can clear the "Session process
    /// stopped" banner immediately on first send. Empty string on older
    /// servers; check [hasLifecycleError] rather than reading this
    /// directly.
    @JsonKey(name: 'lifecycleStateCleartext', fromJson: _asApiStringOrEmpty)
    @Default('')
    String lifecycleStateCleartext,

    /// The highest message seq number in the session, as reported by the
    /// server. Used for lazy tail-loading to avoid fetching all history.
    @JsonKey(fromJson: _asApiIntNullable) int? lastSeq,

    /// `createdAt` of the most recent message, taken from the
    /// server-provided `lastMessage` field on the session response.
    /// Used as a fallback for inbox sorting / grouping / time display
    /// when the local message cache is empty (session not yet opened).
    @JsonKey(name: 'lastMessage', fromJson: _lastMessageAtFromJson)
    int? lastMessageAt,

    /// Local-only: whether this session is pinned for quick access.
    /// Not synced to the server.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(false)
    bool pinned,

    /// Local-only: the folder this session belongs to.
    /// Not synced to the server.
    @JsonKey(includeFromJson: false, includeToJson: false) String? folder,
  }) = _Session;

  const Session._();

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);

  /// Returns `true` when presence is the string `'online'`.
  bool get isPresenceOnline => presence == 'online';

  /// Returns `true` when presence is the string `'online'`.
  bool get isOnline => presence == 'online';

  /// Returns `true` when the backend has marked the local agent process as
  /// failed. Sends to this session may be stored but cannot be processed.
  ///
  /// Cleartext wins over the encrypted metadata blob: the server flips
  /// [lifecycleStateCleartext] to `'running'` the moment it accepts a
  /// user message, so a stale encrypted `'errored'` from a dead daemon
  /// is no longer reported as soon as the user sends something. When
  /// cleartext is unset (`''`) we fall back to the encrypted blob, so
  /// older servers without the new column keep behaving as before.
  bool get hasLifecycleError {
    final c = lifecycleStateCleartext;
    if (c == 'errored') return true;
    if (c == 'running' || c == 'starting') return false;
    return metadata?.lifecycleState == 'errored';
  }

  /// Returns `true` when a failed local agent process has enough metadata for
  /// the daemon to restart it in the same project path.
  bool get canAttemptLifecycleRestore {
    if (!hasLifecycleError) return false;
    final meta = metadata;
    return (meta?.machineId?.isNotEmpty ?? false) &&
        (meta?.path?.isNotEmpty ?? false);
  }

  /// Effective lifecycle state, with the server-owned cleartext column
  /// winning over the encrypted [Metadata.lifecycleState] blob.
  ///
  /// The server flips [lifecycleStateCleartext] to `'running'` the
  /// moment it accepts a user message (with a conditional UPDATE so a
  /// live daemon's later write always wins), so a stale encrypted
  /// `'errored'` from a dead daemon is no longer reported as soon as
  /// the user sends something. When cleartext is unset (`''`) we fall
  /// back to the encrypted blob, so older servers without the new
  /// column keep behaving as before.
  String? get effectiveLifecycleState {
    final c = lifecycleStateCleartext;
    if (c.isNotEmpty) return c;
    return metadata?.lifecycleState;
  }
}

String _sessionIdFromJson(dynamic value) {
  if (value is String) return value;
  throw FormatException('Expected String for id, got ${value.runtimeType}');
}

@freezed
abstract class UsageData with _$UsageData {
  const factory UsageData({
    @JsonKey(fromJson: _asApiInt) required int inputTokens,
    @JsonKey(fromJson: _asApiInt) required int outputTokens,
    @JsonKey(fromJson: _asApiInt) required int cacheCreation,
    @JsonKey(fromJson: _asApiInt) required int cacheRead,
    @JsonKey(fromJson: _asApiInt) required int contextSize,
    @JsonKey(fromJson: _asApiInt) required int timestamp,
  }) = _UsageData;

  factory UsageData.fromJson(Map<String, dynamic> json) =>
      _$UsageDataFromJson(json);
}
