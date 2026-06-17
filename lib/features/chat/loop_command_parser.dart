/// Parses `/loop ...` slash commands into structured requests.
///
/// Supported syntaxes:
///   * `/loop 5m check the deploy`        → recurring, */5 * * * *
///   * `/loop 1h roll up the standup`     → recurring, 0 */1 * * *
///   * `/loop 1d summarize today's commits` → recurring (daily), 0 9 * * *
///   * `/loop every 30 minutes ping`      → recurring, */30 * * * *
///   * `/loop every 2 hours status`       → recurring, 0 */2 * * *
///   * `/loop at 3pm remind me`           → one-shot
///   * `/loop tomorrow at 9am standup`    → one-shot
///   * `/loop cancel <id>`                → loopId (returned by [parseCancelCommand])
///   * `/loop list`                       → no request, no id (handled by caller)
///
/// Anything that doesn't match a known shape falls through and is sent to
/// Claude as a regular user message.
class LoopCommandParser {
  LoopCommandParser._();

  /// Single-letter interval token used after a number: m / h / d.
  static final RegExp _intervalToken = RegExp(r'^(\d+)\s*([mhd])\b\s*(.*)$');

  /// `every <N> (minute|hour|day|...)` form.
  static final RegExp _everyToken = RegExp(
    r'^every\s+(\d+)\s+(minute|minutes|hour|hours|day|days)\b\s*(.*)$',
    caseSensitive: false,
  );

  /// `at <time>` one-shot form. Supports `3pm`, `15:00`, `3:30pm`.
  static final RegExp _atToken = RegExp(
    r'^at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b\s*(.*)$',
    caseSensitive: false,
  );

  /// `tomorrow at <time>` one-shot form.
  static final RegExp _tomorrowAtToken = RegExp(
    r'^tomorrow\s+at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b\s*(.*)$',
    caseSensitive: false,
  );

  /// Returns a parsed request or `null` if [text] doesn't match a known
  /// `/loop` shape. The caller should fall through and send the original
  /// text to Claude when `null` is returned.
  static LoopCreateRequest? parse(String text) {
    final trimmed = text.trim();
    if (!trimmed.toLowerCase().startsWith('/loop ')) return null;
    final body = trimmed.substring('/loop '.length).trim();
    if (body.isEmpty) return null;

    // Cancel / list short-circuits — handled by the caller.
    final lower = body.toLowerCase();
    if (lower == 'list' || lower.startsWith('list ')) return null;
    final cancelMatch = parseCancelCommand(text);
    if (cancelMatch != null) return null;

    // 1. "every N (minute|hour|day) <prompt>"
    final every = _everyToken.firstMatch(body);
    if (every != null) {
      final n = int.parse(every.group(1)!);
      final unit = every.group(2)!.toLowerCase();
      final prompt = (every.group(3) ?? '').trim();
      if (prompt.isEmpty) return null;
      final cron = _everyUnitCron(n, unit);
      if (cron == null) return null;
      return LoopCreateRequest(
        expression: cron,
        prompt: prompt,
        recurring: true,
      );
    }

    // 2. "tomorrow at <time> <prompt>" → one-shot
    final tomorrowAt = _tomorrowAtToken.firstMatch(body);
    if (tomorrowAt != null) {
      final prompt = (tomorrowAt.group(4) ?? '').trim();
      if (prompt.isEmpty) return null;
      final hour = _parseHour(
        tomorrowAt.group(1)!,
        tomorrowAt.group(2),
        tomorrowAt.group(3),
      );
      if (hour == null) return null;
      final minute = int.tryParse(tomorrowAt.group(2) ?? '0') ?? 0;
      final cron = _tomorrowAtCron(hour, minute);
      return LoopCreateRequest(
        expression: cron,
        prompt: prompt,
        recurring: false,
      );
    }

    // 3. "at <time> <prompt>" → one-shot
    final at = _atToken.firstMatch(body);
    if (at != null) {
      final prompt = (at.group(4) ?? '').trim();
      if (prompt.isEmpty) return null;
      final hour = _parseHour(at.group(1)!, at.group(2), at.group(3));
      if (hour == null) return null;
      final minute = int.tryParse(at.group(2) ?? '0') ?? 0;
      final cron = _tomorrowAtCron(hour, minute);
      return LoopCreateRequest(
        expression: cron,
        prompt: prompt,
        recurring: false,
      );
    }

    // 4. "Nm | Nh | Nd <prompt>"
    final interval = _intervalToken.firstMatch(body);
    if (interval != null) {
      final n = int.parse(interval.group(1)!);
      final unit = interval.group(2)!.toLowerCase();
      final prompt = (interval.group(3) ?? '').trim();
      if (prompt.isEmpty) return null;
      if (unit == 'm') {
        if (n < 1 || n > 59) return null;
        return LoopCreateRequest(
          expression: '*/$n * * * *',
          prompt: prompt,
          recurring: true,
        );
      }
      if (unit == 'h') {
        if (n < 1 || n > 23) return null;
        return LoopCreateRequest(
          expression: '0 */$n * * *',
          prompt: prompt,
          recurring: true,
        );
      }
      if (unit == 'd') {
        // Daily at 9am local time — Claude Code's default for `Nd`.
        return LoopCreateRequest(
          expression: '0 9 * * *',
          prompt: prompt,
          recurring: true,
        );
      }
    }

    // 5. Bare "<prompt>" → null (caller treats as plain text).
    return null;
  }

