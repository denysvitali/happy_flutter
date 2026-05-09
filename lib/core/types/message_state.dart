import 'identity_types.dart';

/// Sealed hierarchy describing the *send-state* of a single logical
/// message in the chat list.
///
/// This is the typed counterpart to the loose `'sendStatus'` string
/// used inside the `Map<String, dynamic>` rows in `Sync.sessionMessages`.
/// Adopting this hierarchy at the merge entry point lets the compiler
/// enforce exhaustive transitions:
///
///     draft → sending → (sent | pending | failed) → merged
///
/// The architecture branch is simultaneously introducing a state
/// machine for the same transitions; we deliberately use the same
/// state names so the two branches can converge with minimal merge
/// pain.
sealed class MessageSendState {
  const MessageSendState();

  /// Build a [MessageSendState] from the loose `'sendStatus'` string
  /// historically stored in message maps.  Unknown values map to
  /// [MessageSent] (the conservative default — already-merged server
  /// messages have no `sendStatus` field at all).
  factory MessageSendState.fromWireString(String? raw) {
    switch (raw) {
      case 'sending':
        return const MessageSending();
      case 'pending':
        return const MessagePending();
      case 'failed':
        return const MessageFailed();
      case 'sent':
      case null:
        return const MessageSent();
    }
    return const MessageSent();
  }

  /// String form used in `'sendStatus'` for backwards compatibility
  /// with the existing loose-map representation.
  String get wireString;
}

/// The optimistic message has been inserted locally and the REST
/// request is in flight.
final class MessageSending extends MessageSendState {
  const MessageSending();
  @override
  String get wireString => 'sending';
}

/// REST send failed but the outbox is retrying.
final class MessagePending extends MessageSendState {
  const MessagePending();
  @override
  String get wireString => 'pending';
}

/// All retries exhausted; user-visible failure.
final class MessageFailed extends MessageSendState {
  const MessageFailed();
  @override
  String get wireString => 'failed';
}

/// Server has acknowledged the message (REST 2xx with matching
/// `localId` echoed in the response, or socket inline-message arrival).
final class MessageSent extends MessageSendState {
  const MessageSent();
  @override
  String get wireString => 'sent';
}

/// Identity tuple used at the merge entry point to enforce that we
/// always look at the typed [LocalId] / [ServerMessageId] pair rather
/// than reaching into the underlying loose map.
class MessageIdentity {
  const MessageIdentity({
    required this.serverId,
    this.localId,
  });

  factory MessageIdentity.fromMap(Map<String, dynamic> message) {
    return MessageIdentity(
      serverId: message.serverIdOrNull,
      localId: message.localIdOrNull,
    );
  }

  /// Authoritative server id once assigned.  Null only for transient
  /// optimistic placeholders that have not yet round-tripped.
  final ServerMessageId? serverId;

  /// Client-side identity carried across the entire send/retry/merge
  /// lifecycle.  Empty (`localId.isEmpty`) for pure server messages
  /// (e.g. agent output) — see merge logic in
  /// `_sync_messaging_merge.dart`.
  final LocalId? localId;

  /// Whether this identity carries a non-empty [LocalId].  Used by
  /// the merge logic to decide whether localId-based replacement is
  /// applicable.
  bool get hasLocalId => localId != null && localId!.isNotEmpty;
}
