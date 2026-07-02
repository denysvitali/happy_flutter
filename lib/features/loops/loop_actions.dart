import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;

/// Deletes a loop and reports failures consistently across loop screens.
Future<void> deleteLoopWithFeedback({
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
  required bool Function() isMounted,
  required String logSource,
  required String failureLabel,
  required String sessionId,
  required String loopId,
}) async {
  try {
    await ref
        .read(loopsNotifierProvider.notifier)
        .deleteLoop(sessionId: sessionId, loopId: loopId);
  } catch (e, st) {
    logger.warning('$logSource delete failed: $e', e, st);
    if (!isMounted()) return;
    messenger.showSnackBar(SnackBar(content: Text('$failureLabel: $e')));
  }
}
