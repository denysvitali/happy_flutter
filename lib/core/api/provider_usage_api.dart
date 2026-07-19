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
  ///
  /// When [includeDebugPayload] is true (developer / debug mode), the raw
  /// response body is surfaced via [ProviderUsage.extra] under
  /// `'raw_payload'` / `'raw_payload_compact'` so the in-app debug viewer can
  /// inspect it without re-issuing a request.
  Future<ProviderUsage> getUsage({
    required String apiKey,
    required String accountId,
    String? accountName,
    String baseUrl = kimiDefaultBaseUrl,
    bool includeDebugPayload = false,
  }) async {
    final fetch = await _fetchUsageRaw(apiKey, baseUrl);
    final payload = fetch.body;
    final windows = _parseWindows(payload);
    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.kimi,
      accountName: accountName,
      windows: windows,
      extra: includeDebugPayload
          ? _buildExtra(fetch, windows)
          : const <String, dynamic>{},
    );
  }

  /// GETs `{base}/usages`, falling back to `{base}/usage` on a non-200 — some
  /// gateways expose the singular path. Throws with the server's error detail
  /// if both fail.
  ///
  /// Returns the decoded body together with the raw pretty/compact JSON strings
  /// so the debug surface can display the original response without
  /// re-encoding.
  Future<_KimiFetch> _fetchUsageRaw(
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
    if (primary.statusCode == 200) {
      return _KimiFetch(
        response: primary,
        statusCode: primary.statusCode ?? 0,
        body: _asMap(primary.data, 'Kimi'),
        prettyBody: _safeStringify(primary.data),
        compactBody: _compactStringify(primary.data),
        endpoint: '/usages',
      );
    }

    final fallback = await _dio.get<dynamic>(
      '$root/usage',
      options: _authOptions(apiKey),
    );
    if (fallback.statusCode == 200) {
      return _KimiFetch(
        response: fallback,
        statusCode: fallback.statusCode ?? 0,
        body: _asMap(fallback.data, 'Kimi'),
        prettyBody: _safeStringify(fallback.data),
        compactBody: _compactStringify(fallback.data),
        endpoint: '/usage',
      );
    }

    // Surface the primary failure — it carries the canonical error body.
    _throwHttpError('Kimi', 'usage', primary);
  }

  /// Builds the debug `extra` map carried on [ProviderUsage] — only populated
  /// when a 2xx response arrived so we never leak credential error bodies.
  Map<String, dynamic> _buildExtra(
    _KimiFetch fetch,
    List<ProviderUsageWindow> windows,
  ) {
    if (fetch.statusCode != 200) return const <String, dynamic>{};
    return <String, dynamic>{
      'endpoint': fetch.endpoint,
      'status': fetch.statusCode,
      'request_url': fetch.response.requestOptions.uri.toString(),
      'window_count': windows.length,
      'raw_payload': fetch.prettyBody,
      'raw_payload_compact': fetch.compactBody,
    };
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
  ///
  /// When [includeDebugPayload] is true (developer / debug mode), the raw
  /// response body is surfaced via [ProviderUsage.extra] under
  /// `'raw_payload'` / `'raw_payload_compact'` so the in-app debug viewer can
  /// inspect it without re-issuing a request. The raw body is also emitted at
  /// `LogLevel.debug` so it shows up in DevLogsScreen when developer mode is
  /// enabled.
  ///
  /// In production (default) [includeDebugPayload] is false, the parsed
  /// windows are returned without any debug metadata, and `logger.debug` is
  /// gated out by the logger's own min-level filter.
  Future<ProviderUsage> getUsage({
    required String apiKey,
    required String accountId,
    String? accountName,
    bool includeDebugPayload = false,
  }) async {
    final fetch = await _fetchUsageRaw(apiKey);

    if (fetch.statusCode != 200) {
      _throwHttpError('MiniMax', 'usage', fetch.response);
    }

    final usageResponse = fetch.body;
    final windows = _parseWindows(usageResponse);
    final extra = includeDebugPayload
        ? _buildExtra(fetch, windows)
        : const <String, dynamic>{};

    if (includeDebugPayload) {
      // Debug breadcrumb: raw status + compact body. Compact form (no
      // whitespace) keeps a single log line readable; full pretty JSON is
      // available in the in-app debug viewer.
      logger.debug(
        'MiniMax token_plan/remains HTTP ${fetch.statusCode} '
        'windows=${windows.length} '
        'payload=${fetch.compactBody}',
      );
    }

    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.minimax,
      accountName: accountName,
      windows: windows,
      extra: extra,
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

  /// Performs the GET and captures both the raw Dio response and the decoded
  /// JSON body, so the parser and the debug surface can share the work.
  Future<_MiniMaxFetch> _fetchUsageRaw(String apiKey) async {
    final response = await _dio.get<dynamic>(
      _usageEndpoint,
      options: _authOptions(apiKey),
    );

    final raw = response.data;
    final pretty = _safeStringify(raw);
    final compact = _compactStringify(raw);

    Map<String, dynamic> body;
    try {
      body = _asMap(raw, 'MiniMax');
    } catch (_) {
      body = const <String, dynamic>{};
    }

    return _MiniMaxFetch(
      response: response,
      statusCode: response.statusCode ?? 0,
      body: body,
      prettyBody: pretty,
      compactBody: compact,
    );
  }

  /// Builds the debug `extra` map carried on [ProviderUsage] — only populated
  /// when a 2xx response arrived so we never leak credential error bodies.
  Map<String, dynamic> _buildExtra(
    _MiniMaxFetch fetch,
    List<ProviderUsageWindow> windows,
  ) {
    if (fetch.statusCode != 200) return const <String, dynamic>{};

    return <String, dynamic>{
      'endpoint': _usageEndpoint,
      'status': fetch.statusCode,
      'request_url': 'https://www.minimax.io$_usageEndpoint',
      'window_count': windows.length,
      'raw_payload': fetch.prettyBody,
      'raw_payload_compact': fetch.compactBody,
    };
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
      final window = _windowFromTotalsMap(
        label: 'Token Plan',
        data: packageRemain,
        resetsAtMs: _parseResetMs(packageRemain),
      );
      if (window != null) return <ProviderUsageWindow>[window];
    }

    final window = _windowFromTotalsMap(
      label: 'Token Plan',
      data: response,
      resetsAtMs: _parseResetMs(response),
    );
    return window == null ? const <ProviderUsageWindow>[] : [window];
  }

  /// Parses one entry of `model_remains[]` into zero, one, or two
  /// [ProviderUsageWindow]s (interval + weekly).
  ///
  /// The canonical signal is `current_interval_remaining_percent` /
  /// `current_weekly_remaining_percent` (percent REMAINING, 0–100); the
  /// `*_total_count` / `*_usage_count` fields are auxiliary and frequently
  /// report 0 even when the percent signal is meaningful, so we only use them
  /// as a numeric fallback when the percent is missing.
  Iterable<ProviderUsageWindow?> _parseModelRemain(
    Map<String, dynamic> item,
  ) sync* {
    final modelName = item['model_name']?.toString();
    final label = modelName == null || modelName.isEmpty
        ? 'MiniMax'
        : modelName;

    final interval = _windowFromPercent(
      label: label,
      remainingPercent: _parseDouble(
        item['current_interval_remaining_percent'],
      ),
      total: _parseDouble(item['current_interval_total_count']),
      used: _parseDouble(item['current_interval_usage_count']),
      resetsAtMs: _parseEpochMs(item['end_time']),
    );
    if (interval != null) yield interval;

    final weekly = _windowFromPercent(
      label: '$label Weekly',
      remainingPercent: _parseDouble(
        item['current_weekly_remaining_percent'],
      ),
      total: _parseDouble(item['current_weekly_total_count']),
      used: _parseDouble(item['current_weekly_usage_count']),
      resetsAtMs: _parseEpochMs(item['weekly_end_time']),
    );
    if (weekly != null) yield weekly;
  }

  /// Builds a window preferring the percent-remaining signal. Falls back to
  /// deriving utilization from `total`/`used` (or `total`/`limit`) when the
  /// percent is unavailable so the card still renders something useful.
  ProviderUsageWindow? _windowFromTotalsMap({
    required String label,
    required Map<String, dynamic> data,
    required int? resetsAtMs,
  }) {
    return _windowFromPercent(
      label: label,
      remainingPercent: _parseDouble(
        data['remaining_percent'] ?? data['current_interval_remaining_percent'],
      ),
      total: _parseDouble(data['total_count']),
      used: _parseDouble(data['usage_count'] ?? data['used_count']),
      remaining: _parseDouble(
        data['remain_count'] ?? data['remaining_count'],
      ),
      resetsAtMs: resetsAtMs,
    );
  }

  ProviderUsageWindow? _windowFromPercent({
    required String label,
    required double? remainingPercent,
    required double? total,
    required double? used,
    required int? resetsAtMs,
    double? remaining,
  }) {
    double utilization;
    var remainingNum = remaining;
    double? limitNum;
    double? usedNum;

    if (remainingPercent != null) {
      final safe = remainingPercent.clamp(0.0, 100.0);
      utilization = (100.0 - safe).clamp(0.0, 100.0);
      if (total != null && total > 0) {
        limitNum = total;
        usedNum = (total * (utilization / 100)).clamp(0.0, total);
        remainingNum ??= (limitNum - usedNum).clamp(0.0, limitNum);
      }
    } else if (total != null && total > 0 && used != null) {
      limitNum = total;
      usedNum = used < 0 ? 0 : used;
      remainingNum ??= (total - usedNum).clamp(0.0, total);
      utilization = (usedNum / total) * 100;
    } else if (total != null && total > 0 && remainingNum != null) {
      limitNum = total;
      final safeRemaining = remainingNum.clamp(0.0, total);
      usedNum = (total - safeRemaining).clamp(0.0, total);
      remainingNum = safeRemaining;
      utilization = (usedNum / total) * 100;
    } else if (total != null && total > 0) {
      limitNum = total;
      remainingNum = total;
      utilization = 0.0;
    } else {
      return null;
    }

    return ProviderUsageWindow(
      label: label,
      utilization: utilization,
      resetsAtMs: resetsAtMs,
      limit: limitNum,
      used: usedNum,
      remaining: remainingNum,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Reads a `*_end_time` / `reset_at` value as epoch ms. Token-plan payloads
  /// always use epoch ms (large integers), so we don't accept ISO strings here
  /// — those belong in the generic reset parser below.
  static int? _parseEpochMs(dynamic value) {
    if (value is num) {
      return value > 1e12 ? value.toInt() : value.toInt() * 1000;
    }
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed > 1e12 ? parsed.toInt() : parsed.toInt() * 1000;
      }
    }
    return null;
  }

  static int? _parseResetMs(Map<String, dynamic> data) {
    for (final key in const ['end_time', 'reset_at', 'resetAt']) {
      final parsed = _parseEpochMs(data[key]);
      if (parsed != null) return parsed;
      final value = data[key];
      if (value is String) {
        final dt = DateTime.tryParse(value);
        if (dt != null) return dt.millisecondsSinceEpoch;
      }
    }
    return null;
  }
}

