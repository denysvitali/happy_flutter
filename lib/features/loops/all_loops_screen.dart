import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/loop.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import 'loop_actions.dart';
import 'loop_card.dart';
import 'loop_refresh_state.dart';

/// Global "all loops across all sessions" view.
///
/// Renders every non-empty session's loops, grouped under a collapsible
/// header (session name + per-group count). Loops sort soonest-to-fire
/// within each group; groups sort alphabetically by session name.
///
/// This is a read+manage view — no FAB, since loop creation is a
/// per-session chat action and lives in [LoopsScreen].
class AllLoopsScreen extends ConsumerStatefulWidget {
  const AllLoopsScreen({super.key});

  @override
  ConsumerState<AllLoopsScreen> createState() => _AllLoopsScreenState();
}

class _AllLoopsScreenState extends ConsumerState<AllLoopsScreen>
    with LoopRefreshState<AllLoopsScreen> {
  StreamSubscription<String>? _sub;

  /// Map of `sessionId -> collapsed` so the user's choice persists across
  /// rebuilds without needing persistent storage.
  final Map<String, bool> _collapsed = <String, bool>{};

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
    _sub = sync.onLoopsChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await refreshLoops(failureLogMessage: 'AllLoopsScreen refresh failed');
  }

  /// Earliest-fires-first within a session. Uses [Loop.createdAt] as the
  /// tie-breaker (a stable total ordering) so equal expressions still sort
  /// deterministically.
  int _compareSoonest(Loop a, Loop b) {
    final byExpression = a.expression.compareTo(b.expression);
    if (byExpression != 0) return byExpression;
    return a.createdAt.compareTo(b.createdAt);
  }

  String _sessionDisplayName(Session? session, String fallbackId) {
    // Clamp the preview length so very short test IDs (e.g. "s1") don't
    // trip substring's range check.
    final preview = fallbackId.length <= 6
        ? fallbackId
        : fallbackId.substring(0, 6);
    if (session == null) return 'Session $preview';
    return session.metadata?.name ?? 'Session $preview';
  }

  Future<void> _deleteLoop({
    required String sessionId,
    required String loopId,
  }) async {
    await deleteLoopWithFeedback(
      ref: ref,
      messenger: ScaffoldMessenger.of(context),
      isMounted: () => mounted,
      failureLogMessage: 'AllLoopsScreen delete failed',
      failureLabel: context.l10n.loopsLoopCancelFailed,
      sessionId: sessionId,
      loopId: loopId,
    );
  }

  Future<void> _pauseLoop({
    required String sessionId,
    required String loopId,
    required bool paused,
  }) async {
    await pauseLoopWithFeedback(
      ref: ref,
      messenger: ScaffoldMessenger.of(context),
      isMounted: () => mounted,
      failureLogMessage: 'AllLoopsScreen pause failed',
      failureLabel: paused
          ? context.l10n.loopsLoopPauseFailed
          : context.l10n.loopsLoopResumeFailed,
      sessionId: sessionId,
      loopId: loopId,
      paused: paused,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final loopsBySession = ref.watch(loopsNotifierProvider);
    final sessions = ref.watch(sessionsNotifierProvider);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Flatten + filter for the total-active count in the header. A loop
    // counts as "active" when it has not yet expired. Paused loops still
    // count — they're managed, not gone.
    final allLoops =
        loopsBySession.values.expand((l) => l).toList(growable: false);
    final totalActive =
        allLoops.where((l) => !l.isExpired(nowMs: nowMs)).length;

    // Build the per-session groups. Skip sessions whose loop list is
    // empty (e.g. a loop was just deleted from the last remaining one).
    final groups = <_SessionLoopGroup>[];
    for (final entry in loopsBySession.entries) {
      if (entry.value.isEmpty) continue;
      final session = sessions[entry.key];
      final activeCount = entry.value
          .where((l) => !l.isExpired(nowMs: nowMs))
          .length;
      final sortedLoops = List<Loop>.of(entry.value)
        ..sort(_compareSoonest);
      groups.add(_SessionLoopGroup(
        sessionId: entry.key,
        displayName: _sessionDisplayName(session, entry.key),
        loops: List<Loop>.unmodifiable(sortedLoops),
        activeCount: activeCount,
      ));
    }
    groups.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.allLoopsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: l10n.goalLoopsTitle,
            onPressed: () => context.push('/goal-loops'),
          ),
        ],
      ),
      body: initialLoading
          ? const AppLoadingIndicator()
          : refreshError != null
              ? _AllLoopsErrorState(
                  error: refreshError!,
                  onRetry: () {
                    clearLoopRefreshError();
                    _refresh();
                  },
                )
              : groups.isEmpty
                  ? const _AllLoopsEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                AppSpacing.lg,
                                AppSpacing.lg,
                                AppSpacing.md,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.allLoopsCount(totalActive),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    l10n.allLoopsAcrossSessions(
                                      groups.length,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final group = groups[index];
                                final isCollapsed =
                                    _collapsed[group.sessionId] ?? false;
                                return _SessionGroupSection(
                                  key: ValueKey(
                                    'loops-group-${group.sessionId}',
                                  ),
                                  group: group,
                                  isCollapsed: isCollapsed,
                                  onToggle: () => setState(() {
                                    _collapsed[group.sessionId] =
                                        !isCollapsed;
                                  }),
                                  onLoopPauseToggle: (
                                    paused,
                                    loopId,
                                  ) async {
                                    await _pauseLoop(
                                      sessionId: group.sessionId,
                                      loopId: loopId,
                                      paused: paused,
                                    );
                                  },
                                  onLoopDelete: (loopId) async {
                                    await _deleteLoop(
                                      sessionId: group.sessionId,
                                      loopId: loopId,
                                    );
                                  },
                                );
                              },
                              childCount: groups.length,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.xxxl * 2),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

