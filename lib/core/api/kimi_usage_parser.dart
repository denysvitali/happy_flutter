import '../models/provider_usage.dart';

/// Parses Kimi usage payloads independently of HTTP requests.
class KimiUsageParser {
  const KimiUsageParser();

  /// Parses the two payload shapes used by the Kimi coding-plan API:
  ///   A) `{ "data": [ { "model_name": "all"|<model>, ... } ] }`
  ///   B) `{ "usage": {...}, "limits": [ { "detail", "window" }, ... ] }`
  List<ProviderUsageWindow> parseWindows(Map<String, dynamic> payload) {
    final windows = <ProviderUsageWindow>[];

    final data = payload['data'];
    if (data is List) {
      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;
        final modelName = raw['model_name']?.toString();
        final isSummary = modelName == 'all';
        final fallbackLabel = isSummary
            ? 'Weekly Usage'
            : (modelName == null || modelName.isEmpty ? 'Limit' : modelName);
        final window = _rowToWindow(raw, fallbackLabel);
        if (window != null) windows.add(window);
      }
      return windows;
    }

    final usage = payload['usage'];
    if (usage is Map<String, dynamic>) {
      final window = _rowToWindow(usage, 'Weekly Usage');
      if (window != null) windows.add(window);
    }

    final limits = payload['limits'];
    if (limits is List) {
      for (var i = 0; i < limits.length; i++) {
        final item = limits[i];
        if (item is! Map<String, dynamic>) continue;
        final detail = item['detail'] is Map<String, dynamic>
            ? item['detail'] as Map<String, dynamic>
            : item;
        final win = item['window'] is Map<String, dynamic>
            ? item['window'] as Map<String, dynamic>
            : const <String, dynamic>{};
        final window = _rowToWindow(detail, _limitLabel(item, detail, win, i));
        if (window != null) windows.add(window);
      }
    }

    return windows;
  }

  /// Converts a usage row into a [ProviderUsageWindow].
  ///
  /// Tolerates the field aliases the upstream tools accept (`limit_amount`,
  /// `used_amount`, `remaining`) and derives `used` from `remaining` when only
  /// the latter is reported. `utilization` is the percentage **used** so it
  /// lines up with the card's quota-warning colors and the
  /// [ProviderUsageWindow] contract.
  ProviderUsageWindow? _rowToWindow(
    Map<String, dynamic> data,
    String fallbackLabel,
  ) {
    final limit = _parseDouble(data['limit'] ?? data['limit_amount']);
    var used = _parseDouble(data['used'] ?? data['used_amount']);

    if (used == null) {
      final remaining = _parseDouble(data['remaining']);
      if (remaining != null && limit != null) used = limit - remaining;
    }
    if (used == null && limit == null) return null;

    final usedVal = (used ?? 0) < 0 ? 0.0 : (used ?? 0);
    final limitVal = (limit ?? 0) < 0 ? 0.0 : (limit ?? 0);
    final utilization = limitVal > 0 ? (usedVal / limitVal) * 100 : 0.0;

    final name = data['name'] ?? data['title'];
    final label = (name != null && name.toString().isNotEmpty)
        ? name.toString()
        : fallbackLabel;

    return ProviderUsageWindow(
      label: label,
      utilization: utilization.clamp(0, 100).toDouble(),
      resetsAtMs: _parseResetMs(data),
      limit: limit == null ? null : limitVal,
      used: used == null ? null : usedVal,
      remaining: limit == null ? null : (limitVal - usedVal).clamp(0, limitVal),
    );
  }

  String _limitLabel(
    Map<String, dynamic> item,
    Map<String, dynamic> detail,
    Map<String, dynamic> window,
    int idx,
  ) {
    for (final key in const ['name', 'title', 'scope']) {
      final value = item[key] ?? detail[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }

    final duration = _parseInt(
      window['duration'] ?? item['duration'] ?? detail['duration'],
    );
    final timeUnit =
        (window['timeUnit'] ?? item['timeUnit'] ?? detail['timeUnit'] ?? '')
            .toString()
            .toUpperCase();

    if (duration != null) {
      if (timeUnit.contains('MINUTE')) {
        return duration >= 60 && duration % 60 == 0
            ? '${duration ~/ 60}h Limit'
            : '${duration}m Limit';
      }
      if (timeUnit.contains('HOUR')) return '${duration}h Limit';
      if (timeUnit.contains('DAY')) return '${duration}d Limit';
      if (timeUnit.contains('MONTH')) return '${duration}mo Limit';
      return '${duration}s Limit';
    }

    return 'Limit #${idx + 1}';
  }

  /// Extracts a reset timestamp (ms since epoch) from the assorted reset field
  /// names, accepting ISO-8601 strings, epoch numbers, or relative seconds.
  static int? _parseResetMs(Map<String, dynamic> data) {
    const isoKeys = ['reset_at', 'resetAt', 'reset_time', 'resetTime'];
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
