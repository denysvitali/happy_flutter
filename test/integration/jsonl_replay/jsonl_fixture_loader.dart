// Loads real Claude Code .jsonl transcripts from the local machine and
// converts each line into the wire shape that
// `processDecryptedMessages` consumes.
//
// Transcripts live at ~/.claude/projects/<encoded-path>/<sessionId>.jsonl
// with sidechain sub-agent files under
// ~/.claude/projects/<encoded-path>/<sessionId>/subagents/agent-*.jsonl
//
// This loader is intentionally kept out of production code — tests that
// rely on these fixtures must guard on [FixtureBundle.isAvailable] so CI
// (and any machine without local transcripts) skips gracefully.
library;

import 'dart:convert';
import 'dart:io';

/// One parsed line from a .jsonl transcript plus the wire envelope that
/// the Flutter parser expects to receive after decryption.
class JsonlLine {
  JsonlLine({
    required this.raw,
    required this.wireMessage,
    required this.plaintext,
  });

  /// The raw JSON object from the .jsonl file, unchanged.
  final Map<String, dynamic> raw;

  /// Wire envelope — the entry that goes into `wireMessages`.
  final Map<String, dynamic> wireMessage;

  /// Plaintext content — the entry that goes into `decryptedJsonList`.
  final Map<String, dynamic>? plaintext;

  String get type => raw['type'] as String? ?? '';
  bool get isSidechain => raw['isSidechain'] == true;
  bool get isForwarded => plaintext != null;
}

/// Types that Claude Code writes to .jsonl but happy-cli-go does not
/// forward to the server. Tests must not count these as "expected
/// rendered messages" because they never reach the Flutter parser.
const Set<String> cliLocalTypes = {
  'attachment',
  'last-prompt',
  'queue-operation',
  'ai-title',
};

const Set<String> _taskLifecycleSubtypes = {
  'task_started',
  'task_progress',
  'task_updated',
  'task_notification',
};

const Set<String> _terminalTaskStatuses = {'completed', 'failed', 'stopped'};

/// Wraps one raw .jsonl object in the `{role, content: {type, data}}`
/// envelope produced by happy-cli-go. Returns `null` for CLI-local
/// types that are never forwarded.
Map<String, dynamic>? wrapJsonlLine(Map<String, dynamic> raw) {
  return _DaemonFixtureWrapper().wrap(raw);
}

class _TaskLifecycleRef {
  String? toolUseId;
  String? taskType;
  String? workflowName;
}

class _DaemonFixtureWrapper {
  final _taskRefsById = <String, _TaskLifecycleRef>{};
  final _toolUseIdToParentRef = <String, String>{};
  final _sidechainLastUuid = <String, String>{};
  var _uuidSeq = 0;
  String? _lastUuid;

  Map<String, dynamic>? wrap(Map<String, dynamic> raw) {
    final type = raw['type'] as String? ?? '';
    if (cliLocalTypes.contains(type)) return null;

    final data = _deepCopyMap(raw);

    if (type == 'assistant') {
      if (!_filterAssistantContent(data)) return null;
      _recordToolUses(data);
      _stamp(data, type: type, isMeta: false);
      return _envelope(data);
    }

    if (type == 'user') {
      _recordAsyncTaskLaunch(data);
      _stamp(
        data,
        type: type,
        isMeta: false,
        sidechainToolUseId: _toolResultUseId(data),
      );
      return _envelope(data);
    }

    if (type == 'system') {
      final subtype = data['subtype'] as String? ?? '';
      if (subtype == 'thinking_tokens') return null;

      String? toolUseId;
      if (_taskLifecycleSubtypes.contains(subtype)) {
        toolUseId = _enrichTaskLifecycle(data);
      }

      // happy-cli-go enriches task_progress for state tracking, then drops
      // it before forwarding because it is high-volume progress noise.
      if (subtype == 'task_progress') return null;

      _stamp(
        data,
        type: type,
        subtype: subtype,
        isMeta: true,
        sidechainToolUseId: toolUseId,
      );
      return _envelope(data);
    }

    if (type == 'tool_progress') {
      _stamp(
        data,
        type: type,
        isMeta: true,
        sidechainToolUseId: _firstString(data, const [
          'parent_tool_use_id',
          'parentToolUseId',
          'tool_use_id',
        ]),
      );
      return _envelope(data);
    }

    if (type == 'result' ||
        type == 'error' ||
        type == 'rate_limit_event' ||
        type == 'auth_status' ||
        type == 'prompt_suggestion' ||
        type == 'tool_use_summary') {
      _stamp(data, type: type, isMeta: true);
      return _envelope(data);
    }

    _stamp(data, type: type, isMeta: false);
    return _envelope(data);
  }

