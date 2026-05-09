/// Event-sourced local log (item #1 of the architecture overhaul).
///
/// This is a *behind-the-flag* implementation that turns the current
/// imperative merge loop in `_sync_messaging_merge.dart` into a pure
/// projection over an append-only, lamport-keyed event log.
///
/// Goals
/// -----
///   * Every wire fact (REST page, socket echo, optimistic placeholder,
///     ack, retry) becomes an immutable [MessageEvent] keyed by
///     `(sessionId, lamport)`.
///   * The visible message list is a pure function of the events:
///     [MessageProjection.project] never mutates anything — it folds
///     the log into a `Map<localId, ProjectedMessage>`.
///   * `localId` becomes structurally canonical: it's the aggregate
///     key in the projection.  No content-similarity heuristics,
///     no list-position guesses.
///
/// Storage backend
/// ---------------
/// The contract here is [EventLogStore] — currently implemented by
/// [InMemoryEventLogStore] only.  A SQLite/WAL backend can drop in
/// behind the same interface; we deliberately avoided the sqflite
/// dependency in this scaffold to keep the diff small and CI green
/// across web + native.  The file format used by [JsonlEventLogStore]
/// is a stand-in newline-delimited JSON layout that maps 1:1 onto a
/// future `events(session_id, lamport, kind, payload)` table.
///
/// Activation flag
/// ---------------
/// Production code paths only consult this module when [kUseEventLog]
/// is `true`.  The flag defaults to `false` (see `event_log_flag.dart`)
/// so production behavior is unchanged; tests flip it on.
library;

import 'dart:async';
import 'dart:convert';

/// The canonical kinds of facts the message merge needs to observe.
///
/// New kinds can be added freely — the projection treats unknown kinds
/// as no-ops, which lets us stage rollouts.
enum MessageEventKind {
  /// User tapped Send. The optimistic row was created. Payload:
  ///   { localId, role, text, createdAt }
  optimisticAppended,

  /// REST POST returned a server-assigned id for our localId. Payload:
  ///   { localId, serverId, seq, content }
  serverAcked,

  /// Socket pushed a message we don't yet have. Payload:
  ///   { localId, serverId, seq, content }
  socketObserved,

  /// REST GET /messages page. Payload:
  ///   { localId, serverId, seq, content }
  fetchedFromServer,

  /// User tapped retry on a failed send (preserves localId). Payload:
  ///   { localId }
  retryRequested,

  /// Outbox / network gave up. Payload:
  ///   { localId, reason }
  sendFailed,
}

/// One immutable fact in the log. The (sessionId, lamport) pair is the
/// primary key. Lamport is a monotonic counter scoped to the session,
/// minted by [EventLog.append].
class MessageEvent {
  const MessageEvent({
    required this.sessionId,
    required this.lamport,
    required this.kind,
    required this.payload,
    required this.recordedAt,
  });

  final String sessionId;
  final int lamport;
  final MessageEventKind kind;
  final Map<String, Object?> payload;
  final int recordedAt;

  String? get localId => payload['localId'] as String?;
  String? get serverId => payload['serverId'] as String?;

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'lamport': lamport,
        'kind': kind.name,
        'payload': payload,
        'recordedAt': recordedAt,
      };

  static MessageEvent fromJson(Map<String, Object?> json) {
    final kindName = json['kind'] as String;
    final kind = MessageEventKind.values
        .firstWhere((e) => e.name == kindName, orElse: () {
      throw StateError('Unknown MessageEventKind: $kindName');
    });
    return MessageEvent(
      sessionId: json['sessionId'] as String,
      lamport: json['lamport'] as int,
      kind: kind,
      payload: Map<String, Object?>.from(
        json['payload'] as Map<dynamic, dynamic>,
      ),
      recordedAt: json['recordedAt'] as int,
    );
  }
}

/// Persistence contract. The in-memory implementation below is enough
/// for tests and for a no-op production rollout. A SQLite-backed impl
/// can satisfy the same interface.
abstract class EventLogStore {
  Future<void> append(MessageEvent event);

  /// Returns events for [sessionId] ordered by lamport ascending.
  Future<List<MessageEvent>> read(String sessionId);

  /// Wipes a single session — used on `deleteSession`.
  Future<void> truncate(String sessionId);

  /// Wipes everything — used on logout.
  Future<void> clear();
}

class InMemoryEventLogStore implements EventLogStore {
  final Map<String, List<MessageEvent>> _bySession = {};

  @override
  Future<void> append(MessageEvent event) async {
    final list = _bySession.putIfAbsent(event.sessionId, () => []);
    list.add(event);
  }

  @override
  Future<List<MessageEvent>> read(String sessionId) async =>
      List.unmodifiable(_bySession[sessionId] ?? const []);

  @override
  Future<void> truncate(String sessionId) async {
    _bySession.remove(sessionId);
  }

  @override
  Future<void> clear() async {
    _bySession.clear();
  }
}

/// Newline-delimited JSON store. One file per session would be the
/// natural mapping, but the contract is in-memory until a real disk
/// backend lands. We keep the encoder usable so callers can ship an
/// individual session log to support without a SQLite tool.
class JsonlEventLogStore implements EventLogStore {
  JsonlEventLogStore();

  final Map<String, List<MessageEvent>> _bySession = {};

  @override
  Future<void> append(MessageEvent event) async {
    final list = _bySession.putIfAbsent(event.sessionId, () => []);
    list.add(event);
  }

  @override
  Future<List<MessageEvent>> read(String sessionId) async =>
      List.unmodifiable(_bySession[sessionId] ?? const []);

  @override
  Future<void> truncate(String sessionId) async {
    _bySession.remove(sessionId);
  }

  @override
  Future<void> clear() async {
    _bySession.clear();
  }

  /// Encodes [sessionId]'s log to a single JSONL string. Useful for
  /// support exports while we don't yet have a SQLite UI.
  String encodeSession(String sessionId) {
    final events = _bySession[sessionId] ?? const [];
    return events.map(jsonEncode).join('\n');
  }
}

/// Public facade. Owns the lamport counter per session and broadcasts
/// projection-invalidation events so notifiers can `loadFromSync`.
class EventLog {
  EventLog(this._store);

  final EventLogStore _store;
  final Map<String, int> _lamports = {};
  final StreamController<String> _changesController =
      StreamController<String>.broadcast();

  /// Fires the [sessionId] whose log just changed. The projection is
  /// pure; subscribers should re-fold on demand.
  Stream<String> get onSessionChanged => _changesController.stream;

  Future<MessageEvent> append({
    required String sessionId,
    required MessageEventKind kind,
    required Map<String, Object?> payload,
    int? recordedAt,
  }) async {
    final next = (_lamports[sessionId] ?? 0) + 1;
    _lamports[sessionId] = next;
    final event = MessageEvent(
      sessionId: sessionId,
      lamport: next,
      kind: kind,
      payload: Map<String, Object?>.from(payload),
      recordedAt: recordedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    await _store.append(event);
    if (!_changesController.isClosed) {
      _changesController.add(sessionId);
    }
    return event;
  }

  Future<List<MessageEvent>> events(String sessionId) =>
      _store.read(sessionId);

  Future<void> truncate(String sessionId) async {
    _lamports.remove(sessionId);
    await _store.truncate(sessionId);
    if (!_changesController.isClosed) {
      _changesController.add(sessionId);
    }
  }

  Future<void> clear() async {
    _lamports.clear();
    await _store.clear();
  }

  Future<void> dispose() async {
    await _changesController.close();
  }
}
