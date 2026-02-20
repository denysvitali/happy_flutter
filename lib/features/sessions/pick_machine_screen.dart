import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/components.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

/// Screen for selecting a machine from the list of available machines.
///
/// Pops with the selected [Machine] object when a machine is tapped.
class PickMachineScreen extends ConsumerWidget {
  const PickMachineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final machines =
        ref.watch(machinesNotifierProvider).values.toList();
    final sessions = ref.watch(sessionsNotifierProvider);
    final theme = Theme.of(context);

    // Compute recent machines from sessions (most recently updated first)
    final recentMachineIds = <String>[];
    final seen = <String>{};
    final sortedSessions = sessions.values.toList()
      ..sort((a, b) =>
          (b.updatedAt).compareTo(a.updatedAt));
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
    final otherMachines = machines
        .where((m) => !seen.contains(m.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Machine'),
      ),
      body: machines.isEmpty
          ? Center(
              child: Text(
                'No machines available',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              children: [
                if (recentMachines.isNotEmpty) ...[
                  const AppSectionHeader(title: 'Recent'),
                  ...recentMachines.map(
                    (machine) => _MachineListTile(
                      machine: machine,
                      showRecentIcon: true,
                      onTap: () => context.pop(machine),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (otherMachines.isNotEmpty) ...[
                  if (recentMachines.isNotEmpty)
                    const AppSectionHeader(title: 'All Machines'),
                  ...otherMachines.map(
                    (machine) => _MachineListTile(
                      machine: machine,
                      showRecentIcon: false,
                      onTap: () => context.pop(machine),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _MachineListTile extends StatelessWidget {

  const _MachineListTile({
    required this.machine,
    required this.showRecentIcon,
    required this.onTap,
  });
  final Machine machine;
  final bool showRecentIcon;
  final VoidCallback onTap;

  bool get _isOnline {
    final now = DateTime.now().millisecondsSinceEpoch;
    const onlineThresholdMs = 60 * 1000; // 1 minute
    return now - machine.activeAt < onlineThresholdMs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = machine.metadata?.displayName ??
        machine.metadata?.host ??
        machine.id;
    final host = machine.metadata?.host;
    final isOnline = _isOnline;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            showRecentIcon
                ? Icons.history
                : Icons.computer_outlined,
            color: theme.colorScheme.onSurfaceVariant,
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
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppStatusDot(
                color: isOnline
                    ? Colors.green
                    : theme.colorScheme.outlineVariant,
                size: 8,
                pulse: isOnline,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                isOnline ? 'online' : 'offline',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isOnline
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
