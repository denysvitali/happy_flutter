import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;

/// Deletes a loop and reports failures consistently across loop screens.
Future<void> deleteLoopWithFeedback({
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
  required bool Function() isMounted,
  required String failureLogMessage,
  required String failureLabel,
  required String sessionId,
  required String loopId,
  String? successLabel,
  bool Function(Object error)? shouldHandleError,
}) async {
  try {
    await ref
        .read(loopsNotifierProvider.notifier)
        .deleteLoop(sessionId: sessionId, loopId: loopId);
    if (successLabel != null && isMounted()) {
      messenger.showSnackBar(SnackBar(content: Text(successLabel)));
    }
  } catch (e, st) {
    if (shouldHandleError != null && !shouldHandleError(e)) rethrow;
    logger.warning('$failureLogMessage: $e', e, st);
    if (!isMounted()) return;
    messenger.showSnackBar(SnackBar(content: Text('$failureLabel: $e')));
  }
}
