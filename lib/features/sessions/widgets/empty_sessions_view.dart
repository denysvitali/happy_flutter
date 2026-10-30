import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_circular_progress_indicator.dart';
import '../../auth/widgets/agent_mascot_cluster.dart';
import 'new_session_dialog.dart';

/// Empty sessions view with tiered state.
///
/// First-time users see the computer-linking path, offline users get recovery
/// actions, and ready users get a direct start-session action.
class EmptySessionsView extends ConsumerStatefulWidget {
  const EmptySessionsView({
    super.key,
    this.onCreateSession,
    this.onRefreshMachines,
    this.onManageMachines,
  });

  /// Parent-owned create flow. When set, the CTA uses it so a successful
  /// create can open the new chat (push / tablet-select). The local fallback
  /// only shows the dialog and drops the returned session id.
  final Future<void> Function()? onCreateSession;

  /// Optional refresh override, primarily for parent coordination and tests.
  final Future<void> Function()? onRefreshMachines;

  /// Optional computer-management override.
  final VoidCallback? onManageMachines;

  @override
  ConsumerState<EmptySessionsView> createState() => _EmptySessionsViewState();
}

class _EmptySessionsViewState extends ConsumerState<EmptySessionsView> {
  bool _isRefreshing = false;
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesNotifierProvider);
    final isFirstTimeUser = machines.isEmpty;
    final hasOnlineMachine = machines.values.any((machine) => machine.isOnline);

    if (isFirstTimeUser) {
      return _FirstTimeEmptyState(
        onConnectComputer: _isStarting ? null : _startOrConnect,
      );
    }

    if (!hasOnlineMachine) {
      return _OfflineMachinesEmptyState(
        isRefreshing: _isRefreshing,
        onRefresh: _refreshMachines,
        onManageMachines: _manageMachines,
      );
    }

    final online = machines.values.where((machine) => machine.isOnline);
    // Name the computer only when the choice is unambiguous.
    final machineName = online.length == 1 ? online.first.displayLabel : null;
    return _ReturningUserEmptyState(
      machineName: machineName,
      onNewSession: _isStarting ? null : _startOrConnect,
    );
  }

  Future<void> _startOrConnect() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final create = widget.onCreateSession;
      if (create != null) {
        await create();
        return;
      }
      final machines = ref.read(machinesNotifierProvider);
      if (machines.isEmpty) {
        await context.pushNamed('link');
        return;
      }
      if (!machines.values.any((machine) => machine.isOnline)) {
        _manageMachines();
        return;
      }
      await showNewSessionDialog(context);
    } catch (_) {
      if (mounted) _showActionError();
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _showActionError({VoidCallback? onRetry}) {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonError),
        action: onRetry == null
            ? null
            : SnackBarAction(label: l10n.commonRetry, onPressed: onRetry),
      ),
    );
  }

  Future<void> _refreshMachines() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final refresh = widget.onRefreshMachines;
      if (refresh != null) {
        await refresh();
      } else {
        await ref.read(machinesNotifierProvider.notifier).refreshFromSync();
      }
    } catch (_) {
      if (mounted) {
        _showActionError(
          onRetry: () {
            if (mounted) _refreshMachines();
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _manageMachines() {
    final manage = widget.onManageMachines;
    if (manage != null) {
      manage();
      return;
    }
    context.pushNamed('machines');
  }
}

// ---------------------------------------------------------------------------
// First-time user: progressively disclosed setup guidance
// ---------------------------------------------------------------------------

class _FirstTimeEmptyState extends StatelessWidget {
  const _FirstTimeEmptyState({required this.onConnectComputer});

  final VoidCallback? onConnectComputer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return _HeroEmptyState(
      title: l10n.polishOnboardingTitle,
      subtitle: l10n.polishOnboardingPromise,
      primary: _PillButton(
        onPressed: onConnectComputer,
        icon: Icons.qr_code_scanner_outlined,
        label: l10n.sessionsConnectComputer,
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.polishOnboardingSetupHeader,
              style: AppText.label(theme, theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _OnboardingStepCard(
            step: 1,
            label: l10n.emptySessionsFirstTimeStep1Label,
            detail: l10n.emptySessionsFirstTimeStep1Detail,
          ),
          const SizedBox(height: AppSpacing.sm),
          _OnboardingStepCard(
            step: 2,
            label: l10n.emptySessionsFirstTimeStep2Label,
            detail: l10n.emptySessionsFirstTimeStep2Detail,
          ),
          const SizedBox(height: AppSpacing.sm),
          _OnboardingStepCard(
            step: 3,
            label: l10n.emptySessionsFirstTimeStep3Label,
            detail: l10n.emptySessionsFirstTimeStep3Detail,
          ),
        ],
      ),
    );
  }
}

class _OfflineMachinesEmptyState extends StatelessWidget {
  const _OfflineMachinesEmptyState({
    required this.isRefreshing,
    required this.onRefresh,
    required this.onManageMachines,
  });

  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onManageMachines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: Icons.computer_outlined,
      title: l10n.emptySessionsOfflineTitle,
      subtitle: l10n.emptySessionsOfflineSubtitle,
      action: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        alignment: WrapAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox.square(
                    dimension: AppIconSize.md,
                    child: AppCircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(l10n.commonRefresh),
          ),
          OutlinedButton.icon(
            onPressed: onManageMachines,
            icon: const Icon(Icons.settings_outlined),
            label: Text(l10n.sessionsViewComputers),
          ),
        ],
      ),
    );
  }
}

