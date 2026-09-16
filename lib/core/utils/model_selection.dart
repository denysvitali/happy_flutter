/// Effort levels accepted by Claude Code's `--effort` flag.
const claudeModelEfforts = ['low', 'medium', 'high', 'xhigh', 'max'];

/// Strip only a recognized terminal effort, preserving provider variants.
String stripModelEffortSuffix(String raw, Iterable<String> efforts) {
  final idx = raw.lastIndexOf(':');
  if (idx <= 0 || idx == raw.length - 1) return raw;
  return efforts.contains(raw.substring(idx + 1)) ? raw.substring(0, idx) : raw;
}

/// Provider routing uses model IDs, not CLI effort/context selections.
String normalizeProviderModelSelection(String selection) {
  var model = selection.trim();
  if (model.endsWith('[1m]')) {
    model = model.substring(0, model.length - '[1m]'.length);
  }
  return stripModelEffortSuffix(model, claudeModelEfforts);
}
