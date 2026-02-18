import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';

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
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (recentMachines.isNotEmpty) ...[
                  _SectionHeader(title: 'Recent Machines'),
                  ...recentMachines.map(
                    (machine) => _MachineListTile(
                      machine: machine,
                      showRecentIcon: true,
                      onTap: () => context.pop(machine),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (otherMachines.isNotEmpty) ...[
                  if (recentMachines.isNotEmpty)
                    _SectionHeader(title: 'All Machines'),
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MachineListTile extends StatelessWidget {
  final Machine machine;
  final bool showRecentIcon;
  final VoidCallback onTap;

  const _MachineListTile({
    required this.machine,
    required this.showRecentIcon,
    required this.onTap,
  });

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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(
                showRecentIcon
                    ? Icons.history
                    : Icons.computer_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (host != null &&
                        host != displayName)
                      Text(
                        host,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? Colors.green
                          : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'online' : 'offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline
                          ? Colors.green
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
