library;

int _asCodexUsageInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
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

CodexUsageSummaryCredits? _creditsFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return CodexUsageSummaryCredits.fromJson(value);
  }
  if (value is Map) {
    return CodexUsageSummaryCredits.fromJson(Map<String, dynamic>.from(value));
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
      resetAfterSeconds: _asCodexUsageInt(json['reset_after_seconds']),
      resetAt: _asCodexUsageInt(json['reset_at']),
    );
  }

  final int usedPercent;
  final int limitWindowSeconds;
  final int resetAfterSeconds;
  final int resetAt;
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

class CodexUsageSummary {
  const CodexUsageSummary({
    required this.email,
    required this.planType,
    required this.rateLimit,
    required this.codeReviewRateLimit,
    required this.credits,
  });

  factory CodexUsageSummary.fromJson(Map<String, dynamic> json) {
    return CodexUsageSummary(
      email: _asCodexUsageStringNullable(json['email']),
      planType: _asCodexUsageStringNullable(json['plan_type']),
      rateLimit: _rateLimitFromJson(json['rate_limit']),
      codeReviewRateLimit: _rateLimitFromJson(json['code_review_rate_limit']),
      credits: _creditsFromJson(json['credits']),
    );
  }

  final String? email;
  final String? planType;
  final CodexUsageSummaryRateLimit? rateLimit;
  final CodexUsageSummaryRateLimit? codeReviewRateLimit;
  final CodexUsageSummaryCredits? credits;
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
