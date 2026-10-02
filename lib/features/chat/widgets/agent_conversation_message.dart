import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/workflow_run.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/wire/wire_parsers.dart';
import '../../workflows/workflow_display.dart';
import '../markdown/markdown.dart';
import '../tools/tool_status_indicator.dart';
import '../tools/tool_view.dart';
import 'agent_event_widget.dart';
import 'task_event_summary_card.dart';

/// One sidechain message in an agent's conversation feed.
///
/// Owns presentation and detail navigation; the screen supplies session state.
class AgentConversationMessage extends StatelessWidget {
  const AgentConversationMessage({
    required this.message,
    required this.sessionId,
    required this.isSessionOnline,
    this.metadata,
    super.key,
  });

  final Map<String, dynamic> message;
  final String sessionId;
  final bool isSessionOnline;
  final Map<String, dynamic>? metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = message;
    final kind = msg['kind'] as String?;

    if (kind == 'text') {
      // A task_notification / task_updated completion summary is a meta
      // event the CLI encodes as a text row. Rendering it through the plain
      // text path dresses it as sub-agent prose — an unlabelled bubble that
      // just repeats the step description. The chat timeline already routes
      // it to TaskEventSummaryCard (status icon + transcript path); this
      // feed must too, or the same step reads three times in a row.
      if (msg['taskEvent'] == true) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: TaskEventSummaryCard(data: msg, sessionId: sessionId),
        );
      }
      return _buildTextMessage(theme, msg);
    }

    if (kind == 'tool-call') {
      final toolName = msg['name'] as String? ?? '';
      if (toolName == 'Task' || toolName == 'Agent' || toolName == 'Workflow') {
        return _buildNestedTaskRow(context, theme, msg);
      }
      return _buildToolRow(context, msg);
    }

    if (kind == 'error') {
      return _ErrorRow(theme: theme, msg: msg);
    }

    if (kind == 'agent-event') {
      // Task progress chips in this dedicated step feed render as full
      // "<tool> · <description>" step rows — the chat timeline keeps the
      // compact centered chip (with the tool name de-duplicated) via
      // AgentEventWidget, but here the tool name is part of the step the
      // user tapped to see, so the whole label is shown verbatim.
      if (msg['taskEvent'] == true) {
        return _StepChipRow(theme: theme, msg: msg);
      }
      return AgentEventWidget(event: msg['event'], message: msg);
    }

    return const SizedBox.shrink();
  }

  Widget _buildTextMessage(ThemeData theme, Map<String, dynamic> msg) {
    final content = msg['content'] as String? ?? '';
    if (content.isEmpty) return const SizedBox.shrink();
    final isThinking = msg['isThinking'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: isThinking
          ? const _ThinkingRow()
          : Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: SimpleMarkdownView(markdown: content),
            ),
    );
  }

  Widget _buildToolRow(BuildContext context, Map<String, dynamic> msg) {
    // Use full ToolView for detailed tool call display
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ToolView(
        tool: msg,
        metadata: metadata,
        sessionId: sessionId,
        isSessionOnline: isSessionOnline,
        onPress: () {
          final msgId = msg['id'] as String?;
          if (msgId == null) return;
          context.push('/chat/$sessionId/message/$msgId', extra: msg);
        },
      ),
    );
  }

  Widget _buildNestedTaskRow(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> msg,
  ) {
    final input = WireParsers.asMap(msg['input']);
    final description =
        input?['description'] as String? ??
        input?['prompt'] as String? ??
        AppLocalizations.of(context).agentFallbackTask;
    final subagentType =
        input?['subagent_type'] as String? ?? msg['taskType'] as String?;
    final state = msg['state'] as String? ?? 'pending';
    final toolState = parseToolState(state);
    final children = WireParsers.asList(msg['children']);
    final childCount = children?.length ?? 0;
    final msgId = msg['id'] as String?;

    final Color borderColor;
    switch (toolState) {
      case ToolState.running:
        borderColor = theme.colorScheme.primary.withAlpha(80);
      case ToolState.completed:
        borderColor = AppColors.success.withAlpha(80);
      case ToolState.error:
        borderColor = theme.colorScheme.error.withAlpha(80);
      case ToolState.pending:
        borderColor = theme.colorScheme.outlineVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxs),
      child: InkWell(
        onTap: () {
          if (msgId == null) return;
          context.push(
            '/chat/$sessionId'
            '/agent/$msgId',
            extra: msg,
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.smd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.smd),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: ToolStatusIndicator(state: toolState, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.rocket_launch,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      description,
                      style: AppText.label(theme, theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subagentType != null)
                      Text(
                        subagentType,
                        style: AppText.secondary(
                          theme,
                          theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: AppOpacity.high,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (childCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    '$childCount',
                    style: AppText.secondary(
                      theme,
                      theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: AppOpacity.half,
                      ),
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: AppOpacity.half,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: theme.colorScheme.onSurfaceVariant.withValues(
              alpha: AppOpacity.high,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).chatThinking,
            style: AppText.secondary(
              theme,
              theme.colorScheme.onSurfaceVariant.withValues(
                alpha: AppOpacity.high,
              ),
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------
// Error row (compact inline error indicator)
// ----------------------------------------------------------

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.theme, required this.msg});

  final ThemeData theme;
  final Map<String, dynamic> msg;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final errorType = msg['errorType'] as String? ?? 'unknown';
    final errorMessage = msg['errorMessage'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: InkWell(
        onTap: () => _showErrorSheet(context),
        borderRadius: BorderRadius.circular(AppRadius.xsm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smd,
            vertical: AppSpacing.xsm,
          ),
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: AppOpacity.half),
            borderRadius: BorderRadius.circular(AppRadius.xsm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 14, color: cs.error),
              const SizedBox(width: AppSpacing.xsm),
              Flexible(
                child: Text(
                  '$errorType: $errorMessage',
                  style: AppText.secondary(theme, cs.onErrorContainer),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSheet(BuildContext context) {
    final debugData = WireParsers.asMap(msg['debugData']);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(msg['errorType'] as String? ?? 'Error'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg['errorMessage'] as String? ?? 'Unknown error'),
              if (debugData != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Debug data:', style: AppText.title(Theme.of(ctx))),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  debugData.toString(),
                  style: AppText.secondary(
                    Theme.of(ctx),
                  ).copyWith(fontFamily: 'monospace'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).commonClose),
          ),
        ],
      ),
    );
  }
}

/// A single task-progress chip rendered as a step row in the agent
/// conversation feed. Shows the chip's full label (e.g.
/// `Read · lib/main.dart`) with a status glyph so a chips-only sidechain
/// reads as the list of steps the user opened the screen to inspect.
class _StepChipRow extends StatelessWidget {
  const _StepChipRow({required this.theme, required this.msg});

  final ThemeData theme;
  final Map<String, dynamic> msg;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final label = WorkflowRun.stepLabel(msg);
    final state = WorkflowRun.stepState(msg);
    final (icon, color) = workflowStateStyle(state, cs);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: AppText.label(theme, cs.onSurface)),
          ),
        ],
      ),
    );
  }
}
