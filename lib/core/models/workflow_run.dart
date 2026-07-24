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
    this.lastToolName,
    this.lastToolSummary,
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
      lastToolName: json['lastToolName'] as String?,
      lastToolSummary: json['lastToolSummary'] as String?,
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

  /// Tool the agent invoked most recently, and a one-line summary of it — the
  /// only live signal of what a long-running agent is actually doing.
  final String? lastToolName;
  final String? lastToolSummary;

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
      lastToolName: WireParsers.parseString(json['lastToolName']),
      lastToolSummary: WireParsers.parseString(json['lastToolSummary']),
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
      if (lastToolName != null) 'lastToolName': lastToolName,
      if (lastToolSummary != null) 'lastToolSummary': lastToolSummary,
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
    String? lastToolName,
    bool clearLastToolName = false,
    String? lastToolSummary,
    bool clearLastToolSummary = false,
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
      lastToolName:
          clearLastToolName ? null : (lastToolName ?? this.lastToolName),
      lastToolSummary: clearLastToolSummary
          ? null
          : (lastToolSummary ?? this.lastToolSummary),
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
          error == other.error &&
          lastToolName == other.lastToolName &&
          lastToolSummary == other.lastToolSummary;

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
        lastToolName,
        lastToolSummary,
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

/// Display states a phase can be in.
class WorkflowPhaseState {
  const WorkflowPhaseState._();

  static const String pending = 'pending';
  static const String active = 'active';
  static const String done = 'done';
  static const String failed = 'failed';
}

/// One phase of a run together with the agents that ran inside it.
class WorkflowPhaseGroup {
  /// Creates a [WorkflowPhaseGroup].
  const WorkflowPhaseGroup({
    required this.phase,
    required this.agents,
    required this.state,
    this.wireIndex,
  });

  /// The phase, including its declared `detail` when the script provided one.
  final WorkflowPhase phase;

  /// Agents attached to this phase, in report order.
  final List<WorkflowAgent> agents;

  /// One of the [WorkflowPhaseState] values.
  final String state;

  /// The `index` the wire used for this phase, when it announced one.
  final int? wireIndex;

  /// Whether the phase has started (or finished) as opposed to still waiting.
  bool get hasStarted => state != WorkflowPhaseState.pending;
}

/// A declared phase paired with the progress event that announced it.
class _PhaseSlot {
  const _PhaseSlot({required this.phase, this.event});

  final WorkflowPhase phase;
  final WorkflowPhaseEvent? event;
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

