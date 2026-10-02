import '../models/provider_usage.dart';

/// Parses Qwen usage payloads independently of HTTP requests.
class QwenUsageParser {
  const QwenUsageParser();

  /// Parses the (unverified) Qwen billing payload into usage windows.
  ///
  /// Tolerates, in order:
  ///   1. A list of limit rows under `limits`/`quotas`/`plans`/`data`
  ///      (Z.AI/Kimi style).
  ///   2. A single totals object, unwrapping `data`/`usage`/`result`/
  ///      `credits` envelopes (MiniMax/Grok style).
  List<ProviderUsageWindow> parseWindows(Map<String, dynamic> response) {
    final payload = _unwrap(response);

    for (final key in const ['limits', 'quotas', 'plans', 'data']) {
      final rows = payload[key];
      if (rows is List) {
        final windows = <ProviderUsageWindow>[];
        for (final raw in rows) {
          if (raw is! Map<String, dynamic>) continue;
          final window = _rowToWindow(raw, _rowLabel(raw, 'Credits'));
          if (window != null) windows.add(window);
        }
        if (windows.isNotEmpty) return windows;
      }
    }

    final window = _rowToWindow(payload, 'Credits');
    if (window != null) return <ProviderUsageWindow>[window];

    return const <ProviderUsageWindow>[];
  }

  /// Converts one totals/limits row into a [ProviderUsageWindow].
  ///
  /// Accepts the assorted credit/quota spellings: percent fields first, then
  /// total/used/remaining aliases. Returns null when the row carries nothing
  /// usable so we never render a misleading 0% bar.
  ProviderUsageWindow? _rowToWindow(
    Map<String, dynamic> data,
    String fallbackLabel,
  ) {
    final percentage = _parseDouble(
      data['percentage'] ??
          data['percent'] ??
          data['usage_percent'] ??
          data['used_percent'],
    );

    final limit = _firstDouble(data, const [
      'total_credits',
      'credits_total',
      'credit_total',
      'limit',
      'limit_amount',
      'total',
      'total_amount',
      'quota',
      'capacity',
    ]);
    final used = _firstDouble(data, const [
      'credits_used',
      'used_credits',
      'credit_used',
      'used',
      'used_amount',
      'usage',
      'consumed',
    ]);
    final remaining = _firstDouble(data, const [
      'credits_remaining',
      'remaining_credits',
      'credit_remaining',
      'remaining',
      'remain',
      'balance',
      'left',
    ]);

    double utilization;
    double? limitNum;
    double? usedNum;
    double? remainingNum;

    if (percentage != null) {
      utilization = percentage.clamp(0.0, 100.0);
      if (limit != null && limit > 0) {
        limitNum = limit;
        usedNum = (limit * (utilization / 100)).clamp(0.0, limit);
        remainingNum = (limit - usedNum).clamp(0.0, limit);
      }
    } else if (limit != null && limit > 0 && used != null) {
      limitNum = limit;
      usedNum = used < 0 ? 0 : used;
      remainingNum = (limit - usedNum).clamp(0.0, limit);
      utilization = (usedNum / limit) * 100;
    } else if (limit != null && limit > 0 && remaining != null) {
      limitNum = limit;
      final safeRemaining = remaining.clamp(0.0, limit);
      usedNum = (limit - safeRemaining).clamp(0.0, limit);
      remainingNum = safeRemaining;
      utilization = (usedNum / limit) * 100;
    } else {
      return null;
    }

    return ProviderUsageWindow(
      label: _rowLabel(data, fallbackLabel),
      utilization: utilization.clamp(0.0, 100.0),
      resetsAtMs: _parseResetMs(data),
      limit: limitNum,
      used: usedNum,
      remaining: remainingNum,
    );
  }

  /// Human label for a row, preferring an explicit name/title/plan field and
  /// falling back to [fallback] so single-totals payloads read "Credits".
  static String _rowLabel(Map<String, dynamic> data, String fallback) {
    for (final key in const ['name', 'title', 'plan', 'type', 'scope']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback;
  }

  /// Descends through single-map envelope wrappers (`data` → `usage`/…) until
  /// no wrapper key matches, so both `{data: {...}}` and bare payloads parse
  /// the same way. Lists are left intact — the row-list path handles them.
  static Map<String, dynamic> _unwrap(Map<String, dynamic> value) {
    var current = value;
    var advanced = true;
    while (advanced) {
      advanced = false;
      for (final key in const ['data', 'usage', 'result', 'credits']) {
        final child = current[key];
        if (child is Map<String, dynamic>) {
          current = child;
          advanced = true;
          break;
        }
        if (child is Map) {
          current = Map<String, dynamic>.from(child);
          advanced = true;
          break;
        }
      }
    }
    return current;
  }

  /// Extracts a reset timestamp (ms since epoch) from the assorted reset
  /// field names, accepting ISO-8601 strings, epoch numbers, or relative
  /// seconds.
  static int? _parseResetMs(Map<String, dynamic> data) {
    const isoKeys = [
      'reset_at',
      'resetAt',
      'reset_time',
      'resetTime',
      'nextResetTime',
      'period_end',
      'periodEnd',
      'expire_time',
      'expireTime',
      'end_time',
    ];
    for (final key in isoKeys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) {
        final dt = DateTime.tryParse(value);
        if (dt != null) return dt.millisecondsSinceEpoch;
      } else if (value is num) {
        // Epoch: treat large values as ms, smaller as seconds.
        return value > 1e12 ? value.toInt() : (value * 1000).toInt();
      }
    }

    for (final key in const ['reset_in', 'resetIn', 'ttl']) {
      final seconds = _parseInt(data[key]);
      if (seconds != null) {
        return DateTime.now()
            .add(Duration(seconds: seconds))
            .millisecondsSinceEpoch;
      }
    }

    return null;
  }

  /// First parseable numeric value among [keys]. Maps and lists never match,
  /// so envelope values like `"usage": {...}` are skipped safely.
  static double? _firstDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _parseDouble(data[key]);
      if (value != null) return value;
    }
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null;
  }
}
