/// A scheduled recurring prompt that fires inside an active Claude session.
///
/// Loops mirror Claude Code's `/loop` slash command and the `CronCreate` /
/// `CronList` / `CronDelete` tool family. In Happy Flutter we elevate them to
/// first-class citizens — visible in the chat header, browsable in a
/// dedicated screen, and queryable per-session in the sessions list.
///
/// The on-the-wire shape is a cross-language contract with `happy-cli-go`
/// (see `internal/cli/loop_types.go`). The two repos MUST agree on field
/// names and JSON serialization.
library;

import '../wire/wire_parsers.dart';

/// Lifecycle state of a goal loop.
///
/// Only goal loops carry a status; a plain scheduled loop is always
/// [LoopStatus.running]. Everything except [LoopStatus.running] is terminal:
/// the daemon will not start another iteration, and the loop stays in the
/// list so the user can see how it ended.
enum LoopStatus {
  /// Iterating, or waiting for the next iteration.
  running,

  /// The goal was reached and the iteration verified it.
  complete,

  /// Progress needs a human — a credential, a decision, an external system.
  blocked,

  /// Consecutive iterations stopped changing the progress file, so further
  /// iterations would read exactly the same context.
  stalled,

  /// The iteration cap was reached without the goal being met.
  exhausted;

  /// Parses the daemon's wire value. Unknown/absent values mean running,
  /// which is the safe default: a loop is only shown as finished when the
  /// daemon says so explicitly.
  static LoopStatus fromWire(String? raw) {
    switch (raw) {
      case 'complete':
        return LoopStatus.complete;
      case 'blocked':
        return LoopStatus.blocked;
      case 'stalled':
        return LoopStatus.stalled;
      case 'exhausted':
        return LoopStatus.exhausted;
      default:
        return LoopStatus.running;
    }
  }

  /// Whether the daemon has stopped iterating this loop for good.
  bool get isTerminal => this != LoopStatus.running;
}

class Loop {
  /// Build a [Loop] from a wire payload, tolerating lenient numeric and
  /// boolean coercion (see [WireParsers]).
  ///
  /// Returns `null` when the payload is missing a required field
  /// (id/sessionId/expression/prompt/createdAt/expiresAt) OR when
  /// [WireParsers.parseInt] returns `null` for any of the required
  /// numeric fields. Callers must handle `null` rather than relying on
  /// a thrown exception — a single bad entry must not poison the
  /// surrounding batch (see `_sync_loops.dart` `listLoops`).
  static Loop? tryFromJson(Map<String, dynamic> json) {
    try {
      final id = WireParsers.parseString(json['id']);
      final sessionId = WireParsers.parseString(json['sessionId']);
      final expression = WireParsers.parseString(json['expression']);
      final prompt = WireParsers.parseString(json['prompt']);
      final createdAt = WireParsers.parseInt(json['createdAt']);
      final expiresAt = WireParsers.parseInt(json['expiresAt']);
      if (id == null ||
          sessionId == null ||
          expression == null ||
          prompt == null ||
          createdAt == null ||
          expiresAt == null) {
        return null;
      }
      return Loop(
        id: id,
        sessionId: sessionId,
        expression: expression,
        prompt: prompt,
        recurring: WireParsers.parseBool(json['recurring']) ?? true,
        createdAt: createdAt,
        expiresAt: expiresAt,
        lastFiredAt: WireParsers.parseInt(json['lastFiredAt']),
        fireCount: WireParsers.parseInt(json['fireCount']) ?? 0,
        paused: WireParsers.parseBool(json['paused']) ?? false,
        machineId: WireParsers.parseString(json['machineId']) ?? '',
        directory: WireParsers.parseString(json['directory']) ?? '',
        agent: WireParsers.parseString(json['agent']) ?? '',
        lastSessionId: WireParsers.parseString(json['lastSessionId']),
        activeSessionId: WireParsers.parseString(json['activeSessionId']),
        goal: WireParsers.parseString(json['goal']) ?? '',
        progressFile: WireParsers.parseString(json['progressFile']) ?? '',
        maxIterations: WireParsers.parseInt(json['maxIterations']) ?? 0,
        status: WireParsers.parseString(json['status']) ?? '',
        statusDetail: WireParsers.parseString(json['statusDetail']) ?? '',
        completedAt: WireParsers.parseInt(json['completedAt']),
      );
    } catch (_) {
      return null;
    }
  }
  /// 8-char ID, matches Claude Code convention. Format: `[0-9a-f]{8}`
  /// (lowercase hex).
  final String id;

  /// Session the loop belongs to.
  final String sessionId;

  /// 5-field cron expression in local timezone.
  ///
  /// Each field is `*`, `*/N`, `N`, `N-N`, `N,N`, or `N-N/N`.
  final String expression;

