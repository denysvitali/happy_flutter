import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_tokens.dart';
import 'new_session_dialog.dart';

/// Empty sessions view with tiered state.
///
/// First-time users (no machines ever connected) see an onboarding-style
/// 3-step guidance card: install CLI, start daemon, scan QR code.
/// Returning users (machines known but no active sessions) see a minimal
/// "no active sessions" state with a start-session CTA.
class EmptySessionsView extends ConsumerWidget {
  const EmptySessionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machines = ref.watch(machinesNotifierProvider);
    final isFirstTimeUser = machines.isEmpty;

    if (isFirstTimeUser) {
      return _FirstTimeEmptyState(
        onNewSession: () {
          _showNewSessionDialog(context);
        },
      );
    }

    return _ReturningUserEmptyState(
      onNewSession: () {
        _showNewSessionDialog(context);
      },
    );
  }

  Future<void> _showNewSessionDialog(BuildContext context) async {
    await showNewSessionDialog(context);
  }
}

// ---------------------------------------------------------------------------
// First-time user: 3-step illustrated guidance card
// ---------------------------------------------------------------------------

class _FirstTimeEmptyState extends StatelessWidget {
  const _FirstTimeEmptyState({required this.onNewSession});

  final VoidCallback onNewSession;

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
            onPressed: onNewSession,
            icon: const Icon(Icons.add),
            label: Text(l10n.sessionNewSession),
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
        label: Text(l10n.sessionNewSession),
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
