import 'dart:async';
import 'api_client.dart';
import '../models/usage.dart';

/// Usage Statistics API client
/// Handles API usage tracking, token usage, and cost statistics
/// Based on React Native's apiUsage.ts
class UsageApi {
  final ApiClient _client;

  UsageApi({ApiClient? client})
      : _client = client ?? ApiClient();

  /// Query usage data from the server
  /// Returns usage data points filtered by the provided parameters
  Future<UsageResponse> queryUsage(UsageQueryParams params) async {
    final response = await _client.post(
      '/v1/usage/query',
      data: params.toJson(),
    );

    if (response.statusCode == 404 && params.sessionId != null) {
      throw UsageApiException(
        'Session not found',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw UsageApiException(
        'Failed to query usage: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      return UsageResponse.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw UsageApiException('Failed to parse usage response: $e');
    }
  }

  /// Get usage for a specific time period
  /// Convenience method for common time periods
  Future<UsageResponse> getUsageForPeriod(
    UsagePeriod period, {
    String? sessionId,
  }) async {
    final now = DateTime.now();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final oneDaySeconds = 24 * 60 * 60;

    late int startTime;
    late UsageGroupBy groupBy;

    switch (period) {
      case UsagePeriod.today:
        // Start of today (local timezone)
        final today = DateTime(now.year, now.month, now.day);
        startTime = today.millisecondsSinceEpoch ~/ 1000;
        groupBy = UsageGroupBy.hour;
        break;
      case UsagePeriod.sevenDays:
        startTime = nowSeconds - (7 * oneDaySeconds);
        groupBy = UsageGroupBy.day;
        break;
      case UsagePeriod.thirtyDays:
        startTime = nowSeconds - (30 * oneDaySeconds);
        groupBy = UsageGroupBy.day;
        break;
    }

    return queryUsage(
      UsageQueryParams(
        sessionId: sessionId,
        startTime: startTime,
        endTime: nowSeconds,
        groupBy: groupBy,
      ),
    );
  }

  /// Get usage for today (hourly grouped)
  Future<UsageResponse> getTodayUsage({String? sessionId}) {
    return getUsageForPeriod(
      UsagePeriod.today,
      sessionId: sessionId,
    );
  }

  /// Get usage for the last 7 days (daily grouped)
  Future<UsageResponse> getSevenDayUsage({String? sessionId}) {
    return getUsageForPeriod(
      UsagePeriod.sevenDays,
      sessionId: sessionId,
    );
  }

  /// Get usage for the last 30 days (daily grouped)
  Future<UsageResponse> getThirtyDayUsage({String? sessionId}) {
    return getUsageForPeriod(
      UsagePeriod.thirtyDays,
      sessionId: sessionId,
    );
  }

  /// Get usage for a specific session
  Future<UsageResponse> getSessionUsage(
    String sessionId, {
    UsagePeriod period = UsagePeriod.thirtyDays,
  }) {
    return getUsageForPeriod(period, sessionId: sessionId);
  }

  /// Calculate total tokens and cost from usage data
  /// Returns aggregated totals across all data points
  static UsageTotals calculateTotals(List<UsageDataPoint> usage) {
    return UsageTotals.fromDataPoints(usage);
  }

  /// Get usage summary with totals
  /// Queries usage and returns both the raw data and calculated totals
  Future<UsageSummary> getUsageSummary(
    UsagePeriod period, {
    String? sessionId,
  }) async {
    final response = await getUsageForPeriod(period, sessionId: sessionId);
    final totals = UsageApi.calculateTotals(response.usage);

    return UsageSummary(
      usage: response.usage,
      totals: totals,
      period: period,
    );
  }
}

/// Exception thrown by Usage API operations
class UsageApiException implements Exception {
  final String message;
  final int? statusCode;

  const UsageApiException(this.message, {this.statusCode});

  @override
  String toString() => 'UsageApiException: $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsageApiException &&
        other.message == message &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode => Object.hash(message, statusCode);
}

/// Usage summary with raw data and calculated totals
class UsageSummary {
  final List<UsageDataPoint> usage;
  final UsageTotals totals;
  final UsagePeriod period;

  const UsageSummary({
    required this.usage,
    required this.totals,
    required this.period,
  });

  /// Get the most recent data point
  UsageDataPoint? get mostRecent {
    if (usage.isEmpty) return null;
    return usage.reduce((a, b) => a.timestamp > b.timestamp ? a : b);
  }

  /// Get the oldest data point
  UsageDataPoint? get oldest {
    if (usage.isEmpty) return null;
    return usage.reduce((a, b) => a.timestamp < b.timestamp ? a : b);
  }

  /// Get total report count
  int get totalReportCount {
    return usage.fold<int>(0, (sum, dp) => sum + dp.reportCount);
  }

  /// Get average cost per day
  double get averageCostPerDay {
    if (usage.isEmpty) return 0.0;
    return totals.totalCost / usage.length;
  }

  /// Get average tokens per day
  double get averageTokensPerDay {
    if (usage.isEmpty) return 0.0;
    return totals.totalTokens / usage.length;
  }
}