  /// Returns `true` when [text] starts with `/loop` (with or without
  /// trailing space). Useful for autocomplete highlighting.
  static bool matches(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower == '/loop') return true;
    return lower.startsWith('/loop ');
  }

  /// Parses `/loop cancel <id>` and returns the loopId, or `null` when the
  /// text doesn't match. The id format is `[0-9a-f]{8}` but we accept any
  /// non-whitespace token here so the daemon can do its own validation.
  static String? parseCancelCommand(String text) {
    final trimmed = text.trim();
    if (!trimmed.toLowerCase().startsWith('/loop ')) return null;
    final body = trimmed.substring('/loop '.length).trim();
    final parts = body.split(RegExp(r'\s+'));
    if (parts.length != 2) return null;
    if (parts[0].toLowerCase() != 'cancel') return null;
    final id = parts[1];
    if (id.isEmpty) return null;
    return id;
  }

  // ── Cron helpers ──────────────────────────────────────────────────────

  static String? _everyUnitCron(int n, String unit) {
    if (n < 1) return null;
    switch (unit) {
      case 'minute':
      case 'minutes':
        if (n > 59) return null;
        return '*/$n * * * *';
      case 'hour':
      case 'hours':
        if (n > 23) return null;
        return '0 */$n * * *';
      case 'day':
      case 'days':
        // `every N day` becomes a single-shot at the next 9am — we
        // intentionally do not synthesize a multi-day recurring cron.
        return '0 9 * * *';
    }
    return null;
  }

  /// Returns a cron expression for [hour]:[minute] *tomorrow* in the
  /// local timezone. One-shots fire once and self-delete.
  ///
  /// Computing the actual `dd` day-of-month is non-trivial without a
  /// date library, so we defer to the daemon for the calendar math and
  /// emit a synthetic cron the daemon understands.
  static String _tomorrowAtCron(int hour, int minute) {
    // `0 <minute> <hour> * *` fires every day at that time. Daemon
    // semantics for `recurring: false` make it a one-shot, so the
    // day-of-month doesn't matter.
    return '$minute $hour * * *';
  }

  /// Parses "3", "3pm", "15", "15:30", "3:30pm" into 24h hour. Returns
  /// null on invalid input.
  static int? _parseHour(String hourStr, String? minuteStr, String? ampm) {
    var h = int.tryParse(hourStr);
    if (h == null) return null;
    final m = minuteStr == null ? null : int.tryParse(minuteStr);
    if (minuteStr != null && m == null) return null;
    if (m != null && (m < 0 || m > 59)) return null;
    if (ampm != null) {
      final a = ampm.toLowerCase();
      if (a == 'pm' && h >= 1 && h <= 11) h += 12;
      if (a == 'am' && h == 12) h = 0;
      if (h < 0 || h > 23) return null;
    } else {
      if (h < 0 || h > 23) return null;
    }
    return h;
  }
}

/// Structured `/loop` request ready for the create sheet / RPC.
class LoopCreateRequest {
  const LoopCreateRequest({
    required this.expression,
    required this.prompt,
    required this.recurring,
  });

  /// 5-field cron expression in local timezone.
  final String expression;

  /// Prompt text the loop will inject on each fire.
  final String prompt;

  /// `false` for one-shot reminders.
  final bool recurring;

  @override
  String toString() =>
      'LoopCreateRequest(expression: $expression, recurring: $recurring, '
      'prompt: ${prompt.length > 30 ? '${prompt.substring(0, 30)}…' : prompt})';
}