  void _recordToolUses(Map<String, dynamic> data) {
    final message = _asMap(data['message']);
    final content = _asList(message?['content']);
    if (content == null) return;

    for (final block in content) {
      final item = _asMap(block);
      if (item == null || item['type'] != 'tool_use') continue;
      final toolUseId = item['id'] as String?;
      if (toolUseId == null || toolUseId.isEmpty) continue;
      _toolUseIdToParentRef[toolUseId] = toolUseId;
    }
  }

  bool _filterAssistantContent(Map<String, dynamic> data) {
    final message = _asMap(data['message']);
    final content = _asList(message?['content']);
    if (message == null || content == null) return true;

    final filtered = <dynamic>[];
    for (final block in content) {
      final item = _asMap(block);
      if (item != null && item['type'] == 'redacted_thinking') continue;
      filtered.add(block);
    }
    message['content'] = filtered;
    return filtered.isNotEmpty;
  }

  void _recordAsyncTaskLaunch(Map<String, dynamic> data) {
    final launch = _asMap(data['tool_use_result']);
    if (launch == null) return;

    final status = launch['status'] as String?;
    final isAsync = launch['isAsync'] == true;
    if (status != 'async_launched' && !isAsync) return;

    final taskId = _firstString(launch, const ['taskId', 'task_id']);
    final toolUseId = _toolResultUseId(data);
    if (taskId == null || toolUseId == null) return;

    final ref = _taskRefsById.putIfAbsent(taskId, () => _TaskLifecycleRef());
    final existingTaskType = ref.taskType;
    final existingWorkflowName = ref.workflowName;
    ref
      ..toolUseId = toolUseId
      ..taskType =
          _firstString(launch, const ['taskType', 'task_type']) ??
          existingTaskType
      ..workflowName =
          _firstString(launch, const ['workflowName', 'workflow_name']) ??
          existingWorkflowName;
  }

  String? _enrichTaskLifecycle(Map<String, dynamic> data) {
    final taskId = data['task_id'] as String?;
    var toolUseId = data['tool_use_id'] as String?;
    var taskType = data['task_type'] as String?;
    var workflowName = data['workflow_name'] as String?;
    if (taskId == null || taskId.isEmpty) return toolUseId;

    final ref = _taskRefsById.putIfAbsent(taskId, () => _TaskLifecycleRef());
    final existingToolUseId = ref.toolUseId;
    final existingTaskType = ref.taskType;
    final existingWorkflowName = ref.workflowName;
    ref
      ..toolUseId = toolUseId ?? existingToolUseId
      ..taskType = taskType ?? existingTaskType
      ..workflowName = workflowName ?? existingWorkflowName;

    toolUseId ??= ref.toolUseId;
    taskType ??= ref.taskType;
    workflowName ??= ref.workflowName;

    if (toolUseId != null && toolUseId.isNotEmpty) {
      data['tool_use_id'] = toolUseId;
    }
    if (taskType != null && taskType.isNotEmpty) {
      data['task_type'] = taskType;
    }
    if (workflowName != null && workflowName.isNotEmpty) {
      data['workflow_name'] = workflowName;
    }
    return toolUseId;
  }

  void _stamp(
    Map<String, dynamic> data, {
    required String type,
    required bool isMeta,
    String? subtype,
    String? sidechainToolUseId,
  }) {
    final uuid = _nextUuid();
    dynamic parentUuid;
    var isSidechain = false;

    if (sidechainToolUseId != null && sidechainToolUseId.isNotEmpty) {
      isSidechain = true;
      parentUuid =
          _sidechainLastUuid[sidechainToolUseId] ??
          _toolUseIdToParentRef[sidechainToolUseId] ??
          sidechainToolUseId;
      if (type == 'user' && !_isTerminalTaskStatus(data)) {
        _sidechainLastUuid[sidechainToolUseId] = uuid;
      }
    } else {
      parentUuid = _lastUuid;
    }

    data['uuid'] = uuid;
    if (parentUuid != null) data['parentUuid'] = parentUuid;
    data['isSidechain'] = isSidechain;
    data['userType'] = 'external';
    data['isMeta'] = isMeta;
    data['timestamp'] ??= DateTime.fromMillisecondsSinceEpoch(
      _parseTimestamp(data['timestamp']),
    ).toUtc().toIso8601String();

    if (type == 'assistant' && !isSidechain) {
      _lastUuid = uuid;
    } else if (type == 'user' && !isSidechain) {
      _lastUuid = uuid;
    } else if (type == 'system' &&
        (subtype == 'init' || subtype == 'session_state_changed')) {
      _lastUuid = uuid;
    }
  }

  String _nextUuid() =>
      'fixture_uuid_${(_uuidSeq++).toString().padLeft(6, '0')}';

