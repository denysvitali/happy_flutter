library;

import 'dart:convert';

int _asCodexUsageInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

int? _asCodexUsageIntNullable(dynamic value) {
  if (value is num) return value.toInt();
  return null;
}

bool _asCodexUsageBool(dynamic value) => value == true;

String? _asCodexUsageStringNullable(dynamic value) {
  if (value is String) return value;
  return null;
}

CodexUsageWindow? _windowFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return CodexUsageWindow.fromJson(value);
  }
  if (value is Map) {
    return CodexUsageWindow.fromJson(Map<String, dynamic>.from(value));
  }
  return null;
}

CodexUsageSummaryRateLimit? _rateLimitFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return CodexUsageSummaryRateLimit.fromJson(value);
  }
  if (value is Map) {
    return CodexUsageSummaryRateLimit.fromJson(
      Map<String, dynamic>.from(value),
    );
  }
  return null;
}

CodexUsageSummaryRateLimit? _extractRateLimit(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) {
    if (value.containsKey('rate_limit') && value['rate_limit'] is Map) {
      return CodexUsageSummaryRateLimit.fromJson(
        Map<String, dynamic>.from(value['rate_limit'] as Map),
      );
    }
    return CodexUsageSummaryRateLimit.fromJson(value);
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    if (map.containsKey('rate_limit') && map['rate_limit'] is Map) {
      return CodexUsageSummaryRateLimit.fromJson(
        Map<String, dynamic>.from(map['rate_limit'] as Map),
      );
    }
    return CodexUsageSummaryRateLimit.fromJson(map);
  }
  return null;
}

Map<String, dynamic>? _mapFrom(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

CodexUsageSummaryCredits? _creditsFromJson(dynamic value) {
  final map = _mapFrom(value);
  if (map == null) return null;
  return CodexUsageSummaryCredits.fromJson(map);
}

List<CodexUsageAdditionalRateLimit> _additionalRateLimitsFromJson(
  dynamic value,
) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) {
        return CodexUsageAdditionalRateLimit.fromJson(
          Map<String, dynamic>.from(item),
        );
      })
      .where((item) => item.rateLimit != null)
      .toList(growable: false);
}

Map<String, dynamic> _normalizeCodexUsageJson(Map<String, dynamic> json) {
  final nestedData = _mapFrom(json['data']);
  if (nestedData != null &&
      (json['provider'] == 'codex' || nestedData.containsKey('rate_limit'))) {
    return _normalizeCodexUsageJson(nestedData);
  }

  for (final key in const ['stdout', 'output']) {
    final parsed = _codexUsageJsonFromText(json[key]);
    if (parsed != null) return parsed;
  }

  return json;
}

Map<String, dynamic>? _codexUsageJsonFromText(dynamic value) {
  if (value is! String || value.isEmpty) return null;

  final trimmed = value.trim();
  if (trimmed.startsWith('{')) {
    final parsed = _tryDecodeMap(trimmed);
    if (parsed != null) {
      return _normalizeCodexUsageJson(parsed);
    }
  }

  final headingIndex = value.indexOf('Codex');
  if (headingIndex < 0) return null;
  final start = value.indexOf('{', headingIndex);
  if (start < 0) return null;
  final end = _findJsonObjectEnd(value, start);
  if (end == null) return null;

  final parsed = _tryDecodeMap(value.substring(start, end + 1));
  if (parsed == null) return null;
  return _normalizeCodexUsageJson(parsed);
}

Map<String, dynamic>? _tryDecodeMap(String value) {
  try {
    final parsed = jsonDecode(value);
    return _mapFrom(parsed);
  } catch (_) {
    return null;
  }
}

int? _findJsonObjectEnd(String value, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;

  for (var i = start; i < value.length; i++) {
    final char = value.codeUnitAt(i);
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == 0x5c) {
        escaped = true;
      } else if (char == 0x22) {
        inString = false;
      }
      continue;
    }

    if (char == 0x22) {
      inString = true;
    } else if (char == 0x7b) {
      depth++;
    } else if (char == 0x7d) {
      depth--;
      if (depth == 0) return i;
    }
  }

  return null;
}

class CodexUsageWindow {
  const CodexUsageWindow({
    required this.usedPercent,
    required this.limitWindowSeconds,
    required this.resetAfterSeconds,
    required this.resetAt,
  });

  factory CodexUsageWindow.fromJson(Map<String, dynamic> json) {
    return CodexUsageWindow(
      usedPercent: _asCodexUsageInt(json['used_percent']),
      limitWindowSeconds: _asCodexUsageInt(json['limit_window_seconds']),
      resetAfterSeconds: _asCodexUsageIntNullable(json['reset_after_seconds']),
      resetAt: _asCodexUsageIntNullable(json['reset_at']),
    );
  }

  final int usedPercent;
  final int limitWindowSeconds;
  final int? resetAfterSeconds;

  /// Unix timestamp in seconds when this usage window expires and resets.
  final int? resetAt;

  DateTime? get expiresAt {
    final timestamp = resetAt;
    if (timestamp == null || timestamp <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      timestamp * Duration.millisecondsPerSecond,
      isUtc: true,
    );
  }
}

