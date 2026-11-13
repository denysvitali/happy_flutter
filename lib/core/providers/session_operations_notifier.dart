/// App-local operations on whole sessions (archive, delete), synced to the
/// server in the background on the shared [OperationStore] machine.
///
/// Submitting hides the session at once: archive through sync's optimistic
/// archive set, delete through [SessionsNotifier.optimisticDelete]. A
/// failure restores the row and stays recorded until the user retries or
/// dismisses it (see `OperationFailureListener`). A success needs no
/// overlay, so its record is dropped immediately.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod/riverpod.dart';

import '../api/sessions_api.dart';
import '../models/session.dart';
import '../operations/operation_store.dart';
import '../services/session_archive.dart';
import 'chat_action_notifier.dart';
import 'sessions_notifier.dart';

/// `abort` stops the agent's current turn; the session stays open.
enum SessionOperationAction { archive, delete, abort }

@immutable
class SessionRequest {
  const SessionRequest({
    required this.sessionId,
    required this.action,
    this.session,
    this.reason,
  });

  final String sessionId;
  final SessionOperationAction action;

  /// The row as the user saw it; decides whether a live process is stopped.
  final Session? session;

  /// Diagnostic reason recorded with an abort.
  final String? reason;
}

typedef SessionOperation = Operation<SessionRequest>;

/// Sessions API used by [SessionOperationsNotifier]. Override in tests.
final sessionsApiProvider = Provider<SessionsApi>((ref) => SessionsApi());

class SessionOperationsNotifier extends OperationStore<SessionRequest> {
  @override
  String get logName => 'Session';

  @override
  String keyOf(SessionRequest request) =>
      request.action == SessionOperationAction.abort
      // A Stop never blocks a later archive/delete of the same session.
      ? '${request.sessionId}#abort'
      : request.sessionId;

  SessionsNotifier get _sessions => ref.read(sessionsNotifierProvider.notifier);

  /// Archives [session] in the background; it leaves the list at once.
  bool archive(Session session) => submit(
    SessionRequest(
      sessionId: session.id,
      action: SessionOperationAction.archive,
      session: session,
    ),
  );

  /// Deletes [sessionId] in the background; it leaves the list at once.
  bool delete(String sessionId) => submit(
    SessionRequest(sessionId: sessionId, action: SessionOperationAction.delete),
  );

  /// Stops the agent's current turn in the background.
  bool abort(String sessionId, {required String reason}) => submit(
    SessionRequest(
      sessionId: sessionId,
      action: SessionOperationAction.abort,
      reason: reason,
    ),
  );

  @override
  void onSubmitted(SessionOperation operation) {
    if (operation.request.action == SessionOperationAction.archive) {
      _sessions.hideArchived(operation.key);
    }
  }

  @override
  Future<Object?> perform(SessionRequest request) async {
    switch (request.action) {
      case SessionOperationAction.archive:
        // Stops a Kubernetes pod (keeping its workspace) before the row
        // is archived, then stops any live process and archives it.
        await _sessions.markSessionArchived(request.sessionId, true);
        await archiveSessionStoppingProcess(
          request.sessionId,
          api: ref.read(sessionsApiProvider),
          session: request.session,
        );
      case SessionOperationAction.delete:
        // Hides the row synchronously and restores it on failure.
        if (!await _sessions.optimisticDelete(request.sessionId)) {
          throw const OperationRejected('rejected by server');
        }
      case SessionOperationAction.abort:
        await ref
            .read(chatActionNotifierProvider.notifier)
            .abortSession(request.sessionId, reason: request.reason ?? '');
    }
    return null;
  }

  @override
  void onFailed(SessionOperation operation) {
    if (operation.request.action == SessionOperationAction.archive) {
      _sessions.unhideArchived(operation.key);
    }
  }

  @override
  void onSucceeded(SessionOperation operation) {
    if (operation.request.action != SessionOperationAction.abort) {
      _sessions.loadFromSync();
    }
    dismiss(operation.key);
  }
}

/// Session archive/delete operations recorded this app session, keyed by
/// session id.
final sessionOperationsNotifierProvider =
    NotifierProvider<SessionOperationsNotifier, Map<String, SessionOperation>>(
      SessionOperationsNotifier.new,
    );
