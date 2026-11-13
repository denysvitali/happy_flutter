import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_badge.dart';
import '../../core/components/app_banner.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/rpc/rpc_types.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/snack.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import '../../core/widgets/app_linear_progress_indicator.dart';
import 'kubernetes_pod_format.dart';
import 'kubernetes_pod_operation_view.dart';
import 'kubernetes_pod_state.dart';
import 'kubernetes_pods_model.dart';

export '../../core/providers/pod_operations_notifier.dart'
    show KubernetesPodAction, KubernetesPodActionRunner;

/// Loads one machine's session pods. Injectable for tests.
typedef KubernetesPodsLoader =
    Future<List<SessionPod>> Function(String machineId);

/// Live list of Kubernetes session pods across every reachable daemon,
/// grouped by pod state, with uptime, restarts and CPU/memory usage.
/// Cards open the session's chat; each card's menu pauses, resumes or kills
/// the pod, or opens Session info for logs.
///
/// Pod actions never block the screen: they are recorded in
/// [podOperationsNotifierProvider], which syncs them to the daemon in the
/// background. A card shows its operation in progress ("Deleting…"), its
/// expected outcome once the daemon accepted it, or an inline failure with
/// Retry until the user dismisses it.
///
/// Polls while it is the visible route and the app is in the foreground.
class KubernetesSessionsScreen extends ConsumerStatefulWidget {
  const KubernetesSessionsScreen({super.key, this.loadPods});

  final KubernetesPodsLoader? loadPods;

  /// Refresh cadence while the screen is visible.
  static const Duration pollInterval = Duration(seconds: 10);

  @override
  ConsumerState<KubernetesSessionsScreen> createState() =>
      _KubernetesSessionsScreenState();
}

