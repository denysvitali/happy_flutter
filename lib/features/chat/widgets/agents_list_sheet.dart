import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/wire/wire_parsers.dart';
import '../tools/tool_status_indicator.dart';
import '../tools/tool_view.dart' show parseToolState;

/// Immutable snapshot of Task/Agent progress for a session.
class TaskProgress {
  const TaskProgress({
    required this.total,
    required this.running,
    required this.completed,
    required this.error,
  });

  final int total;
  final int running;
  final int completed;
  final int error;

  double get completionRatio => total == 0 ? 0 : (completed + error) / total;
  bool get hasTasks => total > 0;
  bool get isComplete => total > 0 && running == 0;
}

/// Agent rows and progress counters derived from one transcript traversal.
class AgentSessionProjection {
  const AgentSessionProjection({required this.agents, required this.progress});

  final List<Map<String, dynamic>> agents;
  final TaskProgress progress;
}

class _AgentSessionProjectionCacheEntry {
  _AgentSessionProjectionCacheEntry({
    required this.revision,
    required Object source,
    required this.projection,
  }) : source = WeakReference<Object>(source);

  final int revision;
  final WeakReference<Object> source;
  final AgentSessionProjection projection;
}

/// Bounded cache for transcript-derived agent rows and counters.
///
/// A chat frame renders the app-bar badge and sticky status banner, then may
/// immediately open the agents sheet. All three surfaces need the same
/// projection. Keying it by the session's monotonic message revision avoids
/// repeating a full recursive transcript walk for each consumer. The source
/// identity is also checked so test fixtures and cache hydration remain safe
/// when a list is replaced before a notification advances the revision.
@visibleForTesting
class AgentSessionProjectionCache {
  AgentSessionProjectionCache({this.maxEntries = 24}) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<String, _AgentSessionProjectionCacheEntry> _entries =
      LinkedHashMap<String, _AgentSessionProjectionCacheEntry>();

  int get length => _entries.length;

  AgentSessionProjection resolve({
    required String sessionId,
    required int revision,
    required Object source,
    required AgentSessionProjection Function() load,
  }) {
    final cached = _entries.remove(sessionId);
    if (cached != null &&
        cached.revision == revision &&
        identical(cached.source.target, source)) {
      _entries[sessionId] = cached;
      return cached.projection;
    }

    final projection = load();
    _entries[sessionId] = _AgentSessionProjectionCacheEntry(
      revision: revision,
      source: source,
      projection: projection,
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return projection;
  }
}

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

class _TaskEventAgent {
  _TaskEventAgent({required this.agentId});

  final String agentId;
  String state = 'running';
  String? description;
  String? taskType;
  String? subagentType;
  String? parentToolUseId;

  void merge(Map<String, dynamic> msg) {
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
    if (parentToolUseId != null) '_taskEventParentToolUseId': parentToolUseId,
    'input': <String, dynamic>{
      'description': description ?? agentId,
      'subagent_type': ?(subagentType ?? taskType),
      'run_in_background': true,
    },
  };
}

/// Bottom sheet showing all active/running Task agents in the session.
class AgentsListSheet extends StatelessWidget {
  const AgentsListSheet({required this.sessionId, this.onAgentTap, super.key});

  final String sessionId;

  /// Optional callback invoked when a navigable agent row is tapped.
  ///
  /// Receives the agent map and the resolved navigation id. Callers should
  /// close the sheet and push [AgentConversationScreen] using a context
  /// that outlives the bottom sheet, otherwise the navigation is silently
  /// dropped when the modal is popped.
  final void Function(Map<String, dynamic> agent, String navigationId)?
  onAgentTap;

  static final AgentSessionProjectionCache _projectionCache =
      AgentSessionProjectionCache();

  static bool _isAgentToolName(String? name) =>
      name == 'Task' || name == 'Agent' || name == 'Workflow';

  static List<Map<String, dynamic>> _catalogToAgentMaps(List<String> catalog) {
    return [
      for (final agent in catalog)
        <String, dynamic>{
          'id': 'subagent-catalog-$agent',
          'kind': 'tool-call',
          'name': 'Agent',
          'state': 'pending',
          '_subagentsCatalogSynthetic': true,
          'input': <String, dynamic>{
            'description': agent,
            'subagent_type': agent,
          },
        },
    ];
  }