class CodexUsageSummaryRateLimit {
  const CodexUsageSummaryRateLimit({
    required this.allowed,
    required this.limitReached,
    required this.primaryWindow,
    required this.secondaryWindow,
  });

  factory CodexUsageSummaryRateLimit.fromJson(Map<String, dynamic> json) {
    return CodexUsageSummaryRateLimit(
      allowed: _asCodexUsageBool(json['allowed']),
      limitReached: _asCodexUsageBool(json['limit_reached']),
      primaryWindow: _windowFromJson(json['primary_window']),
      secondaryWindow: _windowFromJson(json['secondary_window']),
    );
  }

  final bool allowed;
  final bool limitReached;
  final CodexUsageWindow? primaryWindow;
  final CodexUsageWindow? secondaryWindow;
}

class CodexUsageSummaryCredits {
  const CodexUsageSummaryCredits({
    required this.hasCredits,
    required this.unlimited,
    required this.balance,
  });

  factory CodexUsageSummaryCredits.fromJson(Map<String, dynamic> json) {
    return CodexUsageSummaryCredits(
      hasCredits: _asCodexUsageBool(json['has_credits']),
      unlimited: _asCodexUsageBool(json['unlimited']),
      balance: _asCodexUsageStringNullable(json['balance']),
    );
  }

  final bool hasCredits;
  final bool unlimited;
  final String? balance;
}

class CodexUsageAdditionalRateLimit {
  const CodexUsageAdditionalRateLimit({
    required this.limitName,
    required this.meteredFeature,
    required this.rateLimit,
  });

  factory CodexUsageAdditionalRateLimit.fromJson(Map<String, dynamic> json) {
    return CodexUsageAdditionalRateLimit(
      limitName: _asCodexUsageStringNullable(json['limit_name']),
      meteredFeature: _asCodexUsageStringNullable(json['metered_feature']),
      rateLimit: _rateLimitFromJson(json['rate_limit']),
    );
  }

  final String? limitName;
  final String? meteredFeature;
  final CodexUsageSummaryRateLimit? rateLimit;

  String get displayName {
    if (limitName != null && limitName!.isNotEmpty) return limitName!;
    if (meteredFeature != null && meteredFeature!.isNotEmpty) {
      return meteredFeature!;
    }
    return 'Additional Limit';
  }
}

class CodexUsageSummary {
  const CodexUsageSummary({
    required this.email,
    required this.planType,
    required this.rateLimit,
    required this.codeReviewRateLimit,
    required this.credits,
    required this.additionalRateLimits,
  });

  factory CodexUsageSummary.fromJson(Map<String, dynamic> json) {
    final normalizedJson = _normalizeCodexUsageJson(json);
    final additionalRateLimits = _additionalRateLimitsFromJson(
      normalizedJson['additional_rate_limits'],
    );
    return CodexUsageSummary(
      email: _asCodexUsageStringNullable(normalizedJson['email']),
      planType: _asCodexUsageStringNullable(normalizedJson['plan_type']),
      rateLimit: _rateLimitFromJson(normalizedJson['rate_limit']),
      codeReviewRateLimit: _rateLimitFromJson(
        normalizedJson['code_review_rate_limit'],
      ),
      credits: _creditsFromJson(normalizedJson['credits']),
      additionalRateLimits: additionalRateLimits.isNotEmpty
          ? additionalRateLimits
          : _legacyAdditionalRateLimits(normalizedJson),
    );
  }

  final String? email;
  final String? planType;
  final CodexUsageSummaryRateLimit? rateLimit;
  final CodexUsageSummaryRateLimit? codeReviewRateLimit;
  final CodexUsageSummaryCredits? credits;
  final List<CodexUsageAdditionalRateLimit> additionalRateLimits;

  bool get hasUsageData {
    return email != null ||
        planType != null ||
        rateLimit != null ||
        codeReviewRateLimit != null ||
        credits != null ||
        additionalRateLimits.isNotEmpty;
  }

  CodexUsageSummaryRateLimit? get sparkRateLimit {
    for (final item in additionalRateLimits) {
      final name = item.displayName.toLowerCase();
      if (name.contains('spark')) {
        return item.rateLimit;
      }
    }
    return null;
  }
}

List<CodexUsageAdditionalRateLimit> _legacyAdditionalRateLimits(
  Map<String, dynamic> json,
) {
  final sparkRateLimit =
      _extractRateLimit(json['spark_rate_limit']) ??
      _extractRateLimit(json['spark']) ??
      _extractRateLimit(json['codex_spark']);
  if (sparkRateLimit == null) return const [];
  return [
    CodexUsageAdditionalRateLimit(
      limitName: 'Spark',
      meteredFeature: null,
      rateLimit: sparkRateLimit,
    ),
  ];
}

class CodexUsageSummaryResponse {
  const CodexUsageSummaryResponse({
    required this.success,
    this.data,
    this.error,
  });

  final bool success;
  final CodexUsageSummary? data;
  final String? error;
}