class _KubernetesSessionsScreenState
    extends ConsumerState<KubernetesSessionsScreen>
    with WidgetsBindingObserver {
  Map<String, List<SessionPod>> _podsByMachine = const {};
  Set<String> _unreachable = const {};
  bool _loaded = false;
  bool _refreshing = true;
  int _generation = 0;
  Timer? _poll;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    unawaited(_refresh());
    _poll = Timer.periodic(KubernetesSessionsScreen.pollInterval, (_) {
      if (!mounted || !_foreground || _refreshing) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground && !_foreground && mounted) unawaited(_refresh());
    _foreground = foreground;
  }

  Future<List<SessionPod>> _load(String machineId) async {
    final loader = widget.loadPods;
    if (loader != null) return loader(machineId);
    final response = await sync.machineListSessionPods(
      machineId: machineId,
      includeArchived: false,
    );
    return response.pods;
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    if (!_refreshing) setState(() => _refreshing = true);
    final machineIds = kubernetesPodMachineIds(
      machines: ref.read(machinesNotifierProvider),
      sessions: ref.read(sessionsNotifierProvider),
      nowMs: DateTime.now().millisecondsSinceEpoch,
    );
    final results = await Future.wait(
      machineIds.map((machineId) async {
        try {
          return (machineId, await _load(machineId));
        } catch (error, stack) {
          logger.warning('Failed to list session pods', error, stack);
          return (machineId, null);
        }
      }),
    );
    if (!mounted || generation != _generation) return;
    final podsByMachine = {
      for (final (machineId, pods) in results) machineId: ?pods,
    };
    // Settle optimistic overlays this report confirms.
    ref
        .read(podOperationsNotifierProvider.notifier)
        .reconcile(
          observedPodOperationStates(
            operations: ref.read(podOperationsNotifierProvider),
            podsByMachine: podsByMachine,
          ),
        );
    setState(() {
      _podsByMachine = podsByMachine;
      _unreachable = {
        for (final (machineId, pods) in results)
          if (pods == null) machineId,
      };
      _loaded = true;
      _refreshing = false;
    });
  }

  void _openChat(Session session) {
    unawaited(
      context.pushNamed('chat', pathParameters: {'sessionId': session.id}),
    );
  }

  void _openInfo(Session session) {
    unawaited(
      context.pushNamed(
        'session-info',
        pathParameters: {'sessionId': session.id},
      ),
    );
  }

  Future<void> _runAction(
    KubernetesPodEntry entry,
    KubernetesPodAction action,
  ) async {
    if (!entry.canControl) return;
    final l10n = context.l10n;
    if (action == KubernetesPodAction.kill) {
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.sessionPodKill,
        content: l10n.kubernetesKillConfirm(
          entry.sessionTitle ?? entry.podName,
        ),
        confirmLabel: l10n.sessionPodKill,
        isDestructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    ref
        .read(podOperationsNotifierProvider.notifier)
        .submit(
          machineId: entry.machineId!,
          sessionId: entry.sessionId,
          action: action,
        );
  }

  /// Reacts to operations settling: a success re-reads the daemons so the
  /// report catches up with the overlay; a failure is announced once (the
  /// card keeps the error until dismissed).
  void _onOperationsChanged(
    Map<String, PodOperation>? previous,
    Map<String, PodOperation> next,
  ) {
    if (!mounted) return;
    var settled = false;
    for (final MapEntry(:key, value: operation) in next.entries) {
      final before = previous?[key];
      if (before == null || before.id != operation.id || !before.isPending) {
        continue;
      }
      if (operation.isPending) continue;
      settled = true;
      if (operation.isFailed) {
        final l10n = context.l10n;
        context.showSnack(
          l10n.kubernetesActionFailed(
            kubernetesPodActionLabel(l10n, operation.action),
            operation.error ?? '',
          ),
          tone: SnackTone.error,
        );
      }
    }
    if (settled) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    ref.listen(podOperationsNotifierProvider, _onOperationsChanged);
    final operations = ref.watch(podOperationsNotifierProvider);
    final entries = applyPodOperations(
      mergeKubernetesPods(
        sessions: ref.watch(sessionsNotifierProvider),
        podsByMachine: _podsByMachine,
      ),
      operations,
    );
    final groups = <SessionPodDisplayState, List<KubernetesPodEntry>>{};
    for (final entry in entries) {
      (groups[entry.state] ??= []).add(entry);
    }
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final Widget body;
    if (!_loaded && entries.isEmpty) {
      body = const AppLoadingIndicator();
    } else if (entries.isEmpty && _unreachable.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppScreenPadding.settings,
        children: [
          AppEmptyState(
            icon: Icons.cloud_outlined,
            title: l10n.kubernetesEmptyTitle,
            subtitle: l10n.kubernetesEmptyHint,
          ),
        ],
      );
    } else {
      final now = DateTime.now();
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppScreenPadding.settings.copyWith(
          bottom: AppSpacing.xxl + bottomInset,
        ),
        children: [
          if (_unreachable.isNotEmpty) ...[
            AppBanner(
              key: const Key('kubernetes-unreachable'),
              tone: AppBadgeTone.warning,
              message: l10n.kubernetesUnreachable(_unreachable.length),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (entries.isNotEmpty) ...[
            KubernetesPodsSummary(entries: entries),
            const SizedBox(height: AppSpacing.xl),
          ],
          for (final MapEntry(key: state, value: rows) in groups.entries) ...[
            Padding(
              key: Key('kubernetes-section-${state.name}'),
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  kubernetesPodCountLabel(l10n, state, rows.length),
                  style: AppText.label(Theme.of(context)),
                ),
              ),
            ),
            for (final entry in rows) ...[
              KubernetesPodTile(
                key: ValueKey('kubernetes-pod-${entry.key}'),
                entry: entry,
                now: now,
                onTap: entry.session == null
                    ? null
                    : () => _openChat(entry.session!),
                onInfo: entry.session == null
                    ? null
                    : () => _openInfo(entry.session!),
                onAction: entry.canControl
                    ? (action) => unawaited(_runAction(entry, action))
                    : null,
                onRetry: () => ref
                    .read(podOperationsNotifierProvider.notifier)
                    .retry(entry.key),
                onDismiss: () => ref
                    .read(podOperationsNotifierProvider.notifier)
                    .dismiss(entry.key),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kubernetesTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            onPressed: _refreshing ? null : () => unawaited(_refresh()),
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: AppIconSize.md,
                    child: AppCircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

/// The outlined card every block on this screen shares.
class _PodCard extends StatelessWidget {
  const _PodCard({required this.child, super.key, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}

/// Totals across the listed pods: how many are ready, and the CPU and
/// memory they use when the cluster reports metrics.
class KubernetesPodsSummary extends StatelessWidget {
  const KubernetesPodsSummary({required this.entries, super.key});

  final List<KubernetesPodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = entries
        .where((e) => e.state == SessionPodDisplayState.ready)
        .length;
    var cpu = 0;
    var memory = 0;
    var sampled = false;
    for (final entry in entries) {
      final pod = entry.runningPod;
      if (pod == null || !pod.metricsAvailable) continue;
      sampled = true;
      cpu += pod.cpuUsageMillicores;
      memory += pod.memoryUsageBytes;
    }
    return _PodCard(
      key: const Key('kubernetes-summary'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              label: l10n.kubernetesSummaryPods,
              value: '${entries.length}',
              caption: l10n.kubernetesSummaryReady(ready, entries.length),
            ),
          ),
          if (sampled) ...[
            Expanded(
              child: _SummaryStat(
                label: l10n.kubernetesCpu,
                value: formatCpuCores(cpu),
                caption: l10n.kubernetesSummaryInUse,
              ),
            ),
            Expanded(
              child: _SummaryStat(
                label: l10n.kubernetesMemory,
                value: formatBinaryBytes(memory),
                caption: l10n.kubernetesSummaryInUse,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(theme)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.secondary(theme),
        ),
      ],
    );
  }
}

/// One pod card: state, session title (or pod name for an untracked pod),
/// repository, uptime and restarts, CPU/memory usage against the pod's
/// limits, any failure detail, and the pod/node identity. The menu opens
/// the chat or Session info and pauses, resumes or kills the pod.
class KubernetesPodTile extends StatelessWidget {
  const KubernetesPodTile({
    required this.entry,
    super.key,
    this.now,
    this.onTap,
    this.onInfo,
    this.onAction,
    this.onRetry,
    this.onDismiss,
  });

  final KubernetesPodEntry entry;

  /// Reference time for uptime; defaults to the build time.
  final DateTime? now;

  final VoidCallback? onTap;
  final VoidCallback? onInfo;

  /// Pod lifecycle actions; null when the pod cannot be controlled.
  final ValueChanged<KubernetesPodAction>? onAction;

  /// Retry / dismiss a failed operation shown on the card.
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = entry.state;
    final tone = kubernetesPodStateTone(state);
    final toneColors = AppToneColors.of(context, tone);
    final title = entry.sessionTitle;
    final running = entry.runningPod;
    final repo = formatPodRepo(entry.repoUrl, entry.repoRef);
    final detail = entry.detail;
    final identity = [
      if (entry.podName.isNotEmpty && title != null) entry.podName,
      if (running != null && running.nodeName.isNotEmpty) running.nodeName,
      if (running == null || running.nodeName.isEmpty)
        if (entry.namespace.isNotEmpty) entry.namespace,
    ].join(' · ');
    final startedAt = running == null || running.startedAtMs <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(running.startedAtMs);
    final restarts = running?.restartCount ?? 0;
    final operation = entry.operation;
    final pendingKill =
        operation != null &&
        operation.isPending &&
        operation.action == KubernetesPodAction.kill;

    final card = _PodCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppStatusDot(
                      color: toneColors.iconColor,
                      size: AppSpacing.sm,
                      pulse: state == SessionPodDisplayState.scheduling,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        title ?? entry.podName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(theme).copyWith(
                          fontFamily: title == null ? 'monospace' : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (title == null)
                  Text(
                    l10n.kubernetesUntrackedPod,
                    style: AppText.secondary(theme),
                  ),
                if (repo.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Icon(
                        Icons.source_outlined,
                        size: AppIconSize.sm,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          repo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.secondary(theme),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppBadge(
                      label: kubernetesPodStateLabel(l10n, state),
                      tone: tone,
                    ),
                    if (operation != null && operation.isPending)
                      AppBadge(
                        key: const Key('kubernetes-pod-operation-pending'),
                        leading: const Icon(Icons.sync_rounded),
                        label: kubernetesPodPendingLabel(
                          l10n,
                          operation.action,
                        ),
                        tone: operation.action == KubernetesPodAction.kill
                            ? AppBadgeTone.danger
                            : AppBadgeTone.info,
                      ),
                    if (startedAt != null)
                      AppBadge(
                        leading: const Icon(Icons.schedule_rounded),
                        label: l10n.kubernetesUptime(
                          formatPodUptime(
                            (now ?? DateTime.now()).difference(startedAt),
                          ),
                        ),
                      ),
                    if (restarts > 0)
                      AppBadge(
                        label: l10n.kubernetesRestarts(restarts),
                        tone: AppBadgeTone.warning,
                      ),
                    if (!entry.live) AppBadge(label: l10n.kubernetesLastKnown),
                  ],
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.secondary(
                      theme,
                      state == SessionPodDisplayState.failed
                          ? cs.error
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
                if (running != null && running.metricsAvailable) ...[
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: KubernetesUsageMeter(
                            key: const Key('kubernetes-usage-cpu'),
                            label: l10n.kubernetesCpu,
                            value: formatCpuCores(running.cpuUsageMillicores),
                            capacity: _capacity(
                              running.cpuLimitMillicores,
                              running.cpuRequestMillicores,
                              formatCpuCores,
                            ),
                            fraction: podUsageFraction(
                              usage: running.cpuUsageMillicores,
                              limit: running.cpuLimitMillicores,
                              request: running.cpuRequestMillicores,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: KubernetesUsageMeter(
                            key: const Key('kubernetes-usage-memory'),
                            label: l10n.kubernetesMemory,
                            value: formatBinaryBytes(running.memoryUsageBytes),
                            capacity: _capacity(
                              running.memoryLimitBytes,
                              running.memoryRequestBytes,
                              formatBinaryBytes,
                            ),
                            fraction: podUsageFraction(
                              usage: running.memoryUsageBytes,
                              limit: running.memoryLimitBytes,
                              request: running.memoryRequestBytes,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (running != null &&
                    state == SessionPodDisplayState.ready) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.kubernetesMetricsUnavailable,
                    style: AppText.secondary(theme),
                  ),
                ],
                if (identity.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    identity,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(theme),
                  ),
                ],
                if (operation != null && operation.isFailed) ...[
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: PodOperationFailureBanner(
                      operation: operation,
                      onRetry: onRetry ?? () {},
                      onDismiss: onDismiss ?? () {},
                    ),
                  ),
                ],
              ],
            ),
          ),
          _menu(context),
        ],
      ),
    );
    // A pod being deleted fades while the daemon confirms.
    return pendingKill ? Opacity(opacity: 0.6, child: card) : card;
  }

  static String? _capacity(int limit, int request, String Function(int) fmt) {
    if (limit > 0) return fmt(limit);
    if (request > 0) return fmt(request);
    return null;
  }

  Widget _menu(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (entry.busy) {
      return const SizedBox.square(
        dimension: AppTouchTarget.comfortable,
        child: Center(
          child: SizedBox.square(
            dimension: AppIconSize.md,
            child: AppCircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final action = onAction;
    final paused = entry.state == SessionPodDisplayState.paused;
    final items = <PopupMenuEntry<VoidCallback>>[
      if (onTap != null)
        PopupMenuItem(
          value: onTap,
          child: _MenuRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.kubernetesOpenChat,
          ),
        ),
      if (onInfo != null)
        PopupMenuItem(
          value: onInfo,
          child: _MenuRow(
            icon: Icons.info_outline_rounded,
            label: l10n.kubernetesInfoAndLogs,
          ),
        ),
      if (action != null) ...[
        if (onTap != null || onInfo != null) const PopupMenuDivider(),
        if (paused)
          PopupMenuItem(
            value: () => action(KubernetesPodAction.resume),
            child: _MenuRow(
              icon: Icons.play_arrow_rounded,
              label: l10n.sessionPodResume,
            ),
          )
        else
          PopupMenuItem(
            value: () => action(KubernetesPodAction.pause),
            child: _MenuRow(
              icon: Icons.pause_rounded,
              label: l10n.sessionPodPause,
            ),
          ),
        PopupMenuItem(
          key: const Key('kubernetes-pod-kill'),
          value: () => action(KubernetesPodAction.kill),
          child: _MenuRow(
            icon: Icons.delete_forever_outlined,
            label: l10n.sessionPodKill,
            color: cs.error,
          ),
        ),
      ],
    ];
    if (items.isEmpty) return const SizedBox(width: AppSpacing.md);
    return PopupMenuButton<VoidCallback>(
      key: Key('kubernetes-pod-menu-${entry.key}'),
      tooltip: l10n.kubernetesPodActions,
      icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
      onSelected: (callback) => callback(),
      itemBuilder: (_) => items,
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.lg, color: color),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(label, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

/// A labelled usage bar: `CPU  0.25 / 2` over a bar filled to the share of
/// the limit (or request). Without either, only the value is shown.
class KubernetesUsageMeter extends StatelessWidget {
  const KubernetesUsageMeter({
    required this.label,
    required this.value,
    super.key,
    this.capacity,
    this.fraction,
  });

  final String label;
  final String value;
  final String? capacity;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final share = fraction;
    final barColor = share == null
        ? null
        : share >= 0.9
        ? AppToneColors.of(context, AppBadgeTone.danger).iconColor
        : share >= 0.75
        ? AppToneColors.of(context, AppBadgeTone.warning).iconColor
        : cs.primary;
    final text = capacity == null ? value : '$value / $capacity';
    return Semantics(
      label: '$label $text',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: AppText.label(theme)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppText.badge(
                    theme,
                    cs.onSurface,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (share != null) ...[
            const SizedBox(height: AppSpacing.xs),
            AppLinearProgressIndicator(
              value: share,
              minHeight: AppSpacing.xs,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              backgroundColor: cs.surfaceContainerHighest,
              color: barColor,
            ),
          ],
        ],
      ),
    );
  }
}