  /// Computes the rows and counters together, visiting each transcript entry
  /// once. This is the canonical projection used by both the sheet and the
  /// sticky banner.
  static AgentSessionProjection computeProjection(String sessionId) {
    final messages = sync.messagesForSession(sessionId);
    return _projectionCache.resolve(
      sessionId: sessionId,
      revision: sync.messagesRevision(sessionId),
      source: messages,
      load: () => _computeProjection(messages),
    );
  }

  static AgentSessionProjection _computeProjection(
    List<Map<String, dynamic>> messages,
  ) {
    final taskStates = <String, _TaskEventAgent>{};
    final backgroundShellTaskIds = <String>{};
    final catalogSeen = <String>{};
    final catalog = <String>[];
    final agentIds = <String>{};
    final agents = <Map<String, dynamic>>[];
    var total = 0;
    var running = 0;
    var completed = 0;
    var error = 0;

    void collect(
      List<dynamic> msgs, {
      required bool isTopLevel,
      required bool collectAgentTree,
      required bool countProgressTree,
      required bool collectTaskEventTree,
    }) {
      for (final msg in msgs) {
        if (msg is! Map<String, dynamic>) continue;

        final messageCatalog = WireParsers.asList(msg['subagentsCatalog']);
        if (messageCatalog != null) {
          for (final entry in messageCatalog) {
            if (entry is String && entry.isNotEmpty && catalogSeen.add(entry)) {
              catalog.add(entry);
            }
          }
        }

        final isOrphan = msg['_orphanRecovery'] == true;
        final isTopLevelSidechain = isTopLevel && msg['isSidechain'] == true;
        var collectTaskEventChildren = collectTaskEventTree && !isOrphan;

        if (collectTaskEventTree && !isOrphan && msg['taskEvent'] == true) {
          final agentId = msg['agentId'] as String?;
          if (agentId != null && agentId.isNotEmpty) {
            final taskType = msg['taskType'] as String?;
            if (taskType == 'local_bash') {
              backgroundShellTaskIds.add(agentId);
              taskStates.remove(agentId);
              collectTaskEventChildren = false;
            } else if (!backgroundShellTaskIds.contains(agentId)) {
              taskStates
                  .putIfAbsent(agentId, () => _TaskEventAgent(agentId: agentId))
                  .merge(msg);
            } else {
              collectTaskEventChildren = false;
            }
          }
        }

        if (collectAgentTree && !isOrphan && msg['kind'] == 'tool-call') {
          final name = msg['name'] as String?;
          final id = msg['id'] as String?;
          if (_isAgentToolName(name) && id != null && agentIds.add(id)) {
            agents.add(msg);
          }
        }

        if (countProgressTree &&
            !isOrphan &&
            !isTopLevelSidechain &&
            msg['kind'] == 'tool-call' &&
            _isAgentToolName(msg['name'] as String?)) {
          total++;
          switch (msg['state'] as String?) {
            case 'running':
              running++;
            case 'completed':
              completed++;
            case 'error':
              error++;
          }
        }

        final children = msg['children'] as List<dynamic>?;
        if (children != null && children.isNotEmpty) {
          collect(
            children,
            isTopLevel: false,
            collectAgentTree: collectAgentTree && !isOrphan,
            countProgressTree:
                countProgressTree && !isOrphan && !isTopLevelSidechain,
            collectTaskEventTree: collectTaskEventChildren,
          );
        }
      }
    }

    collect(
      messages,
      isTopLevel: true,
      collectAgentTree: true,
      countProgressTree: true,
      collectTaskEventTree: true,
    );

    if (taskStates.isNotEmpty) {
      final eventAgents = taskStates.values
          .map((agent) => agent.toAgentMap())
          .toList();
      final eventCompleted = taskStates.values
          .where((state) => state.state == 'completed')
          .length;
      final eventError = taskStates.values
          .where((state) => state.state == 'error')
          .length;
      return AgentSessionProjection(
        agents: eventAgents,
        progress: TaskProgress(
          total: taskStates.length,
          running: taskStates.length - eventCompleted - eventError,
          completed: eventCompleted,
          error: eventError,
        ),
      );
    }

    return AgentSessionProjection(
      agents: agents.isNotEmpty ? agents : _catalogToAgentMaps(catalog),
      progress: TaskProgress(
        total: total,
        running: running,
        completed: completed,
        error: error,
      ),
    );
  }

