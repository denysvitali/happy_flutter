import 'dart:convert';

import '../models/provider_usage.dart';

/// Parses Grok usage payloads independently of HTTP requests.
class GrokUsageParser {
  const GrokUsageParser();

  /// Parses the `format=credits` billing payload into usage windows. The
  /// numbers live under `config` and are USD cents, sometimes wrapped as
  /// `{"val": N}`:
  ///   • `monthlyLimit` / `used` — the included monthly credit allowance.
  ///   • `onDemandCap` / `onDemandUsed` — optional overage budget (cap > 0).
  List<ProviderUsageWindow> parseWindows(Map<String, dynamic> body) {
    var data = unwrap(body, const ['data', 'billing', 'credits']);
    final config = data['config'];
    if (config is Map<String, dynamic>) {
      data = config;
    } else if (config is Map) {
      data = Map<String, dynamic>.from(config);
    }

    final windows = <ProviderUsageWindow>[];
    final resetsAtMs = _parseResetMs(data);

    final monthly = _creditsWindow(
      label: 'Monthly Credits',
      limitCents: _centsOf(data, const ['monthlyLimit', 'monthly_limit']),
      usedCents: _centsOf(data, const ['used']),
      resetsAtMs: resetsAtMs,
    );
    if (monthly != null) windows.add(monthly);

    final capCents = _centsOf(data, const ['onDemandCap', 'on_demand_cap']);
    if (capCents != null && capCents > 0) {
      final onDemand = _creditsWindow(
        label: 'On-demand',
        limitCents: capCents,
        usedCents: _centsOf(data, const ['onDemandUsed', 'on_demand_used']),
        resetsAtMs: resetsAtMs,
      );
      if (onDemand != null) windows.add(onDemand);
    }

    return windows;
  }

  /// Builds one dollar-denominated window from cent amounts. Returns null when
  /// the payload carries no limit, so we never render a misleading 0% bar.
  ProviderUsageWindow? _creditsWindow({
    required String label,
    required double? limitCents,
    required double? usedCents,
    required int? resetsAtMs,
  }) {
    if (limitCents == null || limitCents <= 0) return null;
    final limit = limitCents / 100.0;
    final used = ((usedCents ?? 0) < 0 ? 0.0 : (usedCents ?? 0)) / 100.0;
    return ProviderUsageWindow(
      label: label,
      utilization: ((used / limit) * 100).clamp(0.0, 100.0),
      resetsAtMs: resetsAtMs,
      limit: limit,
      used: used,
      remaining: (limit - used).clamp(0.0, limit),
    );
  }

  /// Billing period end — ISO-8601 in `billingPeriodEnd` or
  /// `currentPeriod.end`.
  static int? _parseResetMs(Map<String, dynamic> data) {
    final period = data['currentPeriod'] ?? data['current_period'];
    final candidates = <dynamic>[
      data['billingPeriodEnd'],
      data['billing_period_end'],
      if (period is Map) period['end'],
    ];
    for (final value in candidates) {
      if (value is String && value.isNotEmpty) {
        final dt = DateTime.tryParse(value);
        if (dt != null) return dt.millisecondsSinceEpoch;
      }
    }
    return null;
  }

  /// Reads a cent amount that may arrive as a number, numeric string, or the
  /// `{"val": N}` wrapper used by the credits format.
  static double? _centsOf(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (value is Map) {
        final inner = value['val'];
        if (inner is num) return inner.toDouble();
        if (inner is String) return double.tryParse(inner);
      }
    }
    return null;
  }

  /// Reads the first supported string or numeric account field.
  static String? stringOf(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
      if (value is num) return value.toString();
    }
    return null;
  }

  /// Descends through the response envelope (`data` → `user`/`billing`/...)
  /// until no wrapper key matches, mirroring grok-proxy's `unwrap`.
  static Map<String, dynamic> unwrap(
    Map<String, dynamic> value, [
    List<String> keys = const ['data', 'user'],
  ]) {
    var current = value;
    var advanced = true;
    while (advanced) {
      advanced = false;
      for (final key in keys) {
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

  /// Recovers the user id from the OAuth access token's JWT claims, the same
  /// fallback the Grok CLI uses before its optional /user enrichment call.
  static String? userIdFromJwt(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is! Map<String, dynamic>) return null;
      return stringOf(claims, const ['userId', 'user_id', 'sub', 'id']);
    } catch (_) {
      return null;
    }
  }
}