  /// Prompt text injected when the loop fires.
  final String prompt;

  /// `false` for one-shot reminders — the loop fires once and self-deletes.
  final bool recurring;

  /// Creation timestamp in milliseconds since epoch.
  final int createdAt;

  /// Expiry timestamp in milliseconds since epoch. For recurring loops this
  /// defaults to `createdAt + 7d` (Claude Code's spec).
  final int expiresAt;

  /// Epoch-ms of the most recent fire, or `null` if it has never fired.
  final int? lastFiredAt;

  /// Number of times this loop has fired since creation.
  final int fireCount;

  /// Manually paused by the user. Paused loops do not fire until resumed.
  final bool paused;

  // ── Machine-loop fields ────────────────────────────────────────────────
  // A machine loop is owned by the daemon rather than by a live session:
  // every run spawns a fresh session in [directory]. Empty for the
  // session-scoped loops that fire inside an already-running session.

  /// Machine whose daemon owns this loop. Empty for a session loop.
  final String machineId;

  /// Working directory each run is spawned in.
  final String directory;

  /// Agent flavor to spawn (`claude`, `codex`, …). Empty means the daemon's
  /// default.
  final String agent;

  /// Session spawned for the most recent run, if any.
  final String? lastSessionId;

  /// Session of the run currently in flight; null between runs. Its presence
  /// is what "this loop is working right now" means.
  final String? activeSessionId;

  // ── Goal-loop fields ───────────────────────────────────────────────────
  // A goal loop iterates towards [goal] with an empty context each run,
  // using [progressFile] as its only memory, and stops when a run reports
  // the goal genuinely reached.

  /// The objective. Non-empty exactly when this is a goal loop.
  final String goal;

  /// The loop's memory between runs, relative to [directory]. Empty means
  /// the daemon's default (`PROGRESS.md`).
  final String progressFile;

  /// Iteration cap. Zero means the daemon's default.
  final int maxIterations;

  /// Raw lifecycle state from the daemon; see [loopStatus].
  final String status;

  /// Why the loop is in its current [status] — the completion summary, or
  /// what it is blocked on.
  final String statusDetail;

  /// When the loop reached a terminal status, in ms since epoch.
  final int? completedAt;

  const Loop({
    required this.id,
    required this.sessionId,
    required this.expression,
    required this.prompt,
    required this.recurring,
    required this.createdAt,
    required this.expiresAt,
    this.lastFiredAt,
    this.fireCount = 0,
    this.paused = false,
    this.machineId = '',
    this.directory = '',
    this.agent = '',
    this.lastSessionId,
    this.activeSessionId,
    this.goal = '',
    this.progressFile = '',
    this.maxIterations = 0,
    this.status = '',
    this.statusDetail = '',
    this.completedAt,
  });


  factory Loop.fromJson(Map<String, dynamic> json) {
    return Loop(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      expression: json['expression'] as String,
      prompt: json['prompt'] as String,
      recurring: json['recurring'] as bool? ?? true,
      createdAt: (json['createdAt'] as num).toInt(),
      expiresAt: (json['expiresAt'] as num).toInt(),
      lastFiredAt: json['lastFiredAt'] == null
          ? null
          : (json['lastFiredAt'] as num).toInt(),
      fireCount: (json['fireCount'] as num?)?.toInt() ?? 0,
      paused: json['paused'] as bool? ?? false,
      machineId: json['machineId'] as String? ?? '',
      directory: json['directory'] as String? ?? '',
      agent: json['agent'] as String? ?? '',
      lastSessionId: json['lastSessionId'] as String?,
      activeSessionId: json['activeSessionId'] as String?,
      goal: json['goal'] as String? ?? '',
      progressFile: json['progressFile'] as String? ?? '',
      maxIterations: (json['maxIterations'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      statusDetail: json['statusDetail'] as String? ?? '',
      completedAt: (json['completedAt'] as num?)?.toInt(),
    );
  }

  /// Serializes back to the daemon's wire shape. Optional fields are omitted
  /// when empty so a round-trip through [LoopStorage] reproduces exactly what
  /// the daemon sent (Go's `omitempty`).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sessionId': sessionId,
      'expression': expression,
      'prompt': prompt,
      'recurring': recurring,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      if (lastFiredAt != null) 'lastFiredAt': lastFiredAt,
      'fireCount': fireCount,
      'paused': paused,
      if (machineId.isNotEmpty) 'machineId': machineId,
      if (directory.isNotEmpty) 'directory': directory,
      if (agent.isNotEmpty) 'agent': agent,
      if (lastSessionId != null) 'lastSessionId': lastSessionId,
      if (activeSessionId != null) 'activeSessionId': activeSessionId,
      if (goal.isNotEmpty) 'goal': goal,
      if (progressFile.isNotEmpty) 'progressFile': progressFile,
      if (maxIterations != 0) 'maxIterations': maxIterations,
      if (status.isNotEmpty) 'status': status,
      if (statusDetail.isNotEmpty) 'statusDetail': statusDetail,
      if (completedAt != null) 'completedAt': completedAt,
    };
  }

