/// Helpers for wire-supplied task lifecycle labels.
///
/// `system` / `task_started` / `task_progress` / `task_updated` events carry
/// a free-form `description` (or `summary`). For `task_type: local_bash` the
/// CLI puts the **entire shell command** in that field — multi-line heredocs
/// included. Those labels render as a single centered chip in the chat
/// timeline, so they must be flattened and clamped before display or a long
/// command dumps a wall of centered text into the transcript.
library;

import 'package:characters/characters.dart';

/// Maximum characters kept in a task chip label.
const int kMaxTaskLabelChars = 120;

/// Collapses [raw] to a single line and clamps it to [maxChars].
///
/// Whitespace runs (including newlines and indentation) become single
/// spaces; the result is trimmed and suffixed with `…` when truncated.
/// Returns an empty string for blank input.
String compactTaskLabel(String raw, {int maxChars = kMaxTaskLabelChars}) {
  final flattened = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Grapheme-safe. This field is free-form CLI text and for `local_bash` it
  // is the whole shell command, so it can contain emoji and other non-BMP
  // characters. A UTF-16 cut through a surrogate pair leaves a lone
  // surrogate, which the text layout rejects with
  // `string is not well-formed UTF-16` — see text_truncate.dart.
  final characters = flattened.characters;
  if (characters.length <= maxChars) return flattened;
  return '${characters.take(maxChars).toString().trimRight()}…';
}
