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
Map<String, dynamic> buildOptimisticUserMessage({
  required String localId,
  required String text,
  int? createdAtMs,
}) {
  return <String, dynamic>{
    'id': localId,
    'localId': localId,
    'role': 'user',
    'content': text,
    'text': text,
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

/// Whether [text] is the special `/clear` command (exact match after trim).
bool isClearCommand(String text) => text.trim() == '/clear';

/// Whether [text] starts with a `/loop ` slash command (case-insensitive).
bool isLoopCommand(String text) {
  final t = text.trim().toLowerCase();
  return t == '/loop' || t.startsWith('/loop ');
}
