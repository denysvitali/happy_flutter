import '../../core/models/workflow_run.dart';
import '../../core/wire/wire_parsers.dart';

/// Shared "what does this sub-agent's step feed contain" logic.
///
/// The chat timeline's `Agent N steps` chip and the agent conversation
/// screen used to derive their counts independently: the chip counted raw
/// `children` while the screen dropped every progress chip whenever any
/// durable transcript row existed. A background agent whose inner tool
/// calls never streamed therefore advertised `20 steps` and opened onto a
/// two-row feed. Both now go through [buildAgentDisplayChildren].

/// Collapse key when [c] is a transient activity indicator — a sub-agent
/// progress chip, a task completion notification, or a thinking
/// placeholder; `null` for durable rows (real text, tool calls, errors,
/// nested tasks).
String? agentTransientKey(Map<String, dynamic> c) {
  if (c['kind'] == 'text' && c['isThinking'] == true) {
    return 'thinking';
  }
  // Completion notifications arrive as `kind: 'text'`, in-flight ticks as
  // `kind: 'agent-event'`; both are task meta, neither is transcript.
  if (c['taskEvent'] == true) {
    return 'task:${agentTaskRowLabel(c)}';
  }
  return null;
}

/// The tool a task meta row reports, or `null` when it names none (task
/// completion notifications never do).
String? agentTaskRowTool(Map<String, dynamic> c) {
  final tool = c['subAgentLastTool'];
  return (tool is String && tool.isNotEmpty) ? tool : null;
}

/// The label a task meta row renders, minus the `<tool> · ` prefix.
String agentTaskRowLabel(Map<String, dynamic> c) {
  final label = WorkflowRun.stepLabel(c);
  final tool = agentTaskRowTool(c);
  if (tool == null) return label;
  const sep = ' · ';
  if (label == tool) return '';
  return label.startsWith('$tool$sep')
      ? label.substring(tool.length + sep.length)
      : label;
}

/// The rows the agent conversation screen renders for [children].
///
/// While the agent runs, every row is kept (deduplicated) so the live feed
/// keeps its progress ticks. Once finished, thinking placeholders always
/// drop. Progress chips drop only when the durable transcript is at least
/// as rich as the chips — that is the classic streamed-sidechain case
/// where the chips merely echo work already visible. When the transcript
/// is thinner than the chip stream (background/async agents whose inner
/// tool calls never crossed the wire) the chips *are* the steps, so they
/// stay, deduplicated, instead of leaving a near-empty feed under an
/// `N steps` label.
List<Map<String, dynamic>> buildAgentDisplayChildren(
  List<Map<String, dynamic>> children,
  bool isRunning,
) {
  var durable = 0;
  var transient = 0;
  for (final c in children) {
    if (agentTransientKey(c) == null) {
      durable++;
    } else if (c['kind'] != 'text' || c['isThinking'] != true) {
      transient++;
    }
  }
  final dropChips = durable >= transient;
  final out = <Map<String, dynamic>>[];
  String? prevTransientKey;
  String? prevTool;
  for (final c in children) {
    final key = agentTransientKey(c);
    if (key == null) {
      prevTransientKey = null;
      prevTool = null;
      out.add(c);
      continue;
    }
    if (!isRunning) {
      // Finished: thinking placeholders carry nothing to show.
      if (c['kind'] == 'text' && c['isThinking'] == true) continue;
      // A transcript at least as rich as the chips already fills the feed;
      // meta rows beside it are noise.
      if (dropChips) continue;
    }
    final tool = agentTaskRowTool(c);
    // Tools must be compatible as well as labels: `Read · notes.md` then
    // `Write · notes.md` are two real steps that share a stripped label,
    // whereas a tool-less completion echo belongs to whatever ran last.
    final sameTool = tool == null || prevTool == null || tool == prevTool;
    if (key == prevTransientKey && sameTool) {
      // Same step reported again: keep the newest row, which carries the
      // final status (a `completed` notification replaces the chip that
      // announced the identical label while the step was in flight).
      out[out.length - 1] = c;
      prevTool = tool ?? prevTool;
      continue;
    }
    prevTransientKey = key;
    prevTool = tool;
    out.add(c);
  }
  return out;
}

/// Number of steps to advertise for an `Agent` / `Task` / `Workflow` tool
/// call — exactly the row count its detail screen will render, so the chip
/// never promises more than the feed delivers.
int agentStepCount(Map<String, dynamic> tool) {
  final children =
      WireParsers.asList(
        tool['children'],
      )?.whereType<Map<String, dynamic>>().toList() ??
      const <Map<String, dynamic>>[];
  if (children.isEmpty) return 0;
  final isRunning = (tool['state'] as String?) == 'running';
  return buildAgentDisplayChildren(children, isRunning).length;
}