  Loop copyWith({
    String? id,
    String? sessionId,
    String? expression,
    String? prompt,
    bool? recurring,
    int? createdAt,
    int? expiresAt,
    int? lastFiredAt,
    bool clearLastFiredAt = false,
    int? fireCount,
    bool? paused,
    String? machineId,
    String? directory,
    String? agent,
    String? lastSessionId,
    String? activeSessionId,
    bool clearActiveSessionId = false,
    String? goal,
    String? progressFile,
    int? maxIterations,
    String? status,
    String? statusDetail,
    int? completedAt,
  }) {
    return Loop(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      expression: expression ?? this.expression,
      prompt: prompt ?? this.prompt,
      recurring: recurring ?? this.recurring,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastFiredAt:
          clearLastFiredAt ? null : (lastFiredAt ?? this.lastFiredAt),
      fireCount: fireCount ?? this.fireCount,
      paused: paused ?? this.paused,
      machineId: machineId ?? this.machineId,
      directory: directory ?? this.directory,
      agent: agent ?? this.agent,
      lastSessionId: lastSessionId ?? this.lastSessionId,
      activeSessionId: clearActiveSessionId
          ? null
          : (activeSessionId ?? this.activeSessionId),
      goal: goal ?? this.goal,
      progressFile: progressFile ?? this.progressFile,
      maxIterations: maxIterations ?? this.maxIterations,
      status: status ?? this.status,
      statusDetail: statusDetail ?? this.statusDetail,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Whether the daemon owns this loop (spawn-a-session-per-run) rather than
  /// a live session (inject-a-prompt-per-fire).
  bool get isMachineLoop => machineId.isNotEmpty || directory.isNotEmpty;

  /// Whether this loop iterates towards a goal until it reports done.
  bool get isGoalLoop => goal.isNotEmpty;

  /// Parsed lifecycle state.
  LoopStatus get loopStatus =>
      LoopStatus.fromWire(status.isEmpty ? null : status);

  /// Whether the daemon has stopped iterating this loop for good.
  bool get isTerminal => loopStatus.isTerminal;

  /// Whether an iteration is in flight right now.
  bool get isIterating =>
      activeSessionId != null && activeSessionId!.isNotEmpty;

  /// The progress file the loop actually uses.
  String get effectiveProgressFile =>
      progressFile.isEmpty ? 'PROGRESS.md' : progressFile;

  /// Iterations completed so far. [fireCount] counts started runs, which is
  /// the same thing between iterations and one ahead during one.
  int get completedIterations => isIterating ? fireCount - 1 : fireCount;

  /// Whether the loop's expiry has passed (one-shots that fired self-delete
  /// on the daemon side; this flag surfaces a soon-to-be-removed loop in
  /// the UI before the next `loops-updated` event arrives).
  bool isExpired({int? nowMs}) {
    final ms = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return ms >= expiresAt;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Loop &&
          id == other.id &&
          sessionId == other.sessionId &&
          expression == other.expression &&
          prompt == other.prompt &&
          recurring == other.recurring &&
          createdAt == other.createdAt &&
          expiresAt == other.expiresAt &&
          lastFiredAt == other.lastFiredAt &&
          fireCount == other.fireCount &&
          paused == other.paused &&
          machineId == other.machineId &&
          directory == other.directory &&
          agent == other.agent &&
          lastSessionId == other.lastSessionId &&
          activeSessionId == other.activeSessionId &&
          goal == other.goal &&
          progressFile == other.progressFile &&
          maxIterations == other.maxIterations &&
          status == other.status &&
          statusDetail == other.statusDetail &&
          completedAt == other.completedAt;

  // Object.hash tops out at 20 positional arguments; hashAll has no such
  // limit and keeps the field list here mechanical.
  @override
  int get hashCode => Object.hashAll(<Object?>[
        id,
        sessionId,
        expression,
        prompt,
        recurring,
        createdAt,
        expiresAt,
        lastFiredAt,
        fireCount,
        paused,
        machineId,
        directory,
        agent,
        lastSessionId,
        activeSessionId,
        goal,
        progressFile,
        maxIterations,
        status,
        statusDetail,
        completedAt,
      ]);

  @override
  String toString() => isGoalLoop
      ? 'Loop(id: $id, goal: $goal, status: $status, '
          'fireCount: $fireCount)'
      : 'Loop(id: $id, expression: $expression, paused: $paused, '
          'fireCount: $fireCount)';
}