  /// Accumulated progress carried on a list of sidechain child messages — the
  /// same `children` array the chat inline view reads.
  ///
  /// **`workflow_progress` is a delta, not a snapshot.** Claude Code emits one
  /// event per state change (usually a single `workflow_agent`), so reading
  /// only the newest child shows one agent, drops every phase announced at run
  /// start, and makes the aggregate token/tool counts collapse to whichever
  /// agent ticked last — the view then jumps around as deltas arrive. This
  /// walks every child forward and folds the stream into the current state:
  /// phases keyed by `index`, agents keyed by `agentId` (newest wins, but
  /// fields absent from a delta are retained and a terminal state is never
  /// reverted), logs appended in order with consecutive duplicates dropped.
  ///
  /// Returns an empty list when no child carries parseable progress.
  static List<WorkflowProgressEvent> accumulateProgressFromChildren(
    List<dynamic>? children,
  ) {
    final list = WireParsers.asList(children);
    if (list == null) return const <WorkflowProgressEvent>[];
    final phases = <int, WorkflowPhaseEvent>{};
    final agents = <String, WorkflowAgent>{};
    final agentOrder = <String>[];
    final logs = <WorkflowLog>[];
    for (final msg in list) {
      if (msg is! Map<String, dynamic>) continue;
      final raw = rawWorkflowProgress(msg);
      if (raw == null || raw.isEmpty) continue;
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        final event = WorkflowProgressEvent.tryFromJson(entry);
        if (event is WorkflowPhaseEvent) {
          phases[event.index] = mergePhaseEvent(phases[event.index], event);
        } else if (event is WorkflowAgent) {
          final prev = agents[event.agentId];
          if (prev == null) agentOrder.add(event.agentId);
          agents[event.agentId] = mergeAgentEvent(prev, event);
        } else if (event is WorkflowLog) {
          if (logs.isEmpty || logs.last.message != event.message) {
            logs.add(event);
          }
        }
      }
    }
    if (phases.isEmpty && agents.isEmpty && logs.isEmpty) {
      return const <WorkflowProgressEvent>[];
    }
    final orderedPhases = phases.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return <WorkflowProgressEvent>[
      ...orderedPhases,
      for (final id in agentOrder) agents[id]!,
      ...logs,
    ];
  }

  /// Agent states that mean the agent will not report again.
  static bool isTerminalAgentState(String state) =>
      state == 'done' ||
      state == 'completed' ||
      state == 'error' ||
      state == 'failed';

  /// Whether the agent is actively working right now.
  static bool isLiveAgentState(String state) =>
      state == 'start' ||
      state == 'running' ||
      state == 'progress' ||
      state == 'queued';

  /// Folds a newer agent delta onto what is already known.
  ///
  /// A delta omits fields it has nothing new to say about (a `progress` tick
  /// carries no `durationMs`/`resultPreview`), so unset fields must fall back
  /// to the retained value instead of blanking the row. Out-of-order delivery
  /// must also not resurrect a finished agent, hence the terminal-state guard.
  static WorkflowAgent mergeAgentEvent(WorkflowAgent? prev, WorkflowAgent next) {
    if (prev == null) return next;
    final keepPrevState =
        isTerminalAgentState(prev.state) && !isTerminalAgentState(next.state);
    return next.copyWith(
      state: keepPrevState ? prev.state : next.state,
      label: next.label.isEmpty ? prev.label : next.label,
      tokens: next.tokens ?? prev.tokens,
      toolCalls: next.toolCalls ?? prev.toolCalls,
      durationMs: next.durationMs ?? prev.durationMs,
      promptPreview: next.promptPreview ?? prev.promptPreview,
      resultPreview: next.resultPreview ?? prev.resultPreview,
      error: next.error ?? prev.error,
      lastToolName: next.lastToolName ?? prev.lastToolName,
      lastToolSummary: next.lastToolSummary ?? prev.lastToolSummary,
    );
  }

  /// Folds a newer phase delta onto what is already known, keeping the more
  /// advanced `kind` so a re-announced phase never regresses from done back to
  /// start.
  static WorkflowPhaseEvent mergePhaseEvent(
    WorkflowPhaseEvent? prev,
    WorkflowPhaseEvent next,
  ) {
    if (prev == null) return next;
    final prevDone = prev.kind == 'done' || prev.kind == 'completed';
    final nextDone = next.kind == 'done' || next.kind == 'completed';
    return next.copyWith(
      kind: prevDone && !nextDone ? prev.kind : next.kind,
      title: next.title.isEmpty ? prev.title : next.title,
    );
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
    final children = childrenForRun(run.runId, messages);
    if (children == null) return run;
    final progress = accumulateProgressFromChildren(children);
    if (progress.isEmpty) return run;
    return _withProgress(run, progress);
  }

  static WorkflowRun _withProgress(
    WorkflowRun run,
    List<WorkflowProgressEvent> progress,
  ) {
    final agents =
        progress.whereType<WorkflowAgent>().toList(growable: false);
    // Merge, never replace: the declared phases carry `detail` and include
    // phases the run has not announced yet, which is the roadmap the user
    // needs while the run is still early.
    final phases = mergePhases(run.phases, progress);
    // Deduped by agentId so a re-reported agent cannot double-count.
    final byId = <String, WorkflowAgent>{};
    for (final agent in agents) {
      byId[agent.agentId] = agent;
    }
    var tokens = 0;
    var toolCalls = 0;
    for (final agent in byId.values) {
      if (agent.tokens != null) tokens += agent.tokens!;
      if (agent.toolCalls != null) toolCalls += agent.toolCalls!;
    }
    return run.copyWith(
      workflowProgress: progress,
      phases: phases,
      agentCount: byId.isNotEmpty ? byId.length : null,
      clearAgentCount: byId.isEmpty,
      totalTokens: tokens > 0 ? tokens : null,
      clearTotalTokens: tokens == 0,
      totalToolCalls: toolCalls > 0 ? toolCalls : null,
      clearTotalToolCalls: toolCalls == 0,
    );
  }

  /// The run's phase roadmap: [declared] phases (from the script's
  /// `meta.phases`, carrying `detail`) enriched with any phase the progress
  /// stream announced but the script never declared. Returns an empty list
  /// when neither source has phases.
  static List<WorkflowPhase> mergePhases(
    List<WorkflowPhase> declared,
    List<WorkflowProgressEvent> progress,
  ) =>
      _phaseSlots(declared, progress)
          .map((slot) => slot.phase)
          .toList(growable: false);

  /// Phases with their agents attached, in run order — the single derivation
  /// the inline view, the list card, and the run detail screen share so a run
  /// reads the same everywhere.
  ///
  /// [fallbackTitle] titles the bucket used when the run reports agents but no
  /// phases at all; agents that match no phase are never dropped.
  static List<WorkflowPhaseGroup> phaseGroups(
    WorkflowRun run, {
    String? fallbackTitle,
  }) =>
      phaseGroupsFrom(
        declared: run.phases,
        progress: run.workflowProgress,
        fallbackTitle: fallbackTitle ?? run.workflowName,
      );

  /// [phaseGroups] for callers that hold a raw progress stream rather than a
  /// [WorkflowRun] — the chat inline view reads sidechain children directly.
  static List<WorkflowPhaseGroup> phaseGroupsFrom({
    required List<WorkflowPhase> declared,
    required List<WorkflowProgressEvent> progress,
    required String fallbackTitle,
  }) {
    final agents = progress.whereType<WorkflowAgent>().toList(growable: false);
    final slots = _phaseSlots(declared, progress);
    if (slots.isEmpty) {
      if (agents.isEmpty) return const <WorkflowPhaseGroup>[];
      return <WorkflowPhaseGroup>[
        WorkflowPhaseGroup(
          phase: WorkflowPhase(title: fallbackTitle),
          agents: agents,
          state: _phaseStateFor(null, agents, isPast: false),
        ),
      ];
    }

    final byWireIndex = <int, int>{};
    for (var i = 0; i < slots.length; i++) {
      final index = slots[i].event?.index;
      if (index != null) byWireIndex[index] = i;
    }
    final buckets = <int, List<WorkflowAgent>>{};
    final leftover = <WorkflowAgent>[];
    for (final agent in agents) {
      final position = _slotForAgent(agent, slots, byWireIndex);
      if (position == null) {
        leftover.add(agent);
      } else {
        buckets.putIfAbsent(position, () => <WorkflowAgent>[]).add(agent);
      }
    }

    // Workflows advance in order, so any phase before the furthest one that
    // has agents is finished even if it reported nothing itself.
    var furthest = -1;
    for (final position in buckets.keys) {
      if (position > furthest) furthest = position;
    }

    final groups = <WorkflowPhaseGroup>[];
    for (var i = 0; i < slots.length; i++) {
      final slotAgents = buckets[i] ?? const <WorkflowAgent>[];
      groups.add(
        WorkflowPhaseGroup(
          phase: slots[i].phase,
          agents: slotAgents,
          state: _phaseStateFor(
            slots[i].event?.kind,
            slotAgents,
            isPast: i < furthest,
          ),
          wireIndex: slots[i].event?.index,
        ),
      );
    }
    if (leftover.isNotEmpty) {
      groups.add(
        WorkflowPhaseGroup(
          phase: WorkflowPhase(title: fallbackTitle),
          agents: leftover,
          state: _phaseStateFor(null, leftover, isPast: false),
        ),
      );
    }
    return groups;
  }

  /// Resolves the phase an agent belongs to.
  ///
  /// The wire index is authoritative when the run announced its phases; it may
  /// be 0- or 1-based, which is exactly why positional matching is the last
  /// resort. `phaseTitle` is carried on every agent event and is what makes
  /// attachment work for a live run whose phase announcement has scrolled out
  /// of the delta stream.
  static int? _slotForAgent(
    WorkflowAgent agent,
    List<_PhaseSlot> slots,
    Map<int, int> byWireIndex,
  ) {
    final byIndex = byWireIndex[agent.phaseIndex];
    if (byIndex != null) return byIndex;
    if (agent.phaseTitle.isNotEmpty) {
      for (var i = 0; i < slots.length; i++) {
        if (slots[i].phase.title == agent.phaseTitle) return i;
      }
    }
    if (byWireIndex.isEmpty) {
      if (agent.phaseIndex >= 0 && agent.phaseIndex < slots.length) {
        return agent.phaseIndex;
      }
      final oneBased = agent.phaseIndex - 1;
      if (oneBased >= 0 && oneBased < slots.length) return oneBased;
    }
    return null;
  }

  static String _phaseStateFor(
    String? kind,
    List<WorkflowAgent> agents, {
    required bool isPast,
  }) {
    if (kind == 'done' || kind == 'completed') return WorkflowPhaseState.done;
    if (agents.isNotEmpty) {
      if (agents.any((a) => isLiveAgentState(a.state))) {
        return WorkflowPhaseState.active;
      }
      if (agents.every((a) => isTerminalAgentState(a.state))) {
        final failed = agents.any(
          (a) => a.state == 'error' || a.state == 'failed',
        );
        return failed ? WorkflowPhaseState.failed : WorkflowPhaseState.done;
      }
      return WorkflowPhaseState.active;
    }
    return isPast ? WorkflowPhaseState.done : WorkflowPhaseState.pending;
  }

  /// Aligns declared phases with announced phase events.
  static List<_PhaseSlot> _phaseSlots(
    List<WorkflowPhase> declared,
    List<WorkflowProgressEvent> progress,
  ) {
    final byIndex = <int, WorkflowPhaseEvent>{};
    for (final event in progress.whereType<WorkflowPhaseEvent>()) {
      byIndex[event.index] = mergePhaseEvent(byIndex[event.index], event);
    }
    final events = byIndex.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (declared.isEmpty) {
      return events
          .map(
            (event) => _PhaseSlot(
              phase: WorkflowPhase(title: event.title),
              event: event,
            ),
          )
          .toList(growable: false);
    }

    final used = <int>{};
    final slots = <_PhaseSlot>[];
    for (var i = 0; i < declared.length; i++) {
      final phase = declared[i];
      WorkflowPhaseEvent? match;
      for (final event in events) {
        if (used.contains(event.index)) continue;
        if (event.title == phase.title) {
          match = event;
          break;
        }
      }
      if (match == null && i < events.length && !used.contains(events[i].index)) {
        match = events[i];
      }
      if (match != null) used.add(match.index);
      slots.add(_PhaseSlot(phase: phase, event: match));
    }
    for (final event in events) {
      if (used.contains(event.index)) continue;
      slots.add(
        _PhaseSlot(phase: WorkflowPhase(title: event.title), event: event),
      );
    }
    return slots;
  }

  /// Locates the sidechain `children` (or top-level step events) that
  /// belong to [runId] — without requiring a `workflowProgress` snapshot.
  ///
  /// Matching order:
  ///  1. A `Workflow` tool-call whose tag (its own `workflowRunId`, a child's
  ///     `workflowRunId`, or the run id echoed in its tool result) equals
  ///     [runId] — its `children` are exactly the step events the chat inline
  ///     view and the agent screen render.
  ///  2. A single `Workflow` tool-call that carries any step event
  ///     (`workflowProgress` *or* a `task_*` progress chip) — the common
  ///     one-run-per-session case where no tag has been stamped yet.
  ///  3. Step events tagged with [runId] that never nested under their tool
  ///     call (orphan `task_*` chips anywhere in the tree).
  ///
  /// Returns `null` when nothing matches. Pure + static for testability.
  static List<dynamic>? childrenForRun(
    String runId,
    List<Map<String, dynamic>> messages,
  ) {
    List<dynamic>? ownerChildren;
    Map<String, dynamic>? soleStepOwner;
    var stepOwnerCount = 0;
    final tagged = <Map<String, dynamic>>[];

    void walk(List<dynamic> list) {
      for (final entry in list) {
        if (entry is! Map<String, dynamic>) continue;
        final children = WireParsers.asList(entry['children']);
        final isWorkflow =
            entry['kind'] == 'tool-call' && entry['name'] == 'Workflow';
        if (isWorkflow) {
          final ownTag = _workflowRunTag(entry) ??
              _firstWorkflowRunTag(children) ??
              runIdFromToolResult(entry['result']);
          if (ownTag == runId && ownerChildren == null) {
            ownerChildren = children;
          }
          if (_anyStepEvent(children)) {
            stepOwnerCount += 1;
            soleStepOwner = entry;
          }
        }
        if (_workflowRunTag(entry) == runId && _isStepEvent(entry)) {
          tagged.add(entry);
        }
        if (children != null) walk(children);
      }
    }

    walk(messages);

    if (ownerChildren != null) return ownerChildren;
    if (stepOwnerCount == 1) {
      return WireParsers.asList(soleStepOwner!['children']);
    }
    if (tagged.isNotEmpty) return tagged;
    return null;
  }

  /// The step events (task_* progress chips / sidechain records) for [runId]
  /// as a flat list of maps, for rendering a step timeline when the
  /// structured `workflowProgress` snapshot is empty. Returns an empty list
  /// when the run has no located steps.
  static List<Map<String, dynamic>> stepChildrenForRun(
    String runId,
    List<Map<String, dynamic>> messages,
  ) {
    final raw = childrenForRun(runId, messages);
    if (raw == null || raw.isEmpty) return const <Map<String, dynamic>>[];
    return raw.whereType<Map<String, dynamic>>().toList(growable: false);
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

  /// The daemon workflow-run id a container tool-call message belongs to,
  /// read off the message's own `workflowRunId` tag or, failing that, the
  /// first child that carries one (the streamed `task_*` events stamp it).
  /// Returns null for non-workflow containers and for a workflow whose first
  /// event has not yet been grouped under the tool call.
  static String? runTagForMessage(Map<String, dynamic> message) =>
      _workflowRunTag(message) ??
      _firstWorkflowRunTag(WireParsers.asList(message['children']));

  static bool _hasProgress(Map<String, dynamic> message) {
    final list = rawWorkflowProgress(message);
    return list != null && list.isNotEmpty;
  }

  /// A step event: either a `workflowProgress` snapshot or a `task_*`
  /// progress chip (`taskEvent: true`). The latter is all older CLI builds /
  /// some workflow types emit — no aggregate `workflow_progress` array — so
  /// matching on it is what lets the Workflows screens show *any* steps.
  static bool _isStepEvent(Map<String, dynamic> message) =>
      _hasProgress(message) || message['taskEvent'] == true;

  static bool _anyStepEvent(List<dynamic>? children) {
    final list = WireParsers.asList(children);
    if (list == null) return false;
    for (final entry in list) {
      if (entry is Map<String, dynamic> && _isStepEvent(entry)) return true;
    }
    return false;
  }

  /// Run id echoed in a Workflow tool result (`Run ID: wf_…`), or carried on
  /// a structured result map (`runId` / `run_id`). `null` when the result has
  /// no id. The tool *result* always echoes the id even before any `task_*`
  /// sidechain event nests under the tool call, so this is the most reliable
  /// tag for a freshly-completed run.
  static String? runIdFromToolResult(dynamic result) {
    if (result is Map<String, dynamic>) {
      final direct = WireParsers.parseString(result['runId']) ??
          WireParsers.parseString(result['run_id']);
      if (direct != null) return direct;
      return runIdFromToolResult(
        result['result'] ?? result['output'] ?? result['content'],
      );
    }
    if (result is String) {
      return _runIdInResult.firstMatch(result)?.group(1);
    }
    return null;
  }

  static final RegExp _runIdInResult = RegExp(r'Run ID:\s*([A-Za-z0-9_-]+)');

  // ── Step rendering helpers (shared by the inline view, the run detail
  //    screen, and the list card so a step reads identically everywhere) ──

  /// Whether [step] is a renderable row in a step timeline (drops invisible
  /// bridges / chain links / thinking placeholders and label-less records).
  static bool isRenderableStep(Map<String, dynamic> step) {
    if (step['isBridge'] == true) return false;
    if (step['kind'] == 'sidechain-link') return false;
    if (step['kind'] == 'text' && step['isThinking'] == true) return false;
    return stepLabel(step).isNotEmpty;
  }

  /// User-visible label for a step event: the task chip message, a tool-call
  /// name + first input line, or a generic agent-event message.
  static String stepLabel(Map<String, dynamic> step) {
    if (step['taskEvent'] == true) {
      final ev = WireParsers.asMap(step['event']);
      final fromEvent = WireParsers.parseString(ev?['message']);
      if (fromEvent != null && fromEvent.isNotEmpty) return fromEvent;
      final content = WireParsers.parseString(step['content']) ??
          WireParsers.parseString(step['text']);
      if (content != null && content.isNotEmpty) return content;
    }
    final kind = WireParsers.parseString(step['kind']);
    if (kind == 'tool-call') {
      final name = WireParsers.parseString(step['name']) ?? 'tool';
      final input = WireParsers.asMap(step['input']);
      final desc = input == null
          ? null
          : (WireParsers.parseString(input['description']) ??
              WireParsers.parseString(input['command']) ??
              WireParsers.parseString(input['prompt']));
      if (desc != null && desc.isNotEmpty) {
        final first = desc.split('\n').first;
        return '$name: $first';
      }
      return name;
    }
    final ev = WireParsers.asMap(step['event']);
    final fromEvent = WireParsers.parseString(ev?['message']);
    if (fromEvent != null && fromEvent.isNotEmpty) return fromEvent;
    final content = WireParsers.parseString(step['content']);
    if (content != null && content.isNotEmpty) return content;
    return WireParsers.parseString(step['workflowName']) ??
        WireParsers.parseString(step['subagentType']) ??
        '';
  }

  /// Status string for a step (`taskStatus` for chips, `state` for tool
  /// calls), empty when unknown.
  static String stepState(Map<String, dynamic> step) =>
      WireParsers.parseString(step['taskStatus']) ??
      WireParsers.parseString(step['state']) ??
      '';

  /// Collapses consecutive identical steps and drops non-renderable ones so a
  /// run of identical progress ticks reads as a single row.
  static List<Map<String, dynamic>> collapseSteps(
    List<Map<String, dynamic>> steps,
  ) {
    final out = <Map<String, dynamic>>[];
    String? prevKey;
    for (final step in steps) {
      if (!isRenderableStep(step)) continue;
      final key = '${stepState(step)}|${stepLabel(step)}';
      if (key == prevKey) continue;
      prevKey = key;
      out.add(step);
    }
    return out;
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