  /// Counts how many Task/Agent tools are currently running.
  ///
  /// Walks both the flat message list and nested `children` arrays.
  /// Sidechain entries in the flat list are skipped (orphans);
  /// nested children under a parent Task/Agent are included.
  static int countActiveAgents(String sessionId) {
    return computeProjection(sessionId).progress.running;
  }

  /// Progress stats for Task/Agent tools in a session.
  ///
  /// Prefers Claude Code task lifecycle events (task_started/progress/
  /// notification) when available; falls back to counting tool-call
  /// states otherwise.  Both paths recurse into `children` arrays
  /// so nested sub-agents are counted.
  static TaskProgress computeTaskProgress(String sessionId) {
    return computeProjection(sessionId).progress;
  }

  /// Extracts all Task/Agent tools from the session messages.
  ///
  /// Walks both the flat message list and nested `children` arrays
  /// so that sub-agents spawned inside a parent Agent's transcript
  /// are included.  Deduplicates by `id` to avoid double-counting
  /// when the sidechain grouper has already attached a child.
  static List<Map<String, dynamic>> _extractAgents(String sessionId) {
    return computeProjection(sessionId).agents;
  }

  /// Public alias retained for callers that only need agent rows. Callers that
  /// also need progress should use [computeProjection] to avoid a second scan.
  static List<Map<String, dynamic>> extractAgents(String sessionId) =>
      _extractAgents(sessionId);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final projection = computeProjection(sessionId);
    final agents = projection.agents;
    final progress = projection.progress;

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
                Icon(Icons.rocket_launch_rounded, size: 20, color: cs.primary),
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
          // Progress bar
          if (progress.hasTasks)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: progress.completionRatio,
                      minHeight: 4,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _progressLabel(progress),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: AppFontSize.xxs,
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
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
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
                      return RepaintBoundary(
                        child: _AgentTile(
                          agent: agent,
                          sessionId: sessionId,
                          onTap: onAgentTap,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String _progressLabel(TaskProgress progress) {
  final done = progress.completed + progress.error;
  final running = progress.running > 0 ? ', ${progress.running} running' : '';
  return '$done of ${progress.total} complete$running';
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({required this.agent, required this.sessionId, this.onTap});

  final Map<String, dynamic> agent;
  final String sessionId;
  final void Function(Map<String, dynamic> agent, String navigationId)? onTap;

  ToolState _parseToolState(String? state) => parseToolState(state);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final input = WireParsers.asMap(agent['input']);
    final description =
        input?['description'] as String? ??
        input?['prompt'] as String? ??
        l10n.agentFallbackTask;
    final subagentType = input?['subagent_type'] as String?;
    final state = agent['state'] as String? ?? 'pending';
    final toolState = _parseToolState(state);
    final runInBackground = input?['run_in_background'] as bool? ?? false;
    final children = WireParsers.asList(agent['children']);
    final childCount = children?.length ?? 0;
    final msgId = agent['id'] as String?;
    final toolUseId = agent['toolUseId'] as String?;
    final parentToolUseId = agent['_taskEventParentToolUseId'] as String?;
    final isSyntheticTaskEvent = agent['_taskEventSynthetic'] == true;
    final navigationId = isSyntheticTaskEvent
        ? (parentToolUseId ?? toolUseId)
        : msgId;
    final canOpenConversation =
        navigationId != null && agent['_subagentsCatalogSynthetic'] != true;

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
      onTap: canOpenConversation
          ? () {
              final tap = onTap;
              if (tap != null) {
                tap(agent, navigationId);
              } else {
                // Fallback for callers that do not supply a callback. This
                // can drop the navigation when called from a modal bottom
                // sheet because the sheet's context is detached by pop.
                Navigator.pop(context);
                context.push(
                  '/chat/$sessionId/agent/$navigationId',
                  extra: agent,
                );
              }
            }
          : null,
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
            if (canOpenConversation)
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
          Icon(icon, size: 10, color: cs.onPrimaryContainer),
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
  const _InfoBadge({required this.icon, required this.label});

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
