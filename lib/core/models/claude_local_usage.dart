/// Model for aggregated Claude Code token usage derived from the local
/// `~/.claude/stats-cache.json` file (scraped by the daemon).
///
/// Distinct from `ClaudeUsageLimits`, which is the OAuth rate-limit
/// response (5-hour/7-day windows as percentages). This model is the
/// lifetime local aggregate: total tokens, total messages, total
/// sessions, total tool calls, per-model token totals, and a daily
/// breakdown (capped to 30 most-recent days).
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'claude_local_usage.freezed.dart';
part 'claude_local_usage.g.dart';

/// Longest session of the lifetime window — useful as a "personal best"
/// hint in the UI.
@freezed
abstract class ClaudeLongestSession with _$ClaudeLongestSession {
  const factory ClaudeLongestSession({
    required String date,
    @JsonKey(name: 'messageCount') required int messageCount,
  }) = _ClaudeLongestSession;

  factory ClaudeLongestSession.fromJson(Map<String, dynamic> json) =>
      _$ClaudeLongestSessionFromJson(json);
}

/// One day's per-model token totals.
@freezed
abstract class ClaudeDailyModelTokens with _$ClaudeDailyModelTokens {
  const factory ClaudeDailyModelTokens({
    required String date,

    @JsonKey(name: 'tokensByModel')
    @Default(<String, int>{})
    Map<String, int> tokensByModel,
  }) = _ClaudeDailyModelTokens;

  factory ClaudeDailyModelTokens.fromJson(Map<String, dynamic> json) =>
      _$ClaudeDailyModelTokensFromJson(json);
}

/// Aggregated local Claude Code usage.
@freezed
abstract class ClaudeLocalUsage with _$ClaudeLocalUsage {
  const factory ClaudeLocalUsage({
    @Default(0) int version,

    @JsonKey(name: 'lastComputedDate') String? lastComputedDate,

    @JsonKey(name: 'totalTokens') @Default(0) int totalTokens,
    @JsonKey(name: 'totalMessages') @Default(0) int totalMessages,
    @JsonKey(name: 'totalSessions') @Default(0) int totalSessions,
    @JsonKey(name: 'totalToolCalls') @Default(0) int totalToolCalls,

    @JsonKey(name: 'tokensByModel')
    @Default(<String, int>{})
    Map<String, int> tokensByModel,

    @JsonKey(name: 'longestSession') ClaudeLongestSession? longestSession,

    @JsonKey(name: 'dailyModelTokens')
    @Default(<ClaudeDailyModelTokens>[])
    List<ClaudeDailyModelTokens> dailyModelTokens,
  }) = _ClaudeLocalUsage;

  const ClaudeLocalUsage._();

  factory ClaudeLocalUsage.fromJson(Map<String, dynamic> json) =>
      _$ClaudeLocalUsageFromJson(json);

  /// tokensByModel entries sorted by token count descending.
  /// Stable for ties: the map's iteration order is preserved by `entries`
  /// in Dart 3+ (LinkedHashMap), so the test fixture is deterministic.
  List<MapEntry<String, int>> get sortedTokensByModel {
    final entries = tokensByModel.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Pretty-printer for a model id, e.g.
  ///   "claude-opus-4-7"   -> "Opus 4 7"
  ///   "kimi-for-coding"   -> "Kimi For Coding"
  ///   "claude-haiku-4-5-20251001" -> "Haiku 4 5 20251001"
  static String formatModelName(String id) {
    var stripped = id;
    if (stripped.startsWith('claude-')) {
      stripped = stripped.substring('claude-'.length);
    }
    return stripped
        .split('-')
        .map((segment) => segment.isEmpty
            ? segment
            : '${segment[0].toUpperCase()}${segment.substring(1)}')
        .join(' ');
  }

  /// Compact token count formatter: 1234 -> "1.2K", 1234567 -> "1.2M",
  /// 1234567890 -> "1.2B". Anything < 1000 prints as the raw integer.
  static String formatTokenCount(int tokens) {
    if (tokens < 1000) return tokens.toString();
    const suffixes = ['', 'K', 'M', 'B', 'T'];
    var value = tokens.toDouble();
    var suffixIndex = 0;
    while (value >= 1000 && suffixIndex < suffixes.length - 1) {
      value /= 1000;
      suffixIndex++;
    }
    final rounded = (value * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.toInt()}${suffixes[suffixIndex]}';
    }
    return '${rounded.toStringAsFixed(1)}${suffixes[suffixIndex]}';
  }
}
