import 'package:flutter/material.dart';

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

/// Global cache for parsed markdown widget trees.
///
/// Parsing markdown to a widget tree is CPU-intensive.  This cache stores
/// the built [MarkdownBody] widget by the exact markdown string, so that
/// identical markdown content reuses the same widget instance on rebuild.
/// This prevents re-parsing on every [build] when the parent rebuilds with
/// an unchanged markdown string (the common case during streaming).
///
/// Caching is safe for [SimpleMarkdownView] (no callbacks) and for
/// [MarkdownView] when [onOptionPress] is stable across rebuilds.
class MarkdownAstCache {
  MarkdownAstCache._();
  static final MarkdownAstCache instance = MarkdownAstCache._();

  /// LRU cache with 200-entry limit.  Each entry stores the built
  /// [MarkdownBody] widget for a given markdown string.
  final LRUCache<String, Widget> _cache = LRUCache(200);

  /// Get the cached [MarkdownBody] widget for [markdown], or null if
  /// not cached.
  Widget? get(String markdown) => _cache.get(markdown);

  /// Store a [MarkdownBody] widget in the cache keyed by [markdown].
  void put(String markdown, Widget widget) => _cache.put(markdown, widget);

  /// Clear all cached markdown widgets.
  void clear() => _cache.clear();

  /// Get cache statistics for debugging.
  Map<String, int> getStats() => _cache.getStats();
}
