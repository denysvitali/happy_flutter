/// Usage statistics models for /v1/usage endpoints
/// Based on React Native's apiUsage.ts
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'usage.freezed.dart';
part 'usage.g.dart';

int _asUsageInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

Map<String, int> _tokensFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((k, v) => MapEntry(k, _asUsageInt(v)));
  }
  return {};
}

Map<String, double> _costFromJson(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map(
      (k, v) => MapEntry(k, v is num ? v.toDouble() : 0.0),
    );
  }
  return {};
}

/// A single usage data point
@freezed
abstract class UsageDataPoint with _$UsageDataPoint {
  const factory UsageDataPoint({
    @JsonKey(fromJson: _asUsageInt) @Default(0) int timestamp,
    @JsonKey(fromJson: _tokensFromJson)
    @Default(<String, int>{})
    Map<String, int> tokens,
    @JsonKey(fromJson: _costFromJson)
    @Default(<String, double>{})
    Map<String, double> cost,
    @JsonKey(fromJson: _asUsageInt) @Default(0) int reportCount,
  }) = _UsageDataPoint;

  factory UsageDataPoint.fromJson(Map<String, dynamic> json) =>
      _$UsageDataPointFromJson(json);
}

/// Response for usage query
@freezed
abstract class UsageResponse with _$UsageResponse {
  const factory UsageResponse({
    required List<UsageDataPoint> usage,
  }) = _UsageResponse;

  factory UsageResponse.fromJson(Map<String, dynamic> json) =>
      _$UsageResponseFromJson(json);
}

/// Usage query parameters
@freezed
abstract class UsageQueryParams with _$UsageQueryParams {
  const factory UsageQueryParams({
    String? sessionId,
    int? startTime, // Unix timestamp in seconds
    int? endTime, // Unix timestamp in seconds
    UsageGroupBy? groupBy,
  }) = _UsageQueryParams;

  const UsageQueryParams._();

  factory UsageQueryParams.fromJson(Map<String, dynamic> json) =>
      _$UsageQueryParamsFromJson(json);

  Map<String, dynamic> toQueryJson() {
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
        costByModel[entry.key] =
            (costByModel[entry.key] ?? 0.0) + entry.value;
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
