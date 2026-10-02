part of 'provider_usage_api.dart';

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
    required this.bodyIsJson,
    required this.contentType,
    required this.prettyBody,
    required this.compactBody,
    required this.requestUrl,
  });

  final Response<dynamic> response;
  final int statusCode;
  final Map<String, dynamic> body;

  /// Whether [body] was decoded from a JSON object (vs. an empty fallback for
  /// a non-JSON body such as an HTML page).
  final bool bodyIsJson;

  /// Lower-cased response `Content-Type` (no parameters), e.g. `text/html`.
  final String contentType;
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
