/// Pure helpers for turning a raw wire model id into something a human
/// can read in the transcript.
///
/// The per-message `model` reported by Claude Code is the real inference
/// model id (`claude-opus-4-5-20251101`, `gpt-5-codex`, …), not the
/// user-facing label picked in the composer. Rendering it verbatim in a
/// divider is noisy, so it is compacted to `Opus 4.5` / `GPT 5 Codex`.
library;

/// Segments that carry no information for a reader.
const _droppedSegments = {'latest', 'preview', 'v1', 'v2'};

/// Human-readable label for a raw wire model id.
///
/// Falls back to the trimmed input whenever the shape is unrecognized —
/// an unknown provider string is still more useful than an empty label.
String modelDisplayName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  // `anthropic/claude-opus-4-5` and `openrouter/openai/gpt-5` — the
  // routing prefix is noise once the family name survives.
  final withoutProvider = trimmed.split('/').last;

  final segments = withoutProvider
      .split('-')
      .where((s) => s.isNotEmpty)
      .where((s) => !_droppedSegments.contains(s.toLowerCase()))
      // Trailing release dates (`20251101`) are not part of the name.
      .where((s) => !_isReleaseDate(s))
      .toList(growable: false);
  if (segments.isEmpty) return trimmed;

  final isClaude = segments.first.toLowerCase() == 'claude';
  final named = isClaude ? segments.sublist(1) : segments;
  if (named.isEmpty) return trimmed;

  // Segment order is kept: Anthropic puts the version on either side of
  // the family (`claude-3-5-sonnet` → "3.5 Sonnet", `claude-opus-4-5` →
  // "Opus 4.5") and both read the way the model is marketed. Adjacent
  // numeric segments are a dotted version, not separate words.
  final words = <String>[];
  final versionRun = <String>[];
  void flushVersion() {
    if (versionRun.isEmpty) return;
    words.add(versionRun.join('.'));
    versionRun.clear();
  }

  for (final segment in named) {
    if (_isNumeric(segment)) {
      versionRun.add(segment);
    } else {
      flushVersion();
      words.add(_capitalize(segment));
    }
  }
  flushVersion();

  return words.isEmpty ? trimmed : words.join(' ');
}

bool _isNumeric(String value) => int.tryParse(value) != null;

/// `20251101` — eight digits is a release stamp, not a version number.
bool _isReleaseDate(String value) =>
    value.length == 8 && int.tryParse(value) != null;

String _capitalize(String value) {
  final upper = value.toUpperCase();
  // Acronym families read wrong in title case (`Gpt`, `Llm`).
  if (upper == 'GPT' || upper == 'GLM' || upper == 'LLM') return upper;
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
