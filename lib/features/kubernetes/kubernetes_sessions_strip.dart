import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_badge.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import 'kubernetes_pod_state.dart';

/// Pod-state counts of the live Kubernetes sessions in the catalog.
///
/// Value equality keeps the sessions-home strip from rebuilding on every
/// catalog publish: only a changed count repaints it.
@immutable
class KubernetesSessionCounts {
  const KubernetesSessionCounts({
    this.ready = 0,
    this.scheduling = 0,
    this.paused = 0,
    this.failed = 0,
  });

  factory KubernetesSessionCounts.fromSessions(Map<String, Session> sessions) {
    var ready = 0;
    var scheduling = 0;
    var paused = 0;
    var failed = 0;
    for (final session in sessions.values) {
      if (!isLiveKubernetesSession(session)) continue;
      switch (session.podDisplayState) {
        case SessionPodDisplayState.ready:
          ready++;
        case SessionPodDisplayState.scheduling:
          scheduling++;
        case SessionPodDisplayState.paused:
          paused++;
        case SessionPodDisplayState.failed:
          failed++;
        case SessionPodDisplayState.archived:
          break;
      }
    }
    return KubernetesSessionCounts(
      ready: ready,
      scheduling: scheduling,
      paused: paused,
      failed: failed,
    );
  }

  final int ready;
  final int scheduling;
  final int paused;
  final int failed;

  int get total => ready + scheduling + paused + failed;

  @override
  bool operator ==(Object other) =>
      other is KubernetesSessionCounts &&
      other.ready == ready &&
      other.scheduling == scheduling &&
      other.paused == paused &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(ready, scheduling, paused, failed);
}

/// One-line Kubernetes summary at the top of the sessions home view:
/// how many session pods are running, starting, paused or failed. Tapping
/// opens the live pod list. Hidden when no Kubernetes session is live.
class KubernetesSessionsStrip extends ConsumerWidget {
  const KubernetesSessionsStrip({
    super.key,
    this.compact = false,
    this.tight = false,
  });

  /// Renders the pill that shares a row with other controls instead of
  /// the full-width strip.
  final bool compact;

  /// With [compact], shows the bare count instead of "1 starting".
  final bool tight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(
      sessionsNotifierProvider.select(KubernetesSessionCounts.fromSessions),
    );
    if (counts.total == 0) return const SizedBox.shrink();
    void open() => unawaited(context.pushNamed('kubernetes'));
    if (compact) {
      return KubernetesSessionsPill(counts: counts, onTap: open, tight: tight);
    }
    return KubernetesSessionsStripView(counts: counts, onTap: open);
  }
}

/// Stateless body of [KubernetesSessionsStrip], split out for tests.
class KubernetesSessionsStripView extends StatelessWidget {
  const KubernetesSessionsStripView({
    required this.counts,
    required this.onTap,
    super.key,
  });

  final KubernetesSessionCounts counts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final badges = <Widget>[
      if (counts.ready > 0)
        _countBadge(l10n, SessionPodDisplayState.ready, counts.ready),
      if (counts.scheduling > 0)
        _countBadge(l10n, SessionPodDisplayState.scheduling, counts.scheduling),
      if (counts.paused > 0)
        _countBadge(l10n, SessionPodDisplayState.paused, counts.paused),
      if (counts.failed > 0)
        _countBadge(l10n, SessionPodDisplayState.failed, counts.failed),
    ];
    return Semantics(
      button: true,
      label: l10n.kubernetesStripSemantics(counts.total),
      excludeSemantics: true,
      child: Material(
        key: const Key('kubernetes-sessions-strip'),
        color: cs.surfaceContainerLow,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.comfortable,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_outlined,
                    size: AppIconSize.md,
                    color: cs.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.kubernetesTitle,
                    style: AppText.label(theme, cs.onSurface),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (index, badge) in badges.indexed) ...[
                            if (index > 0) const SizedBox(width: AppSpacing.xs),
                            badge,
                          ],
                        ],
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: AppIconSize.md,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _countBadge(
    AppLocalizations l10n,
    SessionPodDisplayState state,
    int count,
  ) => AppBadge(
    label: kubernetesPodCountLabel(l10n, state, count),
    tone: kubernetesPodStateTone(state),
  );
}

/// Compact Kubernetes summary for a row shared with other controls: the
/// cloud mark and the one pod state that most needs attention. Tapping
/// opens the live pod list, like the full strip.
class KubernetesSessionsPill extends StatelessWidget {
  const KubernetesSessionsPill({
    required this.counts,
    required this.onTap,
    super.key,
    this.tight = false,
  });

  final KubernetesSessionCounts counts;
  final VoidCallback onTap;

  /// Shows the bare count; the state stays in the badge tone and the
  /// spoken label.
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    // Trouble first, then what is still coming up, then steady state.
    final (state, count) = counts.failed > 0
        ? (SessionPodDisplayState.failed, counts.failed)
        : counts.scheduling > 0
        ? (SessionPodDisplayState.scheduling, counts.scheduling)
        : counts.ready > 0
        ? (SessionPodDisplayState.ready, counts.ready)
        : (SessionPodDisplayState.paused, counts.paused);
    return Semantics(
      button: true,
      label: l10n.kubernetesStripSemantics(counts.total),
      excludeSemantics: true,
      child: InkWell(
        key: const Key('kubernetes-sessions-pill'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_outlined,
                  size: AppIconSize.md,
                  color: cs.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: AppBadge(
                    label: tight
                        ? '$count'
                        : kubernetesPodCountLabel(l10n, state, count),
                    tone: kubernetesPodStateTone(state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
