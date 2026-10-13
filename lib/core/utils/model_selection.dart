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

/// Prime Agent effort is a separate ACP option, not part of its model ID.
({String? model, String? effort}) splitPrimeAgentModelSelection(String? raw) {
  if (raw == null || raw == 'default') return (model: null, effort: null);
  const efforts = {'off', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max'};
  final model = stripModelEffortSuffix(raw, efforts);
  return (
    model: model,
    effort: model == raw ? null : raw.substring(model.length + 1),
  );
}

String? primeAgentModelSelection(String? model, String? effort) =>
    model == null || model.isEmpty
    ? null
    : effort == null || effort.isEmpty
    ? model
    : '$model:$effort';

/// Build the same configuration metadata for send, failed prep, and Retry.
Map<String, dynamic> messageModelMetadata(
  String? modelMode,
  String? flavor, {
  Iterable<String>? opencodeModels,
}) {
  if (flavor == 'opencode') {
    return {
      'model':
          modelMode != 'default' && opencodeModels?.contains(modelMode) == true
          ? modelMode
          : null,
    };
  }
  if (flavor == 'prime-agent') {
    final selection = splitPrimeAgentModelSelection(modelMode);
    return {'model': selection.model, 'reasoning_effort': selection.effort};
  }
  return {'model': modelMode == 'default' ? null : modelMode};
}
