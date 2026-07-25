/// Pure helpers for the chat send path.
///
/// Owns optimistic-row shape and fail-by-`localId` patching so
/// `_sendMessage` and pass-through paths cannot drift. Identity
/// invariants stay here:
/// - one `localId` minted by the caller (via ChatActionNotifier)
/// - optimistic row uses same value for `id` and `localId`
/// - fail/retry only match by `localId` (or equal `id` fallback)
library;

/// Builds the optimistic user message map for an in-flight send.
///
/// [localId] must already be the canonical client identity that will
/// also be passed as `clientLocalId` to [Sync.sendMessage].
///
/// [imageBlocks], when provided, are Anthropic image content blocks
/// (from `OutgoingImage.toContentBlock()`). They land in a `raw` map so
/// the bubble can render the staged images immediately, matching the
/// shape Sync's own optimistic row and server-decoded rows carry.
Map<String, dynamic> buildOptimisticUserMessage({
  required String localId,
  required String text,
  int? createdAtMs,
  List<Map<String, dynamic>>? imageBlocks,
}) {
  final displayText = text.isNotEmpty
      ? text
      : (imageBlocks != null && imageBlocks.isNotEmpty ? '[image]' : text);
  return <String, dynamic>{
    'id': localId,
    'localId': localId,
    'role': 'user',
    'content': displayText,
    'text': displayText,
    if (imageBlocks != null && imageBlocks.isNotEmpty)
      'raw': <String, dynamic>{
        'role': 'user',
        'content': <Map<String, dynamic>>[
          if (text.isNotEmpty) <String, dynamic>{'type': 'text', 'text': text},
          ...imageBlocks,
        ],
      },
    'createdAt': createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
    'seq': -1,
    'sendStatus': 'sending',
  };
}

/// Returns a new list with the message matching [localId] marked failed.
///
/// Match order: `localId` field, then `id` field (both equal on optimistic
/// inserts). If no row matches, returns the original list unchanged.
List<Map<String, dynamic>> markOptimisticMessageFailed(
  List<Map<String, dynamic>> messages,
  String localId,
) {
  final idx = messages.indexWhere(
    (m) => m['localId'] == localId || m['id'] == localId,
  );
  if (idx == -1) return messages;
  return [
    ...messages.sublist(0, idx),
    {...messages[idx], 'sendStatus': 'failed'},
    ...messages.sublist(idx + 1),
  ];
}

/// Returns a new list with the still-`'sending'` message matching
/// [localId] escalated to `'pending'` ("Retry queued").
///
/// Used by the send-stall watchdog: a message that has been in flight for
/// several seconds is indistinguishable from a fast send except by how
/// long the spinner spins. Rows that already reached a terminal state
/// (`'sent'`, `'failed'`) or that are already `'pending'` are left alone,
/// and the original list is returned unchanged when nothing matches — so
/// the caller can skip the rebuild.
List<Map<String, dynamic>> markOptimisticMessageStalled(
  List<Map<String, dynamic>> messages,
  String localId,
) {
  final idx = messages.indexWhere(
    (m) =>
        (m['localId'] == localId || m['id'] == localId) &&
        m['sendStatus'] == 'sending',
  );
  if (idx == -1) return messages;
  return [
    ...messages.sublist(0, idx),
    {...messages[idx], 'sendStatus': 'pending'},
    ...messages.sublist(idx + 1),
  ];
}

/// Whether [text] is the special `/clear` command (exact match after trim).
bool isClearCommand(String text) => text.trim() == '/clear';

/// Whether [text] starts with a `/loop ` slash command (case-insensitive).
bool isLoopCommand(String text) {
  final t = text.trim().toLowerCase();
  return t == '/loop' || t.startsWith('/loop ');
}
