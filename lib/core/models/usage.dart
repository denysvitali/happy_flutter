/// Usage statistics models for /v1/usage endpoints
/// Based on React Native's apiUsage.ts

/// A single usage data point
class UsageDataPoint {
  final int timestamp;
  final Map<String, int> tokens;
  final Map<String, double> cost;
  final int reportCount;

  UsageDataPoint({
    required this.timestamp,
    required this.tokens,
    required this.cost,
    required this.reportCount,
  });

  factory UsageDataPoint.fromJson(Map<String, dynamic> json) {
    return UsageDataPoint(
      timestamp: json['timestamp'] as int,
      tokens: (json['tokens'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as int).toInt()),
      ),
      cost: (json['cost'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as double).toDouble()),
      ),
      reportCount: json['reportCount'] as int,
    );
  }

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
  final List<UsageDataPoint> usage;

  UsageResponse({required this.usage});

  factory UsageResponse.fromJson(Map<String, dynamic> json) {
    final usage = (json['usage'] as List<dynamic>)
        .map((e) => UsageDataPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return UsageResponse(usage: usage);
  }

  Map<String, dynamic> toJson() {
    return {
      'usage': usage.map((e) => e.toJson()).toList(),
    };
  }
}

/// Usage query parameters
class UsageQueryParams {
  final String? sessionId;
  final int? startTime; // Unix timestamp in seconds
  final int? endTime; // Unix timestamp in seconds
  final UsageGroupBy? groupBy;

  UsageQueryParams({
    this.sessionId,
    this.startTime,
    this.endTime,
    this.groupBy,
  });

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
  final int totalTokens;
  final double totalCost;
  final Map<String, int> tokensByModel;
  final Map<String, double> costByModel;

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
}

/// Time period for quick usage queries
enum UsagePeriod {
  today,
  sevenDays,
  thirtyDays,
}
