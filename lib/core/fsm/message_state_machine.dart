/// Adopts the generated [MessageState] sealed hierarchy as the
/// canonical lifecycle for messages flowing through the merge entry
/// point.
///
/// This intentionally duplicates a *small slice* of the merge logic
/// in `_sync_messaging_merge.dart` (`draft → sending → sent/failed`)
/// so we can prove the codegen output is wired in without rewriting
/// the entire ~5,800 LoC merge engine in one go.
///
/// The intended migration path:
///
///   1. The reliability branch lands its localId-canonicalisation
///      changes in `_sync_messaging_merge.dart`.
///   2. We then replace the bag-of-maps message representation in
///      `Sync._sessionMessages` with `Map<String, MessageState>`.
///   3. The merge entry point becomes `apply(state, event)` over the
///      sealed hierarchy emitted at `lib/core/fsm/message_state.g.dart`.
library;

import '../event_log/event_log.dart';
import 'message_state.g.dart';

class MessageStateMachine {
  final Map<String, MessageState> _states = {};

  Map<String, MessageState> get snapshot => Map.unmodifiable(_states);

  MessageState? stateFor(String localId) => _states[localId];

  /// Applies a single [MessageEvent] to the state machine. This is
  /// the analog of one iteration of the merge loop, narrowed to the
  /// events the FSM understands. Unsupported events are silently
  /// ignored so the codegen can grow without breaking callers.
  void apply(MessageEvent event) {
    final localId = event.localId;
    if (localId == null) return;
    final current = _states[localId];

    switch (event.kind) {
      case MessageEventKind.optimisticAppended:
        if (current == null) {
          _states[localId] = MessageStateSending(
            localId: localId,
            text: (event.payload['text'] as String?) ?? '',
          );
        }
      case MessageEventKind.serverAcked:
      case MessageEventKind.fetchedFromServer:
      case MessageEventKind.socketObserved:
        final serverId = (event.payload['serverId'] as String?) ?? '';
        final seq = (event.payload['seq'] as int?) ?? 0;
        final text = (event.payload['content'] as String?) ??
            _textOfCurrent(current);
        if (current is MessageStateSending) {
          final sent = MessageStateTransitions.ackFromSending(
            current,
            serverId: serverId,
            seq: seq,
          )!;
          _states[localId] = MessageStateMerged(
            localId: sent.localId,
            serverId: sent.serverId,
            seq: sent.seq,
            text: text,
          );
        } else if (current is MessageStatePending) {
          final sent = MessageStateTransitions.ackFromPending(
            current,
            serverId: serverId,
            seq: seq,
          )!;
          _states[localId] = MessageStateMerged(
            localId: sent.localId,
            serverId: sent.serverId,
            seq: sent.seq,
            text: text,
          );
        } else {
          _states[localId] = MessageStateMerged(
            localId: localId,
            serverId: serverId,
            seq: seq,
            text: text,
          );
        }
      case MessageEventKind.sendFailed:
        final reason = (event.payload['reason'] as String?) ?? 'unknown';
        if (current is MessageStateSending) {
          _states[localId] = MessageStateTransitions.failFromSending(
            current,
            reason: reason,
          )!;
        } else if (current is MessageStatePending) {
          _states[localId] = MessageStateTransitions.failFromPending(
            current,
            reason: reason,
          )!;
        } else if (current == null) {
          _states[localId] = MessageStateFailed(
            localId: localId,
            reason: reason,
          );
        }
      case MessageEventKind.retryRequested:
        if (current is MessageStateFailed) {
          _states[localId] = MessageStateTransitions.retryFromFailed(
            current,
            text: '',
            attempt: current.attempt + 1,
          )!;
        }
    }
  }

  String _textOfCurrent(MessageState? s) {
    return switch (s) {
      MessageStateSending(:final text) => text,
      MessageStateMerged(:final text) => text,
      MessageStateDraft(:final text) => text,
      _ => '',
    };
  }
}
