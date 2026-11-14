import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_badge.dart';
import '../../core/components/app_banner.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/dialogs/confirm_dialog.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/session_operations_notifier.dart';
import '../../core/rpc/rpc_types.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/snack.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import 'kubernetes_pod_format.dart';
import 'kubernetes_pod_operation_view.dart';
import 'kubernetes_pod_state.dart';
import 'kubernetes_pod_tile.dart';
import 'kubernetes_pods_model.dart';

export '../../core/providers/pod_operations_notifier.dart'
    show KubernetesPodAction, KubernetesPodActionRunner;
export 'kubernetes_pod_tile.dart';

/// Loads one machine's session pods. Injectable for tests.
typedef KubernetesPodsLoader =
    Future<List<SessionPod>> Function(String machineId);

/// Live list of Kubernetes session pods across every reachable daemon,
/// newest first (toggleable), as compact rows with state, uptime, restarts
/// and CPU/memory usage. Rows open the session's chat; each row's menu
/// pauses, resumes or kills the pod, archives the session, or opens
/// Session info for logs.
///
/// Long-press (or the Select action) enters selection mode, where several
/// sessions are archived at once. Archiving goes through
/// [sessionOperationsNotifierProvider]: rows leave the list immediately and
/// a failure is reported by the app-wide operation failure listener.
///
/// Pod actions never block the screen: they are recorded in
/// [podOperationsNotifierProvider], which syncs them to the daemon in the
/// background. A card shows its operation in progress ("Deleting…"), its
/// expected outcome once the daemon accepted it, or an inline failure with
/// Retry until the user dismisses it.
///
/// Polls while it is the visible route and the app is in the foreground.
/// Refreshes also react to machine/session catalog changes, isolate slow or
/// failing daemons with per-machine timeouts/backoff, and keep last-known
/// state visible when a daemon is temporarily unreachable.
class KubernetesSessionsScreen extends ConsumerStatefulWidget {
  const KubernetesSessionsScreen({super.key, this.loadPods});

  final KubernetesPodsLoader? loadPods;

  /// Refresh cadence while the screen is visible.
  static const Duration pollInterval = Duration(seconds: 10);

  /// Upper bound for one machine's pod list request.
  static const Duration machineTimeout = Duration(seconds: 12);

  @override
  ConsumerState<KubernetesSessionsScreen> createState() =>
      _KubernetesSessionsScreenState();
}

class _MachinePodFetchState {
  const _MachinePodFetchState({
    this.lastSuccessMs,
    this.consecutiveFailures = 0,
    this.nextAllowedFetchMs = 0,
  });

  final int? lastSuccessMs;
  final int consecutiveFailures;
  final int nextAllowedFetchMs;

  _MachinePodFetchState copyWith({
    int? lastSuccessMs,
    bool clearLastSuccess = false,
    int? consecutiveFailures,
    int? nextAllowedFetchMs,
  }) => _MachinePodFetchState(
    lastSuccessMs: clearLastSuccess
        ? null
        : (lastSuccessMs ?? this.lastSuccessMs),
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    nextAllowedFetchMs: nextAllowedFetchMs ?? this.nextAllowedFetchMs,
  );
}

