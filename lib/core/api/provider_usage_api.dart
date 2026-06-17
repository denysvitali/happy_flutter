import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/provider_usage.dart';
import 'base_api_exception.dart';

/// Base exception for provider usage API errors.
class ProviderUsageApiException extends BaseApiException {
  const ProviderUsageApiException(super.message, {super.statusCode});

  @override
  String toString() => 'ProviderUsageApiException: $message';
}

/// User-Agent sent with every provider usage request. Some provider gateways
/// reject requests without one.
const String _userAgent = 'happy-flutter';

Dio _createDio([String baseUrl = '']) {
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
/// Talks to the Kimi **Coding Plan** usage API (`{baseUrl}/usages`, default
/// host [kimiDefaultBaseUrl]) using a Bearer coding-plan API key, mirroring
/// https://github.com/Golden0Voyager/kimi-code-usage. This is NOT the consumer
/// `www.kimi.com` web billing service — a coding-plan key cannot authenticate
/// there, which is why earlier builds showed no usage.
class KimiUsageApi {
  KimiUsageApi({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  /// Fetches usage for the account identified by [apiKey].
  Future<ProviderUsage> getUsage({
    required String apiKey,
    required String accountId,
    String? accountName,
    String baseUrl = kimiDefaultBaseUrl,
  }) async {
    final payload = await _fetchUsage(apiKey, baseUrl);
    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.kimi,
      accountName: accountName,
      windows: _parseWindows(payload),
    );
  }

  /// GETs `{base}/usages`, falling back to `{base}/usage` on a non-200 — some
  /// gateways expose the singular path. Throws with the server's error detail
  /// if both fail.
  Future<Map<String, dynamic>> _fetchUsage(
    String apiKey,
    String baseUrl,
  ) async {
    final trimmed = baseUrl.trim();
    final base = trimmed.isEmpty ? kimiDefaultBaseUrl : trimmed;
    final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;

    final primary = await _dio.get<dynamic>(
      '$root/usages',
      options: _authOptions(apiKey),
    );
    if (primary.statusCode == 200) return _asMap(primary.data, 'Kimi');

    final fallback = await _dio.get<dynamic>(
      '$root/usage',
      options: _authOptions(apiKey),
    );
    if (fallback.statusCode == 200) return _asMap(fallback.data, 'Kimi');

    // Surface the primary failure — it carries the canonical error body.
    _throwHttpError('Kimi', 'usage', primary);
  }

  Options _authOptions(String apiKey) => Options(
    headers: <String, dynamic>{
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    },
  );

  /// Parses the two payload shapes used by the Kimi coding-plan API:
  ///   A) `{ "data": [ { "model_name": "all"|<model>, ... } ] }`
  ///   B) `{ "usage": {...}, "limits": [ { "detail", "window" }, ... ] }`
  List<ProviderUsageWindow> _parseWindows(Map<String, dynamic> payload) {
    final windows = <ProviderUsageWindow>[];

    final data = payload['data'];
    if (data is List) {
      for (final raw in data) {
        if (raw is! Map<String, dynamic>) continue;
        final modelName = raw['model_name']?.toString();
        final isSummary = modelName == 'all';
        final fallbackLabel = isSummary
            ? 'Weekly Usage'
            : (modelName == null || modelName.isEmpty ? 'Limit' : modelName);
        final window = _rowToWindow(raw, fallbackLabel);
        if (window != null) windows.add(window);
      }
      return windows;
    }

    final usage = payload['usage'];
    if (usage is Map<String, dynamic>) {
      final window = _rowToWindow(usage, 'Weekly Usage');
      if (window != null) windows.add(window);
    }

    final limits = payload['limits'];
    if (limits is List) {
      for (var i = 0; i < limits.length; i++) {
        final item = limits[i];
        if (item is! Map<String, dynamic>) continue;
        final detail = item['detail'] is Map<String, dynamic>
            ? item['detail'] as Map<String, dynamic>
            : item;
        final win = item['window'] is Map<String, dynamic>
            ? item['window'] as Map<String, dynamic>
            : const <String, dynamic>{};
        final window = _rowToWindow(detail, _limitLabel(item, detail, win, i));
        if (window != null) windows.add(window);
      }
    }

    return windows;
  }

  /// Converts a usage row into a [ProviderUsageWindow].
  ///
  /// Tolerates the field aliases the upstream tools accept (`limit_amount`,
  /// `used_amount`, `remaining`) and derives `used` from `remaining` when only
  /// the latter is reported. `utilization` is the percentage **used** so it
  /// lines up with the card's quota-warning colors and the
  /// [ProviderUsageWindow] contract.
  ProviderUsageWindow? _rowToWindow(
    Map<String, dynamic> data,
    String fallbackLabel,
  ) {
    final limit = _parseDouble(data['limit'] ?? data['limit_amount']);
    var used = _parseDouble(data['used'] ?? data['used_amount']);

    if (used == null) {
      final remaining = _parseDouble(data['remaining']);
      if (remaining != null && limit != null) used = limit - remaining;
    }
    if (used == null && limit == null) return null;

    final usedVal = (used ?? 0) < 0 ? 0.0 : (used ?? 0);
    final limitVal = (limit ?? 0) < 0 ? 0.0 : (limit ?? 0);
    final utilization = limitVal > 0 ? (usedVal / limitVal) * 100 : 0.0;

    final name = data['name'] ?? data['title'];
    final label = (name != null && name.toString().isNotEmpty)
        ? name.toString()
        : fallbackLabel;

    return ProviderUsageWindow(
      label: label,
      utilization: utilization.clamp(0, 100).toDouble(),
      resetsAtMs: _parseResetMs(data),
      limit: limit == null ? null : limitVal,
      used: used == null ? null : usedVal,
      remaining: limit == null ? null : (limitVal - usedVal).clamp(0, limitVal),
    );
  }

  String _limitLabel(
    Map<String, dynamic> item,
    Map<String, dynamic> detail,
    Map<String, dynamic> window,
    int idx,
  ) {
    for (final key in const ['name', 'title', 'scope']) {
      final value = item[key] ?? detail[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }

    final duration = _parseInt(
      window['duration'] ?? item['duration'] ?? detail['duration'],
    );
    final timeUnit =
        (window['timeUnit'] ?? item['timeUnit'] ?? detail['timeUnit'] ?? '')
            .toString()
            .toUpperCase();

    if (duration != null) {
      if (timeUnit.contains('MINUTE')) {
        return duration >= 60 && duration % 60 == 0
            ? '${duration ~/ 60}h Limit'
            : '${duration}m Limit';
      }
      if (timeUnit.contains('HOUR')) return '${duration}h Limit';
      if (timeUnit.contains('DAY')) return '${duration}d Limit';
      if (timeUnit.contains('MONTH')) return '${duration}mo Limit';
      return '${duration}s Limit';
    }

    return 'Limit #${idx + 1}';
  }

  /// Extracts a reset timestamp (ms since epoch) from the assorted reset field
  /// names, accepting ISO-8601 strings, epoch numbers, or relative seconds.
  static int? _parseResetMs(Map<String, dynamic> data) {
    const isoKeys = ['reset_at', 'resetAt', 'reset_time', 'resetTime'];
    for (final key in isoKeys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) {
        final dt = DateTime.tryParse(value);
        if (dt != null) return dt.millisecondsSinceEpoch;
      } else if (value is num) {
        // Epoch: treat large values as ms, smaller as seconds.
        return value > 1e12 ? value.toInt() : (value * 1000).toInt();
      }
    }

    for (final key in const ['reset_in', 'resetIn', 'ttl']) {
      final seconds = _parseInt(data[key]);
      if (seconds != null) {
        return DateTime.now()
            .add(Duration(seconds: seconds))
            .millisecondsSinceEpoch;
      }
    }

    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null;
  }
}

/// MiniMax usage API client.
///
/// Wraps the MiniMax Token Plan remains endpoint.
class MiniMaxUsageApi {
  MiniMaxUsageApi({Dio? dio})
    : _dio = dio ?? _createDio('https://www.minimax.io');

  final Dio _dio;

  static const String _usageEndpoint = '/v1/token_plan/remains';

  /// Fetches usage for the account identified by [apiKey].
  Future<ProviderUsage> getUsage({
    required String apiKey,
    required String accountId,
    String? accountName,
  }) async {
    final usageResponse = await _fetchUsage(apiKey);

    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.minimax,
      accountName: accountName,
      windows: _parseWindows(usageResponse),
    );
  }

  Options _authOptions(String apiKey) => Options(
    headers: <String, dynamic>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': _userAgent,
    },
  );

  Future<Map<String, dynamic>> _fetchUsage(String apiKey) async {
    final response = await _dio.get<dynamic>(
      _usageEndpoint,
      options: _authOptions(apiKey),
    );

    if (response.statusCode != 200) {
      _throwHttpError('MiniMax', 'usage', response);
    }

    return _asMap(response.data, 'MiniMax');
  }

  List<ProviderUsageWindow> _parseWindows(Map<String, dynamic> response) {
    final modelRemains = response['model_remains'];
    if (modelRemains is List<dynamic>) {
      final windows = modelRemains
          .whereType<Map<String, dynamic>>()
          .expand(_parseModelRemain)
          .whereType<ProviderUsageWindow>()
          .toList();
      if (windows.isNotEmpty) return windows;
    }

    final packageRemain = response['package_remain'];
    if (packageRemain is Map<String, dynamic>) {
      final window = _windowFromTotals(
        label: 'Token Plan',
        total: _parseDouble(packageRemain['total_count']),
        remaining: _parseDouble(
          packageRemain['remain_count'] ?? packageRemain['remaining_count'],
        ),
        resetsAtMs: _parseResetMs(packageRemain),
      );
      if (window != null) return <ProviderUsageWindow>[window];
    }

    final window = _windowFromTotals(
      label: 'Token Plan',
      total: _parseDouble(
        response['total_count'] ?? response['current_interval_total_count'],
      ),
      remaining: _parseDouble(
        response['remain_count'] ??
            response['remaining_count'] ??
            response['current_interval_usage_count'],
      ),
      resetsAtMs: _parseResetMs(response),
    );
    return window == null ? const <ProviderUsageWindow>[] : [window];
  }

  Iterable<ProviderUsageWindow?> _parseModelRemain(
    Map<String, dynamic> item,
  ) sync* {
    final modelName = item['model_name']?.toString();
    final label = modelName == null || modelName.isEmpty
        ? 'MiniMax'
        : modelName;

    yield _windowFromTotals(
      label: label,
      total: _parseDouble(item['current_interval_total_count']),
      remaining: _parseDouble(
        item['current_interval_remaining_count'] ??
            item['current_interval_usage_count'],
      ),
      resetsAtMs: _parseResetMs(item),
    );

    final weekly = _windowFromTotals(
      label: '$label Weekly',
      total: _parseDouble(item['current_weekly_total_count']),
      remaining: _parseDouble(
        item['current_weekly_remaining_count'] ??
            item['current_weekly_usage_count'],
      ),
      resetsAtMs: _parseResetMs(item),
    );
    if (weekly != null) yield weekly;
  }

  ProviderUsageWindow? _windowFromTotals({
    required String label,
    required double? total,
    required double? remaining,
    required int? resetsAtMs,
  }) {
    if (total == null || remaining == null) return null;

    final limit = total < 0 ? 0.0 : total;
    final safeRemaining = remaining.clamp(0, limit).toDouble();
    final used = (limit - safeRemaining).clamp(0, limit).toDouble();
    final utilization = limit > 0 ? (used / limit) * 100 : 0.0;

    return ProviderUsageWindow(
      label: label,
      utilization: utilization.clamp(0, 100),
      resetsAtMs: resetsAtMs,
      limit: limit,
      used: used,
      remaining: safeRemaining,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _parseResetMs(Map<String, dynamic> data) {
    for (final key in const ['end_time', 'reset_at', 'resetAt']) {
      final value = data[key];
      if (value is num) {
        return value > 1e12 ? value.toInt() : value.toInt() * 1000;
      }
      if (value is String) {
        final parsedNum = num.tryParse(value);
        if (parsedNum != null) {
          return parsedNum > 1e12
              ? parsedNum.toInt()
              : parsedNum.toInt() * 1000;
        }
        final parsedDate = DateTime.tryParse(value);
        if (parsedDate != null) return parsedDate.millisecondsSinceEpoch;
      }
    }
    return null;
  }
}

/// Builds a [ProviderUsageApiException] for a non-200 response, surfacing the
/// server's error detail so a failure (e.g. an expired/invalid token) is
/// diagnosable instead of an opaque status code.
Never _throwHttpError(String provider, String action, Response<dynamic> r) {
  final status = r.statusCode ?? 0;
  final detail = _extractErrorDetail(r.data);
  final reason = switch (status) {
    401 || 403 =>
      '$provider authentication failed — check the API key/token is valid and '
          'not expired',
    429 => '$provider rate limited',
    >= 500 => '$provider server error',
    _ => '$provider $action request failed',
  };
  final suffix = (detail != null && detail.isNotEmpty) ? ' ($detail)' : '';
  throw ProviderUsageApiException(
    '$reason: HTTP $status$suffix',
    statusCode: status,
  );
}

/// Extracts a short human-readable detail from a provider error body.
String? _extractErrorDetail(dynamic data) {
  Map<String, dynamic>? map;
  if (data is Map<String, dynamic>) {
    map = data;
  } else if (data is String && data.isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      map = decoded is Map<String, dynamic> ? decoded : null;
      if (map == null) return _clip(data);
    } catch (_) {
      return _clip(data);
    }
  }
  if (map == null) return null;

  // Common shapes: {"code":"unauthenticated"}, {"message":"..."},
  // {"error":"..."} or {"error":{"message":"..."}}, {"msg":"..."}, and the
  // MiniMax {"base_resp":{"status_msg":"..."}} envelope.
  final error = map['error'];
  if (error is Map<String, dynamic>) {
    final m = error['message'];
    if (m is String && m.isNotEmpty) return m;
  }
  for (final key in const ['message', 'error', 'msg', 'detail', 'code']) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
  }
  final baseResp = map['base_resp'];
  if (baseResp is Map<String, dynamic>) {
    final msg = baseResp['status_msg'];
    if (msg is String && msg.isNotEmpty) return msg;
  }
  return null;
}

String _clip(String value) =>
    value.length <= 200 ? value : '${value.substring(0, 197)}...';

/// Decodes a response body into a JSON map, tolerating providers that hand
/// back a JSON string body instead of an already-parsed map.
Map<String, dynamic> _asMap(dynamic data, String provider) {
  if (data is Map<String, dynamic>) return data;
  if (data is String && data.isNotEmpty) {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  throw ProviderUsageApiException(
    '$provider returned an unexpected response format',
  );
}
