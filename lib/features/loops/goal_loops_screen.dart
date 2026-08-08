import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/remote_feature_failure_localization.dart';
import '../../core/models/loop.dart';
import '../../core/providers/goal_loops_notifier.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import 'create_goal_loop_sheet.dart';
import 'goal_loop_card.dart';

/// Goal loops across every machine.
///
/// A goal loop restarts itself with an empty context until its goal is
/// reached, so the interesting split is "still working" vs "stopped" — not
/// which machine it happens to run on. Active loops come first because they
/// are the ones the user might want to pause; finished ones are the record.
class GoalLoopsScreen extends ConsumerWidget {
  const GoalLoopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final loops = ref.watch(goalLoopsNotifierProvider);
    final active = loops.where((l) => !l.isTerminal).toList(growable: false);
    final finished = loops.where((l) => l.isTerminal).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.goalLoopsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CreateGoalLoopSheet.show(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.goalLoopsNewButton),
      ),
      body: loops.isEmpty
          ? AppEmptyState(
              icon: Icons.flag_outlined,
              title: l10n.goalLoopsEmptyTitle,
              subtitle: l10n.goalLoopsEmptyMessage,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                // Room for the FAB so the last card is never trapped under it.
                AppSpacing.xxl * 2,
              ),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(label: l10n.goalLoopsActiveSection),
                  ...active.map((loop) => _card(context, ref, loop)),
                ],
                if (finished.isNotEmpty) ...[
                  if (active.isNotEmpty) const SizedBox(height: AppSpacing.lg),
                  _SectionHeader(label: l10n.goalLoopsFinishedSection),
                  ...finished.map((loop) => _card(context, ref, loop)),
                ],
              ],
            ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Loop loop) {
    final notifier = ref.read(goalLoopsNotifierProvider.notifier);
    // Captured before the async mutations below so the callbacks never reach
    // for a context across an async gap.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final fallbackError = l10n.commonError;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GoalLoopCard(
        loop: loop,
        onPauseToggle: (paused) => notifier
            .setPaused(
              machineId: loop.machineId,
              loopId: loop.id,
              paused: paused,
            )
            .then((res) => _report(messenger, l10n, fallbackError, res)),
        onResume: () => notifier
            .resume(machineId: loop.machineId, loopId: loop.id)
            .then((res) => _report(messenger, l10n, fallbackError, res)),
        onDelete: () => notifier
            .delete(machineId: loop.machineId, loopId: loop.id)
            .then((res) => _report(messenger, l10n, fallbackError, res)),
        onOpenSession: (sessionId) => context.push('/chat/$sessionId'),
      ),
    );
  }

  /// Surfaces a failed mutation. Success is already visible in the list, so
  /// only errors are worth a snackbar.
  void _report(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    String fallbackError,
    MachineLoopResponse res,
  ) {
    if (res.success) return;
    final message = res.failureKind == null
        ? fallbackError
        : res.failureKind.localizedRemoteFeatureFailure(l10n);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
