library;

import '../utils/wire_parsers.dart';

/// Canonical status values for a Claude Code workflow run.
class WorkflowStatus {
  const WorkflowStatus._();

  static const String running = 'running';
  static const String paused = 'paused';
  static const String completed = 'completed';
  static const String failed = 'failed';
  static const String killed = 'killed';

  /// Returned by the `Workflow` tool result for a background run that has
  /// been launched but whose snapshot has not been written yet.
  static const String asyncLaunched = 'async_launched';
  static const String queued = 'queued';
  static const String pending = 'pending';
  static const String cancelled = 'cancelled';

  static const Set<String> values = {
    running,
    paused,
    completed,
    failed,
    killed,
    asyncLaunched,
    queued,
    pending,
    cancelled,
  };

  /// Statuses that mean the run has not reached a terminal state, so the
  /// UI should keep polling / show a live indicator.
  static bool isLive(String status) =>
      status == running ||
      status == paused ||
      status == asyncLaunched ||
      status == queued ||
      status == pending;

  /// Whether the run is actively starting/running right now (as opposed to
  /// merely queued or paused). Drives the animated "Starting…" indicator so
  /// a queued/paused run does not spin forever next to its badge.
  static bool isStarting(String status) =>
      status == running || status == asyncLaunched;
}

/// A single phase of a Claude Code workflow run.
class WorkflowPhase {
  const WorkflowPhase({
    required this.title,
    this.detail,
  });

  factory WorkflowPhase.fromJson(Map<String, dynamic> json) {
    return WorkflowPhase(
      title: json['title'] as String,
      detail: json['detail'] as String?,
    );
  }

  final String title;
  final String? detail;

