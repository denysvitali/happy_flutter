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
  await runLoopActionWithFeedback(
    action: () => ref
        .read(loopsNotifierProvider.notifier)
        .deleteLoop(sessionId: sessionId, loopId: loopId),
    messenger: messenger,
    isMounted: isMounted,
    failureLogMessage: failureLogMessage,
    failureLabel: failureLabel,
    successLabel: successLabel,
    shouldHandleError: shouldHandleError,
  );
}

/// Pauses or resumes a loop and reports failures consistently.
Future<void> pauseLoopWithFeedback({
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
  required bool Function() isMounted,
  required String failureLogMessage,
  required String failureLabel,
  required String sessionId,
  required String loopId,
  required bool paused,
}) async {
  await runLoopActionWithFeedback(
    action: () => ref
        .read(loopsNotifierProvider.notifier)
        .pauseLoop(sessionId: sessionId, loopId: loopId, paused: paused),
    messenger: messenger,
    isMounted: isMounted,
    failureLogMessage: failureLogMessage,
    failureLabel: failureLabel,
  );
}

/// Runs a loop mutation and reports failures consistently across loop screens.
Future<void> runLoopActionWithFeedback({
  required Future<void> Function() action,
  required ScaffoldMessengerState messenger,
  required bool Function() isMounted,
  required String failureLogMessage,
  required String failureLabel,
  String? successLabel,
  bool Function(Object error)? shouldHandleError,
}) async {
  try {
    await action();
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
