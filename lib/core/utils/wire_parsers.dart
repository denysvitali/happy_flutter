/// Lenient parsers for wire values coming from different server variants.
///
/// Some backends emit numeric fields as numbers, others as numeric strings.
/// These helpers normalize both shapes.
class WireParsers {
  const WireParsers._();

  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(trimmed);
      if (asDouble != null) return asDouble.toInt();
    }
    return null;
  }

  static bool? parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
          return true;
        case 'false':
        case '0':
          return false;
      }
    }
    return null;
  }

  static String? parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Safely cast a dynamic value to `Map<String, dynamic>?`.
  ///
  /// Returns `null` when the value is not a Map (e.g. a List or a
  /// String). This prevents `TypeError` crashes from hard
  /// `as Map<String, dynamic>?` casts on unexpected wire shapes.
  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Safely cast a dynamic value to `List<dynamic>?`.
  ///
  /// Returns `null` when the value is not a List.
  static List<dynamic>? asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return null;
  }

  /// Safely cast a dynamic value to `List<String>?`.
  ///
  /// Filters out non-string entries rather than throwing.
  static List<String>? asStringList(dynamic value) {
    final list = asList(value);
    if (list == null) return null;
    return list.whereType<String>().toList(growable: false);
  }

  // ── Sidechain anchor detection ──────────────────────────────────────
  //
  // Centralized so the isolate decrypt pipeline (message_processor.dart)
  // and the live-ingest pipeline (_sync_messaging_parse_output.dart) agree
  // on a single definition. See GlitchTip HAPPY_FLUTTER-3C9.

  static const _parentToolUseIdKeys = [
    'parent_tool_use_id',
    'parentToolUseId',
    'parent_toolUseId',
    // task_started / task_progress / task_notification carry the spawning
    // Agent tool_use id as `tool_use_id` (no parent_* form exists there).
    'tool_use_id',
  ];

  static const _agentIdKeys = ['agentId', 'agent_id', 'task_id'];

  static String? _firstNonEmptyString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// The spawning Agent/Task tool_use id, or `null` when absent.
  static String? sidechainParentToolUseId(Map<String, dynamic> data) =>
      _firstNonEmptyString(data, _parentToolUseIdKeys);

  /// The SDK-assigned agent id (async background agents), or `null`.
  static String? sidechainAgentId(Map<String, dynamic> data) =>
      _firstNonEmptyString(data, _agentIdKeys);

  /// Whether the payload carries the raw `isSidechain` / `is_sidechain` flag.
  ///
  /// This is the metadata-stage definition shared by both decrypt pipelines
  /// (message_processor.dart and _sync_messaging_parse_output.dart). The flag
  /// is propagated verbatim so the downstream grouper can stitch sub-agent
  /// transcripts via the `parentUuid` chain even for intermediate messages
  /// (meta/unrendered events) that carry no tool-use/agent anchor of their
  /// own. See GlitchTip HAPPY_FLUTTER-3C9.
  static bool isRawSidechain(Map<String, dynamic> data) =>
      data['isSidechain'] == true || data['is_sidechain'] == true;
}
