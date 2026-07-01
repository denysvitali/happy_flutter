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

/// Pretty-prints a JSON-compatible value, falling back to `toString()` when
/// the value can't be safely serialized (e.g. circular structures, raw bytes).
String _safeStringify(dynamic value) {
  try {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value);
  } catch (_) {
    return value?.toString() ?? 'null';
  }
}

/// Compact (single-line) JSON encoding for log breadcrumbs.
String _compactStringify(dynamic value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return value?.toString() ?? 'null';
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
