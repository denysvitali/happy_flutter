/// Isolate-per-session actor protocol (item #4 of the architecture
/// overhaul).
///
/// Why
/// ---
/// The current Sync singleton runs *every* session's encryption,
/// merge, and reactivity work on the main isolate. A single
/// pathological session (very large message buffer, slow decrypt
/// pass) blocks every other session and the UI itself.
///
/// Goal
/// ----
/// Move per-session state behind an actor message boundary so each
/// session can — eventually — run on its own isolate. This commit
/// only ships the protocol and a single-isolate consumer; turning
/// every session into a real `Isolate.spawn` is the follow-up.
///
/// Protocol
/// --------
///   * Inbound (host -> actor):  [SessionInbound] sealed family
///   * Outbound (actor -> host): [SessionOutbound] sealed family
///   * Message bus is a `SendPort` pair created by the host. Messages
///     are JSON-encodable so they survive `Isolate.spawn`.
///
/// Migration path
/// --------------
///   1. Land this protocol + single-isolate harness (this commit).
///   2. Wire one session's lifecycle (e.g. ChatScreen's active
///      session) through [SessionActorHost.dispatch] instead of
///      Sync directly.
///   3. Replace [InProcessSessionActor] with `Isolate.spawn` of
///      `_actorEntryPoint` and an explicit error supervisor.
///   4. Roll out to all sessions; retire the in-process variant.
library;

import 'dart:async';

/// Inbound messages — what the host (UI / Sync) tells the actor.
sealed class SessionInbound {
  const SessionInbound();
  Map<String, Object?> toJson();
}

class StartActor extends SessionInbound {
  const StartActor({required this.sessionId});
  final String sessionId;
  @override
  Map<String, Object?> toJson() =>
      {'kind': 'start', 'sessionId': sessionId};
}

class SendUserMessage extends SessionInbound {
  const SendUserMessage({
    required this.sessionId,
    required this.localId,
    required this.text,
  });
  final String sessionId;
  final String localId;
  final String text;
  @override
  Map<String, Object?> toJson() => {
        'kind': 'send',
        'sessionId': sessionId,
        'localId': localId,
        'text': text,
      };
}

class IngestServerMessage extends SessionInbound {
  const IngestServerMessage({
    required this.sessionId,
    required this.localId,
    required this.serverId,
    required this.seq,
  });
  final String sessionId;
  final String localId;
  final String serverId;
  final int seq;
  @override
  Map<String, Object?> toJson() => {
        'kind': 'ingest',
        'sessionId': sessionId,
        'localId': localId,
        'serverId': serverId,
        'seq': seq,
      };
}

class StopActor extends SessionInbound {
  const StopActor({required this.sessionId});
  final String sessionId;
  @override
  Map<String, Object?> toJson() =>
      {'kind': 'stop', 'sessionId': sessionId};
}

/// Outbound messages — what the actor tells the host.
sealed class SessionOutbound {
  const SessionOutbound();
}

class ActorReady extends SessionOutbound {
  const ActorReady({required this.sessionId});
  final String sessionId;
}

class MessageProjected extends SessionOutbound {
  const MessageProjected({
    required this.sessionId,
    required this.localId,
    required this.state,
  });
  final String sessionId;
  final String localId;
  final String state;
}

class ActorStopped extends SessionOutbound {
  const ActorStopped({required this.sessionId});
  final String sessionId;
}

/// Single-isolate proof-of-concept consumer. Same protocol as the
/// future cross-isolate variant but no `SendPort` round-trip.
abstract class SessionActor {
  Future<void> handle(SessionInbound message);
  Stream<SessionOutbound> get outbound;
  Future<void> dispose();
}

/// Reference implementation: applies inbound messages to an internal
/// state map and emits projection updates. The future
/// [IsolateSessionActor] will run this exact loop in `Isolate.spawn`.
class InProcessSessionActor implements SessionActor {
  final _outbound = StreamController<SessionOutbound>.broadcast();
  final Map<String, String> _projected = {}; // localId -> state

  @override
  Stream<SessionOutbound> get outbound => _outbound.stream;

  @override
  Future<void> handle(SessionInbound message) async {
    switch (message) {
      case StartActor(:final sessionId):
        _outbound.add(ActorReady(sessionId: sessionId));
      case SendUserMessage(:final sessionId, :final localId):
        _projected[localId] = 'sending';
        _outbound.add(MessageProjected(
          sessionId: sessionId,
          localId: localId,
          state: 'sending',
        ));
      case IngestServerMessage(:final sessionId, :final localId):
        _projected[localId] = 'merged';
        _outbound.add(MessageProjected(
          sessionId: sessionId,
          localId: localId,
          state: 'merged',
        ));
      case StopActor(:final sessionId):
        _outbound.add(ActorStopped(sessionId: sessionId));
    }
  }

  Map<String, String> get projection => Map.unmodifiable(_projected);

  @override
  Future<void> dispose() async {
    await _outbound.close();
  }
}

/// Host-side dispatcher. The host owns one [SessionActor] per
/// sessionId; `dispatch` is the public entry point that the rest of
/// the codebase will call once we move ChatScreen behind this actor
/// boundary.
class SessionActorHost {
  SessionActorHost(this._spawn);

  final SessionActor Function() _spawn;
  final Map<String, SessionActor> _actors = {};
  final _outbound = StreamController<SessionOutbound>.broadcast();
  final Map<String, StreamSubscription<SessionOutbound>> _subs = {};

  Stream<SessionOutbound> get outbound => _outbound.stream;

  SessionActor _ensureActor(String sessionId) {
    final existing = _actors[sessionId];
    if (existing != null) return existing;
    final actor = _spawn();
    _actors[sessionId] = actor;
    _subs[sessionId] = actor.outbound.listen(_outbound.add);
    return actor;
  }

  Future<void> dispatch(SessionInbound message) async {
    final sessionId = switch (message) {
      StartActor(:final sessionId) => sessionId,
      SendUserMessage(:final sessionId) => sessionId,
      IngestServerMessage(:final sessionId) => sessionId,
      StopActor(:final sessionId) => sessionId,
    };
    final actor = _ensureActor(sessionId);
    await actor.handle(message);
    if (message is StopActor) {
      await _subs.remove(sessionId)?.cancel();
      await _actors.remove(sessionId)?.dispose();
    }
  }

  Future<void> dispose() async {
    for (final sub in _subs.values) {
      await sub.cancel();
    }
    for (final actor in _actors.values) {
      await actor.dispose();
    }
    _actors.clear();
    _subs.clear();
    await _outbound.close();
  }
}
