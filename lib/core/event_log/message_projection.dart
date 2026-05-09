/// Pure projection of [MessageEvent]s into the visible message list.
///
/// This is the meat of item #1: instead of the imperative merge in
/// `_sync_messaging_merge.dart` (~1000 LoC of conditional logic), we
/// fold the event log left-to-right into a `Map<localId, ProjectedMessage>`
/// and return its values sorted by `(seq ?? createdAt, lamport)`.
///
/// Rules
/// -----
///   * `localId` is canonical: events that share a localId merge into
///     one [ProjectedMessage].
///   * The first server fact (ack / fetch / socket) for a localId
///     promotes the projection from `optimistic` to `merged`.
///   * `retryRequested` flips state back to `sending`, preserving
///     the localId (I4 of spec/messaging.tla).
///   * `sendFailed` flips to `failed`. Subsequent retry events flip
///     back to `sending`.
///   * Unknown event kinds are no-ops.
library;

import 'event_log.dart';

enum ProjectedState {
  sending,
  failed,
  merged,
}

class ProjectedMessage {
  ProjectedMessage({
    required this.localId,
    required this.state,
    this.serverId,
    this.seq,
    this.role,
    this.text,
    this.createdAt,
    this.lastLamport = 0,
  });

  String localId;
  ProjectedState state;
  String? serverId;
  int? seq;
  String? role;
  String? text;
  int? createdAt;
  int lastLamport;

  ProjectedMessage copy() => ProjectedMessage(
        localId: localId,
        state: state,
        serverId: serverId,
        seq: seq,
        role: role,
        text: text,
        createdAt: createdAt,
        lastLamport: lastLamport,
      );
}

class MessageProjection {
  /// Folds a session's [events] into a deterministic ordered list of
  /// [ProjectedMessage]s.
  static List<ProjectedMessage> project(List<MessageEvent> events) {
    final byLocal = <String, ProjectedMessage>{};
    for (final event in events) {
      final localId = event.localId;
      if (localId == null) continue;
      final existing = byLocal[localId];
      switch (event.kind) {
        case MessageEventKind.optimisticAppended:
          if (existing == null) {
            byLocal[localId] = ProjectedMessage(
              localId: localId,
              state: ProjectedState.sending,
              role: event.payload['role'] as String?,
              text: event.payload['text'] as String?,
              createdAt: event.payload['createdAt'] as int?,
              lastLamport: event.lamport,
            );
          } else {
            existing.lastLamport = event.lamport;
          }
        case MessageEventKind.serverAcked:
        case MessageEventKind.fetchedFromServer:
        case MessageEventKind.socketObserved:
          final base = existing ??
              ProjectedMessage(
                localId: localId,
                state: ProjectedState.sending,
              );
          base.state = ProjectedState.merged;
          base.serverId =
              (event.payload['serverId'] as String?) ?? base.serverId;
          base.seq = (event.payload['seq'] as int?) ?? base.seq;
          base.text = (event.payload['content'] as String?) ?? base.text;
          base.lastLamport = event.lamport;
          byLocal[localId] = base;
        case MessageEventKind.retryRequested:
          if (existing != null && existing.state != ProjectedState.merged) {
            existing.state = ProjectedState.sending;
            existing.lastLamport = event.lamport;
          }
        case MessageEventKind.sendFailed:
          if (existing != null && existing.state != ProjectedState.merged) {
            existing.state = ProjectedState.failed;
            existing.lastLamport = event.lamport;
          }
      }
    }

    final result = byLocal.values.toList()
      ..sort((a, b) {
        final sa = a.seq;
        final sb = b.seq;
        if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
        if (sa != null && sb == null) return -1;
        if (sa == null && sb != null) return 1;
        final ca = a.createdAt ?? 0;
        final cb = b.createdAt ?? 0;
        if (ca != cb) return ca.compareTo(cb);
        return a.lastLamport.compareTo(b.lastLamport);
      });
    return result;
  }
}
