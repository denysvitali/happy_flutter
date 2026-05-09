// GENERATED — DO NOT EDIT.
// Source: spec/message.fsm.yaml
// Run: dart run tools/fsm_codegen.dart
//
// Sealed hierarchy emitted by tools/fsm_codegen.dart for
// item #7 of the architecture overhaul.

// ignore_for_file: public_member_api_docs

sealed class MessageState {
  const MessageState();
  String get localId;
}

final class MessageStateDraft extends MessageState {
  const MessageStateDraft({
    required this.localId,
    required this.text,
  });
  @override
  final String localId;
  final String text;
}

final class MessageStateSending extends MessageState {
  const MessageStateSending({
    required this.localId,
    required this.text,
    this.attempt = 1,
  });
  @override
  final String localId;
  final String text;
  final int attempt;
}

final class MessageStateSent extends MessageState {
  const MessageStateSent({
    required this.localId,
    required this.serverId,
    required this.seq,
  });
  @override
  final String localId;
  final String serverId;
  final int seq;
}

final class MessageStatePending extends MessageState {
  const MessageStatePending({
    required this.localId,
    required this.reason,
  });
  @override
  final String localId;
  final String reason;
}

final class MessageStateFailed extends MessageState {
  const MessageStateFailed({
    required this.localId,
    required this.reason,
    this.attempt = 1,
  });
  @override
  final String localId;
  final String reason;
  final int attempt;
}

final class MessageStateMerged extends MessageState {
  const MessageStateMerged({
    required this.localId,
    required this.serverId,
    required this.seq,
    required this.text,
  });
  @override
  final String localId;
  final String serverId;
  final int seq;
  final String text;
}

abstract final class MessageStateTransitions {
  static MessageStateSending? sendFromDraft(MessageStateDraft from, {
    String? serverId,
    int? seq,
    String? text,
    String? reason,
    int? attempt,
  }) {
    return MessageStateSending(localId: from.localId, text: text ?? '', attempt: attempt ?? 1);
  }

  static MessageStateSent? ackFromSending(MessageStateSending from, {
    String? serverId,
    int? seq,
    String? text,
    String? reason,
    int? attempt,
  }) {
    return MessageStateSent(localId: from.localId, serverId: serverId ?? (throw ArgumentError('serverId required for ack')), seq: seq ?? 0);
  }

  static MessageStateFailed? failFromSending(MessageStateSending from, {
    String? serverId,
    int? seq,
    String? text,
    String? reason,
    int? attempt,
  }) {
    return MessageStateFailed(localId: from.localId, reason: reason ?? 'unknown', attempt: attempt ?? 1);
  }

  static MessageStatePending? pendingFromSending(MessageStateSending from, {
    String? serverId,
    int? seq,
    String? text,
    String? reason,
    int? attempt,
  }) {
    return MessageStatePending(localId: from.localId, reason: reason ?? 'unknown');
  }

  static MessageStateSent? ackFromPending(MessageStatePending from, {
    String? serverId,
    int? seq,
    String? text,
    String? reason,
    int? attempt,
  }) {
    return MessageStateSent(localId: from.localId, serverId: serverId ?? (throw ArgumentError('serverId required for ack')), seq: seq ?? 0);
  }

  static MessageStateFailed? failFromPending(MessageStatePending from, {
    String? serverId,
    int? seq,
    String? text,
    String? reason,
    int? attempt,
  }) {
    return MessageStateFailed(localId: from.localId, reason: reason ?? 'unknown', attempt: attempt ?? 1);
  }

  static MessageStateSending? retryFromFailed(MessageStateFailed from, {
    String? serverId,
    int? seq,
    String? text,
    String? reason,
    int? attempt,
  }) {
    return MessageStateSending(localId: from.localId, text: text ?? '', attempt: attempt ?? 1);
  }

  static MessageStateMerged? mergeFromSent(MessageStateSent from, {
    String? serverId,
    int? seq,
    String? text,
    String? reason,
    int? attempt,
  }) {
    return MessageStateMerged(localId: from.localId, serverId: serverId ?? (throw ArgumentError('serverId required for merge')), seq: seq ?? 0, text: text ?? '');
  }

}
