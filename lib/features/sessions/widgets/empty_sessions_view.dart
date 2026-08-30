import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_tokens.dart';
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

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesNotifierProvider);
    final isFirstTimeUser = machines.isEmpty;
    final hasOnlineMachine = machines.values.any((machine) => machine.isOnline);

    if (isFirstTimeUser) {
      return _FirstTimeEmptyState(onConnectComputer: _startOrConnect);
    }

    if (!hasOnlineMachine) {
      return _OfflineMachinesEmptyState(
        isRefreshing: _isRefreshing,
        onRefresh: _refreshMachines,
        onManageMachines: _manageMachines,
      );
    }

    return _ReturningUserEmptyState(onNewSession: _startOrConnect);
  }

  Future<void> _startOrConnect() async {
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
// First-time user: 3-step illustrated guidance card
// ---------------------------------------------------------------------------

class _FirstTimeEmptyState extends StatelessWidget {
  const _FirstTimeEmptyState({required this.onConnectComputer});

  final VoidCallback onConnectComputer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppEmptyState(
      icon: Icons.rocket_launch_outlined,
      title: l10n.emptySessionsFirstTimeTitle,
      subtitle: l10n.emptySessionsFirstTimeSubtitle,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OnboardingStepCard(
            step: 1,
            label: l10n.emptySessionsFirstTimeStep1Label,
            detail: l10n.emptySessionsFirstTimeStep1Detail,
            icon: Icons.download_outlined,
            colorScheme: cs,
            theme: theme,
          ),
          const SizedBox(height: AppSpacing.sm),
          _OnboardingStepCard(
            step: 2,
            label: l10n.emptySessionsFirstTimeStep2Label,
            detail: l10n.emptySessionsFirstTimeStep2Detail,
            icon: Icons.play_circle_outline,
            colorScheme: cs,
            theme: theme,
          ),
          const SizedBox(height: AppSpacing.sm),
          _OnboardingStepCard(
            step: 3,
            label: l10n.emptySessionsFirstTimeStep3Label,
            detail: l10n.emptySessionsFirstTimeStep3Detail,
            icon: Icons.qr_code_scanner_outlined,
            colorScheme: cs,
            theme: theme,
          ),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            onPressed: onConnectComputer,
            icon: const Icon(Icons.qr_code_scanner_outlined),
            label: Text(l10n.sessionsConnectComputer),
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, AppTouchTarget.min),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
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

/// A single numbered step row inside the onboarding guidance card.
class _OnboardingStepCard extends StatelessWidget {
  const _OnboardingStepCard({
    required this.step,
    required this.label,
    required this.detail,
    required this.icon,
    required this.colorScheme,
    required this.theme,
  });

  final int step;
  final String label;
  final String detail;
  final IconData icon;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: AppBorder.hairline,
        ),
      ),
      child: Row(
        children: [
          // Step number badge.
          Container(
            width: AppSpacing.xl,
            height: AppSpacing.xl,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Step text.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(icon, size: AppSpacing.lg, color: cs.primary),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Returning user: minimal "no active sessions" state
// ---------------------------------------------------------------------------

class _ReturningUserEmptyState extends StatelessWidget {
  const _ReturningUserEmptyState({required this.onNewSession});

  final VoidCallback onNewSession;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppEmptyState(
      icon: Icons.computer_outlined,
      title: l10n.emptySessionsReturningTitle,
      subtitle: l10n.emptySessionsReturningSubtitle,
      action: FilledButton.icon(
        onPressed: onNewSession,
        icon: const Icon(Icons.add),
        label: Text(l10n.sessionsStartSession),
        style: FilledButton.styleFrom(
          minimumSize: const Size(160, AppTouchTarget.min),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
