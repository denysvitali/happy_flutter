/// Actionable outcome of retrying a failed user message.
enum MessageRetryOutcome {
  queued,
  sessionUnavailable,
  messageNotFound,
  rawDataUnavailable,
  attachmentDataUnavailable,
  encryptionUnavailable,
  encryptionFailed,
}

/// Typed result returned by the retry boundary instead of a silent no-op.
final class MessageRetryResult {
  const MessageRetryResult(this.outcome);

  final MessageRetryOutcome outcome;

  bool get isQueued => outcome == MessageRetryOutcome.queued;
}
