import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/provider_usage.dart';
import '../services/logger_service.dart' show logger;
import 'base_api_exception.dart';

/// Base exception for provider usage API errors.
class ProviderUsageApiException extends BaseApiException {
  const ProviderUsageApiException(super.message, {super.statusCode});

  @override
  String toString() => 'ProviderUsageApiException: $message';
}

Dio _createDio(String baseUrl) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      contentType: 'application/json',
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ),
  );
}

/// Kimi usage API client.
///
/// Wraps the undocumented-but-stable Kimi billing endpoints used by
/// https://github.com/denysvitali/llm-usage.
class KimiUsageApi {
  KimiUsageApi({Dio? dio}) : _dio = dio ?? _createDio('https://www.kimi.com');

  final Dio _dio;

  static const String _usageEndpoint =
      '/apiv2/kimi.gateway.billing.v1.BillingService/GetUsages';
  static const String _subscriptionEndpoint =
      '/apiv2/kimi.gateway.order.v1.SubscriptionService/GetSubscription';

  /// Fetches usage for the account identified by [apiKey].
  Future<ProviderUsage> getUsage({
    required String apiKey,
    required String accountId,
    String? accountName,
  }) async {
    final usageResponse = await _fetchUsage(apiKey);
    final windows = _parseWindows(usageResponse);

    Map<String, dynamic>? subscriptionExtra;
    try {
      final subscription = await _fetchSubscription(apiKey);
      subscriptionExtra = _formatSubscriptionExtra(subscription);
    } catch (e, stack) {
      // Subscription is best-effort; do not fail the whole request.
      logger.warning('Kimi subscription fetch failed', e, stack);
    }

    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.kimi,
      accountName: accountName,
      windows: windows,
      extra: subscriptionExtra ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> _fetchUsage(String apiKey) async {
    final response = await _dio.post<dynamic>(
      _usageEndpoint,
      data: const <String, dynamic>{
        'scope': <String>['FEATURE_CODING'],
      },
      options: Options(
        headers: <String, dynamic>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw ProviderUsageApiException(
        'Kimi usage request failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return response.data! as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchSubscription(String apiKey) async {
    final response = await _dio.post<dynamic>(
      _subscriptionEndpoint,
      data: const <String, dynamic>{},
      options: Options(
        headers: <String, dynamic>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw ProviderUsageApiException(
        'Kimi subscription request failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return response.data! as Map<String, dynamic>;
  }

  List<ProviderUsageWindow> _parseWindows(Map<String, dynamic> response) {
    final usages = response['usages'];
    if (usages is! List<dynamic>) return const <ProviderUsageWindow>[];

    final windows = <ProviderUsageWindow>[];
    for (final raw in usages) {
      if (raw is! Map<String, dynamic>) continue;
      final scope = raw['scope'] as String? ?? '';
      final detail = raw['detail'];
      final limits = raw['limits'];

      if (detail is Map<String, dynamic>) {
        final window = _parseScopeWindow(scope, detail);
        if (window != null) windows.add(window);
      }

      if (limits is List<dynamic>) {
        for (final rawLimit in limits) {
          if (rawLimit is! Map<String, dynamic>) continue;
          final window = _parseLimitWindow(scope, rawLimit);
          if (window != null) windows.add(window);
        }
      }
    }

    return windows;
  }

  ProviderUsageWindow? _parseScopeWindow(
    String scope,
    Map<String, dynamic> detail,
  ) {
    final limit = _parseDouble(detail['limit']);
    final used = _parseDouble(detail['used']);
    if (limit == null || used == null || limit <= 0) return null;

    final utilization = (used / limit) * 100;
    final resetTime = _parseDateTime(detail['resetTime']);

    return ProviderUsageWindow(
      label: _formatScopeLabel(scope),
      utilization: utilization.clamp(0, 100),
      resetsAtMs: resetTime?.millisecondsSinceEpoch,
      limit: limit,
      used: used,
      remaining: (limit - used).clamp(0, double.infinity),
    );
  }

  ProviderUsageWindow? _parseLimitWindow(
    String scope,
    Map<String, dynamic> rawLimit,
  ) {
    final window = rawLimit['window'];
    final detail = rawLimit['detail'];
    if (window is! Map<String, dynamic> || detail is! Map<String, dynamic>) {
      return null;
    }

    final limit = _parseDouble(detail['limit']);
    final used = _parseDouble(detail['used']);
    if (limit == null || used == null || limit <= 0) return null;

    final utilization = (used / limit) * 100;
    final resetTime = _parseDateTime(detail['resetTime']);
    final duration = window['duration'] as int? ?? 0;
    final timeUnit = window['timeUnit'] as String? ?? '';

    return ProviderUsageWindow(
      label: _formatDurationLabel(duration, timeUnit),
      utilization: utilization.clamp(0, 100),
      resetsAtMs: resetTime?.millisecondsSinceEpoch,
      limit: limit,
      used: used,
      remaining: (limit - used).clamp(0, double.infinity),
    );
  }

  Map<String, dynamic> _formatSubscriptionExtra(
    Map<String, dynamic> subscription,
  ) {
    final result = <String, dynamic>{
      'subscribed': subscription['subscribed'] ?? false,
    };

    final sub = subscription['subscription'];
    if (sub is Map<String, dynamic>) {
      final goods = sub['goods'];
      if (goods is Map<String, dynamic>) {
        result['plan'] = <String, dynamic>{
          'title': goods['title'] ?? '',
          'level': _formatMembershipLevel(goods['membershipLevel'] as String?),
          'status': _formatSubscriptionStatus(sub['status'] as String?),
        };
      }
      final currentEndTime = sub['currentEndTime'] as String?;
      if (currentEndTime != null && currentEndTime.isNotEmpty) {
        final expiresAt = _parseDateTime(currentEndTime);
        if (expiresAt != null) {
          result['expires_at'] = expiresAt.toIso8601String();
        }
      }
    }

    final memberships = subscription['memberships'];
    if (memberships is List<dynamic>) {
      result['features'] = memberships
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => <String, dynamic>{
              'feature': _formatFeatureName(m['feature'] as String?),
              'left': m['leftCount'] ?? 0,
              'total': m['totalCount'] ?? 0,
            },
          )
          .toList();
    }

    return result;
  }

  static String _formatScopeLabel(String scope) {
    final parts = scope.split('_').where((p) => p.isNotEmpty).toList();
    return parts
        .map(
          (p) =>
              '${p.substring(0, 1).toUpperCase()}${p.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String _formatDurationLabel(int duration, String timeUnit) {
    var unit = timeUnit.toLowerCase().replaceFirst('time_unit_', '');
    if (unit.endsWith('s')) unit = unit.substring(0, unit.length - 1);
    if (unit.isEmpty) unit = 'window';
    return '$duration-${unit[0].toUpperCase()}${unit.substring(1)} Rate Limit';
  }

  static String _formatSubscriptionStatus(String? status) {
    return switch (status) {
      'SUBSCRIPTION_STATUS_ACTIVE' => 'Active',
      'SUBSCRIPTION_STATUS_CANCELLED' => 'Cancelled',
      'SUBSCRIPTION_STATUS_EXPIRED' => 'Expired',
      _ => status?.replaceFirst('SUBSCRIPTION_STATUS_', '') ?? 'Unknown',
    };
  }

  static String _formatMembershipLevel(String? level) {
    return switch (level) {
      'LEVEL_BASIC' => 'Basic',
      'LEVEL_STANDARD' => 'Standard',
      'LEVEL_PREMIUM' => 'Premium',
      _ => level?.replaceFirst('LEVEL_', '') ?? 'Unknown',
    };
  }

  static String _formatFeatureName(String? feature) {
    final name = feature?.replaceFirst('FEATURE_', '') ?? '';
    if (name.isEmpty) return name;
    return '${name[0].toUpperCase()}${name.substring(1).toLowerCase()}';
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// MiniMax usage API client.
///
/// Wraps the MiniMax open-platform endpoints used by
/// https://github.com/denysvitali/llm-usage.
class MiniMaxUsageApi {
  MiniMaxUsageApi({Dio? dio})
      : _dio = dio ?? _createDio('https://platform.minimax.io');

  final Dio _dio;

  static const String _usageEndpoint =
      '/v1/api/openplatform/coding_plan/remains';
  static const String _subscriptionEndpoint =
      '/v1/api/openplatform/charge/combo/cycle_audio_resource_package';

  /// Fetches usage for the account identified by [cookie] and [groupId].
  Future<ProviderUsage> getUsage({
    required String cookie,
    required String groupId,
    required String accountId,
    String? accountName,
  }) async {
    final usageResponse = await _fetchUsage(cookie, groupId);
    final windows = _parseWindows(usageResponse);

    Map<String, dynamic>? subscriptionExtra;
    try {
      final subscription = await _fetchSubscription(cookie, groupId);
      subscriptionExtra = <String, dynamic>{
        'status': (subscription['base_resp']
                as Map<String, dynamic>?)?['status_msg']
            as String?,
      };
    } catch (e, stack) {
      logger.warning('MiniMax subscription fetch failed', e, stack);
    }

    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.minimax,
      accountName: accountName,
      windows: windows,
      extra: subscriptionExtra ?? const <String, dynamic>{},
    );
  }

  Future<Map<String, dynamic>> _fetchUsage(
    String cookie,
    String groupId,
  ) async {
    final response = await _dio.get<dynamic>(
      _usageEndpoint,
      queryParameters: <String, dynamic>{'GroupId': groupId},
      options: Options(
        headers: <String, dynamic>{
          'Cookie': cookie,
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw ProviderUsageApiException(
        'MiniMax usage request failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return response.data! as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _fetchSubscription(
    String cookie,
    String groupId,
  ) async {
    final response = await _dio.get<dynamic>(
      _subscriptionEndpoint,
      queryParameters: <String, dynamic>{
        'GroupId': groupId,
        'biz_line': '2',
        'cycle_type': '3',
        'resource_package_type': '7',
      },
      options: Options(
        headers: <String, dynamic>{
          'Cookie': cookie,
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw ProviderUsageApiException(
        'MiniMax subscription request failed: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    return response.data! as Map<String, dynamic>;
  }

  List<ProviderUsageWindow> _parseWindows(Map<String, dynamic> response) {
    final modelRemains = response['model_remains'];
    if (modelRemains is! List<dynamic>) return const <ProviderUsageWindow>[];

    return modelRemains
        .whereType<Map<String, dynamic>>()
        .map(_parseModelRemain)
        .whereType<ProviderUsageWindow>()
        .toList();
  }

  ProviderUsageWindow? _parseModelRemain(Map<String, dynamic> item) {
    final total = (item['current_interval_total_count'] as num?)?.toDouble();
    final used = (item['current_interval_usage_count'] as num?)?.toDouble();
    final remains = (item['remains_time'] as num?)?.toDouble();
    final endTime = (item['end_time'] as num?)?.toInt();
    final modelName = item['model_name'] as String? ?? 'MiniMax';

    if (total == null || used == null) return null;

    final utilization = total > 0 ? ((total - used) / total) * 100 : 0.0;

    return ProviderUsageWindow(
      label: modelName,
      utilization: utilization.clamp(0, 100),
      resetsAtMs: endTime,
      limit: total,
      used: used,
      remaining: remains,
    );
  }
}

/// Kimi + MiniMax response helper kept private to this library.
Map<String, dynamic> decodeJsonBody(String body) =>
    jsonDecode(body) as Map<String, dynamic>;
