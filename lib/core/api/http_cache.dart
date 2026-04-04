import 'package:dio/dio.dart';

import '../services/logger_service.dart' show logger;

/// HTTP cache entry with response data and expiration
class HttpCacheEntry {
  HttpCacheEntry(this.response, this.expiresAt);

  final Response response;
  final int expiresAt;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > expiresAt;
}

/// In-memory HTTP response cache for GET requests
class HttpResponseCache {
  final _cache = <String, HttpCacheEntry>{};

  static const int maxEntries = 200;
  static const int defaultMaxAge = 5 * 60 * 1000; // 5 minutes

  /// Generate cache key from request options
  String generateKey(RequestOptions options) {
    final buffer = StringBuffer(options.method)
      ..write(':')
      ..write(options.uri.path);
    if (options.queryParameters.isNotEmpty) {
      final sortedParams = Map<String, dynamic>.fromEntries(
        options.queryParameters.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      buffer
        ..write('?')
        ..write(sortedParams.entries
            .map((e) => '${e.key}=${e.value}')
            .join('&'));
    }
    return buffer.toString();
  }

  /// Get cached response if available and not expired
  Response? get(RequestOptions options) {
    final key = generateKey(options);
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      logger.debug('HTTP cache hit: $key');
      return entry.response;
    }
    if (entry != null && entry.isExpired) {
      _cache.remove(key);
    }
    return null;
  }

  /// Cache a response with expiration time
  void put(RequestOptions options, Response response) {
    // Only cache successful GET requests
    if (options.method != 'GET') return;
    if (response.statusCode != 200) return;

    final maxAge = _parseMaxAge(response.headers);
    if (maxAge == 0) return; // no-store

    final key = generateKey(options);
    final expiresAt =
        DateTime.now().millisecondsSinceEpoch + maxAge;
    _cache[key] = HttpCacheEntry(response, expiresAt);

    logger.debug(
      'HTTP cache stored: $key (expires in $maxAge ms)',
    );
    _evictOldest();
  }

  /// Invalidate cache entries matching a pattern
  void invalidate(String pathPattern) {
    final keysToRemove = _cache.keys
        .where((key) =>
            key.contains('GET:') && key.contains(pathPattern))
        .toList();
    for (final key in keysToRemove) {
      _cache.remove(key);
      logger.debug('HTTP cache invalidated: $key');
    }
  }

  /// Clear all cached responses
  void clear() {
    _cache.clear();
    logger.info('HTTP cache cleared');
  }

  /// Get cache statistics for debugging
  Map<String, int> getStats() {
    final expiredCount =
        _cache.values.where((entry) => entry.isExpired).length;
    return {
      'totalEntries': _cache.length,
      'activeEntries': _cache.length - expiredCount,
      'expiredEntries': expiredCount,
    };
  }

  /// Parse Cache-Control header to get max-age directive
  int _parseMaxAge(Headers headers) {
    final cacheControl =
        headers.value('cache-control')?.toLowerCase();
    if (cacheControl == null) return defaultMaxAge;

    // Check for no-store directive
    if (cacheControl.contains('no-store')) return 0;

    // Extract max-age value
    final maxAgeMatch =
        RegExp(r'max-age\s*=\s*(\d+)').firstMatch(cacheControl);
    if (maxAgeMatch != null) {
      final seconds = int.tryParse(maxAgeMatch.group(1) ?? '');
      if (seconds != null) return seconds * 1000;
    }

    return defaultMaxAge;
  }

  /// Evict oldest entries when cache exceeds max size
  void _evictOldest() {
    if (_cache.length <= maxEntries) return;

    final entries = _cache.entries.toList()
      ..sort(
        (a, b) => a.value.expiresAt.compareTo(b.value.expiresAt),
      );

    final toRemove = entries.length - maxEntries;
    for (var i = 0; i < toRemove; i++) {
      _cache.remove(entries[i].key);
    }
  }
}
