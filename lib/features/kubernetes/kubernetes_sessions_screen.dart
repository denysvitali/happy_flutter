import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_badge.dart';
import '../../core/components/app_banner.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/rpc/rpc_types.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/services/sync_service.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_circular_progress_indicator.dart';
import 'kubernetes_pod_state.dart';
import 'kubernetes_pods_model.dart';

/// Loads one machine's session pods. Injectable for tests.
typedef KubernetesPodsLoader =
    Future<List<SessionPod>> Function(String machineId);

/// Live list of Kubernetes session pods across every reachable daemon,
/// grouped by pod state. Rows open the session's chat; the info button
/// opens Session info, which owns the pod controls and logs.
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
    setState(() {
      _podsByMachine = {
        for (final (machineId, pods) in results)
          if (pods != null) machineId: pods,
      };
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final entries = mergeKubernetesPods(
      sessions: ref.watch(sessionsNotifierProvider),
      podsByMachine: _podsByMachine,
    );
    final groups = <SessionPodDisplayState, List<KubernetesPodEntry>>{};
    for (final entry in entries) {
      (groups[entry.state] ??= []).add(entry);
    }

    final Widget body;
    if (!_loaded && entries.isEmpty) {
      body = const AppLoadingIndicator();
    } else if (entries.isEmpty && _unreachable.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: Icons.cloud_outlined,
            title: l10n.kubernetesEmptyTitle,
            subtitle: l10n.kubernetesEmptyHint,
          ),
        ],
      );
    } else {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          if (_unreachable.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: AppBanner(
                key: const Key('kubernetes-unreachable'),
                tone: AppBadgeTone.warning,
                message: l10n.kubernetesUnreachable(_unreachable.length),
              ),
            ),
          for (final MapEntry(key: state, value: rows) in groups.entries)
            SettingsSection(
              key: Key('kubernetes-section-${state.name}'),
              title: kubernetesPodCountLabel(l10n, state, rows.length),
              children: [
                for (final entry in rows)
                  KubernetesPodTile(
                    key: ValueKey('kubernetes-pod-${entry.key}'),
                    entry: entry,
                    onTap: entry.session == null
                        ? null
                        : () => _openChat(entry.session!),
                    onInfo: entry.session == null
                        ? null
                        : () => _openInfo(entry.session!),
                  ),
              ],
            ),
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
        ],
      ),
      body: RefreshIndicator(onRefresh: _refresh, child: body),
    );
  }
}

/// One pod row: session title (or pod name for an untracked pod), the pod
/// name and namespace, the repository, any failure detail, and its state.
class KubernetesPodTile extends StatelessWidget {
  const KubernetesPodTile({
    required this.entry,
    super.key,
    this.onTap,
    this.onInfo,
  });

  final KubernetesPodEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = entry.state;
    final tone = kubernetesPodStateTone(state);
    final title = entry.sessionTitle;
    final podLine = [
      if (title != null && entry.podName.isNotEmpty) entry.podName,
      if (entry.namespace.isNotEmpty) entry.namespace,
    ].join(' · ');
    final repo = entry.repoUrl.isEmpty
        ? ''
        : entry.repoRef.isEmpty
        ? entry.repoUrl
        : '${entry.repoUrl} @ ${entry.repoRef}';
    final detail = entry.detail;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppTouchTarget.comfortable,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              SettingsIconContainer(
                icon: Icons.cloud_outlined,
                color: AppToneColors.of(context, tone).iconColor,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? entry.podName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: title == null ? 'monospace' : null,
                      ),
                    ),
                    if (title == null)
                      Text(
                        l10n.kubernetesUntrackedPod,
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                      ),
                    if (podLine.isNotEmpty)
                      Text(
                        podLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.mono(theme, cs.onSurfaceVariant),
                      ),
                    if (repo.isNotEmpty)
                      Text(
                        repo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                      ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.secondary(
                          theme,
                          state == SessionPodDisplayState.failed
                              ? cs.error
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppBadge(
                          label: kubernetesPodStateLabel(l10n, state),
                          tone: tone,
                        ),
                        if (!entry.live)
                          AppBadge(label: l10n.kubernetesLastKnown),
                      ],
                    ),
                  ],
                ),
              ),
              if (onInfo != null)
                IconButton(
                  tooltip: l10n.kubernetesSessionInfo,
                  onPressed: onInfo,
                  icon: Icon(
                    Icons.info_outline_rounded,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
