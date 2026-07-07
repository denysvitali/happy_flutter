import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart'
    hide LogLevel, Logger;
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart' show Breadcrumb, Sentry;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/services/opentelemetry_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'agents_list_sheet.dart';

/// Sticky banner shown above the chat messages when a session has any
/// spawned sub-agents (Task/Agent tool calls). Communicates overall
/// progress at a glance:
///
/// - Blue with rocket icon + spinner   → tasks still running
/// - Green with check icon              → all tasks finished successfully
/// - Red with warning icon              → one or more tasks errored
///
/// Tapping the banner opens [AgentsListSheet] (the same sheet the rocket
/// button in the app bar opens), giving users a single tap path to
/// inspect every spawned sub-agent.
///
/// The banner is intentionally not dismissable and not gated behind
/// "hideToolCalls" — sub-agent activity is a first-class signal that
/// must be visible at all times, regardless of how the user has
/// configured tool-call display.
class SubAgentStatusBanner extends StatelessWidget {
  const SubAgentStatusBanner({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  /// Listens to [sync.sessionMessages] for the given session and computes
  /// the live [TaskProgress]. Riverpod's [ref.listen] is not used because
  /// the banner reads directly off the singleton; rebuilding on every
  /// 100ms-debounced [Sync.onDataChanged] tick is correct here.
  static TaskProgress _progress(String sessionId) {
    // Avoid touching sync at construction time (e.g. when the session is
    // not yet loaded). Returns an empty progress that hides the banner.
    if (sessionId.isEmpty) {
      return const TaskProgress(total: 0, running: 0, completed: 0, error: 0);
    }
    return AgentsListSheet.computeTaskProgress(sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return _SubAgentStatusBannerStateful(sessionId: sessionId);
  }
}

class _SubAgentStatusBannerStateful extends StatefulWidget {
  const _SubAgentStatusBannerStateful({required this.sessionId});

  final String sessionId;

  @override
  State<_SubAgentStatusBannerStateful> createState() =>
      _SubAgentStatusBannerStatefulState();
}

class _SubAgentStatusBannerStatefulState
    extends State<_SubAgentStatusBannerStateful> {
  StreamSubscription<void>? _dataSubscription;
  TaskProgress? _lastSeenProgress;
  int _lastSeenTotal = 0;

  /// toolUseId → OTel span for sub-agents we've seen start running but
  /// have not yet observed finish. Cleaned up on dispose and whenever
  /// the corresponding agent reaches a terminal state. Holds at most
  /// `_lastSeenTotal` entries, which is bounded by the chat's per-
  /// message ToolProgress cap.
  final Map<String, OTelSpan> _inflightSubAgentSpans = <String, OTelSpan>{};

  @override
  void initState() {
    super.initState();
    _dataSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      setState(() {});
      // Reconcile per-sub-agent OTel spans after the rebuild so the
      // diff sees the latest state. New Task/Agent tool-call messages
      // open spans; transitions from running→completed/error close them.
      _reconcileSubAgentSpans();
    });
    // Record a one-time session-load breadcrumb so we can measure how
    // often a session with sub-agents is opened and how often the user
    // reaches the chat screen vs. the dedicated agents-list sheet.
    _emitTelemetryIfNeeded(
      const TaskProgress(total: 0, running: 0, completed: 0, error: 0),
    );
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    // Close any in-flight sub-agent spans so a session switch doesn't
    // leave dangling traces. We mark them ok because we observed the
    // session is going away — closing them with error would create
    // noise in dashboards.
    for (final span in _inflightSubAgentSpans.values) {
      span.end(ok: true);
    }
    _inflightSubAgentSpans.clear();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SubAgentStatusBannerStateful old) {
    super.didUpdateWidget(old);
    if (old.sessionId != widget.sessionId) {
      _lastSeenProgress = null;
      _lastSeenTotal = 0;
      for (final span in _inflightSubAgentSpans.values) {
        span.end(ok: true);
      }
      _inflightSubAgentSpans.clear();
    }
  }

  /// Diffs the current Task/Agent tool-call list against the previous
  /// tick and emits OTel spans for new sub-agents, closing spans for
  /// ones that have reached a terminal state. Runs on every
  /// [sync.onDataChanged] tick so the spans track the real lifecycle
  /// of each spawned sub-agent.
  void _reconcileSubAgentSpans() {
    final agents = AgentsListSheet.extractAgents(widget.sessionId);
    final currentIds = <String>{};
    for (final agent in agents) {
      final id = agent['toolUseId'] as String?;
      if (id == null || id.isEmpty) continue;
      currentIds.add(id);
      if (_inflightSubAgentSpans.containsKey(id)) {
        // Already tracking. If it transitioned to completed/error
        // we'll close below.
        continue;
      }
      // New sub-agent — start a span.
      final input = agent['input'] as Map<String, dynamic>?;
      final subagentType = input?['subagent_type'] as String? ??
          agent['subagentType'] as String? ??
          'unknown';
      final description = input?['description'] as String? ??
          input?['prompt'] as String?;
      final activeSpan = OpenTelemetryService().currentSpan;
      final span = activeSpan != null
          ? OpenTelemetryService().startChildSpan(
              'subagent.spawn',
              parent: activeSpan,
              kind: SpanKind.internal,
              attributes: {
                'session.id': widget.sessionId,
                'subagent.parent_tool_use_id': id,
                'subagent.type': subagentType,
                if (description != null)
                  'subagent.description':
                      description.length > 200
                          ? '${description.substring(0, 197)}...'
                          : description,
              },
            )
          : OpenTelemetryService().startTrace(
              'subagent.spawn',
              kind: SpanKind.internal,
              attributes: {
                'session.id': widget.sessionId,
                'subagent.parent_tool_use_id': id,
                'subagent.type': subagentType,
                if (description != null)
                  'subagent.description':
                      description.length > 200
                          ? '${description.substring(0, 197)}...'
                          : description,
              },
            );
      if (span != null) {
        _inflightSubAgentSpans[id] = span;
      }
    }
    // Close spans for agents that have reached a terminal state or
    // disappeared from the agent list entirely.
    final terminalIds = <String>[];
    for (final entry in _inflightSubAgentSpans.entries) {
      if (!currentIds.contains(entry.key)) {
        terminalIds.add(entry.key);
      }
    }
    for (final id in terminalIds) {
      final span = _inflightSubAgentSpans.remove(id);
      // Sub-agents that drop off the list (typically because they
      // completed) are end-ok. If they reappear later we'll start a
      // new span — duplicated short spans are cheaper than a leaked
      // one.
      span?.end(ok: true);
    }
  }
  @override
  Widget build(BuildContext context) {
    final progress = SubAgentStatusBanner._progress(widget.sessionId);
    if (!progress.hasTasks) {
      _lastSeenProgress = progress;
      _lastSeenTotal = progress.total;
      return const SizedBox.shrink();
    }
    _emitTelemetryIfNeeded(progress);
    _lastSeenProgress = progress;
    _lastSeenTotal = progress.total;
    return _BannerBody(progress: progress, sessionId: widget.sessionId);
  }

  /// Emits a Sentry breadcrumb when the total sub-agent count changes.
  /// This lets us track two funnel events:
  ///
  /// 1. subagent_banner_shown — when the banner first appears
  ///    (user opened a session with N spawned sub-agents).
  /// 2. subagent_banner_progress — when the running/completed
  ///    counters change (sub-agents finishing mid-session).
  ///
  /// Taps on the banner are tracked separately in [_BannerBody].
  void _emitTelemetryIfNeeded(TaskProgress progress) {
    if (progress.total == _lastSeenTotal && _lastSeenProgress != null) {
      return;
    }
    final crumb = Breadcrumb(
      category: 'subagent',
      type: progress.total > _lastSeenTotal
          ? 'subagent_banner_shown'
          : 'subagent_banner_progress',
      data: {
        'sessionId': widget.sessionId,
        'total': progress.total,
        'running': progress.running,
        'completed': progress.completed,
        'error': progress.error,
        'previousTotal': _lastSeenTotal,
      },
    );
    try {
      Sentry.addBreadcrumb(crumb);
    } catch (e) {
      logger.warning(
        '[subagent-banner] failed to emit Sentry breadcrumb: $e',
      );
    }
  }
}

/// Visible body of the banner. Stateless so a single build renders the
/// styled strip; the parent handles subscription/lifecycle.
class _BannerBody extends StatelessWidget {
  const _BannerBody({required this.progress, required this.sessionId});

