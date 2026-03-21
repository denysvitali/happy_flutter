/// Model for Claude Code usage limits from the Anthropic OAuth API.
///
/// The API returns usage windows (5-hour, 7-day, per-model) with
/// utilization percentages and reset timestamps.
library;

/// A single usage window (e.g. 5-hour rate limit, 7-day quota).
class ClaudeUsageWindow {
  const ClaudeUsageWindow({
    required this.utilization,
    this.resetsAt,
  });

  factory ClaudeUsageWindow.fromJson(Map<String, dynamic> json) =>
      ClaudeUsageWindow(
        utilization:
            (json['utilization'] as num?)?.toDouble() ?? 0.0,
        resetsAt: json['resets_at'] as String?,
      );

  /// Usage percentage (0–100).
  final double utilization;

  /// ISO-8601 timestamp when this window resets.
  final String? resetsAt;

  /// Convenience: utilization as a 0.0–1.0 fraction.
  double get fraction => (utilization / 100).clamp(0.0, 1.0);
}

/// Extra usage / credits information.
class ClaudeExtraUsage {
  const ClaudeExtraUsage({
    required this.isEnabled,
    this.monthlyLimit,
    this.usedCredits,
    this.utilization,
  });

  factory ClaudeExtraUsage.fromJson(Map<String, dynamic> json) =>
      ClaudeExtraUsage(
        isEnabled: json['is_enabled'] as bool? ?? false,
        monthlyLimit:
            (json['monthly_limit'] as num?)?.toDouble(),
        usedCredits:
            (json['used_credits'] as num?)?.toDouble(),
        utilization:
            (json['utilization'] as num?)?.toDouble(),
      );

  final bool isEnabled;
  final double? monthlyLimit;
  final double? usedCredits;
  final double? utilization;
}

/// Top-level Claude usage limits response.
class ClaudeUsageLimits {
  const ClaudeUsageLimits({
    this.fiveHour,
    this.sevenDay,
    this.sevenDaySonnet,
    this.sevenDayOpus,
    this.sevenDayOauthApps,
    this.sevenDayCowork,
    this.iguanaNecktie,
    this.extraUsage,
  });

  factory ClaudeUsageLimits.fromJson(Map<String, dynamic> json) =>
      ClaudeUsageLimits(
        fiveHour: _windowOrNull(json['five_hour']),
        sevenDay: _windowOrNull(json['seven_day']),
        sevenDaySonnet: _windowOrNull(json['seven_day_sonnet']),
        sevenDayOpus: _windowOrNull(json['seven_day_opus']),
        sevenDayOauthApps:
            _windowOrNull(json['seven_day_oauth_apps']),
        sevenDayCowork: _windowOrNull(json['seven_day_cowork']),
        iguanaNecktie: _windowOrNull(json['iguana_necktie']),
        extraUsage: json['extra_usage'] is Map<String, dynamic>
            ? ClaudeExtraUsage.fromJson(
                json['extra_usage'] as Map<String, dynamic>,
              )
            : null,
      );

  final ClaudeUsageWindow? fiveHour;
  final ClaudeUsageWindow? sevenDay;
  final ClaudeUsageWindow? sevenDaySonnet;
  final ClaudeUsageWindow? sevenDayOpus;
  final ClaudeUsageWindow? sevenDayOauthApps;
  final ClaudeUsageWindow? sevenDayCowork;
  final ClaudeUsageWindow? iguanaNecktie;
  final ClaudeExtraUsage? extraUsage;

  /// All non-null windows as labelled pairs for UI display.
  List<(String, ClaudeUsageWindow)> get activeWindows {
    final list = <(String, ClaudeUsageWindow)>[];
    if (fiveHour != null) list.add(('5-Hour', fiveHour!));
    if (sevenDay != null) list.add(('7-Day', sevenDay!));
    if (sevenDaySonnet != null) {
      list.add(('7-Day Sonnet', sevenDaySonnet!));
    }
    if (sevenDayOpus != null) {
      list.add(('7-Day Opus', sevenDayOpus!));
    }
    if (sevenDayOauthApps != null) {
      list.add(('7-Day OAuth', sevenDayOauthApps!));
    }
    if (sevenDayCowork != null) {
      list.add(('7-Day Cowork', sevenDayCowork!));
    }
    if (iguanaNecktie != null) {
      list.add(('Iguana Necktie', iguanaNecktie!));
    }
    return list;
  }

  static ClaudeUsageWindow? _windowOrNull(dynamic value) {
    if (value is Map<String, dynamic>) {
      return ClaudeUsageWindow.fromJson(value);
    }
    return null;
  }
}
