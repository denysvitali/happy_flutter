/// In-conversation message search.
///
/// The chat screen keeps a resident window of decrypted message rows whose
/// shapes differ by kind (`text` / `tool-call` / `thinking` / `agent-event` /
/// `error` — see `lib/core/encryption/processors/`). Search only needs the
/// text a user would recognise, so this module flattens each row to a bounded
/// plain-text blob and matches case-insensitively against it.
///
/// Pure on purpose: the UI owns indexing, navigation and highlight state, so
/// the matching rules stay unit-testable without a widget tree.
library;

import 'send/chat_send_coordinator.dart';

/// Upper bound on the flattened text kept per top-level row.
///
/// The index is only built while search is open, but a session can hold a
/// thousand resident rows and tool outputs run to megabytes. Capping keeps
/// both the index memory and the per-keystroke scan bounded; the cap is far
/// above any snippet a user reads.
const int kChatSearchTextBudget = 2000;

/// Characters of context kept on each side of a hit when building a snippet.
const int kChatSearchSnippetRadius = 40;

/// One search hit: the identity key of the *row* to reveal plus a preview.
///
/// [key] is always a top-level row key (`canonicalMessageIdentityKey` of a
/// message the chat list renders), never a nested sidechain child — children
/// render inside their parent row, so that is the row to scroll to.
class ChatSearchMatch {
  const ChatSearchMatch({required this.key, required this.snippet});

  final String key;
  final String snippet;
}

/// Fields whose text a user can see, in the order they are appended.
///
/// Bookkeeping (`id`, `seq`, `uuid`, `localId`, timestamps) is deliberately
/// absent: matching an opaque id would surface hits the user cannot see in
/// the transcript.
const List<String> _kTextFields = [
  'content',
  'text',
  'message',
  'event',
  'input',
  'result',
  'output',
  'error',
  'errorMessage',
  'name',
];

/// Flattens [message] (and the sidechain children rendered inside it) into
/// bounded plain text suitable for substring matching.
String chatMessageSearchText(
  Map<String, dynamic> message, {
  int maxChars = kChatSearchTextBudget,
}) {
  final buffer = StringBuffer();
  _appendSearchText(message, buffer, maxChars, 0);
  return buffer.toString();
}

void _appendSearchText(
  Map<String, dynamic> message,
  StringBuffer buffer,
  int maxChars,
  int depth,
) {
  if (buffer.length >= maxChars) return;

  final kind = message['kind'] as String?;
  // Control rows carry no user-visible prose.
  if (kind == 'model-change') return;

  for (final field in _kTextFields) {
    final value = message[field];
    if (value == null) continue;
    _appendValue(value, buffer, maxChars, depth);
    if (buffer.length >= maxChars) return;
  }

  // Sidechain children are rendered inline under their parent row, so their
  // text belongs to the parent's searchable blob — the parent is what the
  // reveal targets.
  final children = message['children'];
  if (children is List && depth < 4) {
    for (final child in children) {
      if (child is Map<String, dynamic>) {
        _appendSearchText(child, buffer, maxChars, depth + 1);
      }
      if (buffer.length >= maxChars) return;
    }
  }
}

void _appendValue(
  dynamic value,
  StringBuffer buffer,
  int maxChars,
  int depth,
) {
  if (value is String) {
    _appendChunk(value, buffer, maxChars);
    return;
  }
  if (value is List) {
    if (depth >= 6) return;
    for (final item in value) {
      _appendValue(item, buffer, maxChars, depth + 1);
      if (buffer.length >= maxChars) return;
    }
    return;
  }
  if (value is Map) {
    if (depth >= 6) return;
    for (final entry in value.entries) {
      // Nested tool payloads are the interesting part (`input.command`,
      // `result.stdout`, content blocks); the keys themselves are generally
      // not, so only leaf values are appended.
      _appendValue(entry.value, buffer, maxChars, depth + 1);
      if (buffer.length >= maxChars) return;
    }
  }
}

void _appendChunk(String text, StringBuffer buffer, int maxChars) {
  if (text.isEmpty) return;
  final remaining = maxChars - buffer.length;
  if (remaining <= 0) return;
  buffer
    ..write(text.length > remaining ? text.substring(0, remaining) : text)
    ..write('\n');
}

/// One resident row prepared for matching.
///
/// Flattening a row costs a walk over its content, so the chat screen builds
/// this list once per transcript revision while search is open and then runs
/// every keystroke against [lower] with a plain `indexOf`.
class ChatSearchIndexEntry {
  const ChatSearchIndexEntry({
    required this.key,
    required this.text,
    required this.lower,
  });

  /// Canonical identity of the row, as the chat list renders it.
  final String key;

  /// Flattened user-visible text (capped at [kChatSearchTextBudget]).
  final String text;

  /// [text] lowercased once, so matching is allocation-free per keystroke.
  final String lower;
}

/// Prepares [messages] for repeated searching.
List<ChatSearchIndexEntry> buildChatSearchIndex(
  List<Map<String, dynamic>> messages, {
  int maxChars = kChatSearchTextBudget,
}) {
  final entries = <ChatSearchIndexEntry>[];
  for (final message in messages) {
    final text = chatMessageSearchText(message, maxChars: maxChars);
    if (text.isEmpty) continue;
    // Reuse the canonical identity helper so a hit resolves to the same key
    // the chat list renders under — never a second identity scheme.
    final key = canonicalMessageIdentityKey(message);
    if (key.isEmpty) continue;
    entries.add(
      ChatSearchIndexEntry(key: key, text: text, lower: text.toLowerCase()),
    );
  }
  return entries;
}

/// Case-insensitive substring search over a prepared [index].
///
/// Returns one match per row, in transcript order. A row matches once even
/// when the query appears several times; navigation is per-row.
List<ChatSearchMatch> findChatSearchMatches(
  String query, {
  required List<ChatSearchIndexEntry> index,
  int maxMatches = 500,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const <ChatSearchMatch>[];

  final matches = <ChatSearchMatch>[];
  for (final entry in index) {
    if (matches.length >= maxMatches) break;
    final at = entry.lower.indexOf(needle);
    if (at < 0) continue;
    matches.add(
      ChatSearchMatch(
        key: entry.key,
        snippet: buildSearchSnippet(entry.text, at, needle.length),
      ),
    );
  }
  return matches;
}

/// Convenience wrapper for callers that search once (tests, small windows).
List<ChatSearchMatch> searchChatMessages(
  List<Map<String, dynamic>> messages,
  String query, {
  int maxMatches = 500,
}) {
  return findChatSearchMatches(
    query,
    index: buildChatSearchIndex(messages),
    maxMatches: maxMatches,
  );
}

/// Builds a one-line preview around a hit, collapsing whitespace so a match
/// inside a stack trace or a diff does not render as a wall of formatting.
String buildSearchSnippet(String text, int matchIndex, int matchLength) {
  final start = (matchIndex - kChatSearchSnippetRadius).clamp(0, text.length);
  final end = (matchIndex + matchLength + kChatSearchSnippetRadius).clamp(
    0,
    text.length,
  );
  final raw = text.substring(start, end);
  final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final prefix = start > 0 ? '…' : '';
  final suffix = end < text.length ? '…' : '';
  return '$prefix$collapsed$suffix';
}
