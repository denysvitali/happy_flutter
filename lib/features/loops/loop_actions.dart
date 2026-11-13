import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/utils/snack.dart';

/// Deletes a loop through [LoopOperationsNotifier]: lists hide it at once and
/// the delete syncs in the background. Completes when the daemon answered,
/// reporting failures consistently across loop screens; callers that only
/// need the optimistic UI may leave it unawaited.
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
}) => runLoopOperationWithFeedback(
  ref: ref,
  request: LoopRequest(
    sessionId: sessionId,
    loopId: loopId,
    action: LoopOperationAction.delete,
  ),
  messenger: messenger,
  isMounted: isMounted,
  failureLogMessage: failureLogMessage,
  failureLabel: failureLabel,
  successLabel: successLabel,
  shouldHandleError: shouldHandleError,
);

/// Pauses or resumes a loop through [LoopOperationsNotifier]; lists show the
/// new state at once. Completes when the daemon answered.
Future<void> pauseLoopWithFeedback({
  required WidgetRef ref,
  required ScaffoldMessengerState messenger,
  required bool Function() isMounted,
  required String failureLogMessage,
  required String failureLabel,
  required String sessionId,
  required String loopId,
  required bool paused,
}) => runLoopOperationWithFeedback(
  ref: ref,
  request: LoopRequest(
    sessionId: sessionId,
    loopId: loopId,
    action: paused ? LoopOperationAction.pause : LoopOperationAction.resume,
  ),
  messenger: messenger,
  isMounted: isMounted,
  failureLogMessage: failureLogMessage,
  failureLabel: failureLabel,
);

/// Submits [request] and reports its outcome: [successLabel] on success,
/// `failureLabel: error` on failure. Errors [shouldHandleError] rejects are
/// rethrown (the optimistic overlay is already dropped).
Future<void> runLoopOperationWithFeedback({
  required WidgetRef ref,
  required LoopRequest request,
  required ScaffoldMessengerState messenger,
  required bool Function() isMounted,
  required String failureLogMessage,
  required String failureLabel,
  String? successLabel,
  bool Function(Object error)? shouldHandleError,
}) async {
  final operations = ref.read(loopOperationsNotifierProvider.notifier)
    ..submit(request);
  final settled = await operations.whenSettled(operations.keyOf(request));
  if (settled == null) return;
  if (settled.isSucceeded) {
    if (successLabel != null && isMounted()) messenger.showSnack(successLabel);
    return;
  }
  if (!settled.isFailed) return;
  final error = settled.cause ?? settled.error ?? 'unknown error';
  // A failed record has no overlay; clear it so it cannot linger.
  operations.dismiss(settled.key);
  if (shouldHandleError != null && !shouldHandleError(error)) {
    // Rethrow the original failure (any type) for the caller to classify.
    Error.throwWithStackTrace(error, StackTrace.current);
  }
  logger.warning('$failureLogMessage: $error', error);
  if (!isMounted()) return;
  messenger.showSnack('$failureLabel: $error', tone: SnackTone.error);
}
