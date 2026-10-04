import '../../core/wire/wire_parsers.dart';

/// Child configuration reported by the agent thread, never parent defaults.
class AgentPresentation {
  const AgentPresentation({
    required this.isNativeCodex,
    required this.metadata,
    this.model,
    this.parentModel,
    this.role,
    this.metadataObservedAt,
  });

  final bool isNativeCodex;
  final Map<String, dynamic> metadata;
  final String? model;
  final String? parentModel;
  final String? role;
  final num? metadataObservedAt;

  String? get nickname => _text(metadata['nickname']);
  String? get effort => _text(metadata['reasoningEffort']);
  String? get source => _text(metadata['source']);
  String? get threadStatus => _text(metadata['status']);

  String get sandboxLabel => switch (_text(metadata['effectiveSandbox'])) {
    'read-only' => 'Read only',
    'workspace-write' => 'Workspace writes',
    'danger-full-access' => 'Full access',
    final String value => value,
    _ => 'Not reported',
  };

  String get approvalLabel => switch (_text(metadata['approvalPolicy'])) {
    'never' => 'Never ask',
    'on-request' => 'When requested',
    'on-failure' => 'After failure',
    'untrusted' => 'For untrusted commands',
    final String value => value,
    _ => 'Not reported',
  };

  String? get overview => [role, model].whereType<String>().join(' · ').isEmpty
      ? null
      : [role, model].whereType<String>().join(' · ');

  static AgentPresentation fromMessage(Map<String, dynamic>? message) {
    final input = WireParsers.asMap(message?['input']);
    final type = _text(input?['subagent_type']);
    final isNative = type == 'codex' || type == 'codex-agent';
    final metadata = <String, dynamic>{};
    num? observedAt;
    void snapshot(dynamic value, {dynamic timestamp}) {
      final map = WireParsers.asMap(value);
      if (map == null) return;
      final nextTime = timestamp is num ? timestamp : null;
      if (observedAt != null && nextTime != null && nextTime < observedAt!) {
        return;
      }
      // Present maps are authoritative, including an empty invalidation.
      metadata
        ..clear()
        ..addAll(map);
      observedAt = nextTime;
    }

    snapshot(input?['agentMetadata'], timestamp: message?['createdAt']);
    if (message?['_taskEventSynthetic'] != true) {
      snapshot(
        message?['agentMetadata'],
        timestamp:
            message?['_agentMetadataObservedAt'] ?? message?['createdAt'],
      );
    }
    final children = WireParsers.asList(message?['children']) ?? const [];
    for (final child in children) {
      final childMap = WireParsers.asMap(child);
      if (childMap == null) continue;
      // A nested Agent's configuration describes the grandchild.
      if (['Agent', 'Task', 'Workflow'].contains(childMap['name'])) continue;
      snapshot(
        childMap['agentMetadata'],
        timestamp:
            childMap['_agentMetadataObservedAt'] ?? childMap['createdAt'],
      );
    }
    snapshot(
      WireParsers.asMap(message?['result'])?['agentMetadata'],
      timestamp: message?['completedAt'],
    );
    if (message?['_taskEventSynthetic'] == true) {
      snapshot(
        message?['agentMetadata'],
        timestamp: message?['_agentMetadataObservedAt'],
      );
    }
    final legacyMetadata = WireParsers.asMap(message?['metadata']);
    return AgentPresentation(
      isNativeCodex: isNative,
      metadata: Map<String, dynamic>.unmodifiable(metadata),
      model: isNative
          ? _text(metadata['model'])
          : (_text(input?['model']) ??
                _text(legacyMetadata?['model']) ??
                children
                    .map(WireParsers.asMap)
                    .map((c) => _text(c?['model']))
                    .whereType<String>()
                    .firstOrNull),
      parentModel: isNative ? null : _text(message?['model']),
      role: isNative ? _text(metadata['role']) : type,
      metadataObservedAt: observedAt,
    );
  }
}

String? _text(dynamic value) =>
    value is String && value.trim().isNotEmpty ? value : null;
