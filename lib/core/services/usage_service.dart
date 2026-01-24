import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/usage.dart';

/// Service for usage statistics and costs (/v1/usage/*)
/// Based on React Native's apiUsage.ts
class UsageService {
  static final UsageService _instance = UsageService._();
  factory UsageService() => _instance;
  UsageService._();

  final _apiClient = ApiClient();

  /// Query usage data from the server
  Future<UsageResponse> query(UsageQueryParams params) async {
    try {
      final response = await _apiClient.post(
        '/v1/usage/query',
        data: params.toJson(),
      );

      if (response.statusCode == 404 && params.sessionId != null) {
        throw UsageException('Session not found');
      }

      if (!_apiClient.isSuccess(response)) {
        throw UsageException('Failed to query usage: ${response.statusCode}');
      }

      return UsageResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw UsageException('Failed to query usage: ${e.message}');
    }
  }

  /// Get usage for a specific time period
  Future<UsageResponse> getForPeriod(
    UsagePeriod period, {
    String? sessionId,
  }) async {
    final now = DateTime.now();
    final startTime = _getStartTimeForPeriod(now, period);
    final groupBy = _getGroupByForPeriod(period);

    return query(UsageQueryParams(
      sessionId: sessionId,
      startTime: startTime,
      endTime: now.millisecondsSinceEpoch ~/ 1000,
      groupBy: groupBy,
    ));
  }

  /// Calculate total tokens and cost from usage data
  UsageTotals calculateTotals(List<UsageDataPoint> dataPoints) {
    return UsageTotals.fromDataPoints(dataPoints);
  }

  int _getStartTimeForPeriod(DateTime now, UsagePeriod period) {
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    const oneDaySeconds = 24 * 60 * 60;

    switch (period) {
      case UsagePeriod.today:
        final today = DateTime(now.year, now.month, now.day);
        return today.millisecondsSinceEpoch ~/ 1000;
      case UsagePeriod.sevenDays:
        return nowSeconds - (7 * oneDaySeconds);
      case UsagePeriod.thirtyDays:
        return nowSeconds - (30 * oneDaySeconds);
    }
  }

  UsageGroupBy _getGroupByForPeriod(UsagePeriod period) {
    switch (period) {
      case UsagePeriod.today:
        return UsageGroupBy.hour;
      case UsagePeriod.sevenDays:
      case UsagePeriod.thirtyDays:
        return UsageGroupBy.day;
    }
  }
}

/// Exception for usage operations
class UsageException implements Exception {
  final String message;
  UsageException(this.message);

  @override
  String toString() => 'UsageException: $message';
}