  final TaskProgress progress;
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final hasErrors = progress.error > 0;
    final isComplete = progress.running == 0 && progress.completed > 0;
    final isRunning = progress.running > 0;

    final Color backgroundColor;
    final Color foregroundColor;
    final IconData icon;
    final String label;
    if (hasErrors) {
      backgroundColor = theme.colorScheme.errorContainer;
      foregroundColor = theme.colorScheme.onErrorContainer;
      icon = Icons.warning_amber_rounded;
      label = l10n.subAgentBannerError(
        progress.error,
        progress.total,
      );
    } else if (isComplete) {
      backgroundColor = AppColors.success.withValues(alpha: 0.16);
      foregroundColor = AppColors.success;
      icon = Icons.check_circle_rounded;
      label = l10n.subAgentBannerComplete(progress.total);
    } else {
      backgroundColor = theme.colorScheme.primaryContainer.withValues(
        alpha: 0.6,
      );
      foregroundColor = theme.colorScheme.onPrimaryContainer;
      icon = Icons.rocket_launch_rounded;
      label = l10n.subAgentBannerRunning(progress.running, progress.total);
    }

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _openAgentsSheet(context);
        },
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xsm,
            ),
            child: Row(
              children: [
                if (isRunning)
                  const _RunningDots()
                else
                  Icon(icon, size: 16, color: foregroundColor),
                const SizedBox(width: AppSpacing.xsm),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.subAgentBannerTapToOpen,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: foregroundColor.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAgentsSheet(BuildContext context) {
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'subagent',
          type: 'subagent_banner_tapped',
          data: {
            'sessionId': sessionId,
            'total': progress.total,
            'running': progress.running,
            'completed': progress.completed,
            'error': progress.error,
          },
        ),
      );
    } catch (e) {
      logger.warning(
        '[subagent-banner] failed to emit Sentry breadcrumb on tap: $e',
      );
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (sheetContext) => AgentsListSheet(
        sessionId: sessionId,
        onAgentTap: (agent, navigationId) {
          Navigator.of(sheetContext).pop();
          context.push(
            '/chat/$sessionId/agent/$navigationId',
            extra: agent,
          );
        },
      ),
    );
  }
}

/// Three bouncing dots shown while sub-agents are running, evoking a
/// "thinking" affordance without an explicit spinner (the sub-agents
/// themselves report no real-time progress; a spinner would imply
/// something local is happening).
class _RunningDots extends StatefulWidget {
  const _RunningDots();

  @override
  State<_RunningDots> createState() => _RunningDotsState();
}

class _RunningDotsState extends State<_RunningDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return SizedBox(
      width: 18,
      height: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final phase = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
              final scale = 0.6 + 0.4 * (1.0 - (phase - 0.5).abs() * 2);
              return Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.4 + 0.6 * scale),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