/// Keeps setup labels visible while revealing commands on demand.
class _OnboardingStepCard extends StatelessWidget {
  const _OnboardingStepCard({
    required this.step,
    required this.label,
    required this.detail,
  });

  final int step;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        width: AppBorder.hairline,
      ),
    );

    return ExpansionTile(
      key: PageStorageKey('empty-session-onboarding-step-$step'),
      initiallyExpanded: step == 1,
      expansionAnimationStyle: AppMotion.reduceMotion(context)
          ? AnimationStyle.noAnimation
          : null,
      minTileHeight: AppTouchTarget.comfortable,
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      expandedAlignment: AlignmentDirectional.centerStart.resolve(
        Directionality.of(context),
      ),
      shape: shape,
      collapsedShape: shape,
      backgroundColor: cs.surfaceContainerLow,
      collapsedBackgroundColor: cs.surfaceContainerLow,
      leading: ExcludeSemantics(
        child: CircleAvatar(
          radius: AppSpacing.md,
          backgroundColor: cs.primaryContainer,
          child: Text(
            '$step',
            style: AppText.secondary(theme, cs.onPrimaryContainer),
          ),
        ),
      ),
      title: Text(
        label,
        semanticsLabel: '$step. $label',
        style: AppText.title(theme),
      ),
      children: [
        SelectableText(
          detail,
          key: PageStorageKey('empty-session-onboarding-command-$step'),
          style: AppText.secondary(
            theme,
            cs.onSurfaceVariant,
          ).copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Returning user: minimal "no active sessions" state
// ---------------------------------------------------------------------------

class _ReturningUserEmptyState extends StatelessWidget {
  const _ReturningUserEmptyState({
    required this.onNewSession,
    required this.machineName,
  });

  final VoidCallback? onNewSession;

  /// The single online computer, or null when there are several.
  final String? machineName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machine = machineName;

    return _HeroEmptyState(
      title: l10n.polishEmptyReadyTitle,
      subtitle: machine == null
          ? l10n.polishEmptyReadySubtitleGeneric
          : l10n.polishEmptyReadySubtitle(machine),
      primary: _PillButton(
        onPressed: onNewSession,
        icon: Icons.add_rounded,
        label: machine == null
            ? l10n.sessionsStartSession
            : l10n.polishEmptyReadyAction(machine),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared hero layout: mascot cluster, one-line promise, one primary action.
// ---------------------------------------------------------------------------

class _HeroEmptyState extends StatelessWidget {
  const _HeroEmptyState({
    required this.title,
    required this.subtitle,
    required this.primary,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget primary;
  final Widget? footer;

  static const double _maxWidth = 420;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final extra = footer;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.hero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AgentMascotCluster(height: 132)),
          const SizedBox(height: AppSpacing.xxl),
          Semantics(
            container: true,
            label: context.l10n.a11yEmptyState(title, subtitle),
            excludeSemantics: true,
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          primary,
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: AppIconSize.sm,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  context.l10n.polishTrustLine,
                  textAlign: TextAlign.center,
                  style: AppText.secondary(theme, cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
          if (extra != null) ...[
            const SizedBox(height: AppSpacing.hero),
            extra,
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width pill primary action (Grok/Dots style).
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppTouchTarget.comfortable + 4),
        shape: const StadiumBorder(),
        textStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
