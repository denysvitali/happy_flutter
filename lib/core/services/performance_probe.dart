import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kProfileMode;
import 'package:flutter/painting.dart' show PaintingBinding;

import 'sync_service.dart';

/// Count-only probe on the authenticated VM service, never a release endpoint.
/// The memory capture script reads this instead of requiring a custom metrics
/// executable. It exposes no account/session identifiers or message bodies.
void registerPerformanceProbe() {
  if (!kProfileMode) return;
  developer.registerExtension('ext.happy.performanceMetrics', (_, _) async {
    if (!sync.isInitialized || !sync.isEncryptionInitialized) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        jsonEncode({'message': 'Sync metrics are not ready'}),
      );
    }
    return developer.ServiceExtensionResponse.result(
      jsonEncode({
        'image_cache_bytes':
            PaintingBinding.instance.imageCache.currentSizeBytes,
        'encryption_cache_bytes':
            sync.encryption.cache.getStats()['retainedBytes'] ?? 0,
        'resident_rows': sync.residentMessageRowCount,
        // Catalog-backed sessions with at least one resident message window.
        'resident_sessions': sync.sessionsView.keys
            .where((id) => sync.messagesForSession(id).isNotEmpty)
            .length,
      }),
    );
  });
}