class _KubernetesSessionsScreenState
    extends ConsumerState<KubernetesSessionsScreen>
    with WidgetsBindingObserver {
  Map<String, List<SessionPod>> _podsByMachine = const {};
  Set<String> _unreachable = const {};
  final Map<String, _MachinePodFetchState> _machineFetch = {};
  bool _loaded = false;
  bool _refreshing = true;
  int _generation = 0;
  Timer? _poll;
  Timer? _catalogRefreshDebounce;
  bool _foreground = true;

  /// Newest pods first unless the user flipped the order.
  bool _newestFirst = true;

  /// Selected entry keys while in selection mode; null outside it.
  Set<String>? _selection;

  /// Sessions archived from this screen; their rows stay hidden while the
  /// archive syncs and the daemons catch up. A failed archive unhides them.
  final Set<String> _archivedSessionIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    unawaited(_refresh());
    _poll = Timer.periodic(KubernetesSessionsScreen.pollInterval, (_) {
      if (!mounted || !_foreground) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _catalogRefreshDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground && !_foreground && mounted) unawaited(_refresh());
    _foreground = foreground;
  }

  void _scheduleCatalogRefresh() {
    if (!mounted) return;
    _catalogRefreshDebounce?.cancel();
    _catalogRefreshDebounce = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || !_foreground) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      unawaited(_refresh());
    });
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

  Future<List<SessionPod>> _loadWithTimeout(String machineId) =>
      _load(machineId).timeout(KubernetesSessionsScreen.machineTimeout);

  int _backoffMs(int failures) {
    const stepsMs = [10000, 20000, 40000, 60000];
    return stepsMs[math.min(failures - 1, stepsMs.length - 1)];
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    if (!_refreshing && mounted) setState(() => _refreshing = true);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final machineIds = kubernetesPodMachineIds(
      machines: ref.read(machinesNotifierProvider),
      sessions: ref.read(sessionsNotifierProvider),
      nowMs: nowMs,
    );
    final machines = ref.read(machinesNotifierProvider);
    final queried = <String>[];
    final deferred = <String>[];
    for (final machineId in machineIds) {
      final fetchState = _machineFetch[machineId];
      if (fetchState != null && nowMs < fetchState.nextAllowedFetchMs) {
        deferred.add(machineId);
      } else {
        queried.add(machineId);
      }
    }

    final results = await Future.wait(
      queried.map((machineId) async {
        try {
          return (machineId, await _loadWithTimeout(machineId));
        } catch (error, stack) {
          final machine = machines[machineId];
          if (machine == null || !machine.isOnlineAt(nowMs)) {
            logger.info(
              'Skipping unavailable Kubernetes daemon $machineId: $error',
            );
          } else {
            logger.warning('Failed to list session pods', error, stack);
          }
          return (machineId, null);
        }
      }),
    );
    if (!mounted || generation != _generation) return;

    final nextPodsByMachine = Map<String, List<SessionPod>>.of(_podsByMachine)
      ..removeWhere((id, _) => !machineIds.contains(id));
    final nextFetch = Map<String, _MachinePodFetchState>.from(_machineFetch)
      ..removeWhere((id, _) => !machineIds.contains(id));
    final unreachable = <String>{...deferred};
    final completedNow = DateTime.now().millisecondsSinceEpoch;

    for (final (machineId, pods) in results) {
      if (pods != null) {
        nextPodsByMachine[machineId] = pods;
        nextFetch[machineId] = const _MachinePodFetchState();
      } else {
        unreachable.add(machineId);
        final previous = nextFetch[machineId];
        final hadData = nextPodsByMachine.containsKey(machineId);
        final failures = (previous?.consecutiveFailures ?? 0) + 1;
        nextFetch[machineId] = _MachinePodFetchState(
          lastSuccessMs: previous?.lastSuccessMs,
          consecutiveFailures: failures,
          nextAllowedFetchMs: completedNow + _backoffMs(failures),
        );
        if (!hadData && previous?.lastSuccessMs == null) {
          nextPodsByMachine.remove(machineId);
        }
      }
    }

    // Settle optimistic overlays this report confirms.
    ref
        .read(podOperationsNotifierProvider.notifier)
        .reconcile(
          observedPodOperationStates(
            operations: ref.read(podOperationsNotifierProvider),
            podsByMachine: {
              for (final (machineId, pods) in results) machineId: ?pods,
            },
          ),
        );

    setState(() {
      _podsByMachine = nextPodsByMachine;
      _unreachable = unreachable;
      _machineFetch
        ..clear()
        ..addAll(nextFetch);
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
    if (!entry.canControl) {
      final op = entry.operation;
      if (op != null && op.isPending && mounted) {
        final l10n = context.l10n;
        context.showSnack(
          l10n.kubernetesActionInProgress(
            kubernetesPodActionLabel(l10n, op.action),
          ),
        );
      }
      return;
    }
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
    final submitted = ref
        .read(podOperationsNotifierProvider.notifier)
        .submitAction(
          machineId: entry.machineId!,
          sessionId: entry.sessionId,
          action: action,
        );
    if (!submitted && mounted) {
      context.showSnack(
        l10n.kubernetesActionInProgress(kubernetesPodActionLabel(l10n, action)),
      );
    }
  }

  void _enterSelection([String? key]) {
    setState(() => _selection = {?key});
  }

  void _exitSelection() {
    if (_selection == null) return;
    setState(() => _selection = null);
  }

  void _toggleSelected(String key) {
    final selection = _selection;
    if (selection == null) return;
    setState(() {
      _selection = selection.contains(key)
          ? ({...selection}..remove(key))
          : {...selection, key};
    });
  }

  /// Archives the sessions of [targets] after one confirmation. Each archive
  /// syncs in the background (stopping the pod, keeping its workspace); the
  /// rows leave the list at once.
  Future<void> _archive(List<KubernetesPodEntry> targets) async {
    final archivable = [
      for (final entry in targets)
        if (entry.canArchive) entry,
    ];
    if (archivable.isEmpty) return;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.sessionsArchiveNConfirm(archivable.length),
      content: switch (archivable) {
        [final only] =>
          '${only.sessionTitle ?? only.podName}\n\n'
              '${l10n.kubernetesArchiveHint}',
        _ => l10n.kubernetesArchiveHint,
      },
      confirmLabel: l10n.sessionsArchive,
    );
    if (!confirmed || !mounted) return;
    final operations = ref.read(sessionOperationsNotifierProvider.notifier);
    var rejected = 0;
    setState(() {
      for (final entry in archivable) {
        if (operations.archive(entry.session!)) {
          _archivedSessionIds.add(entry.sessionId);
        } else {
          rejected++;
        }
      }
      _selection = null;
    });
    if (rejected > 0 && mounted) {
      context.showSnack(l10n.kubernetesArchiveInProgress);
    }
  }

  /// A failed archive restores its row (the failure itself is reported by
  /// the app-wide operation failure listener). Successful or superseded
  /// archive operations drop their optimistic hide once the catalog can
  /// reflect the archived state, so an unarchived session is never stuck
  /// hidden by this screen's local set.
  void _onSessionOperationsChanged(
    Map<String, SessionOperation>? previous,
    Map<String, SessionOperation> next,
  ) {
    if (!mounted) return;
    if (_archivedSessionIds.isNotEmpty) {
      final restored = <String>[];
      final cleared = <String>[];
      for (final id in _archivedSessionIds) {
        final operation = next[id];
        if (operation == null) {
          cleared.add(id);
          continue;
        }
        if (operation.request.action != SessionOperationAction.archive) {
          cleared.add(id);
          continue;
        }
        if (operation.isFailed) {
          restored.add(id);
        } else if (!operation.isPending) {
          cleared.add(id);
        }
      }
      if (restored.isNotEmpty || cleared.isNotEmpty) {
        setState(() {
          _archivedSessionIds
            ..removeAll(restored)
            ..removeAll(cleared);
        });
      }
    }
  }

  /// Whether [entry]'s session is archived or being archived, so its pod
  /// no longer belongs on this screen.
  bool _isArchiving(
    KubernetesPodEntry entry,
    Map<String, SessionOperation> sessionOperations,
  ) {
    if (entry.session?.archived ?? false) return true;
    final id = entry.sessionId;
    if (id.isEmpty) return false;
    final operation = sessionOperations[id];
    if (operation != null &&
        !operation.isFailed &&
        operation.request.action == SessionOperationAction.archive) {
      return true;
    }
    return _archivedSessionIds.contains(id);
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

  String _unreachableMessage(AppLocalizations l10n) {
    if (_unreachable.isEmpty) return '';
    final machines = ref.read(machinesNotifierProvider);
    final names = _unreachable.map((id) {
      final machine = machines[id];
      final host = machine?.metadata?.displayName ?? machine?.metadata?.host;
      if (host != null && host.trim().isNotEmpty) return host.trim();
      return id.length > 8 ? '${id.substring(0, 8)}…' : id;
    }).toList()..sort();
    final base = l10n.kubernetesUnreachable(_unreachable.length);
    if (names.length <= 3) {
      return '$base ${l10n.kubernetesUnreachableDetails(names.join(', '))}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    ref.listen(machinesNotifierProvider, (_, _) => _scheduleCatalogRefresh());
    ref.listen(sessionsNotifierProvider, (_, _) => _scheduleCatalogRefresh());
    ref.listen(podOperationsNotifierProvider, _onOperationsChanged);
    ref.listen(sessionOperationsNotifierProvider, _onSessionOperationsChanged);
    final operations = ref.watch(podOperationsNotifierProvider);
    final sessionOperations = ref.watch(sessionOperationsNotifierProvider);
    final merged =
        applyPodOperations(
              mergeKubernetesPods(
                sessions: ref.watch(sessionsNotifierProvider),
                podsByMachine: _podsByMachine,
              ),
              operations,
            )
            .where((entry) => !_isArchiving(entry, sessionOperations))
            .map(
              (entry) => _unreachable.contains(entry.machineId)
                  ? entry.withLive(false)
                  : entry,
            );
    final entries = _newestFirst
        ? merged.toList()
        : merged.toList().reversed.toList();
    final archivable = [
      for (final entry in entries)
        if (entry.canArchive) entry,
    ];
    // Rows that left the list (or became busy) drop out of the selection.
    final selection = _selection;
    final selected = selection == null
        ? const <KubernetesPodEntry>[]
        : [
            for (final entry in archivable)
              if (selection.contains(entry.key)) entry,
          ];
    final selecting = selection != null;
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
      final rows = <Widget>[];
      for (final entry in entries) {
        if (rows.isNotEmpty) {
          rows.add(Divider(height: 1, thickness: 1, color: cs.outlineVariant));
        }
        final session = entry.session;
        final lastSuccessMs = entry.machineId == null
            ? null
            : _machineFetch[entry.machineId!]?.lastSuccessMs;
        rows.add(
          KubernetesPodTile(
            key: ValueKey('kubernetes-pod-${entry.key}'),
            entry: entry,
            now: now,
            lastUpdatedMs: lastSuccessMs,
            selected: selecting ? selected.contains(entry) : null,
            onTap: selecting
                ? (entry.canArchive ? () => _toggleSelected(entry.key) : null)
                : session == null
                ? null
                : () => _openChat(session),
            onLongPress: selecting || !entry.canArchive
                ? null
                : () => _enterSelection(entry.key),
            onInfo: session == null ? null : () => _openInfo(session),
            onAction: (entry.canControl || entry.busy)
                ? (action) => unawaited(_runAction(entry, action))
                : null,
            onArchive: entry.canArchive
                ? () => unawaited(_archive([entry]))
                : null,
            onRetry: () => ref
                .read(podOperationsNotifierProvider.notifier)
                .retry(entry.key),
            onDismiss: () => ref
                .read(podOperationsNotifierProvider.notifier)
                .dismiss(entry.key),
          ),
        );
      }
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
              message: _unreachableMessage(l10n),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (entries.isNotEmpty) ...[
            KubernetesPodsSummary(entries: entries),
            const SizedBox(height: AppSpacing.sm),
            Card(
              key: const Key('kubernetes-pod-list'),
              margin: EdgeInsets.zero,
              color: cs.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(color: cs.outlineVariant),
              ),
              child: Column(children: rows),
            ),
          ],
        ],
      );
    }

    final allSelected =
        selected.isNotEmpty && selected.length == archivable.length;
    final appBar = selecting
        ? AppBar(
            leading: IconButton(
              key: const Key('kubernetes-selection-close'),
              tooltip: l10n.commonClose,
              icon: const Icon(Icons.close_rounded),
              onPressed: _exitSelection,
            ),
            title: Text(l10n.sessionsSelectedCount(selected.length)),
            actions: [
              IconButton(
                key: const Key('kubernetes-select-all'),
                tooltip: allSelected
                    ? l10n.sessionsDeselectAll
                    : l10n.sessionsSelectAll,
                icon: Icon(
                  allSelected
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                ),
                onPressed: archivable.isEmpty
                    ? null
                    : () => setState(
                        () => _selection = allSelected
                            ? <String>{}
                            : {for (final entry in archivable) entry.key},
                      ),
              ),
              IconButton(
                key: const Key('kubernetes-archive-selected'),
                tooltip: l10n.sessionsArchive,
                icon: const Icon(Icons.archive_outlined),
                onPressed: selected.isEmpty
                    ? null
                    : () => unawaited(_archive(selected)),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          )
        : AppBar(
            title: Text(l10n.kubernetesTitle),
            actions: [
              PopupMenuButton<bool>(
                key: const Key('kubernetes-sort'),
                tooltip: l10n.kubernetesSort,
                icon: Icon(Icons.sort_rounded, color: cs.onSurfaceVariant),
                initialValue: _newestFirst,
                onSelected: (newest) => setState(() => _newestFirst = newest),
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: true,
                    checked: _newestFirst,
                    child: Text(l10n.kubernetesSortNewest),
                  ),
                  CheckedPopupMenuItem(
                    value: false,
                    checked: !_newestFirst,
                    child: Text(l10n.kubernetesSortOldest),
                  ),
                ],
              ),
              if (archivable.isNotEmpty)
                IconButton(
                  key: const Key('kubernetes-select'),
                  tooltip: l10n.kubernetesSelectPods,
                  onPressed: _enterSelection,
                  icon: Icon(
                    Icons.checklist_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
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
          );

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        appBar: appBar,
        body: RefreshIndicator(onRefresh: _refresh, child: body),
      ),
    );
  }
}