  Map<String, dynamic> _envelope(Map<String, dynamic> data) {
    return <String, dynamic>{
      'role': 'agent',
      'content': <String, dynamic>{'type': 'output', 'data': data},
    };
  }
}

Map<String, dynamic> _deepCopyMap(Map<String, dynamic> value) {
  return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic>? _asList(dynamic value) {
  if (value is List<dynamic>) return value;
  if (value is List) return List<dynamic>.from(value);
  return null;
}

String? _firstString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

String? _toolResultUseId(Map<String, dynamic> data) {
  final message = _asMap(data['message']);
  final content = _asList(message?['content']);
  if (content == null) return null;

  for (final block in content) {
    final item = _asMap(block);
    if (item == null || item['type'] != 'tool_result') continue;
    final toolUseId = item['tool_use_id'] as String?;
    if (toolUseId != null && toolUseId.isNotEmpty) return toolUseId;
  }
  return null;
}

bool _isTerminalTaskStatus(Map<String, dynamic> data) {
  final status = data['status'] as String?;
  return status != null && _terminalTaskStatuses.contains(status);
}

/// Loads and wraps every line of a .jsonl file.
List<JsonlLine> loadJsonl(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final lines = file.readAsLinesSync();
  final out = <JsonlLine>[];
  final wrapper = _DaemonFixtureWrapper();
  var seq = 0;
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final decoded = jsonDecode(line);
    if (decoded is! Map<String, dynamic>) continue;
    final plaintext = wrapper.wrap(decoded);
    final createdAt = _parseTimestamp(decoded['timestamp']);
    final wire = <String, dynamic>{
      'id': 'fx_${seq.toString().padLeft(6, '0')}',
      'seq': seq,
      'createdAt': createdAt,
      // Not base64 — the fake path writes plaintext directly.
      'content': plaintext,
    };
    out.add(JsonlLine(raw: decoded, wireMessage: wire, plaintext: plaintext));
    seq++;
  }
  return out;
}

int _parseTimestamp(dynamic raw) {
  if (raw is int) return raw;
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.millisecondsSinceEpoch;
  }
  return 0;
}

/// A bundle of fixture paths for a single Claude Code session — the main
/// transcript plus any sidechain sub-agent files under `subagents/`.
class FixtureBundle {
  FixtureBundle({
    required this.label,
    required this.mainPath,
    required this.sidechainPaths,
  });

  final String label;
  final String mainPath;
  final List<String> sidechainPaths;

  bool get isAvailable => File(mainPath).existsSync();

  /// All lines from the main transcript.
  List<JsonlLine> loadMain() => loadJsonl(mainPath);

  /// All lines from every sidechain file, flattened.
  List<JsonlLine> loadSidechains() {
    final out = <JsonlLine>[];
    for (final p in sidechainPaths) {
      out.addAll(loadJsonl(p));
    }
    return out;
  }

  /// Known-good bundles used by the contract tests.
  static FixtureBundle happyFlutterInterrupts() {
    const base =
        '/home/workspace/.claude/projects/-home-workspace-git-happy-flutter';
    return FixtureBundle(
      label: 'happy_flutter interrupts + api errors',
      mainPath: '$base/0d2a4f91-7969-4c04-9c22-62bce4319308.jsonl',
      sidechainPaths: const [],
    );
  }

  static FixtureBundle gpsTrackerSidechain() {
    const base =
        '/home/workspace/.claude/projects/-home-workspace-git-gps-tracker';
    const session = 'cdbe1b65-4713-4ea2-b32a-fbb14aa3abf9';
    final subagents = Directory('$base/$session/subagents');
    final sidechainPaths = subagents.existsSync()
        ? subagents
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.jsonl'))
              .map((f) => f.path)
              .toList()
        : <String>[];
    return FixtureBundle(
      label: 'gps-tracker main + subagents',
      mainPath: '$base/$session.jsonl',
      sidechainPaths: sidechainPaths,
    );
  }

  static FixtureBundle claudeDynamicWorkflows() {
    return FixtureBundle(
      label: 'claude dynamic workflows',
      mainPath:
          'test/integration/jsonl_replay/fixtures/'
          'claude_dynamic_workflows.stdout.jsonl',
      sidechainPaths: const [],
    );
  }

  static FixtureBundle minimaxTasksCommandsFiles() {
    return FixtureBundle(
      label: 'minimax tasks commands files',
      mainPath:
          'test/integration/jsonl_replay/fixtures/'
          'minimax_e2e_tasks_commands_files.stdout.jsonl',
      sidechainPaths: const [],
    );
  }

  static FixtureBundle minimaxHappyCliProbe() {
    return FixtureBundle(
      label: 'minimax happy cli probe',
      mainPath:
          'test/integration/jsonl_replay/fixtures/'
          'minimax_happy_cli_probe.transcript.jsonl',
      sidechainPaths: const [],
    );
  }
}
