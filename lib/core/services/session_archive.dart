import '../api/sessions_api.dart';
import '../models/session.dart';
import 'logger_service.dart' show logger;
import 'sync_service.dart';

/// Whether an agent process currently owns [session].
bool sessionHasLiveProcess(Session session) =>
    session.presence == 'online' || session.active;

/// Archives a session the user chose to close.
///
/// A session is archived exactly when no process owns it: the server reopens
/// an archived session as soon as a live process heartbeats again. Archiving
/// a live session therefore stops its process first. A failed stop is logged
/// and the archive still proceeds; the server keeps the row open while the
/// process lives, which is the truthful state.
Future<void> archiveSessionStoppingProcess(
  String sessionId, {
  required SessionsApi api,
  Session? session,
  Future<void> Function(String sessionId)? stopProcess,
}) async {
  final current = session ?? sync.sessions[sessionId];
  if (current != null && sessionHasLiveProcess(current)) {
    try {
      await (stopProcess ?? _stopViaDaemon)(sessionId);
    } catch (e, st) {
      logger.warning(
        'Archive: failed to stop live process for session $sessionId',
        e,
        st,
      );
    }
  }
  await api.setSessionArchived(sessionId, true);
}

Future<void> _stopViaDaemon(String sessionId) async {
  await sync.stopSessionProcess(sessionId);
}
