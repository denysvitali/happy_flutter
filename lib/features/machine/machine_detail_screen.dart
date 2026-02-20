import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';

/// Detail screen for a single machine.
///
/// Shows machine info (name, host, OS, version) and lists sessions
/// connected to this machine.
class MachineDetailScreen extends ConsumerStatefulWidget {
  const MachineDetailScreen({required this.machineId, super.key});

  final String machineId;

  @override
  ConsumerState<MachineDetailScreen> createState() =>
      _MachineDetailScreenState();
}

class _MachineDetailScreenState
    extends ConsumerState<MachineDetailScreen> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref
          .read(machinesNotifierProvider.notifier)
          .refreshFromSync();
    });
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  bool _isMachineOnline(int activeAt) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const onlineThresholdMs = 60 * 1000; // 1 minute
    return now - activeAt < onlineThresholdMs;
  }

  String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'just now';
  }

  String _getSessionName(Session session) {
    final meta = session.metadata;
    if (meta?.name != null) return meta!.name!;
    if (meta?.path != null) {
      final parts = meta!.path!.split('/');
      return parts.last.isNotEmpty ? parts.last : meta.path!;
    }
    return session.id;
  }

  String _getSessionSubtitle(Session session) {
    return session.metadata?.path ?? session.metadata?.host ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesNotifierProvider);
    final sessions = ref.watch(sessionsNotifierProvider);
    final machine = machines[widget.machineId];
    final theme = Theme.of(context);

    if (machine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('')),
        body: Center(
          child: Text(
            'Machine not found',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final metadata = machine.metadata;
    final machineName = metadata?.displayName ??
        metadata?.host ??
        machine.id;
    final isOnline = _isMachineOnline(machine.activeAt);

    // Sessions for this machine, sorted by most recently updated
    final machineSessions = sessions.values
        .where((s) => s.metadata?.machineId == widget.machineId)
        .toList()
      ..sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

    // Recent distinct paths used on this machine
    final pathsSeen = <String>{};
    final recentPaths = <String>[];
    for (final s in machineSessions) {
      final p = s.metadata?.path;
      if (p != null && p.isNotEmpty && !pathsSeen.contains(p)) {
        pathsSeen.add(p);
        recentPaths.add(p);
        if (recentPaths.length >= 5) break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              machineName,
              style: const TextStyle(fontSize: 17),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'online' : 'offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(machinesNotifierProvider.notifier).refreshFromSync(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Machine info section
            _SectionCard(
              title: 'Machine',
              children: [
                if (metadata?.host != null)
                  _InfoRow(label: 'Host', value: metadata!.host),
                _InfoRow(
                  label: 'Machine ID',
                  value: widget.machineId,
                ),
                if (metadata?.username != null)
                  _InfoRow(
                    label: 'Username',
                    value: metadata!.username!,
                  ),
                if (metadata?.platform != null)
                  _InfoRow(
                    label: 'Platform',
                    value: metadata!.platform,
                  ),
                if (metadata?.arch != null)
                  _InfoRow(
                    label: 'Architecture',
                    value: metadata!.arch!,
                  ),
                if (metadata?.happyCliVersion != null)
                  _InfoRow(
                    label: 'CLI Version',
                    value: metadata!.happyCliVersion,
                    mono: true,
                  ),
                if (metadata?.homeDir != null)
                  _InfoRow(
                    label: 'Home Dir',
                    value: metadata!.homeDir,
                    mono: true,
                  ),
                _InfoRow(
                  label: 'Last Seen',
                  value: _formatTimestamp(machine.activeAt),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Daemon status section
            _SectionCard(
              title: 'Daemon',
              children: [
                _InfoRow(
                  label: 'Status',
                  value: isOnline ? 'likely alive' : 'stopped',
                  valueColor: isOnline
                      ? Colors.green
                      : Colors.orange,
                ),
                if (metadata?.daemonLastKnownStatus != null)
                  _InfoRow(
                    label: 'Last Known Status',
                    value: metadata!.daemonLastKnownStatus!,
                  ),
                if (metadata?.daemonLastKnownPid != null)
                  _InfoRow(
                    label: 'Last Known PID',
                    value: metadata!.daemonLastKnownPid.toString(),
                    mono: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Sessions section
            if (machineSessions.isNotEmpty) ...[
              _SectionCard(
                title:
                    'Sessions (${machineSessions.length})',
                children: [
                  for (int i = 0;
                      i < machineSessions.length && i < 5;
                      i++)
                    _SessionTile(
                      session: machineSessions[i],
                      name: _getSessionName(
                        machineSessions[i],
                      ),
                      subtitle: _getSessionSubtitle(
                        machineSessions[i],
                      ),
                      showDivider: i <
                          (machineSessions.length > 5
                                  ? 5
                                  : machineSessions.length) -
                              1,
                      onTap: () => context.push(
                        '/chat/${machineSessions[i].id}',
                      ),
                    ),
                  if (machineSessions.length > 5)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        '+ ${machineSessions.length - 5} more sessions',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {

  const _SectionCard({
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Card(
          elevation: 0,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {

  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
  });
  final String label;
  final String? value;
  final bool mono;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (value == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: mono ? 'monospace' : null,
                fontSize: mono ? 13 : null,
                color: valueColor,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {

  const _SessionTile({
    required this.session,
    required this.name,
    required this.subtitle,
    required this.showDivider,
    required this.onTap,
  });
  final Session session;
  final String name;
  final String subtitle;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            color: theme.colorScheme.outlineVariant,
          ),
      ],
    );
  }
}
