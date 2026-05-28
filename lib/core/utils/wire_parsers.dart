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
  static bool isRawSidechain(Map<String, dynamic> data) =>
      data['isSidechain'] == true || data['is_sidechain'] == true;

  /// Whether a sidechain payload carries a real anchor (parent tool-use id
  /// or agent id) the grouper can attach it to.
  static bool hasSidechainAnchor(Map<String, dynamic> data) =>
      sidechainParentToolUseId(data) != null ||
      sidechainAgentId(data) != null;

  /// Effective sidechain flag after stripping an SDK misclassification:
  /// when the orchestrator emits multiple Agent/Task tool_use blocks in one
  /// assistant turn, the CLI flags the 2nd..Nth as `isSidechain: true` even
  /// though they belong to the top-level orchestrator (no parent_tool_use_id,
  /// no agentId/task_id). Without an anchor the sidechain grouper can never
  /// attach them, so they become hidden orphans and only the first Agent card
  /// renders. Treating anchorless sidechain payloads as top-level keeps the
  /// remaining Agent cards visible while preserving real sub-agent sidechains,
  /// which always carry an anchor.
  static bool isEffectiveSidechain(Map<String, dynamic> data) =>
      isRawSidechain(data) && hasSidechainAnchor(data);
}