/// Lightweight view-model for one session's loops within the all-loops list.
@immutable
class _SessionLoopGroup {
  const _SessionLoopGroup({
    required this.sessionId,
    required this.displayName,
    required this.loops,
    required this.activeCount,
  });

  final String sessionId;
  final String displayName;
  final List<Loop> loops;
  final int activeCount;
}

class _SessionGroupSection extends StatelessWidget {
  const _SessionGroupSection({
    required this.group,
    required this.isCollapsed,
    required this.onToggle,
    required this.onLoopPauseToggle,
    required this.onLoopDelete,
    super.key,
  });

  final _SessionLoopGroup group;
  final bool isCollapsed;
  final VoidCallback onToggle;

  /// Tapped when the user toggles a loop's pause state. Receives the
  /// desired new paused value and the loop ID.
  final Future<void> Function(bool paused, String loopId) onLoopPauseToggle;

  /// Tapped when the user confirms deletion of a loop.
  final Future<void> Function(String loopId) onLoopDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      group.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.pushNamed(
                      'chat-loops',
                      pathParameters: {'sessionId': group.sessionId},
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(context.l10n.allLoopsViewPerSession),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${group.activeCount}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: isCollapsed ? -0.25 : 0,
                    duration: AppDuration.fast,
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDuration.fast,
            curve: AppCurve.standard,
            child: isCollapsed
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      for (final loop in group.loops)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.sm,
                          ),
                          child: LoopCard(
                            key: ValueKey(
                              'all-loops-${group.sessionId}-${loop.id}',
                            ),
                            loop: loop,
                            onPauseToggle: (paused) =>
                                onLoopPauseToggle(paused, loop.id),
                            onDelete: () => onLoopDelete(loop.id),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AllLoopsEmptyState extends StatelessWidget {
  const _AllLoopsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: AppEmptyState(
        icon: Icons.schedule_outlined,
        title: l10n.allLoopsEmptyTitle,
        subtitle: l10n.allLoopsEmptyDescription,
      ),
    );
  }
}

class _AllLoopsErrorState extends StatelessWidget {
  const _AllLoopsErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: AppEmptyState(
        icon: Icons.error_outline,
        title: l10n.loopsLoadFailed,
        subtitle: error,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.commonRetry),
        ),
      ),
    );
  }
}
