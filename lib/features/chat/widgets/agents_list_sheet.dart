import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../tools/tool_status_indicator.dart';

/// Bottom sheet showing all active/running Task agents in the session.
class AgentsListSheet extends StatelessWidget {
  const AgentsListSheet({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  /// Counts how many Task/Agent tools are currently running.
  static int countActiveAgents(String sessionId) {
    final messages = sync.sessionMessages[sessionId] ?? [];
    var count = 0;
    for (final msg in messages) {
      final kind = msg['kind'] as String?;
      if (kind == 'tool-call') {
        final name = msg['name'] as String?;
        if (name == 'Task' || name == 'Agent') {
          final state = msg['state'] as String?;
          if (state == 'running') {
            count++;
          }
        }
      }
    }
    return count;
  }

  /// Extracts all Task/Agent tools from the session messages.
  static List<Map<String, dynamic>> _extractAgents(String sessionId) {
    final messages = sync.sessionMessages[sessionId] ?? [];
    final agents = <Map<String, dynamic>>[];
    for (final msg in messages) {
      final kind = msg['kind'] as String?;
      if (kind == 'tool-call') {
        final name = msg['name'] as String?;
        if (name == 'Task' || name == 'Agent') {
          agents.add(msg);
        }
      }
    }
    return agents;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final agents = _extractAgents(sessionId);

    return DraggableScrollableSheet(
      initialChildSize: agents.isEmpty ? 0.3 : 0.5,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.rocket_launch_rounded,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.agentsListTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (agents.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      '${agents.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: agents.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.rocket_launch_outlined,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            l10n.agentsListEmpty,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: agents.length,
                    itemBuilder: (context, index) {
                      final agent = agents[index];
                      return _AgentTile(
                        agent: agent,
                        sessionId: sessionId,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({
    required this.agent,
    required this.sessionId,
  });

  final Map<String, dynamic> agent;
  final String sessionId;

  ToolState _parseToolState(String? state) {
    switch (state) {
      case 'running':
        return ToolState.running;
      case 'completed':
        return ToolState.completed;
      case 'error':
        return ToolState.error;
      default:
        return ToolState.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final input = agent['input'] as Map<String, dynamic>?;
    final description =
        input?['description'] as String? ??
        input?['prompt'] as String? ??
        l10n.agentFallbackTask;
    final subagentType = input?['subagent_type'] as String?;
    final state = agent['state'] as String? ?? 'pending';
    final toolState = _parseToolState(state);
    final runInBackground = input?['run_in_background'] as bool? ?? false;
    final children = agent['children'] as List<dynamic>?;
    final childCount = children?.length ?? 0;
    final msgId = agent['id'] as String?;

    final Color borderColor;
    switch (toolState) {
      case ToolState.running:
        borderColor = cs.primary.withAlpha(100);
      case ToolState.completed:
        borderColor = AppColors.success.withAlpha(100);
      case ToolState.error:
        borderColor = cs.error.withAlpha(100);
      case ToolState.pending:
        borderColor = cs.outlineVariant;
    }

    return InkWell(
      onTap: () {
        if (msgId == null) return;
        Navigator.pop(context); // Close sheet
        context.push(
          '/chat/$sessionId/agent/$msgId',
          extra: agent,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxxs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: ToolStatusIndicator(state: toolState, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subagentType != null || runInBackground)
                    Row(
                      children: [
                        if (subagentType != null)
                          _AgentTypeBadge(type: subagentType),
                        if (runInBackground) ...[
                          if (subagentType != null)
                            const SizedBox(width: AppSpacing.xs),
                          _InfoBadge(
                            icon: Icons.run_circle_outlined,
                            label: 'background',
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            if (childCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _ChildCountBadge(count: childCount),
              ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentTypeBadge extends StatelessWidget {
  const _AgentTypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final icon = _iconForType(type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 10,
            color: cs.onPrimaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            type,
            style: TextStyle(
              fontSize: AppFontSize.xxs,
              fontWeight: FontWeight.w500,
              color: cs.onPrimaryContainer,
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

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: cs.onTertiaryContainer),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.xxs,
              fontWeight: FontWeight.w500,
              color: cs.onTertiaryContainer,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildCountBadge extends StatelessWidget {
  const _ChildCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
          fontSize: AppFontSize.xxs,
        ),
      ),
    );
  }
}
