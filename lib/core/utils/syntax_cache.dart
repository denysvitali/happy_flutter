import '../../features/chat/syntax_highlighter.dart';
import '../../features/chat/syntax_tokenizer.dart';
import '../utils/lru_cache.dart';

/// Characters of trailing content rendered as plain text while a code block
/// is still streaming; the completed block is tokenized (and cached) once.
const int syntaxStreamingTailUnits = 2000;

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
  ///
  /// While [isStreaming] is true the block is still receiving appends: the
  /// full-content key can never hit, tokenizing the whole block re-runs the
  /// regex/bracket scans on every delta, and inserting every intermediate
  /// snapshot would evict live entries from the shared LRU. Streaming calls
  /// therefore get a bounded plain-text tail ([syntaxStreamingTailUnits])
  /// and touch neither the tokenizer nor the cache; the completed block is
  /// tokenized and cached normally once streaming ends.
  List<SyntaxToken> get(
    String code,
    String? language, {
    bool isStreaming = false,
  }) {
    if (isStreaming) return _streamingTokens(code);
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

  /// Plain monochrome tokens for at most [syntaxStreamingTailUnits]
  /// trailing characters — no tokenizer run, no cache write.
  static List<SyntaxToken> _streamingTokens(String code) {
    final start = code.length <= syntaxStreamingTailUnits
        ? 0
        : code.length - syntaxStreamingTailUnits;
    return [
      SyntaxToken(
        text: start == 0 ? code : code.substring(start),
        type: SyntaxTokenType.default_,
      ),
    ];
  }

  /// Clear all cached tokenization results.
  void clear() => _cache.clear();

  /// Get cache statistics for debugging.
  Map<String, int> getStats() => _cache.getStats();
}
