import 'package:flutter/painting.dart' show PaintingBinding;

import '../../platform_io.dart'
    if (dart.library.js_interop) '../../platform_stub.dart';
import '../utils/performance_buckets.dart';
import 'opentelemetry_service.dart';
import 'performance_context_service.dart';
import 'sync_service.dart';

/// Samples process memory and its attributable parts once per frame-metrics
/// window: RSS, the decoded-image cache, the EncryptionCache and resident
/// transcript rows. RSS says how much; the other gauges say where.
class MemoryMetricsSampler {
  /// Boundaries for the `app.memory.rss_mb` histogram. RSS of a Flutter
  /// app spans ~150 MB (fresh launch) to 1 GB+ (pathological); the top
  /// buckets exist to make runaway growth visible, not to be healthy.
  static const List<double> _rssMbBuckets = [
    128,
    192,
    256,
    320,
    384,
    448,
    512,
    640,
    768,
    1024,
    1536,
    2048,
  ];

  /// Boundaries for `app.memory.image_cache_mb`. The decoded-image cache is
  /// the classic silent hoarder: inline base64 chat images decode at full
  /// resolution and stay pinned until eviction pressure. Production RSS
  /// p95 sits near 2 GB at large session counts — if this gauge does not
  /// move with it, images are ruled out as the driver.
  static const List<double> _imageCacheMbBuckets = [
    8,
    16,
    32,
    64,
    96,
    128,
    192,
    256,
    384,
    512,
  ];

  /// Boundaries for `app.memory.encryption_cache_mb`. The cache's own byte
  /// budgets sum to ~19 MB (agent state 4 + metadata 2 + messages 8 +
  /// machine metadata 1 + daemon state 4); buckets resolve below that cap
  /// and expose a breach past it.
  static const List<double> _encryptionCacheMbBuckets = [
    1,
    2,
    4,
    8,
    12,
    16,
    20,
    32,
    64,
  ];

  /// Boundaries for `app.memory.resident_rows`: decrypted transcript rows
  /// held in memory. Full residency is capped at 8 sessions x 200 rows plus
  /// 25-row previews for the rest of the catalog, so the healthy ceiling
  /// scales with catalog size; the top buckets name runaway retention.
  static const List<double> _residentRowsBuckets = [
    100,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  /// Test-only override for the EncryptionCache byte total. Production code
  /// must never set this; null falls through to
  /// [_encryptionCacheRetainedBytes].
  int? Function()? debugEncryptionRetainedBytes;

  /// Best-effort read of the EncryptionCache byte budgets. [Sync] only
  /// holds an encryption instance after a successful login, so pre-auth
  /// windows have nothing retained — that emits an explicit zero, it
  /// is not an error. Sampling telemetry must never throw out of a flush.
  int _encryptionCacheRetainedBytes() {
    final override = debugEncryptionRetainedBytes;
    if (override != null) return override() ?? 0;
    if (!sync.isEncryptionInitialized) return 0;
    return sync.encryption.cache.getStats()['retainedBytes'] ?? 0;
  }

  /// Record every memory gauge for the current window. RSS is gated on > 0
  /// because 0 means unsupported (web); every attribution gauge rides the
  /// same gate so a high-RSS launch can be decomposed on the same window.
  void sample() {
    final rssBytes = currentRssBytes;
    if (rssBytes > 0) {
      final attributes = <String, Object>{
        'current_route': PerformanceContextService().currentRoute ?? 'unknown',
        'session_count_bucket': collectionSizeBucket(sync.sessionCount),
      };
      OpenTelemetryService().recordValue(
        'app.memory.rss_mb',
        rssBytes / (1024 * 1024),
        unit: 'MB',
        boundaries: _rssMbBuckets,
        attributes: attributes,
        description:
            'Process resident set size sampled once per metrics window — '
            'quantile this per build to see progressive heap growth',
      );
      // The pinned runtime has no supported release-mode Dart heap/external
      // counters. Emit explicit unavailable zeros, never infer them from RSS.
      for (final name in ['dart_heap', 'dart_external']) {
        OpenTelemetryService().recordValue(
          'app.memory.${name}_mb',
          0,
          unit: 'MB',
          boundaries: _rssMbBuckets,
          attributes: attributes,
          description:
              'Dart $name memory per metrics window; '
              'zero means unavailable on this runtime, not measured usage',
        );
      }
      // RSS says how much; these say where.
      final imageCacheBytes =
          PaintingBinding.instance.imageCache.currentSizeBytes;
      OpenTelemetryService().recordValue(
        'app.memory.image_cache_mb',
        imageCacheBytes / (1024 * 1024),
        unit: 'MB',
        boundaries: _imageCacheMbBuckets,
        attributes: attributes,
        description:
            'Decoded-image cache bytes sampled once per metrics window — '
            'attributes the RSS signal to inline chat images or rules '
            'images out',
      );
      final encryptionRetainedBytes = _encryptionCacheRetainedBytes();
      OpenTelemetryService().recordValue(
        'app.memory.encryption_cache_mb',
        encryptionRetainedBytes / (1024 * 1024),
        unit: 'MB',
        boundaries: _encryptionCacheMbBuckets,
        attributes: attributes,
        description:
            'EncryptionCache retained bytes sampled once per metrics '
            'window; zero before login',
      );
      OpenTelemetryService().recordValue(
        'app.memory.resident_rows',
        sync.residentMessageRowCount.toDouble(),
        unit: '{rows}',
        boundaries: _residentRowsBuckets,
        attributes: attributes,
        description:
            'Decrypted transcript rows resident across all sessions — '
            'the residency budget should keep this flat as the catalog '
            'grows',
      );
    }
  }
}
