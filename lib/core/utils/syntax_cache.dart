import 'dart:math';

import '../utils/lru_cache.dart';
import '../../features/chat/syntax_highlighter.dart';

/// Global cache for syntax-highlighted code tokenization results.
///
/// Tokenization is expensive (regex heavy, bracket nesting calculations).
/// This cache shares tokenization results across all SyntaxHighlighter
/// instances — same code+language renders instantly.
class SyntaxTokenCache {
  SyntaxTokenCache._();
  static final SyntaxTokenCache instance = SyntaxTokenCache._();

  /// LRU cache with 500-entry limit (~1-2MB for typical code blocks)
  final LRUCache<String, List<SyntaxToken>> _cache = LRUCache(500);

  /// Generate cache key from code content and language.
  String _generateKey(String code, String? language) {
    // Use content hash for compact keys; language is short.
    final hash = Object.hash(code, language ?? '');
    return '$language:$hash';
  }

  /// Get cached tokens for [code] in [language], or compute and cache.
  List<SyntaxToken> get(String code, String? language) {
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

/// Global cache for markdown parsed AST nodes.
///
/// Parsing markdown to AST is CPU-intensive. This cache stores the parsed
/// document nodes by content hash, allowing identical markdown strings
/// across the app to render without re-parsing.
class MarkdownAstCache {
  MarkdownAstCache._();
  static final MarkdownAstCache instance = MarkdownAstCache._();

  /// LRU cache with 200-entry limit (~500KB-1MB for typical markdown)
  final LRUCache<String, String> _cache = LRUCache(200);

  /// Generate cache key from markdown content.
  String _generateKey(String markdown) {
    // Short hash for compact keys.
    final hash = Object.hash(markdown);
    return hash.toString();
  }

  /// Check if markdown is cached (for stats/debugging).
  bool contains(String markdown) {
    final key = _generateKey(markdown);
    return _cache.containsKey(key);
  }

  /// Store parsed markdown result by hash.
  /// Note: flutter_markdown_plus doesn't expose AST, so this is a placeholder
  /// for future integration or custom parsing. Currently used for hit tracking.
  void put(String markdown) {
    final key = _generateKey(markdown);
    _cache.put(key, markdown);
  }

  /// Clear all cached markdown.
  void clear() => _cache.clear();

  /// Get cache statistics for debugging.
  Map<String, int> getStats() => _cache.getStats();
}
