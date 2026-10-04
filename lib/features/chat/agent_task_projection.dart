import '../../core/wire/wire_parsers.dart';

import 'agent_presentation.dart';

String? _taskEventDescription(Map<String, dynamic> msg) {
  final event = WireParsers.asMap(msg['event']);
  final eventMessage = event?['message'] as String?;
  if (eventMessage != null && eventMessage.isNotEmpty) {
    return eventMessage;
  }
  final content = msg['content'] as String?;
  if (content != null && content.isNotEmpty) {
    return content;
  }
  return null;
}

class AgentTaskEventProjection {
  AgentTaskEventProjection({required this.agentId});

  final String agentId;
  String state = 'running';
  String? description;
  String? taskType;
  String? subagentType;
  String? parentToolUseId;
  Map<String, dynamic>? agentMetadata;
  num? metadataObservedAt;

  void merge(Map<String, dynamic> msg) {
    final nextMetadata = WireParsers.asMap(msg['agentMetadata']);
    if (nextMetadata != null) {
      final timestamp = msg['_agentMetadataObservedAt'] ?? msg['createdAt'];
      final nextObservedAt = timestamp is num ? timestamp : null;
      if (metadataObservedAt == null ||
          nextObservedAt == null ||
          nextObservedAt >= metadataObservedAt!) {
        agentMetadata = Map.of(nextMetadata);
        metadataObservedAt = nextObservedAt;
      }
    }
    final status = msg['taskStatus'] as String?;
    if (status == 'completed') {
      state = 'completed';
    } else if (status == 'failed') {
      state = 'error';
    } else if (state != 'completed' && state != 'error') {
      state = 'running';
    }

    final nextDescription = _taskEventDescription(msg);
    if (nextDescription != null && nextDescription.isNotEmpty) {
      description = nextDescription;
    }

    final nextTaskType = msg['taskType'] as String?;
    if (nextTaskType != null && nextTaskType.isNotEmpty) {
      taskType = nextTaskType;
    }

    final nextSubagentType = msg['subagentType'] as String?;
    if (nextSubagentType != null && nextSubagentType.isNotEmpty) {
      subagentType = nextSubagentType;
    }

    final nextParentToolUseId = msg['parentToolUseId'] as String?;
    if (nextParentToolUseId != null && nextParentToolUseId.isNotEmpty) {
      parentToolUseId = nextParentToolUseId;
    }
  }

  Map<String, dynamic> toAgentMap() => <String, dynamic>{
    'id': 'task-event-$agentId',
    'toolUseId': parentToolUseId ?? agentId,
    'agentId': agentId,
    'kind': 'tool-call',
    'name': 'Agent',
    'state': state,
    '_taskEventSynthetic': true,
    'agentMetadata': ?agentMetadata,
    '_agentMetadataObservedAt': ?metadataObservedAt,
    if (parentToolUseId != null) '_taskEventParentToolUseId': parentToolUseId,
    'input': <String, dynamic>{
      'description': description ?? agentId,
      'subagent_type': ?(subagentType ?? taskType),
      'run_in_background': true,
      'agentMetadata': ?agentMetadata,
    },
  };
}

/// Preserve the latest known child snapshot in a task lifecycle projection.
Map<String, dynamic> buildAgentTaskEventProjection(
  AgentTaskEventProjection agent,
  Map<String, dynamic>? anchor,
) {
  final synthetic = agent.toAgentMap();
  if (anchor == null) return synthetic;
  final anchorInput = WireParsers.asMap(anchor['input']);
  final details = AgentPresentation.fromMessage(anchor);
  return <String, dynamic>{
    ...anchor,
    ...synthetic,
    'agentMetadata': agent.agentMetadata ?? details.metadata,
    '_agentMetadataObservedAt': agent.agentMetadata != null
        ? agent.metadataObservedAt
        : details.metadataObservedAt,
    'input': <String, dynamic>{
      ...?anchorInput,
      ...?WireParsers.asMap(synthetic['input']),
      if (details.isNativeCodex) 'subagent_type': 'codex',
      'agentMetadata': agent.agentMetadata ?? details.metadata,
    },
  };
}
