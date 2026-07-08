import 'package:flutter/material.dart';

import 'known_tools.dart';
import 'tool_view_widgets.dart' show ToolViewBuilder;
import 'views/ask_user_question_view.dart';
import 'views/bash_view.dart';
import 'views/codex_bash_view.dart';
import 'views/codex_diff_view.dart';
import 'views/codex_patch_view.dart';
import 'views/edit_view.dart';
import 'views/exit_plan_tool_view.dart';
import 'views/gemini_edit_view.dart';
import 'views/gemini_execute_view.dart';
import 'views/glob_view.dart';
import 'views/grep_view.dart';
import 'views/ls_view.dart';
import 'views/multi_edit_view.dart';
import 'views/read_view.dart';
import 'views/task_tool_view.dart';
import 'views/task_view.dart';
import 'views/todo_view.dart';
import 'views/web_fetch_view.dart';
import 'views/write_view.dart';

/// Single source of truth for tool-name → body view builders.
///
/// [KnownTools.aliases] handles name normalization; this registry maps
/// only **canonical** names. Call [resolve] with the raw wire name.
class ToolViewRegistry {
  ToolViewRegistry._();

  /// Canonical name → view builder.
  ///
  /// Keep in sync with [KnownTools.tools] keys that have custom bodies.
  static final Map<String, ToolViewBuilder> _builders =
      <String, ToolViewBuilder>{
        'Glob': (t, m, s) => GlobView(tool: t, metadata: m),
        'Grep': (t, m, s) => GrepView(tool: t, metadata: m),
        'LS': (t, m, s) => LSView(tool: t, metadata: m),
        'Read': (t, m, s) => ReadView(tool: t, metadata: m, sessionId: s),
        'Edit': (t, m, s) => EditView(tool: t, metadata: m, sessionId: s),
        'MultiEdit': (t, m, s) => MultiEditView(tool: t, metadata: m),
        'Write': (t, m, s) => WriteView(tool: t, metadata: m),
        // Gemini uses lowercase "edit" as a distinct body.
        'edit': (t, m, s) => GeminiEditView(tool: t, metadata: m),
        'Bash': (t, m, s) => BashView(tool: t, metadata: m),
        'exec_command': (t, m, s) => ExecCommandView(tool: t),
        'CodexBash': (t, m, s) => CodexBashView(tool: t, metadata: m),
        'execute': (t, m, s) => GeminiExecuteView(tool: t, metadata: m),
        'CodexPatch': (t, m, s) => CodexPatchView(tool: t, metadata: m),
        'CodexDiff': (t, m, s) => CodexDiffView(tool: t, metadata: m),
        'TaskCreate': (t, m, s) =>
            TaskToolView(tool: t, metadata: m, sessionId: s),
        'TaskUpdate': (t, m, s) =>
            TaskToolView(tool: t, metadata: m, sessionId: s),
        'TaskList': (t, m, s) =>
            TaskToolView(tool: t, metadata: m, sessionId: s),
        'TaskGet': (t, m, s) =>
            TaskToolView(tool: t, metadata: m, sessionId: s),
        'TodoWrite': (t, m, s) => TodoView(tool: t, metadata: m, sessionId: s),
        'todo_list': (t, m, s) => TodoView(tool: t, metadata: m, sessionId: s),
        'WebFetch': (t, m, s) => WebFetchView(tool: t, metadata: m),
        'ExitPlanMode': (t, m, s) => ExitPlanToolView(tool: t, metadata: m),
        'NotebookRead': (t, m, s) =>
            ReadView(tool: t, metadata: m, sessionId: s),
        'NotebookEdit': (t, m, s) =>
            EditView(tool: t, metadata: m, sessionId: s),
      };

  /// Whether [toolName] (raw or alias) has a registered custom body.
  static bool has(String toolName) {
    final canonical = KnownTools.canonicalName(toolName);
    return _builders.containsKey(canonical) ||
        _builders.containsKey(toolName) ||
        _isTaskFamily(canonical) ||
        canonical == 'AskUserQuestion';
  }

  static bool _isTaskFamily(String name) =>
      name == 'Task' || name == 'Agent' || name == 'Workflow';

  /// Resolve a body builder for [toolName], or null for default fallback.
  ///
  /// [onNavigate] is only used for Task/Agent/Workflow cards.
  /// [askUserBuilder] is supplied by ToolView so the ask-user key
  /// and sessionId stay owned by the widget state.
  static ToolViewBuilder? resolve(
    String toolName, {
    required VoidCallback onNavigate,
    ToolViewBuilder? askUserBuilder,
  }) {
    final canonical = KnownTools.canonicalName(toolName);

    if (canonical == 'AskUserQuestion' || toolName == 'AskUserQuestion') {
      return askUserBuilder ??
          (t, m, s) {
            final toolUseId =
                t['toolUseId'] as String? ?? t['id'] as String?;
            return AskUserQuestionView(
              key: toolUseId != null ? ValueKey('ask-$toolUseId') : null,
              tool: t,
              metadata: m,
              sessionId: s,
            );
          };
    }

    if (_isTaskFamily(canonical)) {
      return (t, m, s) => TaskView(
        tool: t,
        metadata: m,
        onNavigate: onNavigate,
      );
    }

    return _builders[canonical] ?? _builders[toolName];
  }
}
