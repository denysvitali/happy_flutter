import 'dart:collection';

import 'package:flutter/material.dart';

import 'ansi_parser.dart';

/// Bounded LRU memo for [AnsiParser.parse] results.
///
/// Tool views re-parse the same tool output on every rebuild while a
/// session streams; parsing is ~8x more expensive than stripping
/// (`ansi_parse_20kb` p50 0.573 ms vs `ansi_strip_20kb` 0.067 ms, JIT)
/// and runs on the UI isolate inside build. This cache lets repeated
/// builds of unchanged output return the previously built span list at
/// O(1) cost.
///
/// Keying without hashing megabytes: a lookup first checks string
/// identity, then (length + sampled fingerprint of ~300 code units).
/// A fingerprint match is verified with full string equality before the
/// cached spans are returned, so distinct content can never receive
/// another string's spans even on a fingerprint collision. Outputs that
/// grow between ticks change length and therefore miss and reparse —
/// the expected streaming behaviour.
///
/// Bounds: at most [maxEntries] entries (LRU) and outputs longer than
/// [maxCacheableChars] are parsed but never stored, so giant
/// transcripts cannot pin memory. Worst case retained span text is
/// `maxEntries * maxCacheableChars` (~8 MB), typical use far less.
/// UI-isolate only — no cross-isolate synchronization.
class AnsiSpanCache {
  AnsiSpanCache._();

  /// Process-wide singleton shared by all call sites.
  static final AnsiSpanCache instance = AnsiSpanCache._();

  /// Maximum number of cached parse results.
  static const int maxEntries = 32;

  /// Outputs longer than this bypass the cache entirely.
  static const int maxCacheableChars = 256 * 1024;

  final LinkedHashMap<_AnsiCacheKey, _AnsiCacheEntry> _cache =
      LinkedHashMap<_AnsiCacheKey, _AnsiCacheEntry>();

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _bypasses = 0;

  /// Parses [text], returning cached spans when an identical
  /// (text, style) pair was parsed recently.
  ///
  /// The returned list is shared between callers; treat it as
  /// immutable. [TextSpan]s themselves are immutable, so sharing them
  /// across widgets is safe.
  List<TextSpan> parse(String text, {TextStyle? defaultStyle}) {
    if (text.isEmpty) return const <TextSpan>[];
    if (text.length > maxCacheableChars) {
      _bypasses++;
      return AnsiParser.parse(text, defaultStyle: defaultStyle);
    }
    final style = defaultStyle ?? const TextStyle();
    final key = _AnsiCacheKey(text.length, _fingerprint(text), style);
    final entry = _cache.remove(key);
    if (entry != null &&
        (identical(entry.source, text) || entry.source == text)) {
      _cache[key] = entry;
      _hits++;
      return entry.spans;
    }
    _misses++;
    // `entry != null` here means a same-length, same-fingerprint,
    // same-style key mapped to different content (fingerprint
    // collision). The remove above already dropped it; store the fresh
    // parse under the key.
    final spans = AnsiParser.parse(text, defaultStyle: defaultStyle);
    _cache[key] = _AnsiCacheEntry(text, spans);
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
      _evictions++;
    }
    return spans;
  }

  /// Cheap content fingerprint: samples ~[probes] * [probeLen] code
  /// units spread evenly across the string regardless of its length.
  /// Not used for correctness (a match is verified with equality); it
  /// only routes likely-misses away from the O(n) comparison.
  static int _fingerprint(String text) {
    const probes = 12;
    const probeLen = 24;
    final n = text.length;
    var hash = 0x811C9DC5 ^ n;
    for (var p = 0; p < probes; p++) {
      final start = n <= probeLen ? 0 : p * (n - probeLen) ~/ (probes - 1);
      final end = start + probeLen > n ? n : start + probeLen;
      for (var i = start; i < end; i++) {
        hash = ((hash ^ text.codeUnitAt(i)) * 0x01000193) & 0xFFFFFFFF;
      }
    }
    return hash;
  }

  /// Number of resident entries.
  @visibleForTesting
  int get debugEntryCount => _cache.length;

  /// Cache hits since process start (or the last [debugClear]).
  @visibleForTesting
  int get debugHits => _hits;

  /// Cache misses since process start (or the last [debugClear]).
  @visibleForTesting
  int get debugMisses => _misses;

  /// LRU evictions since process start (or the last [debugClear]).
  @visibleForTesting
  int get debugEvictions => _evictions;

  /// Oversize-bypass count since process start (or last [debugClear]).
  @visibleForTesting
  int get debugBypasses => _bypasses;

  /// Drops every cached entry and resets counters. Tests only.
  @visibleForTesting
  void debugClear() {
    _cache.clear();
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _bypasses = 0;
  }
}

class _AnsiCacheKey {
  const _AnsiCacheKey(this.length, this.fingerprint, this.style);

  final int length;
  final int fingerprint;
  final TextStyle style;

  @override
  int get hashCode => Object.hash(length, fingerprint, style);

  @override
  bool operator ==(Object other) {
    return other is _AnsiCacheKey &&
        other.length == length &&
        other.fingerprint == fingerprint &&
        other.style == style;
  }
}

class _AnsiCacheEntry {
  const _AnsiCacheEntry(this.source, this.spans);

  final String source;
  final List<TextSpan> spans;
}
