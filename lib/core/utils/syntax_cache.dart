import '../../features/chat/syntax_highlighter.dart';
import '../../features/chat/syntax_tokenizer.dart';
import '../utils/lru_cache.dart';

/// Global cache for syntax-highlighted code tokenization results.
///
/// Tokenization is expensive (regex heavy, bracket nesting calculations).
/// This cache shares tokenization results across all SyntaxHighlighter
/// instances — same code+language renders instantly.
class SyntaxTokenCache {
  SyntaxTokenCache._();
  static final SyntaxTokenCache instance = SyntaxTokenCache._();

  static const int _maxCacheEntries = 200;
  static const int _maxCachedCodeUnits = 50000;

  /// LRU cache with an entry limit. Very large code blocks are not cached
  /// because a few of them can retain far more memory than the entry count
  /// suggests on web.
  final LRUCache<String, List<SyntaxToken>> _cache = LRUCache(_maxCacheEntries);

  /// Generate cache key from code content and language.
  String _generateKey(String code, String? language) {
    // Use content hash for compact keys; language is short.
    final hash = Object.hash(code, language ?? '');
    return '$language:$hash';
  }

  /// Get cached tokens for [code] in [language], or compute and cache.
  List<SyntaxToken> get(String code, String? language) {
    if (code.length > _maxCachedCodeUnits) {
      return SyntaxTokenizer.tokenize(code, language);
    }
    final key = _generateKey(code, language);
    final cached = _cache.get(key);
    if (cached != null) return cached;

    // Cache miss — tokenize and store.
    final tokens = SyntaxTokenizer.tokenize(code, language);
    _cache.put(key, tokens);
    return tokens;
  }

  /// Clear all cached tokenization results.
  void clear() => _cache.clear();

  /// Get cache statistics for debugging.
  Map<String, int> getStats() => _cache.getStats();
}
