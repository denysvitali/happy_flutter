import '../models/provider_usage.dart';

/// Parses MiniMax usage payloads independently of HTTP requests.
class MiniMaxUsageParser {
  const MiniMaxUsageParser();

  List<ProviderUsageWindow> parseWindows(Map<String, dynamic> response) {
    final modelRemains = response['model_remains'];
    if (modelRemains is List<dynamic>) {
      final windows = modelRemains
          .whereType<Map<String, dynamic>>()
          .expand(_parseModelRemain)
          .whereType<ProviderUsageWindow>()
          .toList();
      if (windows.isNotEmpty) return windows;
    }

    final packageRemain = response['package_remain'];
    if (packageRemain is Map<String, dynamic>) {
      final window = _windowFromTotalsMap(
        label: 'Token Plan',
        data: packageRemain,
        resetsAtMs: _parseResetMs(packageRemain),
      );
      if (window != null) return <ProviderUsageWindow>[window];
    }

    final window = _windowFromTotalsMap(
      label: 'Token Plan',
      data: response,
      resetsAtMs: _parseResetMs(response),
    );
    return window == null ? const <ProviderUsageWindow>[] : [window];
  }

  /// Parses one entry of `model_remains[]` into zero, one, or two
  /// [ProviderUsageWindow]s (interval + weekly).
  ///
  /// The canonical signal is `current_interval_remaining_percent` /
  /// `current_weekly_remaining_percent` (percent REMAINING, 0–100); the
  /// `*_total_count` / `*_usage_count` fields are auxiliary and frequently
  /// report 0 even when the percent signal is meaningful, so we only use them
  /// as a numeric fallback when the percent is missing.
  Iterable<ProviderUsageWindow?> _parseModelRemain(
    Map<String, dynamic> item,
  ) sync* {
    final modelName = item['model_name']?.toString();
    final label = modelName == null || modelName.isEmpty
        ? 'MiniMax'
        : modelName;

    final interval = _windowFromPercent(
      label: label,
      remainingPercent: _parseDouble(
        item['current_interval_remaining_percent'],
      ),
      total: _parseDouble(item['current_interval_total_count']),
      used: _parseDouble(item['current_interval_usage_count']),
      resetsAtMs: _parseEpochMs(item['end_time']),
    );
    if (interval != null) yield interval;

    final weekly = _windowFromPercent(
      label: '$label Weekly',
      remainingPercent: _parseDouble(item['current_weekly_remaining_percent']),
      total: _parseDouble(item['current_weekly_total_count']),
      used: _parseDouble(item['current_weekly_usage_count']),
      resetsAtMs: _parseEpochMs(item['weekly_end_time']),
    );
    if (weekly != null) yield weekly;
  }

  /// Builds a window preferring the percent-remaining signal. Falls back to
  /// deriving utilization from `total`/`used` (or `total`/`limit`) when the
  /// percent is unavailable so the card still renders something useful.
  ProviderUsageWindow? _windowFromTotalsMap({
    required String label,
    required Map<String, dynamic> data,
    required int? resetsAtMs,
  }) {
    return _windowFromPercent(
      label: label,
      remainingPercent: _parseDouble(
        data['remaining_percent'] ?? data['current_interval_remaining_percent'],
      ),
      total: _parseDouble(data['total_count']),
      used: _parseDouble(data['usage_count'] ?? data['used_count']),
      remaining: _parseDouble(data['remain_count'] ?? data['remaining_count']),
      resetsAtMs: resetsAtMs,
    );
  }

  ProviderUsageWindow? _windowFromPercent({
    required String label,
    required double? remainingPercent,
    required double? total,
    required double? used,
    required int? resetsAtMs,
    double? remaining,
  }) {
    double utilization;
    var remainingNum = remaining;
    double? limitNum;
    double? usedNum;

    if (remainingPercent != null) {
      final safe = remainingPercent.clamp(0.0, 100.0);
      utilization = (100.0 - safe).clamp(0.0, 100.0);
      if (total != null && total > 0) {
        limitNum = total;
        usedNum = (total * (utilization / 100)).clamp(0.0, total);
        remainingNum ??= (limitNum - usedNum).clamp(0.0, limitNum);
      }
    } else if (total != null && total > 0 && used != null) {
      limitNum = total;
      usedNum = used < 0 ? 0 : used;
      remainingNum ??= (total - usedNum).clamp(0.0, total);
      utilization = (usedNum / total) * 100;
    } else if (total != null && total > 0 && remainingNum != null) {
      limitNum = total;
      final safeRemaining = remainingNum.clamp(0.0, total);
      usedNum = (total - safeRemaining).clamp(0.0, total);
      remainingNum = safeRemaining;
      utilization = (usedNum / total) * 100;
    } else if (total != null && total > 0) {
      limitNum = total;
      remainingNum = total;
      utilization = 0.0;
    } else {
      return null;
    }

    return ProviderUsageWindow(
      label: label,
      utilization: utilization,
      resetsAtMs: resetsAtMs,
      limit: limitNum,
      used: usedNum,
      remaining: remainingNum,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Reads a `*_end_time` / `reset_at` value as epoch ms. Token-plan payloads
  /// always use epoch ms (large integers), so we don't accept ISO strings here
  /// — those belong in the generic reset parser below.
  static int? _parseEpochMs(dynamic value) {
    if (value is num) {
      return value > 1e12 ? value.toInt() : value.toInt() * 1000;
    }
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed > 1e12 ? parsed.toInt() : parsed.toInt() * 1000;
      }
    }
    return null;
  }

  static int? _parseResetMs(Map<String, dynamic> data) {
    for (final key in const ['end_time', 'reset_at', 'resetAt']) {
      final parsed = _parseEpochMs(data[key]);
      if (parsed != null) return parsed;
      final value = data[key];
      if (value is String) {
        final dt = DateTime.tryParse(value);
        if (dt != null) return dt.millisecondsSinceEpoch;
      }
    }
    return null;
  }
}
