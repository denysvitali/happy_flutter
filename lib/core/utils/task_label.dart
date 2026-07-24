/// Helpers for wire-supplied task lifecycle labels.
///
/// `system` / `task_started` / `task_progress` / `task_updated` events carry
/// a free-form `description` (or `summary`). For `task_type: local_bash` the
/// CLI puts the **entire shell command** in that field — multi-line heredocs
/// included. Those labels render as a single centered chip in the chat
/// timeline, so they must be flattened and clamped before display or a long
/// command dumps a wall of centered text into the transcript.
library;

/// Maximum characters kept in a task chip label.
const int kMaxTaskLabelChars = 120;

/// Collapses [raw] to a single line and clamps it to [maxChars].
///
/// Whitespace runs (including newlines and indentation) become single
/// spaces; the result is trimmed and suffixed with `…` when truncated.
/// Returns an empty string for blank input.
String compactTaskLabel(String raw, {int maxChars = kMaxTaskLabelChars}) {
  final flattened = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flattened.length <= maxChars) return flattened;
  return '${flattened.substring(0, maxChars).trimRight()}…';
}
