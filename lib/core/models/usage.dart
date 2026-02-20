/// Usage statistics models for /v1/usage endpoints
/// Based on React Native's apiUsage.ts
library;

int? _asUsageInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return null;
}

double? _asUsageDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  return null;
}

/// A single usage data point
class UsageDataPoint {

  UsageDataPoint({
    required this.timestamp,
    required this.tokens,
    required this.cost,
    required this.reportCount,
  });

  factory UsageDataPoint.fromJson(Map<String, dynamic> json) {
    final tokensRaw = json['tokens'];
    final costRaw = json['cost'];
    return UsageDataPoint(
      timestamp: _asUsageInt(json['timestamp']) ?? 0,
      tokens: tokensRaw is Map<String, dynamic>
          ? tokensRaw.map((k, v) => MapEntry(k, _asUsageInt(v) ?? 0))
          : {},
      cost: costRaw is Map<String, dynamic>
          ? costRaw.map((k, v) => MapEntry(k, _asUsageDouble(v) ?? 0.0))
          : {},
      reportCount: _asUsageInt(json['reportCount']) ?? 0,
    );
  }
  final int timestamp;
  final Map<String, int> tokens;
  final Map<String, double> cost;
  final int reportCount;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'tokens': tokens,
      'cost': cost,
      'reportCount': reportCount,
    };
  }
}

/// Response for usage query
class UsageResponse {

  UsageResponse({required this.usage});

  factory UsageResponse.fromJson(Map<String, dynamic> json) {
    final usage = (json['usage'] as List<dynamic>)
        .map((e) => UsageDataPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return UsageResponse(usage: usage);
  }
  final List<UsageDataPoint> usage;

  Map<String, dynamic> toJson() {
    return {
      'usage': usage.map((e) => e.toJson()).toList(),
    };
  }
}

/// Usage query parameters
class UsageQueryParams {

  UsageQueryParams({
    this.sessionId,
    this.startTime,
    this.endTime,
    this.groupBy,
  });
  final String? sessionId;
  final int? startTime; // Unix timestamp in seconds
  final int? endTime; // Unix timestamp in seconds
  final UsageGroupBy? groupBy;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (sessionId != null) json['sessionId'] = sessionId;
    if (startTime != null) json['startTime'] = startTime;
    if (endTime != null) json['endTime'] = endTime;
    if (groupBy != null) json['groupBy'] = groupBy!.name;
    return json;
  }
}

/// Grouping option for usage data
enum UsageGroupBy {
  hour,
  day,
}

/// Aggregated totals from usage data
class UsageTotals {

  UsageTotals({
    required this.totalTokens,
    required this.totalCost,
    required this.tokensByModel,
    required this.costByModel,
  });

  factory UsageTotals.fromDataPoints(List<UsageDataPoint> dataPoints) {
    var totalTokens = 0;
    var totalCost = 0.0;
    final tokensByModel = <String, int>{};
    final costByModel = <String, double>{};

    for (final dataPoint in dataPoints) {
      // Sum tokens
      for (final entry in dataPoint.tokens.entries) {
        totalTokens += entry.value;
        tokensByModel[entry.key] =
            (tokensByModel[entry.key] ?? 0) + entry.value;
      }

      // Sum costs
      for (final entry in dataPoint.cost.entries) {
        totalCost += entry.value;
        costByModel[entry.key] = (costByModel[entry.key] ?? 0.0) + entry.value;
      }
    }

    return UsageTotals(
      totalTokens: totalTokens,
      totalCost: totalCost,
      tokensByModel: tokensByModel,
      costByModel: costByModel,
    );
  }
  final int totalTokens;
  final double totalCost;
  final Map<String, int> tokensByModel;
  final Map<String, double> costByModel;
}

/// Time period for quick usage queries
enum UsagePeriod {
  today,
  sevenDays,
  thirtyDays,
}
