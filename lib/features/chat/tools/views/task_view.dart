import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/wire_parsers.dart';
import '../../markdown/markdown_view.dart';
import '../known_tools.dart';
import '../tool_status_indicator.dart';
import '../tool_view.dart' show parseToolState;

/// Max number of child tool calls shown inline.
const int _kMaxToolsShown = 3;

/// Compact view for a Task (sub-agent) tool call.
///
/// Shows the last [_kMaxToolsShown] tool calls from the
/// children with status indicators, plus a sub-agent type
/// badge when available. Tapping navigates to the full
/// agent conversation screen.
class TaskView extends StatelessWidget {
  /// Creates a [TaskView].
  const TaskView({
    required this.tool,
    required this.onNavigate,
    super.key,
    this.metadata,
    this.messages,
  });

  /// The tool call data.
  final Map<String, dynamic> tool;

  /// Called when the user taps to open the agent conversation.
  final VoidCallback onNavigate;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// All session messages (unused in this widget).
  final List<Map<String, dynamic>>? messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input = WireParsers.asMap(tool['input']);
    final description = input?['description'] as String?;
    final prompt = input?['prompt'] as String?;
    final headerText = description ?? prompt ?? 'Task';
    final subagentType =
        input?['subagent_type'] as String?;
    final runInBackground =
        input?['run_in_background'] as bool? ?? false;
    final toolState =
        tool['state'] as String? ?? 'pending';
    final parsedState = _parseState(toolState);

    // Show prompt detail when description is separate
    final showPromptDetail =
        description != null && prompt != null;

    final children = tool['children'] as List<dynamic>?;
    final toolCalls = _extractToolCalls(children);
    final shownTools = toolCalls.length > _kMaxToolsShown
        ? toolCalls.sublist(
            toolCalls.length - _kMaxToolsShown,
          )
        : toolCalls;
    final remainingCount =
        toolCalls.length - shownTools.length;

    final Color borderColor;
    switch (parsedState) {
      case ToolState.running:
        borderColor =
            theme.colorScheme.primary.withAlpha(100);
      case ToolState.completed:
        borderColor =
            AppColors.success.withAlpha(100);
      case ToolState.error:
        borderColor =
            theme.colorScheme.error.withAlpha(100);
      case ToolState.pending:
        borderColor = theme.colorScheme.outlineVariant;
    }

