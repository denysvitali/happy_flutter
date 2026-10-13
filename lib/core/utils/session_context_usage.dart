import 'model_context_window.dart';

/// Context snapshots describe occupancy; cumulative billing counters do not.
Map<String, dynamic> reduceSessionUsage(
  Map<String, dynamic>? existing,
  Map<String, dynamic> usage,
  int timestamp, {
  int? seq,
}) {
  final existingTimestamp = existing?['timestamp'];
  final sequence = seq != null && seq > 0 ? seq : null;
  final existingSequence = existing?['seq'];
  if (sequence != null && existingSequence is int && existingSequence > 0) {
    // Server sequence survives shared timestamps and wall-clock adjustments.
    if (sequence <= existingSequence) return existing!;
  } else if (existingTimestamp is int && timestamp <= existingTimestamp) {
    return existing!;
  }
  final input = _tokenCount(usage['input_tokens']) ?? 0;
  final output = _tokenCount(usage['output_tokens']) ?? 0;
  final cacheCreation = _tokenCount(usage['cache_creation_input_tokens']) ?? 0;
  final cacheRead = _tokenCount(usage['cache_read_input_tokens']) ?? 0;
  final explicitContext =
      usage['source'] == 'prime-agent-daemon' ||
      usage.containsKey('context_size') ||
      usage.containsKey('context_window');
  final window = _tokenCount(usage['context_window']);
  return {
    'inputTokens': input,
    'outputTokens': output,
    'cacheCreation': cacheCreation,
    'cacheRead': cacheRead,
    'totalTokens': _tokenCount(usage['total_tokens']),
    'contextSize': explicitContext
        ? _tokenCount(usage['context_size'])
        : input + cacheCreation + cacheRead,
    'contextWindow': window != null && window > 0 ? window : null,
    'contextModel': usage['model'] is String ? usage['model'] : null,
    'contextProvider': usage['provider'] is String ? usage['provider'] : null,
    'contextIsExplicit': explicitContext,
    'contextIsEstimate': usage['context_is_estimate'] == true,
    'usageSource': usage['source'],
    'timestamp': timestamp,
    'seq': ?sequence,
  };
}

/// Use Prime's fresh, matching snapshot; retain legacy provider defaults.
({int? contextSize, int? contextWindow}) projectSessionContext({
  required Map<String, dynamic> usage,
  required String? flavor,
  String? currentModel,
  String? selectedModel,
  int? fallbackWindow,
}) {
  final isPrime = flavor == 'prime-agent';
  if (isPrime) {
    if (usage['usageSource'] != 'prime-agent-daemon' ||
        usage['contextIsExplicit'] != true) {
      return (contextSize: null, contextWindow: null);
    }
    final reportedModel = _modelLeaf(usage['contextModel']);
    final reportedProvider = usage['contextProvider'];
    for (final candidate in [currentModel, selectedModel]) {
      final expectedModel = _modelLeaf(candidate);
      if (expectedModel != null && expectedModel != reportedModel) {
        return (contextSize: null, contextWindow: null);
      }
      final expectedProvider = _providerRoute(candidate);
      if (expectedProvider != null && expectedProvider != reportedProvider) {
        return (contextSize: null, contextWindow: null);
      }
    }
  }
  final contextSize = _tokenCount(usage['contextSize']);
  final reportedWindow = _tokenCount(usage['contextWindow']);
  return (
    contextSize: contextSize,
    contextWindow: reportedWindow != null && reportedWindow > 0
        ? reportedWindow
        : isPrime
        ? null
        : fallbackWindow,
  );
}

int? _tokenCount(dynamic value) {
  if (value is! num || !value.isFinite || value < 0 || value % 1 != 0) {
    return null;
  }
  return value.toInt();
}

String? _modelLeaf(dynamic raw) {
  if (raw is! String) return null;
  final key = modelContextKey(raw);
  if (key == null || key == 'default') return null;
  return key.split('/').last;
}

String? _providerRoute(String? raw) {
  final key = modelContextKey(raw);
  if (key == null) return null;
  final slash = key.lastIndexOf('/');
  return slash > 0 ? key.substring(0, slash) : null;
}
