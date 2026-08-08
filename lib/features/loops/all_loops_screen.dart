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

enum _LoopsDestination { scheduled, goals }

enum _LoopFilter { all, active, paused }

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
  _LoopFilter _filter = _LoopFilter.all;

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

  bool _matchesFilter(Loop loop, {required int nowMs}) {
    final isExpired = loop.isExpired(nowMs: nowMs);
    return switch (_filter) {
      _LoopFilter.all => true,
      _LoopFilter.active => !loop.paused && !isExpired,
      _LoopFilter.paused => loop.paused && !isExpired,
    };
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

    // Keep active and paused distinct so operational state is explicit.
    // Expired loops remain available under All for historical context.
    final allLoops = loopsBySession.values
        .expand((l) => l)
        .toList(growable: false);
    final totalActive = allLoops
        .where((l) => !l.paused && !l.isExpired(nowMs: nowMs))
        .length;
    final totalPaused = allLoops
        .where((l) => l.paused && !l.isExpired(nowMs: nowMs))
        .length;

    // Build both the complete and filtered groups. The complete set drives
    // the overview while the filtered set drives list disclosure.
    final allGroups = <_SessionLoopGroup>[];
    final filteredGroups = <_SessionLoopGroup>[];
    for (final entry in loopsBySession.entries) {
      if (entry.value.isEmpty) continue;
      final session = sessions[entry.key];
      final sortedLoops = List<Loop>.of(entry.value)..sort(_compareSoonest);
      final group = _SessionLoopGroup(
        sessionId: entry.key,
        displayName: _sessionDisplayName(session, entry.key),
        loops: List<Loop>.unmodifiable(sortedLoops),
      );
      allGroups.add(group);

      final visibleLoops = sortedLoops
          .where((loop) => _matchesFilter(loop, nowMs: nowMs))
          .toList(growable: false);
      if (visibleLoops.isNotEmpty) {
        filteredGroups.add(
          _SessionLoopGroup(
            sessionId: group.sessionId,
            displayName: group.displayName,
            loops: List<Loop>.unmodifiable(visibleLoops),
          ),
        );
      }
    }
    int compareGroups(_SessionLoopGroup a, _SessionLoopGroup b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    allGroups.sort(compareGroups);
    filteredGroups.sort(compareGroups);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.allLoopsTitle)),
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
          : RefreshIndicator(
              onRefresh: _refresh,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoint.contentMax,
                  ),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _LoopsOverview(
                          activeCount: totalActive,
                          pausedCount: totalPaused,
                          sessionCount: allGroups.length,
                          filter: _filter,
                          onFilterChanged: (filter) {
                            setState(() => _filter = filter);
                          },
                          onOpenGoals: () => context.push('/goal-loops'),
                        ),
                      ),
                      if (allGroups.isEmpty)
                        const SliverFillRemaining(
                          child: _AllLoopsEmptyState(),
                        )
                      else if (filteredGroups.isEmpty)
                        SliverFillRemaining(
                          child: _FilteredLoopsEmptyState(
                            filter: _filter,
                            onShowAll: () {
                              setState(() => _filter = _LoopFilter.all);
                            },
                          ),
                        )
                      else ...[
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final group = filteredGroups[index];
                            final isCollapsed =
                                _collapsed[group.sessionId] ?? false;
                            return _SessionGroupSection(
                              key: ValueKey('loops-group-${group.sessionId}'),
                              group: group,
                              isCollapsed: isCollapsed,
                              onToggle: () => setState(() {
                                _collapsed[group.sessionId] = !isCollapsed;
                              }),
                              onLoopPauseToggle: (paused, loopId) async {
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
                          }, childCount: filteredGroups.length),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.xxxl * 2),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _LoopsOverview extends StatelessWidget {
  const _LoopsOverview({
    required this.activeCount,
    required this.pausedCount,
    required this.sessionCount,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpenGoals,
  });

  final int activeCount;
  final int pausedCount;
  final int sessionCount;
  final _LoopFilter filter;
  final ValueChanged<_LoopFilter> onFilterChanged;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_LoopsDestination>(
            key: const ValueKey('loops-destination-switcher'),
            segments: [
              ButtonSegment<_LoopsDestination>(
                value: _LoopsDestination.scheduled,
                icon: const Icon(Icons.schedule_outlined),
                label: Text(l10n.allLoopsScheduledTab),
              ),
              ButtonSegment<_LoopsDestination>(
                value: _LoopsDestination.goals,
                icon: const Icon(Icons.flag_outlined),
                label: Text(l10n.goalLoopsTitle),
              ),
            ],
            selected: const {_LoopsDestination.scheduled},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              if (selection.contains(_LoopsDestination.goals)) onOpenGoals();
            },
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, AppTouchTarget.min)),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.autorenew, color: cs.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.allLoopsCount(activeCount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        children: [
                          Text(
                            l10n.allLoopsPausedCount(pausedCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '•',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            l10n.allLoopsAcrossSessions(sessionCount),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _LoopFilterChip(
                filter: _LoopFilter.all,
                label: l10n.allLoopsFilterAll,
                selected: filter == _LoopFilter.all,
                onSelected: onFilterChanged,
              ),
              _LoopFilterChip(
                filter: _LoopFilter.active,
                label: l10n.loopsStatusActive,
                selected: filter == _LoopFilter.active,
                onSelected: onFilterChanged,
              ),
              _LoopFilterChip(
                filter: _LoopFilter.paused,
                label: l10n.loopsStatusPaused,
                selected: filter == _LoopFilter.paused,
                onSelected: onFilterChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoopFilterChip extends StatelessWidget {
  const _LoopFilterChip({
    required this.filter,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final _LoopFilter filter;
  final String label;
  final bool selected;
  final ValueChanged<_LoopFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppTouchTarget.min,
      child: ChoiceChip(
        key: ValueKey('loops-filter-${filter.name}'),
        label: Text(label),
        selected: selected,
        onSelected: (value) {
          if (value) onSelected(filter);
        },
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
  });

  final String sessionId;
  final String displayName;
  final List<Loop> loops;
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
    final l10n = context.l10n;
    final groupLabel = l10n.allLoopsGroupLabel(
      group.displayName,
      group.loops.length,
    );
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
          Row(
            children: [
              Expanded(
                child: Semantics(
                  key: ValueKey('loops-group-toggle-${group.sessionId}'),
                  button: true,
                  expanded: !isCollapsed,
                  label: groupLabel,
                  onTap: onToggle,
                  child: ExcludeSemantics(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: onToggle,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppTouchTarget.min,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_outlined,
                                  size: AppIconSize.lg,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    group.displayName,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  l10n.allLoopsGroupLoopCount(
                                    group.loops.length,
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                AnimatedRotation(
                                  turns: isCollapsed ? -0.25 : 0,
                                  duration: AppMotion.duration(
                                    context,
                                    AppDuration.fast,
                                  ),
                                  child: Icon(
                                    Icons.expand_more,
                                    size: AppIconSize.xl,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: TextButton.icon(
                  key: ValueKey('view-session-loops-${group.sessionId}'),
                  onPressed: () => context.pushNamed(
                    'chat-loops',
                    pathParameters: {'sessionId': group.sessionId},
                  ),
                  icon: const Icon(Icons.open_in_new, size: AppIconSize.md),
                  label: Text(l10n.allLoopsViewPerSession),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurfaceVariant,
                    minimumSize: const Size(0, AppTouchTarget.min),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: AppMotion.duration(context, AppDuration.fast),
            curve: AppCurve.standard,
            child: isCollapsed
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      for (final loop in group.loops)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
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

class _FilteredLoopsEmptyState extends StatelessWidget {
  const _FilteredLoopsEmptyState({
    required this.filter,
    required this.onShowAll,
  });

  final _LoopFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isPaused = filter == _LoopFilter.paused;
    return AppEmptyState(
      icon: isPaused ? Icons.pause_circle_outline : Icons.play_circle_outline,
      title: isPaused ? l10n.allLoopsNoPausedTitle : l10n.allLoopsNoActiveTitle,
      subtitle: isPaused
          ? l10n.allLoopsNoPausedDescription
          : l10n.allLoopsNoActiveDescription,
      action: TextButton.icon(
        onPressed: onShowAll,
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: Text(l10n.allLoopsShowAll),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppTouchTarget.min),
        ),
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
