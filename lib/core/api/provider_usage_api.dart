import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/provider_usage.dart';
import '../services/logger_service.dart' show logger;
import 'base_api_exception.dart';
import 'grok_usage_parser.dart';
import 'kimi_usage_parser.dart';
import 'minimax_usage_parser.dart';
import 'qwen_usage_parser.dart';
import 'zai_usage_parser.dart';

part '_provider_usage_response.dart';

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
    final windows = const KimiUsageParser().parseWindows(payload);
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
  Future<_KimiFetch> _fetchUsageRaw(String apiKey, String baseUrl) async {
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
    final windows = const MiniMaxUsageParser().parseWindows(usageResponse);
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
}

/// Z.AI (Zhipu GLM) usage API client.
///
/// Talks to Z.AI's internal usage/quota endpoint
/// (`{baseUrl}/api/monitor/usage/quota/limit`, with default host
/// [zaiDefaultBaseUrl])
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

    final windows = const ZaiUsageParser().parseWindows(fetch.body);
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

  static String _normalizeRoot(String baseUrl) {
    final trimmed = baseUrl.trim();
    final base = trimmed.isEmpty ? zaiDefaultBaseUrl : trimmed;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
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
    var userId = GrokUsageParser.userIdFromJwt(accessToken);
    var account = const <String, dynamic>{};
    final userResponse = await _dio.get<dynamic>(
      '$root$_userPath',
      options: _authOptions(accessToken),
    );
    if (userResponse.statusCode == 200) {
      account = GrokUsageParser.unwrap(_asMapLenient(userResponse.data));
      final fetchedId = GrokUsageParser.stringOf(account, const [
        'userId',
        'user_id',
        'id',
      ]);
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
    final windows = const GrokUsageParser().parseWindows(body);

    final extra = <String, dynamic>{};
    final email = GrokUsageParser.stringOf(account, const [
      'email',
      'emailAddress',
      'email_address',
    ]);
    final tier = GrokUsageParser.stringOf(account, const [
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

    // A 200 whose body is not a JSON object means the host served a web page
    // (the console's SPA shell) instead of a usage API response — the default
    // Qwen path is a guess the console does not back with a real endpoint for
    // API keys, so it never yields windows. Surface it as an actionable error
    // rather than a misleading "no usage"; the raw body is still captured so
    // the debug sheet can show what came back.
    if (!fetch.bodyIsJson) {
      final parseError = _qwenNonJsonParseError(fetch);
      final extra = includeDebugPayload
          ? _buildExtra(
              fetch,
              const <ProviderUsageWindow>[],
              parseError: parseError,
            )
          : const <String, dynamic>{};
      if (includeDebugPayload) {
        logger.debug(
          'Qwen token-plan usage HTTP ${fetch.statusCode} '
          'non-json body: $parseError payload=${fetch.compactBody}',
        );
      }
      return ProviderUsage(
        accountId: accountId,
        type: ProviderUsageType.qwen,
        accountName: accountName,
        windows: const <ProviderUsageWindow>[],
        extra: extra,
        error: parseError,
      );
    }

    final windows = const QwenUsageParser().parseWindows(fetch.body);
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
    var bodyIsJson = false;
    try {
      body = _asMap(raw, 'Qwen');
      bodyIsJson = true;
    } catch (_) {
      body = const <String, dynamic>{};
    }

    return _QwenFetch(
      response: response,
      statusCode: response.statusCode ?? 0,
      body: body,
      bodyIsJson: bodyIsJson,
      contentType: _responseContentType(response),
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
    List<ProviderUsageWindow> windows, {
    String? parseError,
  }) {
    if (fetch.statusCode != 200) return const <String, dynamic>{};
    return <String, dynamic>{
      'endpoint': _usagePath,
      'status': fetch.statusCode,
      'request_url': fetch.requestUrl,
      'content_type': fetch.contentType,
      'window_count': windows.length,
      if (parseError != null) 'parse_error': parseError,
      'raw_payload': fetch.prettyBody,
      'raw_payload_compact': fetch.compactBody,
    };
  }

  /// Lower-cased `Content-Type` (without parameters) for [response], or `''`
  /// when the header is missing — used to explain a non-JSON 200 body.
  String _responseContentType(Response<dynamic> response) {
    final raw = response.headers.value('content-type') ?? '';
    return raw.split(';').first.trim().toLowerCase();
  }

  /// Actionable error shown when a Qwen 200 response carries a non-JSON body.
  String _qwenNonJsonParseError(_QwenFetch fetch) {
    final ct = fetch.contentType;
    final kind = ct.isNotEmpty ? ct : 'non-JSON';
    return 'Qwen returned a web page ($kind), not a usage API response. '
        'The default path is the console app shell and accepts no API key, '
        'so no windows parsed. Open the Token Plan page in a browser, copy '
        'the real usage request URL from the DevTools Network tab into '
        'Base URL; otherwise this account cannot be tracked with an API key.';
  }

  static String _normalizeRoot(String baseUrl) {
    final trimmed = baseUrl.trim();
    final base = trimmed.isEmpty ? qwenDefaultBaseUrl : trimmed;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }
}
