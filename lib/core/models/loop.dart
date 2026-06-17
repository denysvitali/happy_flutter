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
class Loop {
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
    );
  }

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
    );
  }

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
          paused == other.paused;

  @override
  int get hashCode => Object.hash(
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
      );

  @override
  String toString() =>
      'Loop(id: $id, expression: $expression, paused: $paused, '
      'fireCount: $fireCount)';
}
