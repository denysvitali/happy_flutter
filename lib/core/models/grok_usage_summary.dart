library;

/// Grok Build monthly billing usage for a machine.
///
/// Source: machine RPC `get-grok-usage`, which reads `~/.grok/auth.json` (or
/// `XAI_API_KEY`) and calls `cli-chat-proxy.grok.com/v1/billing`. Values are
/// in USD cents (matching the Grok Build billing API).
class GrokUsageSummary {
  const GrokUsageSummary({
    required this.monthlyLimitCents,
    required this.usedCents,
    required this.onDemandCapCents,
    this.email,
    this.billingPeriodStart,
    this.billingPeriodEnd,
  });

  factory GrokUsageSummary.fromJson(Map<String, dynamic> json) {
    final normalized = _normalizeGrokUsageJson(json);
    return GrokUsageSummary(
      email: _asString(normalized['email']),
      monthlyLimitCents: _asInt(normalized['monthlyLimitCents']),
      usedCents: _asInt(normalized['usedCents']),
      onDemandCapCents: _asInt(normalized['onDemandCapCents']),
      billingPeriodStart: _asString(normalized['billingPeriodStart']),
      billingPeriodEnd: _asString(normalized['billingPeriodEnd']),
    );
  }

  final String? email;
  final int monthlyLimitCents;
  final int usedCents;
  final int onDemandCapCents;
  final String? billingPeriodStart;
  final String? billingPeriodEnd;

  bool get hasUsageData =>
      email != null || monthlyLimitCents > 0 || usedCents > 0;

  double get usedDollars => usedCents / 100.0;

  double get monthlyLimitDollars => monthlyLimitCents / 100.0;

  double get onDemandCapDollars => onDemandCapCents / 100.0;

  /// Percent of the monthly included allowance that has been used (0–100).
  double get usedPercent {
    if (monthlyLimitCents <= 0) return 0;
    final pct = (usedCents / monthlyLimitCents) * 100;
    if (pct < 0) return 0;
    if (pct > 100) return 100;
    return pct;
  }

  int get remainingCents {
    final rem = monthlyLimitCents - usedCents;
    return rem < 0 ? 0 : rem;
  }

  double get remainingDollars => remainingCents / 100.0;

  /// Formats a cents amount as `$X.YY`.
  static String formatDollars(num dollars) {
    return '\$${dollars.toStringAsFixed(2)}';
  }
}

class GrokUsageSummaryResponse {
  const GrokUsageSummaryResponse({
    required this.success,
    this.data,
    this.error,
  });

  final bool success;
  final GrokUsageSummary? data;
  final String? error;
}

Map<String, dynamic> _normalizeGrokUsageJson(Map<String, dynamic> json) {
  final nested = json['data'];
  if (nested is Map<String, dynamic>) {
    return _normalizeGrokUsageJson(nested);
  }
  if (nested is Map) {
    return _normalizeGrokUsageJson(Map<String, dynamic>.from(nested));
  }
  // Daemon may nest under provider envelope: {provider, success, data: {...}}
  if (json['provider'] == 'grok' && json.containsKey('monthlyLimitCents')) {
    return json;
  }
  // Raw Grok billing shape fallback.
  final config = json['config'];
  if (config is Map) {
    final cfg = Map<String, dynamic>.from(config);
    return <String, dynamic>{
      'email': json['email'],
      'monthlyLimitCents': _centsVal(cfg['monthlyLimit']),
      'usedCents': _centsVal(cfg['used']),
      'onDemandCapCents': _centsVal(cfg['onDemandCap']),
      'billingPeriodStart': cfg['billingPeriodStart'],
      'billingPeriodEnd': cfg['billingPeriodEnd'],
    };
  }
  return json;
}

int _centsVal(dynamic value) {
  if (value is Map) {
    return _asInt(value['val']);
  }
  return _asInt(value);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? 0;
  return 0;
}

String? _asString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}
