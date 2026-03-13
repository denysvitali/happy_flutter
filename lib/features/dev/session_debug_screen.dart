import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/socket_io_client.dart';
import '../../core/components/settings_section.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Debug screen showing session state and sync status.
class SessionDebugScreen extends ConsumerStatefulWidget {
  const SessionDebugScreen({super.key});

  @override
  ConsumerState<SessionDebugScreen> createState() =>
      _SessionDebugScreenState();
}

class _SessionDebugScreenState extends ConsumerState<SessionDebugScreen> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final syncInitialized = sync.isInitialized;

    final sessions = sync.sessions;
    final sessionCount = sessions.length;
    final activeSessions =
        sessions.values.where((s) => s.active).length;
    final onlineSessions = sessions.values
        .where((s) => s.presence == 'online')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy debug info',
            onPressed: () => _copyDebugInfo(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          // Connection Status
          SettingsSection(
            title: 'Connection',
            children: [
              _InfoRow(
                icon: _connectionIcon(connectionStatus),
                label: 'Socket status',
                value: connectionStatus.name,
                valueColor: _connectionColor(connectionStatus, cs),
              ),
              _InfoRow(
                icon: Icons.power,
                label: 'Sync initialized',
                value: syncInitialized ? 'Yes' : 'No',
                valueColor:
                    syncInitialized ? AppColors.success : cs.error,
              ),
              _InfoRow(
                icon: Icons.check_circle,
                label: 'Sync ready',
                value: sync.isReady ? 'Yes' : 'No',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Session Summary
          SettingsSection(
            title: 'Sessions',
            children: [
              _InfoRow(
                icon: Icons.all_inbox,
                label: 'Total sessions',
                value: '$sessionCount',
              ),
              _InfoRow(
                icon: Icons.play_circle,
                label: 'Active sessions',
                value: '$activeSessions',
              ),
              _InfoRow(
                icon: Icons.circle,
                label: 'Online sessions',
                value: '$onlineSessions',
              ),
              _InfoRow(
                icon: Icons.numbers,
                label: 'Data change counter',
                value: '${sync.dataChangeCounter}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Session Details
          if (sessions.isNotEmpty) ...[
            SettingsSection(
              title: 'Session Details',
              children: [
                for (final session in sessions.values.take(10))
                  _buildSessionTile(context, session),
              ],
            ),
            if (sessions.length > 10)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  left: AppSpacing.lg,
                ),
                child: Text(
                  'Showing 10 of ${sessions.length} sessions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Sync Managers
          SettingsSection(
            title: 'Sync Managers',
            children: [
              _InfoRow(
                icon: Icons.chat,
                label: 'Sessions sync',
                value: 'Active',
              ),
              _InfoRow(
                icon: Icons.message,
                label: 'Message syncs',
                value: '${sync.messagesSync.length}',
              ),
              _InfoRow(
                icon: Icons.settings,
                label: 'Settings sync',
                value: 'Active',
              ),
              _InfoRow(
                icon: Icons.person,
                label: 'Profile sync',
                value: 'Active',
              ),
              _InfoRow(
                icon: Icons.computer,
                label: 'Machines sync',
                value: 'Active',
              ),
              _InfoRow(
                icon: Icons.notifications,
                label: 'Push token sync',
                value: 'Active',
              ),
              _InfoRow(
                icon: Icons.description,
                label: 'Artifacts sync',
                value: 'Active',
              ),
              _InfoRow(
                icon: Icons.people,
                label: 'Friends sync',
                value: 'Active',
              ),
              _InfoRow(
                icon: Icons.rss_feed,
                label: 'Feed sync',
                value: 'Active',
              ),
              _InfoRow(
                icon: Icons.checklist,
                label: 'Todos sync',
                value: 'Active',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Other State
          SettingsSection(
            title: 'Other State',
            children: [
              _InfoRow(
                icon: Icons.attach_money,
                label: 'RevenueCat init',
                value: sync.revenueCatInitialized ? 'Yes' : 'No',
              ),
              _InfoRow(
                icon: Icons.system_update,
                label: 'Native update available',
                value: sync.hasNativeUpdate ? 'Yes' : 'No',
              ),
              _InfoRow(
                icon: Icons.list,
                label: 'Todo lists',
                value: '${sync.todoLists.length}',
              ),
              _InfoRow(
                icon: Icons.people,
                label: 'Friends',
                value: '${sync.friends.length}',
              ),
              _InfoRow(
                icon: Icons.feed,
                label: 'Feed items',
                value: '${sync.feedItems.length}',
              ),
              _InfoRow(
                icon: Icons.description,
                label: 'Artifacts',
                value: '${sync.artifacts.length}',
              ),
              _InfoRow(
                icon: Icons.computer,
                label: 'Machines',
                value: '${sync.machines.length}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, session) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                session.active
                    ? Icons.play_circle
                    : Icons.pause_circle,
                size: 18,
                color: session.active ? AppColors.success : cs.outline,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  session.metadata?.summary?.text ??
                      session.id.substring(0, 12),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: session.presence == 'online'
                      ? AppColors.success.withValues(alpha: 0.2)
                      : cs.surfaceContainerHighest,
                  borderRadius:
                      BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  session.presence,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: session.presence == 'online'
                        ? AppColors.success
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              'ID: ${session.id.substring(0, 16)}...'
              ' | seq: ${session.seq}'
              ' | msgs: ${session.lastSeq ?? 0}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _connectionIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Icons.wifi;
      case ConnectionStatus.connecting:
        return Icons.wifi_find;
      case ConnectionStatus.disconnected:
        return Icons.wifi_off;
      case ConnectionStatus.error:
        return Icons.error;
    }
  }

  Color _connectionColor(ConnectionStatus status, ColorScheme cs) {
    switch (status) {
      case ConnectionStatus.connected:
        return AppColors.success;
      case ConnectionStatus.connecting:
        return AppColors.warning;
      case ConnectionStatus.disconnected:
        return cs.onSurfaceVariant;
      case ConnectionStatus.error:
        return cs.error;
    }
  }

  void _copyDebugInfo(BuildContext context) {
    final sessions = sync.sessions;
    final connectionStatus = ref.read(connectionNotifierProvider);
    final onlineCount = sessions.values
        .where((s) => s.presence == 'online')
        .length;

    final buffer = StringBuffer()
      ..writeln('=== Session Debug Info ===')
      ..writeln('Connection: ${connectionStatus.name}')
      ..writeln('Sync initialized: ${sync.isInitialized}')
      ..writeln('Sync ready: ${sync.isReady}')
      ..writeln('')
      ..writeln('Sessions: ${sessions.length}')
      ..writeln('Active: ${sessions.values.where((s) => s.active).length}')
      ..writeln('Online: $onlineCount')
      ..writeln('Data change counter: ${sync.dataChangeCounter}')
      ..writeln('')
      ..writeln('Session list:');

    for (final s in sessions.values) {
      buffer
        ..writeln('  ${s.id}:')
        ..writeln('    active: ${s.active}')
        ..writeln('    presence: ${s.presence}')
        ..writeln('    seq: ${s.seq}')
        ..writeln('    lastSeq: ${s.lastSeq ?? 0}');
    }

    buffer
      ..writeln('')
      ..writeln('Sync managers:')
      ..writeln('  Message syncs: ${sync.messagesSync.length}')
      ..writeln('  Todo lists: ${sync.todoLists.length}')
      ..writeln('  Friends: ${sync.friends.length}')
      ..writeln('  Feed items: ${sync.feedItems.length}')
      ..writeln('  Artifacts: ${sync.artifacts.length}')
      ..writeln('  Machines: ${sync.machines.length}');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session debug info copied')),
    );
  }
}

/// A simple row showing a label and value with an icon.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: valueColor ?? cs.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