    return GestureDetector(
      onTap: onNavigate,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius:
              BorderRadius.circular(AppRadius.smd),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row: status + description + badges
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: ToolStatusIndicator(
                    state: parsedState,
                    size: 16,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    headerText,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (runInBackground) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _InfoBadge(
                    icon: Icons.run_circle_outlined,
                    label: 'background',
                    color: theme.colorScheme.tertiary,
                  ),
                ],
                if (subagentType != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  _SubAgentBadge(type: subagentType),
                ],
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
            // Prompt detail (when description is the
            // short summary and prompt has the full task)
            if (showPromptDetail) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding:
                    const EdgeInsets.only(left: 24),
                child: MarkdownView(
                  markdown: prompt,
                  textColor:
                      theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // Inline tool call list
            if (shownTools.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xsm),
              ...shownTools.map(
                (t) {
                  final name =
                      t['name'] as String? ?? '';
                  if (name == 'Task' ||
                      name == 'Agent') {
                    return _InlineNestedTaskRow(
                      key: ValueKey(
                        t['toolUseId'] ?? t['id'],
                      ),
                      tool: t,
                      metadata: metadata,
                    );
                  }
                  return _InlineToolRow(
                    key: ValueKey(
                      t['toolUseId'] ?? t['id'],
                    ),
                    tool: t,
                    metadata: metadata,
                  );
                },
              ),
              if (remainingCount > 0)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 24,
                    top: 2,
                  ),
                  child: Text(
                    'and $remainingCount more...',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(
                      color: theme
                          .colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
            // Most recent text message from the sub-agent
            if (_extractLastTextMessage(children) case final lastText?
                when lastText.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xsm),
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: MarkdownView(
                  markdown: lastText,
                  textColor: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _extractToolCalls(
    List<dynamic>? children,
  ) {
    if (children == null) return [];
    return children
        .whereType<Map<String, dynamic>>()
        .where((c) => c['kind'] == 'tool-call')
        .toList();
  }

  String? _extractLastTextMessage(List<dynamic>? children) {
    if (children == null) return null;
    for (var i = children.length - 1; i >= 0; i--) {
      final child = children[i];
      if (child is Map<String, dynamic> &&
          child['kind'] == 'text' &&
          child['isThinking'] != true) {
        final content = child['content'] as String?;
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }
}

// ----------------------------------------------------------
// Sub-agent type badge
// ----------------------------------------------------------

class _SubAgentBadge extends StatelessWidget {
  const _SubAgentBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _iconForType(type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            type,
            style: TextStyle(
              fontSize: AppFontSize.xxs,
              fontWeight: FontWeight.w500,
              color:
                  theme.colorScheme.onPrimaryContainer,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'explore':
        return Icons.explore;
      case 'bash':
        return Icons.terminal;
      case 'plan':
        return Icons.architecture;
      case 'general-purpose':
        return Icons.auto_awesome;
      default:
        return Icons.rocket_launch;
    }
  }
}

// ----------------------------------------------------------
// Generic info badge (e.g. "background")
// ----------------------------------------------------------

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.xxs,
              fontWeight: FontWeight.w500,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------
// Inline tool call row (compact, shown inside TaskView)
// ----------------------------------------------------------

class _InlineToolRow extends StatelessWidget {
  const _InlineToolRow({
    required this.tool,
    super.key,
    this.metadata,
  });

  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolName = tool['name'] as String? ?? '';
    final state =
        tool['state'] as String? ?? 'pending';
    final toolState = _parseState(state);

    final knownTool = KnownTools.get(toolName);
    var title = toolName;
    if (knownTool?.extractDescription != null) {
      title =
          knownTool!.extractDescription!(tool, metadata)
              ?? toolName;
    } else if (knownTool?.title is String) {
      title = knownTool!.title as String;
    }

    final icon = KnownTools.iconFor(
      toolName,
      12,
      theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          const SizedBox(width: 24),
          SizedBox(width: 12, height: 12, child: icon),
          const SizedBox(width: AppSpacing.xsm),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
                fontSize: AppFontSize.xs,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 12,
            height: 12,
            child: ToolStatusIndicator(
              state: toolState,
              size: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------
// Inline nested Task/Agent row (shows sub-agent children)
// ----------------------------------------------------------

class _InlineNestedTaskRow extends StatelessWidget {
  const _InlineNestedTaskRow({
    required this.tool,
    super.key,
    this.metadata,
  });

  final Map<String, dynamic> tool;
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final input =
        WireParsers.asMap(tool['input']);
    final description =
        input?['description'] as String? ??
            input?['prompt'] as String? ??
            'Task';
    final state =
        tool['state'] as String? ?? 'pending';
    final toolState = _parseState(state);
    final subagentType =
        input?['subagent_type'] as String?;

    final children =
        tool['children'] as List<dynamic>?;
    final nestedToolCalls = children
            ?.whereType<Map<String, dynamic>>()
            .where((c) => c['kind'] == 'tool-call')
            .toList() ??
        [];
    final shownNested =
        nestedToolCalls.length > _kMaxToolsShown
            ? nestedToolCalls.sublist(
                nestedToolCalls.length -
                    _kMaxToolsShown,
              )
            : nestedToolCalls;
    final remainingCount =
        nestedToolCalls.length - shownNested.length;

    return Padding(
      padding: const EdgeInsets.only(
        left: 24,
        top: 2,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: ToolStatusIndicator(
                  state: toolState,
                  size: 12,
                ),
              ),
              const SizedBox(width: AppSpacing.xsm),
              Icon(
                Icons.rocket_launch,
                size: 10,
                color:
                    theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(
                    color: theme
                        .colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.xs,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (subagentType != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _SubAgentBadge(type: subagentType),
              ],
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 12,
                height: 12,
                child: ToolStatusIndicator(
                  state: toolState,
                  size: 12,
                ),
              ),
            ],
          ),
          ...shownNested.map(
            (t) {
              final name =
                  t['name'] as String? ?? '';
              if (name == 'Task' ||
                  name == 'Agent') {
                return _InlineNestedTaskRow(
                  key: ValueKey(
                    t['toolUseId'] ?? t['id'],
                  ),
                  tool: t,
                  metadata: metadata,
                );
              }
              return _InlineToolRow(
                key: ValueKey(
                  t['toolUseId'] ?? t['id'],
                ),
                tool: t,
                metadata: metadata,
              );
            },
          ),
          if (remainingCount > 0)
            Padding(
              padding:
                  const EdgeInsets.only(left: 24),
              child: Text(
                'and $remainingCount more...',
                style: theme.textTheme.labelSmall
                    ?.copyWith(
                  color: theme
                      .colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

ToolState _parseState(String state) => parseToolState(state);
