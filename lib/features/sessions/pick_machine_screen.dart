import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/components.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Screen for selecting a machine from the list of available machines.
///
/// Pops with the selected [Machine] object when a machine is tapped.
class PickMachineScreen extends ConsumerWidget {
  const PickMachineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final machines =
        ref.watch(machinesNotifierProvider).values.toList();
    final sessions = ref.watch(sessionsNotifierProvider);
    final theme = Theme.of(context);

    // Compute recent machines from sessions (most recently updated)
    final recentMachineIds = <String>[];
    final seen = <String>{};
    final sortedSessions = sessions.values.toList()
      ..sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );
    for (final session in sortedSessions) {
      final mid = session.metadata?.machineId;
      if (mid != null && !seen.contains(mid)) {
        seen.add(mid);
        recentMachineIds.add(mid);
      }
    }
    final recentMachines = recentMachineIds
        .map((id) {
          try {
            return machines.firstWhere((m) => m.id == id);
          } catch (_) {
            return null;
          }
        })
        .whereType<Machine>()
        .toList();
    final otherMachines =
        machines.where((m) => !seen.contains(m.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pickSelectMachine),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      body: machines.isEmpty
          ? AppEmptyState(
              icon: Icons.computer_outlined,
              title: l10n.pickNoMachinesAvailable,
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              children: [
                if (recentMachines.isNotEmpty) ...[
                  AppSectionHeader(title: l10n.pickRecent),
                  const SizedBox(height: AppSpacing.xs),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0;
                            i < recentMachines.length;
                            i++) ...[
                          _MachineListTile(
                            machine: recentMachines[i],
                            showRecentIcon: true,
                            isFirst: i == 0,
                            isLast:
                                i == recentMachines.length - 1,
                            onTap: () => context
                                .pop(recentMachines[i]),
                          ),
                          if (i < recentMachines.length - 1)
                            Divider(
                              height: 1,
                              indent: AppSpacing.lg +
                                  36 +
                                  AppSpacing.md,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
                if (otherMachines.isNotEmpty) ...[
                  if (recentMachines.isNotEmpty)
                    AppSectionHeader(
                      title: l10n.pickAllMachines,
                    ),
                  if (recentMachines.isNotEmpty)
                    const SizedBox(height: AppSpacing.xs),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (int i = 0;
                            i < otherMachines.length;
                            i++) ...[
                          _MachineListTile(
                            machine: otherMachines[i],
                            showRecentIcon: false,
                            isFirst: i == 0,
                            isLast:
                                i == otherMachines.length - 1,
                            onTap: () =>
                                context.pop(otherMachines[i]),
                          ),
                          if (i < otherMachines.length - 1)
                            Divider(
                              height: 1,
                              indent: AppSpacing.lg +
                                  36 +
                                  AppSpacing.md,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}

class _MachineListTile extends StatelessWidget {
  const _MachineListTile({
    required this.machine,
    required this.showRecentIcon,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final Machine machine;
  final bool showRecentIcon;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  bool get _isOnline {
    final now = DateTime.now().millisecondsSinceEpoch;
    const onlineThresholdMs = 60 * 1000; // 1 minute
    return now - machine.activeAt < onlineThresholdMs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final displayName = machine.metadata?.displayName ??
        machine.metadata?.host ??
        machine.id;
    final host = machine.metadata?.host;
    final isOnline = _isOnline;

    final borderRadius = BorderRadius.vertical(
      top: isFirst
          ? const Radius.circular(AppRadius.lg)
          : Radius.zero,
      bottom: isLast
          ? const Radius.circular(AppRadius.lg)
          : Radius.zero,
    );

    return AppTappable(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.smd,
        ),
        child: Row(
          children: [
            SettingsIconContainer(
              icon: showRecentIcon
                  ? Icons.history_rounded
                  : Icons.computer_outlined,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (host != null && host != displayName)
                    Text(
                      host,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Online badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: (isOnline
                        ? AppColors.success
                        : cs.onSurfaceVariant)
                    .withValues(alpha: AppOpacity.subtle),
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppStatusDot(
                    color: isOnline
                        ? AppColors.success
                        : cs.outlineVariant,
                    size: 6,
                    pulse: isOnline,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    isOnline
                        ? context.l10n.sidebarStatusConnected
                        : context.l10n.settingsOffline,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOnline
                          ? AppColors.success
                          : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