  static WorkflowPhase? tryFromJson(Map<String, dynamic> json) {
    final title = WireParsers.parseString(json['title']);
    if (title == null) return null;
    return WorkflowPhase(
      title: title,
      detail: WireParsers.parseString(json['detail']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      if (detail != null) 'detail': detail,
    };
  }

  WorkflowPhase copyWith({
    String? title,
    String? detail,
    bool clearDetail = false,
  }) {
    return WorkflowPhase(
      title: title ?? this.title,
      detail: clearDetail ? null : (detail ?? this.detail),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowPhase &&
          title == other.title &&
          detail == other.detail;

  @override
  int get hashCode => Object.hash(title, detail);

  @override
  String toString() => 'WorkflowPhase(title: $title)';
}

/// An event emitted while a workflow run progresses.
sealed class WorkflowProgressEvent {
  const WorkflowProgressEvent();

  factory WorkflowProgressEvent.fromJson(Map<String, dynamic> json) {
    final event = tryFromJson(json);
    if (event == null) {
      throw ArgumentError(
        'Unknown workflow progress event type: ${json['type']}',
      );
    }
    return event;
  }

  String get type;

  Map<String, dynamic> toJson();

  static WorkflowProgressEvent? tryFromJson(Map<String, dynamic> json) {
    final type = WireParsers.parseString(json['type']);
    switch (type) {
      case 'workflow_agent':
        return WorkflowAgent.tryFromJson(json);
      case 'workflow_phase':
        return WorkflowPhaseEvent.tryFromJson(json);
      case 'workflow_log':
        return WorkflowLog.tryFromJson(json);
      default:
        return null;
    }
  }
}

/// An agent step inside a workflow run.
class WorkflowAgent implements WorkflowProgressEvent {
  const WorkflowAgent({
    required this.agentId,
    required this.label,
    required this.phaseIndex,
    required this.phaseTitle,
    required this.model,
    required this.state,
    this.tokens,
    this.toolCalls,
    this.durationMs,
    this.promptPreview,
    this.resultPreview,
    this.error,
  });

  factory WorkflowAgent.fromJson(Map<String, dynamic> json) {
    return WorkflowAgent(
      agentId: json['agentId'] as String,
      label: json['label'] as String,
      phaseIndex: (json['phaseIndex'] as num).toInt(),
      phaseTitle: json['phaseTitle'] as String,
      model: json['model'] as String,
      state: json['state'] as String,
      tokens: (json['tokens'] as num?)?.toInt(),
      toolCalls: (json['toolCalls'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      promptPreview: json['promptPreview'] as String?,
      resultPreview: json['resultPreview'] as String?,
      error: json['error'] as String?,
    );
  }

  @override
  String get type => 'workflow_agent';

  final String agentId;
  final String label;
  final int phaseIndex;
  final String phaseTitle;
  final String model;
  final String state;
  final int? tokens;
  final int? toolCalls;
  final int? durationMs;
  final String? promptPreview;
  final String? resultPreview;
  final String? error;

  static WorkflowAgent? tryFromJson(Map<String, dynamic> json) {
    final agentId = WireParsers.parseString(json['agentId']);
    final label = WireParsers.parseString(json['label']);
    final phaseIndex = WireParsers.parseInt(json['phaseIndex']);
    final phaseTitle = WireParsers.parseString(json['phaseTitle']);
    final model = WireParsers.parseString(json['model']);
    final state = WireParsers.parseString(json['state']);
    if (agentId == null ||
        label == null ||
        phaseIndex == null ||
        phaseTitle == null ||
        model == null ||
        state == null) {
      return null;
    }
    return WorkflowAgent(
      agentId: agentId,
      label: label,
      phaseIndex: phaseIndex,
      phaseTitle: phaseTitle,
      model: model,
      state: state,
      tokens: WireParsers.parseInt(json['tokens']),
      toolCalls: WireParsers.parseInt(json['toolCalls']),
      durationMs: WireParsers.parseInt(json['durationMs']),
      promptPreview: WireParsers.parseString(json['promptPreview']),
      resultPreview: WireParsers.parseString(json['resultPreview']),
      error: WireParsers.parseString(json['error']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'agentId': agentId,
      'label': label,
      'phaseIndex': phaseIndex,
      'phaseTitle': phaseTitle,
      'model': model,
      'state': state,
      if (tokens != null) 'tokens': tokens,
      if (toolCalls != null) 'toolCalls': toolCalls,
      if (durationMs != null) 'durationMs': durationMs,
      if (promptPreview != null) 'promptPreview': promptPreview,
      if (resultPreview != null) 'resultPreview': resultPreview,
      if (error != null) 'error': error,
    };
  }

  WorkflowAgent copyWith({
    String? agentId,
    String? label,
    int? phaseIndex,
    String? phaseTitle,
    String? model,
    String? state,
    int? tokens,
    bool clearTokens = false,
    int? toolCalls,
    bool clearToolCalls = false,
    int? durationMs,
    bool clearDurationMs = false,
    String? promptPreview,
    bool clearPromptPreview = false,
    String? resultPreview,
    bool clearResultPreview = false,
    String? error,
    bool clearError = false,
  }) {
    return WorkflowAgent(
      agentId: agentId ?? this.agentId,
      label: label ?? this.label,
      phaseIndex: phaseIndex ?? this.phaseIndex,
      phaseTitle: phaseTitle ?? this.phaseTitle,
      model: model ?? this.model,
      state: state ?? this.state,
      tokens: clearTokens ? null : (tokens ?? this.tokens),
      toolCalls: clearToolCalls ? null : (toolCalls ?? this.toolCalls),
      durationMs: clearDurationMs ? null : (durationMs ?? this.durationMs),
      promptPreview: clearPromptPreview
          ? null
          : (promptPreview ?? this.promptPreview),
      resultPreview: clearResultPreview
          ? null
          : (resultPreview ?? this.resultPreview),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowAgent &&
          agentId == other.agentId &&
          label == other.label &&
          phaseIndex == other.phaseIndex &&
          phaseTitle == other.phaseTitle &&
          model == other.model &&
          state == other.state &&
          tokens == other.tokens &&
          toolCalls == other.toolCalls &&
          durationMs == other.durationMs &&
          promptPreview == other.promptPreview &&
          resultPreview == other.resultPreview &&
          error == other.error;

  @override
  int get hashCode => Object.hash(
        agentId,
        label,
        phaseIndex,
        phaseTitle,
        model,
        state,
        tokens,
        toolCalls,
        durationMs,
        promptPreview,
        resultPreview,
        error,
      );

  @override
  String toString() =>
      'WorkflowAgent(agentId: $agentId, label: $label, state: $state)';
}

/// A phase transition event inside a workflow run.
class WorkflowPhaseEvent implements WorkflowProgressEvent {
  const WorkflowPhaseEvent({
    required this.index,
    required this.title,
    required this.kind,
  });

  factory WorkflowPhaseEvent.fromJson(Map<String, dynamic> json) {
    return WorkflowPhaseEvent(
      index: (json['index'] as num).toInt(),
      title: json['title'] as String,
      kind: json['kind'] as String,
    );
  }

  @override
  String get type => 'workflow_phase';

  final int index;
  final String title;
  final String kind;

  static WorkflowPhaseEvent? tryFromJson(Map<String, dynamic> json) {
    final index = WireParsers.parseInt(json['index']);
    final title = WireParsers.parseString(json['title']);
    if (index == null || title == null) return null;
    return WorkflowPhaseEvent(
      index: index,
      title: title,
      kind: WireParsers.parseString(json['kind']) ?? 'start',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'index': index,
      'title': title,
      'kind': kind,
    };
  }

  WorkflowPhaseEvent copyWith({
    int? index,
    String? title,
    String? kind,
  }) {
    return WorkflowPhaseEvent(
      index: index ?? this.index,
      title: title ?? this.title,
      kind: kind ?? this.kind,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowPhaseEvent &&
          index == other.index &&
          title == other.title &&
          kind == other.kind;

  @override
  int get hashCode => Object.hash(index, title, kind);

  @override
  String toString() => 'WorkflowPhaseEvent(index: $index, title: $title)';
}

/// A log line emitted by a workflow run.
class WorkflowLog implements WorkflowProgressEvent {
  const WorkflowLog({required this.message});

  factory WorkflowLog.fromJson(Map<String, dynamic> json) {
    return WorkflowLog(message: json['message'] as String);
  }

  @override
  String get type => 'workflow_log';

  final String message;

  static WorkflowLog? tryFromJson(Map<String, dynamic> json) {
    final message = WireParsers.parseString(json['message']);
    if (message == null) return null;
    return WorkflowLog(message: message);
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'message': message,
    };
  }

  WorkflowLog copyWith({String? message}) {
    return WorkflowLog(message: message ?? this.message);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowLog && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'WorkflowLog(message: $message)';
}

/// A Claude Code workflow run mirrored from the daemon.
class WorkflowRun {
  const WorkflowRun({
    required this.runId,
    required this.workflowName,
    required this.status,
    this.taskId,
    this.summary,
    this.script = '',
    this.scriptPath = '',
    this.args,
    this.phases = const <WorkflowPhase>[],
    this.defaultModel,
    this.startTime,
    this.durationMs,
    this.agentCount,
    this.totalTokens,
    this.totalToolCalls,
    this.error,
    this.result,
    this.logs,
    this.workflowProgress = const <WorkflowProgressEvent>[],
  });

  factory WorkflowRun.fromJson(Map<String, dynamic> json) {
    final phasesJson = WireParsers.asList(json['phases']);
    final progressJson = rawWorkflowProgress(json);
    return WorkflowRun(
      runId: json['runId'] as String,
      workflowName: json['workflowName'] as String,
      status: json['status'] as String,
      taskId: json['taskId'] as String?,
      summary: json['summary'] as String?,
      script: json['script'] as String? ?? '',
      scriptPath: json['scriptPath'] as String? ?? '',
      args: WireParsers.asMap(json['args']),
      phases: phasesJson == null
          ? const <WorkflowPhase>[]
          : phasesJson
              .whereType<Map<String, dynamic>>()
              .map(WorkflowPhase.fromJson)
              .toList(growable: false),
      defaultModel: json['defaultModel'] as String?,
      startTime: (json['startTime'] as num?)?.toInt(),
      durationMs: (json['durationMs'] as num?)?.toInt(),
      agentCount: (json['agentCount'] as num?)?.toInt(),
      totalTokens: (json['totalTokens'] as num?)?.toInt(),
      totalToolCalls: (json['totalToolCalls'] as num?)?.toInt(),
      error: json['error'] as String?,
      result: json['result'] as String?,
      logs: json['logs'] as String?,
      workflowProgress: progressJson == null
          ? const <WorkflowProgressEvent>[]
          : progressJson
              .whereType<Map<String, dynamic>>()
              .map(WorkflowProgressEvent.fromJson)
              .toList(growable: false),
    );
  }

  final String runId;
  final String? taskId;
  final String workflowName;
  final String? summary;
  final String status;
  final String script;
  final String scriptPath;
  final Map<String, dynamic>? args;
  final List<WorkflowPhase> phases;
  final String? defaultModel;
  final int? startTime;
  final int? durationMs;
  final int? agentCount;
  final int? totalTokens;
  final int? totalToolCalls;
  final String? error;
  final String? result;
  final String? logs;
  final List<WorkflowProgressEvent> workflowProgress;

  /// Raw progress-event list from a map, accepting both the camelCase key
  /// used by on-disk / `workflow-list` / `workflow-read` snapshots
  /// (`workflowProgress`) and the snake_case key the streamed task events
  /// use (`workflow_progress`). Centralised so the casing rule lives in one
  /// place — every reader (RPC parse, message overlay, inline view) agrees.
  static List<dynamic>? rawWorkflowProgress(Map<String, dynamic> json) =>
      WireParsers.asList(
        json['workflowProgress'] ?? json['workflow_progress'],
      );

  /// Returns [next], but when it is a sparse snapshot (no progress and no
  /// phases — e.g. a running run whose on-disk snapshot is not written yet)
  /// the progress/phases/counts already held in [prev] are kept, so a thin
  /// poll result never blanks a live overlay. Pure + static for testability.
  static WorkflowRun withFallbackProgress(
    WorkflowRun next,
    WorkflowRun? prev,
  ) {
    if (prev == null) return next;
    if (next.workflowProgress.isNotEmpty || next.phases.isNotEmpty) {
      return next;
    }
    // A terminal snapshot is authoritative even when sparse; never paste a
    // stale live overlay onto a completed/failed run.
    if (!WorkflowStatus.isLive(next.status)) return next;
    return next.copyWith(
      workflowProgress: prev.workflowProgress,
      phases: prev.phases,
      agentCount: prev.agentCount,
      totalTokens: prev.totalTokens,
      totalToolCalls: prev.totalToolCalls,
    );
  }

  static WorkflowRun? tryFromJson(Map<String, dynamic> json) {
    final runId = WireParsers.parseString(json['runId']);
    final taskId = WireParsers.parseString(json['taskId']);
    final workflowName = WireParsers.parseString(json['workflowName']);
    final status = WireParsers.parseString(json['status']);
    if (runId == null || workflowName == null || status == null) {
      return null;
    }
    final phasesJson = WireParsers.asList(json['phases']);
    final progressJson = rawWorkflowProgress(json);
    return WorkflowRun(
      runId: runId,
      workflowName: workflowName,
      status: status,
      taskId: taskId,
      summary: WireParsers.parseString(json['summary']),
      script: WireParsers.parseString(json['script']) ?? '',
      scriptPath: WireParsers.parseString(json['scriptPath']) ?? '',
      args: WireParsers.asMap(json['args']),
      phases: phasesJson == null
          ? const <WorkflowPhase>[]
          : phasesJson
              .whereType<Map<String, dynamic>>()
              .map(WorkflowPhase.tryFromJson)
              .whereType<WorkflowPhase>()
              .toList(growable: false),
      defaultModel: WireParsers.parseString(json['defaultModel']),
      startTime: WireParsers.parseInt(json['startTime']),
      durationMs: WireParsers.parseInt(json['durationMs']),
      agentCount: WireParsers.parseInt(json['agentCount']),
      totalTokens: WireParsers.parseInt(json['totalTokens']),
      totalToolCalls: WireParsers.parseInt(json['totalToolCalls']),
      error: WireParsers.parseString(json['error']),
      result: WireParsers.parseString(json['result']),
      logs: WireParsers.parseString(json['logs']),
      workflowProgress: progressJson == null
          ? const <WorkflowProgressEvent>[]
          : progressJson
              .whereType<Map<String, dynamic>>()
              .map(WorkflowProgressEvent.tryFromJson)
              .whereType<WorkflowProgressEvent>()
              .toList(growable: false),
    );
  }

  /// Most recent progress snapshot carried on a list of sidechain child
  /// messages — the same `children` array the chat inline view reads.
  ///
  /// Walks the list in reverse because the most recent task event carries
  /// the complete snapshot. Returns an empty list when no child carries a
  /// parseable, non-empty `workflowProgress`.
  static List<WorkflowProgressEvent> latestProgressFromChildren(
    List<dynamic>? children,
  ) {
    final list = WireParsers.asList(children);
    if (list == null) return const <WorkflowProgressEvent>[];
    for (var i = list.length - 1; i >= 0; i--) {
      final msg = list[i];
      if (msg is! Map<String, dynamic>) continue;
      final raw = rawWorkflowProgress(msg);
      if (raw == null || raw.isEmpty) continue;
      final parsed = raw
          .whereType<Map<String, dynamic>>()
          .map(WorkflowProgressEvent.tryFromJson)
          .whereType<WorkflowProgressEvent>()
          .toList(growable: false);
      if (parsed.isNotEmpty) return parsed;
    }
    return const <WorkflowProgressEvent>[];
  }

  /// Overlays the live, in-flight progress snapshot for this run from the
  /// session's grouped messages and returns a copy with
  /// `workflowProgress`, `phases`, and the aggregate counts refreshed.
  ///
  /// Completed runs already carry a full rich snapshot (phases, agents,
  /// tokens, `workflowProgress`) from the daemon's `workflow-list` /
  /// `workflow-read` — both read straight from the on-disk
  /// `wf_<runId>.json` — so for them this is usually a no-op. It matters
  /// for *running foreground* workflows whose streamed `task_progress`
  /// sidechain events are more current than the last persisted snapshot:
  /// the chat inline view reads those events directly, and this lets the
  /// Workflows list and detail screens show the same live picture.
  /// Background workflows emit no events into the parent transcript, so
  /// there is nothing to overlay for them until they complete.
  ///
  /// Returns [run] unchanged when the messages carry no progress for it,
  /// so an already-rich daemon snapshot is never wiped out.
  static WorkflowRun enrichFromMessages(
    WorkflowRun run,
    List<Map<String, dynamic>> messages,
  ) {
    final children = _progressChildrenForRun(run.runId, messages);
    if (children == null) return run;
    final progress = latestProgressFromChildren(children);
    if (progress.isEmpty) return run;
    return _withProgress(run, progress);
  }

  static WorkflowRun _withProgress(
    WorkflowRun run,
    List<WorkflowProgressEvent> progress,
  ) {
    final phaseEvents = progress
        .whereType<WorkflowPhaseEvent>()
        .toList(growable: false)
      ..sort((a, b) => a.index.compareTo(b.index));
    final agents =
        progress.whereType<WorkflowAgent>().toList(growable: false);
    final phases = phaseEvents
        .map((event) => WorkflowPhase(title: event.title))
        .toList(growable: false);
    final seenAgents = <String>{};
    var tokens = 0;
    var toolCalls = 0;
    for (final agent in agents) {
      seenAgents.add(agent.agentId);
      if (agent.tokens != null) tokens += agent.tokens!;
      if (agent.toolCalls != null) toolCalls += agent.toolCalls!;
    }
    return run.copyWith(
      workflowProgress: progress,
      phases: phases,
      agentCount: seenAgents.isNotEmpty ? seenAgents.length : null,
      clearAgentCount: seenAgents.isEmpty,
      totalTokens: tokens > 0 ? tokens : null,
      clearTotalTokens: tokens == 0,
      totalToolCalls: toolCalls > 0 ? toolCalls : null,
      clearTotalToolCalls: toolCalls == 0,
    );
  }

  /// Locates the sidechain `children` array that belongs to [runId].
  ///
  /// Primary match: a `Workflow` tool-call message whose own tag (or a
  /// child's tag) equals [runId] — its `children` are exactly what the
  /// chat inline view renders, including in-flight events that may not
  /// carry the tag themselves. Fallbacks cover a single progress-bearing
  /// `Workflow` tool-call (one-run sessions whose tag is missing) and the
  /// set of messages tagged with [runId] anywhere in the tree (ungrouped
  /// or orphan sidechains).
  static List<dynamic>? _progressChildrenForRun(
    String runId,
    List<Map<String, dynamic>> messages,
  ) {
    List<dynamic>? ownerChildren;
    Map<String, dynamic>? soleProgressOwner;
    var progressOwnerCount = 0;
    final tagged = <Map<String, dynamic>>[];

    void walk(List<dynamic> list) {
      for (final entry in list) {
        if (entry is! Map<String, dynamic>) continue;
        final children = WireParsers.asList(entry['children']);
        final isWorkflow =
            entry['kind'] == 'tool-call' && entry['name'] == 'Workflow';
        if (isWorkflow) {
          final ownTag = _workflowRunTag(entry) ??
              _firstWorkflowRunTag(children);
          if (ownTag == runId && ownerChildren == null) {
            ownerChildren = children;
          }
          if (_anyProgress(children)) {
            progressOwnerCount += 1;
            soleProgressOwner = entry;
          }
        }
        if (_workflowRunTag(entry) == runId && _hasProgress(entry)) {
          tagged.add(entry);
        }
        if (children != null) walk(children);
      }
    }

    walk(messages);

    if (ownerChildren != null) return ownerChildren;
    if (progressOwnerCount == 1) {
      return WireParsers.asList(soleProgressOwner!['children']);
    }
    if (tagged.isNotEmpty) return tagged;
    return null;
  }

  static String? _workflowRunTag(Map<String, dynamic> message) =>
      WireParsers.parseString(message['workflowRunId']);

  static String? _firstWorkflowRunTag(List<dynamic>? children) {
    final list = WireParsers.asList(children);
    if (list == null) return null;
    for (final entry in list) {
      if (entry is! Map<String, dynamic>) continue;
      final tag = WireParsers.parseString(entry['workflowRunId']);
      if (tag != null) return tag;
    }
    return null;
  }

  static bool _hasProgress(Map<String, dynamic> message) {
    final list = rawWorkflowProgress(message);
    return list != null && list.isNotEmpty;
  }

  static bool _anyProgress(List<dynamic>? children) {
    final list = WireParsers.asList(children);
    if (list == null) return false;
    for (final entry in list) {
      if (entry is Map<String, dynamic> && _hasProgress(entry)) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'runId': runId,
      if (taskId != null) 'taskId': taskId,
      'workflowName': workflowName,
      if (summary != null) 'summary': summary,
      'status': status,
      'script': script,
      'scriptPath': scriptPath,
      if (args != null) 'args': args,
      'phases': phases.map((p) => p.toJson()).toList(growable: false),
      if (defaultModel != null) 'defaultModel': defaultModel,
      if (startTime != null) 'startTime': startTime,
      if (durationMs != null) 'durationMs': durationMs,
      if (agentCount != null) 'agentCount': agentCount,
      if (totalTokens != null) 'totalTokens': totalTokens,
      if (totalToolCalls != null) 'totalToolCalls': totalToolCalls,
      if (error != null) 'error': error,
      if (result != null) 'result': result,
      if (logs != null) 'logs': logs,
      'workflowProgress': workflowProgress
          .map((e) => e.toJson())
          .toList(growable: false),
    };
  }

  WorkflowRun copyWith({
    String? runId,
    String? workflowName,
    String? status,
    String? taskId,
    bool clearTaskId = false,
    String? summary,
    bool clearSummary = false,
    String? script,
    String? scriptPath,
    Map<String, dynamic>? args,
    bool clearArgs = false,
    List<WorkflowPhase>? phases,
    String? defaultModel,
    bool clearDefaultModel = false,
    int? startTime,
    bool clearStartTime = false,
    int? durationMs,
    bool clearDurationMs = false,
    int? agentCount,
    bool clearAgentCount = false,
    int? totalTokens,
    bool clearTotalTokens = false,
    int? totalToolCalls,
    bool clearTotalToolCalls = false,
    String? error,
    bool clearError = false,
    String? result,
    bool clearResult = false,
    String? logs,
    bool clearLogs = false,
    List<WorkflowProgressEvent>? workflowProgress,
  }) {
    return WorkflowRun(
      runId: runId ?? this.runId,
      workflowName: workflowName ?? this.workflowName,
      status: status ?? this.status,
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      summary: clearSummary ? null : (summary ?? this.summary),
      script: script ?? this.script,
      scriptPath: scriptPath ?? this.scriptPath,
      args: clearArgs ? null : (args ?? this.args),
      phases: phases ?? this.phases,
      defaultModel: clearDefaultModel
          ? null
          : (defaultModel ?? this.defaultModel),
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      durationMs: clearDurationMs ? null : (durationMs ?? this.durationMs),
      agentCount: clearAgentCount ? null : (agentCount ?? this.agentCount),
      totalTokens: clearTotalTokens
          ? null
          : (totalTokens ?? this.totalTokens),
      totalToolCalls: clearTotalToolCalls
          ? null
          : (totalToolCalls ?? this.totalToolCalls),
      error: clearError ? null : (error ?? this.error),
      result: clearResult ? null : (result ?? this.result),
      logs: clearLogs ? null : (logs ?? this.logs),
      workflowProgress: workflowProgress ?? this.workflowProgress,
    );
  }

  static bool _listsEqual<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapsEqual(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      final otherValue = b[entry.key];
      if (otherValue != entry.value) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowRun &&
          runId == other.runId &&
          taskId == other.taskId &&
          workflowName == other.workflowName &&
          summary == other.summary &&
          status == other.status &&
          script == other.script &&
          scriptPath == other.scriptPath &&
          _mapsEqual(args, other.args) &&
          _listsEqual(phases, other.phases) &&
          defaultModel == other.defaultModel &&
          startTime == other.startTime &&
          durationMs == other.durationMs &&
          agentCount == other.agentCount &&
          totalTokens == other.totalTokens &&
          totalToolCalls == other.totalToolCalls &&
          error == other.error &&
          result == other.result &&
          logs == other.logs &&
          _listsEqual(workflowProgress, other.workflowProgress);

  @override
  int get hashCode => Object.hash(
        runId,
        taskId,
        workflowName,
        summary,
        status,
        script,
        scriptPath,
        args,
        Object.hashAll(phases),
        defaultModel,
        startTime,
        durationMs,
        agentCount,
        totalTokens,
        totalToolCalls,
        error,
        result,
        logs,
        Object.hashAll(workflowProgress),
      );

  @override
  String toString() =>
      'WorkflowRun(runId: $runId, workflowName: $workflowName, '
      'status: $status)';
}