/// One line over the list: how many pods there are, how many are in each
/// state, and the CPU and memory they use when the cluster reports metrics.
class KubernetesPodsSummary extends StatelessWidget {
  const KubernetesPodsSummary({required this.entries, super.key});

  final List<KubernetesPodEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final counts = <SessionPodDisplayState, int>{};
    for (final entry in entries) {
      counts[entry.state] = (counts[entry.state] ?? 0) + 1;
    }
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
    final states = [
      for (final state in const [
        SessionPodDisplayState.failed,
        SessionPodDisplayState.scheduling,
        SessionPodDisplayState.ready,
        SessionPodDisplayState.paused,
      ])
        if ((counts[state] ?? 0) > 0)
          kubernetesPodCountLabel(l10n, state, counts[state]!),
    ];
    return Padding(
      key: const Key('kubernetes-summary'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: l10n.kubernetesPodCount(entries.length),
                      style: AppText.label(theme, theme.colorScheme.onSurface),
                    ),
                    for (final label in states) TextSpan(text: ' · $label'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.secondary(theme),
              ),
            ),
          ),
          if (sampled) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              key: const Key('kubernetes-summary-usage'),
              '${l10n.kubernetesCpu} ${formatCpuCores(cpu)} · '
              '${l10n.kubernetesMemory} ${formatBinaryBytes(memory)}',
              style: AppText.badge(theme),
            ),
          ],
        ],
      ),
    );
  }
}
