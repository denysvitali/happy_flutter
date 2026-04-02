/// Model for Claude Code usage limits from the Anthropic OAuth API.
///
/// The API returns usage windows (5-hour, 7-day, per-model) with
/// utilization percentages and reset timestamps.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'claude_usage_limits.freezed.dart';
part 'claude_usage_limits.g.dart';

/// A single usage window (e.g. 5-hour rate limit, 7-day quota).
@freezed
abstract class ClaudeUsageWindow with _$ClaudeUsageWindow {
  const factory ClaudeUsageWindow({
    @JsonKey(fromJson: _utilizationFromJson)
    @Default(0.0)
    double utilization,
    @JsonKey(name: 'resets_at') String? resetsAt,
  }) = _ClaudeUsageWindow;

  const ClaudeUsageWindow._();

  factory ClaudeUsageWindow.fromJson(Map<String, dynamic> json) =>
      _$ClaudeUsageWindowFromJson(json);

  /// Convenience: utilization as a 0.0–1.0 fraction.
  double get fraction => (utilization / 100).clamp(0.0, 1.0);
}

double _utilizationFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  return 0.0;
}

double? _optionalDoubleFromJson(dynamic value) {
  if (value is num) return value.toDouble();
  return null;
}

/// Extra usage / credits information.
@freezed
abstract class ClaudeExtraUsage with _$ClaudeExtraUsage {
  const factory ClaudeExtraUsage({
    @JsonKey(name: 'is_enabled') @Default(false) bool isEnabled,
    @JsonKey(name: 'monthly_limit', fromJson: _optionalDoubleFromJson)
    double? monthlyLimit,
    @JsonKey(name: 'used_credits', fromJson: _optionalDoubleFromJson)
    double? usedCredits,
    @JsonKey(fromJson: _optionalDoubleFromJson) double? utilization,
  }) = _ClaudeExtraUsage;

  factory ClaudeExtraUsage.fromJson(Map<String, dynamic> json) =>
      _$ClaudeExtraUsageFromJson(json);
}

ClaudeUsageWindow? _windowOrNull(dynamic value) {
  if (value is Map<String, dynamic>) {
    return ClaudeUsageWindow.fromJson(value);
  }
  return null;
}

ClaudeExtraUsage? _extraUsageFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return ClaudeExtraUsage.fromJson(value);
  }
  return null;
}

/// Top-level Claude usage limits response.
@freezed
abstract class ClaudeUsageLimits with _$ClaudeUsageLimits {
  const factory ClaudeUsageLimits({
    @JsonKey(name: 'five_hour', fromJson: _windowOrNull)
    ClaudeUsageWindow? fiveHour,
    @JsonKey(name: 'seven_day', fromJson: _windowOrNull)
    ClaudeUsageWindow? sevenDay,
    @JsonKey(name: 'seven_day_sonnet', fromJson: _windowOrNull)
    ClaudeUsageWindow? sevenDaySonnet,
    @JsonKey(name: 'seven_day_opus', fromJson: _windowOrNull)
    ClaudeUsageWindow? sevenDayOpus,
    @JsonKey(name: 'seven_day_oauth_apps', fromJson: _windowOrNull)
    ClaudeUsageWindow? sevenDayOauthApps,
    @JsonKey(name: 'seven_day_cowork', fromJson: _windowOrNull)
    ClaudeUsageWindow? sevenDayCowork,
    @JsonKey(name: 'iguana_necktie', fromJson: _windowOrNull)
    ClaudeUsageWindow? iguanaNecktie,
    @JsonKey(name: 'extra_usage', fromJson: _extraUsageFromJson)
    ClaudeExtraUsage? extraUsage,
  }) = _ClaudeUsageLimits;

  const ClaudeUsageLimits._();

  factory ClaudeUsageLimits.fromJson(Map<String, dynamic> json) =>
      _$ClaudeUsageLimitsFromJson(json);

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
}
