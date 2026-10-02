import '../models/provider_usage.dart';

/// Parses Zai usage payloads independently of HTTP requests.
class ZaiUsageParser {
  const ZaiUsageParser();

  /// Parses Z.AI's `{ code, data: { limits: [...] }, success }` envelope.
  List<ProviderUsageWindow> parseWindows(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) return const <ProviderUsageWindow>[];
    final limits = data['limits'];
    if (limits is! List) return const <ProviderUsageWindow>[];

    final windows = <ProviderUsageWindow>[];
    for (final raw in limits) {
      if (raw is! Map<String, dynamic>) continue;
      final window = _limitToWindow(raw);
      if (window != null) windows.add(window);
    }
    return windows;
  }

  /// Converts one `limits[]` entry into a [ProviderUsageWindow]. Returns null
  /// when the entry carries neither a `percentage` nor enough raw counts to be
  /// meaningful, so we never render a misleading 0% bar.
  ProviderUsageWindow? _limitToWindow(Map<String, dynamic> limit) {
    final type = limit['type']?.toString();
    final percentage = _parseDouble(limit['percentage']);
    final total = _parseDouble(limit['usage']);
    final used = _parseDouble(limit['currentValue']);
    final remaining = _parseDouble(limit['remaining']);

    double utilization;
    if (percentage != null) {
      utilization = percentage.clamp(0.0, 100.0);
    } else if (total != null && total > 0 && used != null) {
      utilization = (used / total) * 100;
    } else {
      return null;
    }

    // TOKENS_LIMIT carries nextResetTime; TIME_LIMIT (monthly) does not, so we
    // derive its reset as the next 1st-of-month 00:00 UTC.
    final resetsAtMs =
        _parseEpochMs(limit['nextResetTime']) ??
        (type == 'TIME_LIMIT' ? _nextMonthlyResetMs() : null);

    return ProviderUsageWindow(
      label: _labelFor(type, limit['unit']),
      utilization: utilization,
      resetsAtMs: resetsAtMs,
      limit: total,
      used: used,
      remaining: remaining,
    );
  }

  /// Human label for a limit, derived from the documented Z.AI window codes:
  ///   • `TOKENS_LIMIT` with `unit:3` → 5-hour session window
  ///   • `TOKENS_LIMIT` with `unit:6` → 7-day weekly window
  ///   • `TIME_LIMIT` → web-search/reader quota (monthly)
  String _labelFor(String? type, dynamic unit) {
    if (type == 'TIME_LIMIT') return 'Web Searches';
    final unitCode = _parseInt(unit);
    if (unitCode == 3) return 'Session';
    if (unitCode == 6) return 'Weekly';
    // Unknown window — fall back to an honest generic label so the
    // utilization number is still legible if Z.AI adds a new window type.
    return 'Tokens';
  }

  /// Next 1st-of-month 00:00 UTC — the documented reset for the monthly
  /// web-search quota, which carries no `nextResetTime` in the payload.
  static int? _nextMonthlyResetMs() {
    try {
      final now = DateTime.now().toUtc();
      return DateTime.utc(now.year, now.month + 1, 1).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
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

  static int? _parseEpochMs(dynamic value) {
    if (value == null) return null;
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
}