/// Z.AI (Zhipu GLM) usage API client.
///
/// Talks to Z.AI's internal usage/quota endpoint
/// (`{baseUrl}/api/monitor/usage/quota/limit`, default host [zaiDefaultBaseUrl])
/// using a Bearer API key from the Z.AI console. These endpoints are NOT part
/// of Z.AI's public API reference — they mirror the subscription-management UI
/// and are the same ones community tools (openusage, zai-usage-tracker) call.
///
/// Returns one [ProviderUsageWindow] per reported limit:
///   • `TOKENS_LIMIT` — rolling token quota. `unit:3`/`number:5` is the 5-hour
///     session window; `unit:6`/`number:7` is the 7-day weekly window.
///   • `TIME_LIMIT` — web-search/reader call quota, resets monthly.
class ZaiUsageApi {
  ZaiUsageApi({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  static const String _usagePath = '/api/monitor/usage/quota/limit';

  /// Fetches usage for the account identified by [apiKey].
  ///
  /// When [includeDebugPayload] is true (developer / debug mode), the raw
  /// response body is surfaced via [ProviderUsage.extra] under
  /// `'raw_payload'` / `'raw_payload_compact'` so the in-app debug viewer can
  /// inspect it without re-issuing a request.
  Future<ProviderUsage> getUsage({
    required String apiKey,
    required String accountId,
    String? accountName,
    String baseUrl = zaiDefaultBaseUrl,
    bool includeDebugPayload = false,
  }) async {
    final fetch = await _fetchUsageRaw(apiKey, baseUrl);

    if (fetch.statusCode != 200) {
      _throwHttpError('Z.AI', 'usage', fetch.response);
    }

    final windows = _parseWindows(fetch.body);
    final extra = includeDebugPayload
        ? _buildExtra(fetch, windows)
        : const <String, dynamic>{};

    if (includeDebugPayload) {
      logger.debug(
        'Z.AI monitor/usage/quota/limit HTTP ${fetch.statusCode} '
        'windows=${windows.length} '
        'payload=${fetch.compactBody}',
      );
    }

    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.zai,
      accountName: accountName,
      windows: windows,
      extra: extra,
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

  /// Performs the GET and captures both the raw Dio response and the decoded
  /// JSON body, so the parser and the debug surface can share the work.
  Future<_ZaiFetch> _fetchUsageRaw(String apiKey, String baseUrl) async {
    final root = _normalizeRoot(baseUrl);
    final response = await _dio.get<dynamic>(
      '$root$_usagePath',
      options: _authOptions(apiKey),
    );

    final raw = response.data;
    final pretty = _safeStringify(raw);
    final compact = _compactStringify(raw);

    Map<String, dynamic> body;
    try {
      body = _asMap(raw, 'Z.AI');
    } catch (_) {
      body = const <String, dynamic>{};
    }

    return _ZaiFetch(
      response: response,
      statusCode: response.statusCode ?? 0,
      body: body,
      prettyBody: pretty,
      compactBody: compact,
    );
  }

  /// Builds the debug `extra` map carried on [ProviderUsage] — only populated
  /// when a 2xx response arrived so we never leak credential error bodies.
  Map<String, dynamic> _buildExtra(
    _ZaiFetch fetch,
    List<ProviderUsageWindow> windows,
  ) {
    if (fetch.statusCode != 200) return const <String, dynamic>{};
    final root = _normalizeRoot(zaiDefaultBaseUrl);
    return <String, dynamic>{
      'endpoint': _usagePath,
      'status': fetch.statusCode,
      'request_url': '$root$_usagePath',
      'window_count': windows.length,
      'raw_payload': fetch.prettyBody,
      'raw_payload_compact': fetch.compactBody,
    };
  }

  /// Parses Z.AI's `{ code, data: { limits: [...] }, success }` envelope.
  List<ProviderUsageWindow> _parseWindows(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) return const <ProviderUsageWindow>[];
    final limits = data['limits'];
    if (limits is! List) return const <ProviderUsageWindow>[];

    final windows = <ProviderUsageWindow>[];
    for (final raw in limits) {
      if (raw is! Map<String, dynamic>) continue;
      final window = _limitToWindow(raw);
      if (window != null) windows.add(window);
    }
    return windows;
  }

  /// Converts one `limits[]` entry into a [ProviderUsageWindow]. Returns null
  /// when the entry carries neither a `percentage` nor enough raw counts to be
  /// meaningful, so we never render a misleading 0% bar.
  ProviderUsageWindow? _limitToWindow(Map<String, dynamic> limit) {
    final type = limit['type']?.toString();
    final percentage = _parseDouble(limit['percentage']);
    final total = _parseDouble(limit['usage']);
    final used = _parseDouble(limit['currentValue']);
    final remaining = _parseDouble(limit['remaining']);

    double utilization;
    if (percentage != null) {
      utilization = percentage.clamp(0.0, 100.0);
    } else if (total != null && total > 0 && used != null) {
      utilization = (used / total) * 100;
    } else {
      return null;
    }

    // TOKENS_LIMIT carries nextResetTime; TIME_LIMIT (monthly) does not, so we
    // derive its reset as the next 1st-of-month 00:00 UTC.
    final resetsAtMs = _parseEpochMs(limit['nextResetTime']) ??
        (type == 'TIME_LIMIT' ? _nextMonthlyResetMs() : null);

    return ProviderUsageWindow(
      label: _labelFor(type, limit['unit']),
      utilization: utilization,
      resetsAtMs: resetsAtMs,
      limit: total,
      used: used,
      remaining: remaining,
    );
  }

  /// Human label for a limit, derived from the documented Z.AI window codes:
  ///   • `TOKENS_LIMIT` with `unit:3` → 5-hour session window
  ///   • `TOKENS_LIMIT` with `unit:6` → 7-day weekly window
  ///   • `TIME_LIMIT` → web-search/reader quota (monthly)
  String _labelFor(String? type, dynamic unit) {
    if (type == 'TIME_LIMIT') return 'Web Searches';
    final unitCode = _parseInt(unit);
    if (unitCode == 3) return 'Session';
    if (unitCode == 6) return 'Weekly';
    // Unknown window — fall back to an honest generic label so the
    // utilization number is still legible if Z.AI adds a new window type.
    return 'Tokens';
  }

  /// Next 1st-of-month 00:00 UTC — the documented reset for the monthly
  /// web-search quota, which carries no `nextResetTime` in the payload.
  static int? _nextMonthlyResetMs() {
    try {
      final now = DateTime.now().toUtc();
      return DateTime.utc(now.year, now.month + 1, 1).millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  static String _normalizeRoot(String baseUrl) {
    final trimmed = baseUrl.trim();
    final base = trimmed.isEmpty ? zaiDefaultBaseUrl : trimmed;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
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

  static int? _parseEpochMs(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      return value > 1e12 ? value.toInt() : value.toInt() * 1000;
    }
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) {
        return parsed > 1e12 ? parsed.toInt() : parsed.toInt() * 1000;
      }
    }
    return null;
  }
}

/// Grok (xAI subscription / Grok Build) usage API client.
///
/// Talks to the Grok CLI subscription host (default [grokDefaultBaseUrl]),
/// mirroring grok-proxy's dashboard client:
///   • `GET {base}/user?include=subscription` — account identity (userId,
///     email, subscription tier). The `x-userid` header for billing comes from
///     here, falling back to the JWT claims in the access token.
///   • `GET {base}/billing?format=credits` — monthly credit allowance. Values
///     are USD cents.
///
/// The endpoint is NOT a stable public API — headers mirror the Grok CLI
/// (`X-XAI-Token-Auth`, `x-grok-client-version`) because the gateway rejects
/// unidentified clients.
class GrokUsageApi {
  GrokUsageApi({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  static const String _userPath = '/user?include=subscription';
  static const String _billingPath = '/billing?format=credits';

  /// Client version advertised to the account service; tracks the Grok CLI
  /// release that grok-proxy mirrors.
  static const String _clientVersion = '0.2.99';

  /// Fetches usage for the account identified by [accessToken].
  ///
  /// When [includeDebugPayload] is true (developer / debug mode), the raw
  /// billing response body is surfaced via [ProviderUsage.extra] under
  /// `'raw_payload'` / `'raw_payload_compact'` so the in-app debug viewer can
  /// inspect it without re-issuing a request.
  Future<ProviderUsage> getUsage({
    required String accessToken,
    required String accountId,
    String? accountName,
    String baseUrl = grokDefaultBaseUrl,
    bool includeDebugPayload = false,
  }) async {
    final root = _normalizeRoot(baseUrl);

    // Billing requires an x-userid header. Prefer the /user endpoint (same
    // enrichment call the CLI makes); fall back to the JWT claims so a
    // temporarily failing /user does not take the whole card down.
    var userId = _userIdFromJwt(accessToken);
    var account = const <String, dynamic>{};
    final userResponse = await _dio.get<dynamic>(
      '$root$_userPath',
      options: _authOptions(accessToken),
    );
    if (userResponse.statusCode == 200) {
      account = _unwrap(_asMapLenient(userResponse.data));
      final fetchedId = _stringOf(account, const ['userId', 'user_id', 'id']);
      if (fetchedId != null && fetchedId.isNotEmpty) userId = fetchedId;
    } else if (userId == null) {
      // No identity at all — surface the auth failure from /user.
      _throwHttpError('Grok', 'account', userResponse);
    }

    final billingResponse = await _dio.get<dynamic>(
      '$root$_billingPath',
      options: _authOptions(accessToken, userId: userId),
    );
    if (billingResponse.statusCode != 200) {
      _throwHttpError('Grok', 'usage', billingResponse);
    }

    final body = _asMapLenient(billingResponse.data);
    final windows = _parseWindows(body);

    final extra = <String, dynamic>{};
    final email = _stringOf(account, const [
      'email',
      'emailAddress',
      'email_address',
    ]);
    final tier = _stringOf(account, const [
      'subscriptionTier',
      'subscription_tier',
    ]);
    if (email != null && email.isNotEmpty) extra['email'] = email;
    if (tier != null && tier.isNotEmpty) extra['subscription_tier'] = tier;
    if (includeDebugPayload) {
      extra.addAll(<String, dynamic>{
        'endpoint': _billingPath,
        'status': billingResponse.statusCode,
        'request_url': '$root$_billingPath',
        'window_count': windows.length,
        'raw_payload': _safeStringify(billingResponse.data),
        'raw_payload_compact': _compactStringify(billingResponse.data),
      });
      logger.debug(
        'Grok billing HTTP ${billingResponse.statusCode} '
        'windows=${windows.length} '
        'payload=${_compactStringify(billingResponse.data)}',
      );
    }

    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.grok,
      accountName: accountName,
      windows: windows,
      extra: extra,
    );
  }

  Options _authOptions(String accessToken, {String? userId}) => Options(
    headers: <String, dynamic>{
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
      'User-Agent': _userAgent,
      'X-XAI-Token-Auth': 'xai-grok-cli',
      'x-grok-client-version': _clientVersion,
      'x-grok-client-mode': 'interactive',
      if (userId != null && userId.isNotEmpty) 'x-userid': userId,
    },
  );

  /// Parses the `format=credits` billing payload into usage windows. The
  /// numbers live under `config` and are USD cents, sometimes wrapped as
  /// `{"val": N}`:
  ///   • `monthlyLimit` / `used` — the included monthly credit allowance.
  ///   • `onDemandCap` / `onDemandUsed` — optional overage budget (cap > 0).
  List<ProviderUsageWindow> _parseWindows(Map<String, dynamic> body) {
    var data = _unwrap(body, const ['data', 'billing', 'credits']);
    final config = data['config'];
    if (config is Map<String, dynamic>) {
      data = config;
    } else if (config is Map) {
      data = Map<String, dynamic>.from(config);
    }

    final windows = <ProviderUsageWindow>[];
    final resetsAtMs = _parseResetMs(data);

    final monthly = _creditsWindow(
      label: 'Monthly Credits',
      limitCents: _centsOf(data, const ['monthlyLimit', 'monthly_limit']),
      usedCents: _centsOf(data, const ['used']),
      resetsAtMs: resetsAtMs,
    );
    if (monthly != null) windows.add(monthly);

    final capCents = _centsOf(data, const ['onDemandCap', 'on_demand_cap']);
    if (capCents != null && capCents > 0) {
      final onDemand = _creditsWindow(
        label: 'On-demand',
        limitCents: capCents,
        usedCents: _centsOf(data, const ['onDemandUsed', 'on_demand_used']),
        resetsAtMs: resetsAtMs,
      );
      if (onDemand != null) windows.add(onDemand);
    }

    return windows;
  }

  /// Builds one dollar-denominated window from cent amounts. Returns null when
  /// the payload carries no limit, so we never render a misleading 0% bar.
  ProviderUsageWindow? _creditsWindow({
    required String label,
    required double? limitCents,
    required double? usedCents,
    required int? resetsAtMs,
  }) {
    if (limitCents == null || limitCents <= 0) return null;
    final limit = limitCents / 100.0;
    final used = ((usedCents ?? 0) < 0 ? 0.0 : (usedCents ?? 0)) / 100.0;
    return ProviderUsageWindow(
      label: label,
      utilization: ((used / limit) * 100).clamp(0.0, 100.0),
      resetsAtMs: resetsAtMs,
      limit: limit,
      used: used,
      remaining: (limit - used).clamp(0.0, limit),
    );
  }

  /// Billing period end — ISO-8601 in `billingPeriodEnd` or
  /// `currentPeriod.end`.
  static int? _parseResetMs(Map<String, dynamic> data) {
    final period = data['currentPeriod'] ?? data['current_period'];
    final candidates = <dynamic>[
      data['billingPeriodEnd'],
      data['billing_period_end'],
      if (period is Map) period['end'],
    ];
    for (final value in candidates) {
      if (value is String && value.isNotEmpty) {
        final dt = DateTime.tryParse(value);
        if (dt != null) return dt.millisecondsSinceEpoch;
      }
    }
    return null;
  }

  /// Reads a cent amount that may arrive as a number, numeric string, or the
  /// `{"val": N}` wrapper used by the credits format.
  static double? _centsOf(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      if (value is Map) {
        final inner = value['val'];
        if (inner is num) return inner.toDouble();
        if (inner is String) return double.tryParse(inner);
      }
    }
    return null;
  }

  static String? _stringOf(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
      if (value is num) return value.toString();
    }
    return null;
  }

  /// Descends through the response envelope (`data` → `user`/`billing`/...)
  /// until no wrapper key matches, mirroring grok-proxy's `unwrap`.
  static Map<String, dynamic> _unwrap(
    Map<String, dynamic> value, [
    List<String> keys = const ['data', 'user'],
  ]) {
    var current = value;
    var advanced = true;
    while (advanced) {
      advanced = false;
      for (final key in keys) {
        final child = current[key];
        if (child is Map<String, dynamic>) {
          current = child;
          advanced = true;
          break;
        }
        if (child is Map) {
          current = Map<String, dynamic>.from(child);
          advanced = true;
          break;
        }
      }
    }
    return current;
  }

  /// Recovers the user id from the OAuth access token's JWT claims, the same
  /// fallback the Grok CLI uses before its optional /user enrichment call.
  static String? _userIdFromJwt(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is! Map<String, dynamic>) return null;
      return _stringOf(claims, const ['userId', 'user_id', 'sub', 'id']);
    } catch (_) {
      return null;
    }
  }

  /// Like [_asMap] but returns an empty map instead of throwing, so a
  /// non-JSON body surfaces as "no windows" plus the HTTP error path.
  static Map<String, dynamic> _asMapLenient(dynamic data) {
    try {
      return _asMap(data, 'Grok');
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  static String _normalizeRoot(String baseUrl) {
    final trimmed = baseUrl.trim();
    final base = trimmed.isEmpty ? grokDefaultBaseUrl : trimmed;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }
}

/// Qwen Cloud (Token Plan) usage API client.
///
/// Qwen Cloud does NOT publish a stable usage/credits endpoint — its docs
/// only point at the web console (`home.qwencloud.com/billing/subscription/
/// token-plan`). This client calls the console's subscription path
/// (`{baseUrl}/api/billing/subscription/token-plan/usage`, default host
/// [qwenDefaultBaseUrl]) with a Bearer API key (`sk-sp-…` for Token Plan
/// Individual). The path is a best-effort default: point the account's base
/// URL at the real billing endpoint (e.g. after inspecting the console's
/// network traffic) and the in-app debug payload viewer will show the raw
/// response so the parser can be aligned to it.
///
/// Parsing is deliberately lenient — the payload shape is unverified, so the
/// parser accepts the common credit/quota spellings (`credits`/`limit`/
/// `used`/`remaining` aliases, percent fields, `data`/`usage`/`result`
/// envelopes, and lists of limit rows) rather than one exact shape.
class QwenUsageApi {
  QwenUsageApi({Dio? dio}) : _dio = dio ?? _createDio();

  final Dio _dio;

  /// Best-effort usage path mirroring the console's subscription page
  /// (`/billing/subscription/token-plan`). Override via [getUsage]'s
  /// `baseUrl` when the real billing endpoint is known.
  static const String _usagePath = '/api/billing/subscription/token-plan/usage';

  /// Fetches usage for the account identified by [apiKey].
  ///
  /// When [includeDebugPayload] is true (developer / debug mode), the raw
  /// response body is surfaced via [ProviderUsage.extra] under
  /// `'raw_payload'` / `'raw_payload_compact'` so the in-app debug viewer can
  /// inspect it without re-issuing a request — the primary way to align the
  /// parser with the (undocumented) billing response shape.
  Future<ProviderUsage> getUsage({
    required String apiKey,
    required String accountId,
    String? accountName,
    String baseUrl = qwenDefaultBaseUrl,
    bool includeDebugPayload = false,
  }) async {
    final fetch = await _fetchUsageRaw(apiKey, baseUrl);

    if (fetch.statusCode != 200) {
      _throwHttpError('Qwen', 'usage', fetch.response);
    }

    final windows = _parseWindows(fetch.body);
    final extra = includeDebugPayload
        ? _buildExtra(fetch, windows)
        : const <String, dynamic>{};

    if (includeDebugPayload) {
      logger.debug(
        'Qwen token-plan usage HTTP ${fetch.statusCode} '
        'windows=${windows.length} '
        'payload=${fetch.compactBody}',
      );
    }

    return ProviderUsage(
      accountId: accountId,
      type: ProviderUsageType.qwen,
      accountName: accountName,
      windows: windows,
      extra: extra,
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

  /// Performs the GET and captures both the raw Dio response and the decoded
  /// JSON body, so the parser and the debug surface can share the work.
  Future<_QwenFetch> _fetchUsageRaw(String apiKey, String baseUrl) async {
    final root = _normalizeRoot(baseUrl);
    final response = await _dio.get<dynamic>(
      '$root$_usagePath',
      options: _authOptions(apiKey),
    );

    final raw = response.data;
    final pretty = _safeStringify(raw);
    final compact = _compactStringify(raw);

    Map<String, dynamic> body;
    try {
      body = _asMap(raw, 'Qwen');
    } catch (_) {
      body = const <String, dynamic>{};
    }

    return _QwenFetch(
      response: response,
      statusCode: response.statusCode ?? 0,
      body: body,
      prettyBody: pretty,
      compactBody: compact,
      requestUrl: '$root$_usagePath',
    );
  }

  /// Builds the debug `extra` map carried on [ProviderUsage] — only populated
  /// when a 2xx response arrived so we never leak credential error bodies.
  /// The `request_url` reflects the account's (possibly overridden) base URL
  /// since endpoint discovery is the main reason to open the debug sheet.
  Map<String, dynamic> _buildExtra(
    _QwenFetch fetch,
    List<ProviderUsageWindow> windows,
  ) {
    if (fetch.statusCode != 200) return const <String, dynamic>{};
    return <String, dynamic>{
      'endpoint': _usagePath,
      'status': fetch.statusCode,
      'request_url': fetch.requestUrl,
      'window_count': windows.length,
      'raw_payload': fetch.prettyBody,
      'raw_payload_compact': fetch.compactBody,
    };
  }

  /// Parses the (unverified) Qwen billing payload into usage windows.
  ///
  /// Tolerates, in order:
  ///   1. A list of limit rows under `limits`/`quotas`/`plans`/`data`
  ///      (Z.AI/Kimi style).
  ///   2. A single totals object, unwrapping `data`/`usage`/`result`/
  ///      `credits` envelopes (MiniMax/Grok style).
  List<ProviderUsageWindow> _parseWindows(Map<String, dynamic> response) {
    final payload = _unwrap(response);

    for (final key in const ['limits', 'quotas', 'plans', 'data']) {
      final rows = payload[key];
      if (rows is List) {
        final windows = <ProviderUsageWindow>[];
        for (final raw in rows) {
          if (raw is! Map<String, dynamic>) continue;
          final window = _rowToWindow(raw, _rowLabel(raw, 'Credits'));
          if (window != null) windows.add(window);
        }
        if (windows.isNotEmpty) return windows;
      }
    }

    final window = _rowToWindow(payload, 'Credits');
    if (window != null) return <ProviderUsageWindow>[window];

    return const <ProviderUsageWindow>[];
  }

  /// Converts one totals/limits row into a [ProviderUsageWindow].
  ///
  /// Accepts the assorted credit/quota spellings: percent fields first, then
  /// total/used/remaining aliases. Returns null when the row carries nothing
  /// usable so we never render a misleading 0% bar.
  ProviderUsageWindow? _rowToWindow(
    Map<String, dynamic> data,
    String fallbackLabel,
  ) {
    final percentage = _parseDouble(
      data['percentage'] ??
          data['percent'] ??
          data['usage_percent'] ??
          data['used_percent'],
    );

    final limit = _firstDouble(data, const [
      'total_credits', 'credits_total', 'credit_total',
      'limit', 'limit_amount', 'total', 'total_amount', 'quota', 'capacity',
    ]);
    final used = _firstDouble(data, const [
      'credits_used', 'used_credits', 'credit_used',
      'used', 'used_amount', 'usage', 'consumed',
    ]);
    final remaining = _firstDouble(data, const [
      'credits_remaining', 'remaining_credits', 'credit_remaining',
      'remaining', 'remain', 'balance', 'left',
    ]);

    double utilization;
    double? limitNum;
    double? usedNum;
    double? remainingNum;

    if (percentage != null) {
      utilization = percentage.clamp(0.0, 100.0);
      if (limit != null && limit > 0) {
        limitNum = limit;
        usedNum = (limit * (utilization / 100)).clamp(0.0, limit);
        remainingNum = (limit - usedNum).clamp(0.0, limit);
      }
    } else if (limit != null && limit > 0 && used != null) {
      limitNum = limit;
      usedNum = used < 0 ? 0 : used;
      remainingNum = (limit - usedNum).clamp(0.0, limit);
      utilization = (usedNum / limit) * 100;
    } else if (limit != null && limit > 0 && remaining != null) {
      limitNum = limit;
      final safeRemaining = remaining.clamp(0.0, limit);
      usedNum = (limit - safeRemaining).clamp(0.0, limit);
      remainingNum = safeRemaining;
      utilization = (usedNum / limit) * 100;
    } else {
      return null;
    }

    return ProviderUsageWindow(
      label: _rowLabel(data, fallbackLabel),
      utilization: utilization.clamp(0.0, 100.0),
      resetsAtMs: _parseResetMs(data),
      limit: limitNum,
      used: usedNum,
      remaining: remainingNum,
    );
  }

  /// Human label for a row, preferring an explicit name/title/plan field and
  /// falling back to [fallback] so single-totals payloads read "Credits".
  static String _rowLabel(Map<String, dynamic> data, String fallback) {
    for (final key in const ['name', 'title', 'plan', 'type', 'scope']) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback;
  }

  /// Descends through single-map envelope wrappers (`data` → `usage`/…) until
  /// no wrapper key matches, so both `{data: {...}}` and bare payloads parse
  /// the same way. Lists are left intact — the row-list path handles them.
  static Map<String, dynamic> _unwrap(Map<String, dynamic> value) {
    var current = value;
    var advanced = true;
    while (advanced) {
      advanced = false;
      for (final key in const ['data', 'usage', 'result', 'credits']) {
        final child = current[key];
        if (child is Map<String, dynamic>) {
          current = child;
          advanced = true;
          break;
        }
        if (child is Map) {
          current = Map<String, dynamic>.from(child);
          advanced = true;
          break;
        }
      }
    }
    return current;
  }

  /// Extracts a reset timestamp (ms since epoch) from the assorted reset
  /// field names, accepting ISO-8601 strings, epoch numbers, or relative
  /// seconds.
  static int? _parseResetMs(Map<String, dynamic> data) {
    const isoKeys = [
      'reset_at', 'resetAt', 'reset_time', 'resetTime', 'nextResetTime',
      'period_end', 'periodEnd', 'expire_time', 'expireTime', 'end_time',
    ];
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

  /// First parseable numeric value among [keys]. Maps and lists never match,
  /// so envelope values like `"usage": {...}` are skipped safely.
  static double? _firstDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _parseDouble(data[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String _normalizeRoot(String baseUrl) {
    final trimmed = baseUrl.trim();
    final base = trimmed.isEmpty ? qwenDefaultBaseUrl : trimmed;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
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

/// Encapsulates one Kimi HTTP exchange so the parser and the debug surface
/// can share the same body without re-decoding.
class _KimiFetch {
  const _KimiFetch({
    required this.response,
    required this.statusCode,
    required this.body,
    required this.prettyBody,
    required this.compactBody,
    required this.endpoint,
  });

  final Response<dynamic> response;
  final int statusCode;
  final Map<String, dynamic> body;
  final String prettyBody;
  final String compactBody;
  final String endpoint;
}

/// Encapsulates one Z.AI HTTP exchange so the parser and the debug surface
/// can share the same body without re-decoding.
class _ZaiFetch {
  const _ZaiFetch({
    required this.response,
    required this.statusCode,
    required this.body,
    required this.prettyBody,
    required this.compactBody,
  });

  final Response<dynamic> response;
  final int statusCode;
  final Map<String, dynamic> body;
  final String prettyBody;
  final String compactBody;
}

/// Encapsulates one MiniMax HTTP exchange so the parser and the debug surface
/// can share the same body without re-decoding.
class _MiniMaxFetch {
  const _MiniMaxFetch({
    required this.response,
    required this.statusCode,
    required this.body,
    required this.prettyBody,
    required this.compactBody,
  });

  final Response<dynamic> response;
  final int statusCode;
  final Map<String, dynamic> body;
  final String prettyBody;
  final String compactBody;
}

/// Encapsulates one Qwen HTTP exchange so the parser and the debug surface
/// can share the same body without re-decoding. Carries [requestUrl] because
/// the base URL is expected to be overridden during endpoint discovery.
class _QwenFetch {
  const _QwenFetch({
    required this.response,
    required this.statusCode,
    required this.body,
    required this.prettyBody,
    required this.compactBody,
    required this.requestUrl,
  });

  final Response<dynamic> response;
  final int statusCode;
  final Map<String, dynamic> body;
  final String prettyBody;
  final String compactBody;
  final String requestUrl;
}

/// Pretty-prints a JSON-compatible value, falling back to `toString()` when
/// the value can't be safely serialized (e.g. circular structures, raw bytes).
///
/// If [value] is a [String] that contains JSON, it is decoded first so the
/// pretty output has real line breaks instead of a single quoted string with
/// escaped `\n` characters.
String _safeStringify(dynamic value) {
  try {
    const encoder = JsonEncoder.withIndent('  ');
    final decoded = _decodeIfJsonString(value);
    return encoder.convert(decoded ?? value);
  } catch (_) {
    return value?.toString() ?? 'null';
  }
}

/// Compact (single-line) JSON encoding for log breadcrumbs.
///
/// Like [_safeStringify], JSON string bodies are decoded before re-encoding so
/// the compact form is valid JSON rather than a quoted JSON string.
String _compactStringify(dynamic value) {
  try {
    final decoded = _decodeIfJsonString(value);
    return jsonEncode(decoded ?? value);
  } catch (_) {
    return value?.toString() ?? 'null';
  }
}

/// Decodes [value] when it is a non-empty JSON string, otherwise returns null.
///
/// Some gateways or proxies return the response body as a JSON string rather
/// than a parsed object. Without this step, `JsonEncoder` would emit a quoted
/// string with escaped newlines, making the debug sheet render the payload as
/// one garbled line.
dynamic _decodeIfJsonString(dynamic value) {
  if (value is String && value.isNotEmpty) {
    try {
      return jsonDecode(value);
    } catch (_) {
      // Not a JSON string — fall through and let the caller encode the raw
      // value (e.g. a plain text error body).
    }
  }
  return null;
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
