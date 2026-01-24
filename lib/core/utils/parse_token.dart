import 'dart:convert';

/// Parse JWT token to extract user ID from server token format
String parseToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) {
      return token.substring(0, 8);
    }

    final payload = parts[1];
    final normalized = base64Url.normalize(payload);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final Map<String, dynamic> claims = jsonDecode(decoded);

    return claims['sub'] as String? ??
           claims['user_id'] as String? ??
           claims['userId'] as String? ??
           'unknown';
  } catch (e) {
    return token.substring(0, 8);
  }
}
