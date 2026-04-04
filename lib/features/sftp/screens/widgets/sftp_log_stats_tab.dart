import 'package:flutter/material.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_section_header.dart';
import '../../../../core/components/settings_section.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../models/sftp_log.dart';

/// Stats tab content for the SFTP log viewer
class SftpLogStatsTab extends StatelessWidget {
  const SftpLogStatsTab({
    required this.deviceIds,
    required this.onRotateLogs,
    required this.onClearLogs,
    super.key,
  });

  final List<String> deviceIds;
  final VoidCallback onRotateLogs;
  final VoidCallback onClearLogs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    var totalLogs = 0;
    var errorCount = 0;
    var warningCount = 0;
    var infoCount = 0;
    final opCounts = <String, int>{};
    final userCounts = <String, int>{};

    for (final deviceId in sftpLogStore.deviceIdsWithLogs) {
      final logs = sftpLogStore.getLogs(deviceId);
      totalLogs += logs.length;
      for (final log in logs) {
        switch (log.level) {
          case 'error':
            errorCount++;
          case 'warning':
            warningCount++;
          default:
            infoCount++;
        }
        if (log.operation != null) {
          opCounts[log.operation!] =
              (opCounts[log.operation!] ?? 0) + 1;
        }
        if (log.username != null) {
          userCounts[log.username!] =
              (userCounts[log.username!] ?? 0) + 1;
        }
      }
    }

    return ListView(
      padding: AppScreenPadding.standard,
      children: [
        Row(
          children: [
            StatCard(
              label: 'Total',
              value: totalLogs.toString(),
              icon: Icons.article,
              color: cs.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            StatCard(
              label: 'Errors',
              value: errorCount.toString(),
              icon: Icons.error_outline,
              color: cs.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            StatCard(
              label: 'Warnings',
              value: warningCount.toString(),
              icon: Icons.warning_amber,
              color: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            StatCard(
              label: 'Info',
              value: infoCount.toString(),
              icon: Icons.info_outline,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            StatCard(
              label: 'Devices',
              value: deviceIds.length.toString(),
              icon: Icons.devices,
              color: cs.tertiary,
            ),
            const SizedBox(width: AppSpacing.sm),
            StatCard(
              label: 'Retention',
              value: '7d',
              icon: Icons.schedule,
              color: cs.secondary,
            ),
          ],
        ),
        if (opCounts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppSectionHeader(title: 'Operations'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _buildSortedEntries(
                opCounts,
                (e) => StatsRow(
                  leading: _getOperationIcon(e.key, context),
                  title: e.key,
                  trailing: e.value.toString(),
                ),
              ),
            ),
          ),
        ],
        if (userCounts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          AppSectionHeader(title: 'Users'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: _buildSortedEntries(
                userCounts,
                (e) => StatsRow(
                  leading: SettingsIconContainer(
                    icon: Icons.person,
                    color: cs.primary,
                  ),
                  title: e.key,
                  trailing: e.value.toString(),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(title: 'Storage'),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              StatsRow(
                leading: SettingsIconContainer(
                  icon: Icons.storage,
                  color: cs.primary,
                ),
                title: 'Max logs per device',
                trailing: '1,000',
              ),
              Divider(
                height: 1,
                thickness: AppBorder.hairline,
                color: cs.outlineVariant,
              ),
              StatsRow(
                leading: SettingsIconContainer(
                  icon: Icons.timer,
                  color: cs.secondary,
                ),
                title: 'Log retention',
                trailing: '7 days',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: onRotateLogs,
          icon: const Icon(
            Icons.cleaning_services,
            size: 18,
          ),
          label: const Text('Rotate old logs now'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onClearLogs,
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Clear all logs'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
          ),
        ),
      ],
    );
  }

  Widget _getOperationIcon(
    String operation,
    BuildContext context,
  ) {
    final cs = Theme.of(context).colorScheme;
    switch (operation.toLowerCase()) {
      case 'connect':
        return SettingsIconContainer(
          icon: Icons.login,
          color: cs.primary,
        );
      case 'disconnect':
        return SettingsIconContainer(
          icon: Icons.logout,
          color: cs.onSurfaceVariant,
        );
      case 'read':
      case 'get':
        return SettingsIconContainer(
          icon: Icons.file_download,
          color: AppColors.success,
        );
      case 'write':
      case 'put':
        return SettingsIconContainer(
          icon: Icons.file_upload,
          color: AppColors.warning,
        );
      case 'list':
        return SettingsIconContainer(
          icon: Icons.folder_open,
          color: cs.tertiary,
        );
      case 'delete':
      case 'remove':
        return SettingsIconContainer(
          icon: Icons.delete,
          color: cs.error,
        );
      case 'rename':
      case 'move':
        return SettingsIconContainer(
          icon: Icons.drive_file_rename_outline,
          color: cs.secondary,
        );
      case 'mkdir':
        return SettingsIconContainer(
          icon: Icons.create_new_folder,
          color: cs.tertiary,
        );
      case 'chmod':
        return SettingsIconContainer(
          icon: Icons.security,
          color: AppColors.warning,
        );
      default:
        return SettingsIconContainer(
          icon: Icons.circle,
          color: cs.onSurfaceVariant,
        );
    }
  }

  List<Widget> _buildSortedEntries(
    Map<String, int> counts,
    Widget Function(MapEntry<String, int>) builder,
  ) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).map(builder).toList();
  }
}

/// A stat summary card
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// A row for stats breakdown sections
class StatsRow extends StatelessWidget {
  const StatsRow({
    required this.leading,
    required this.title,
    required this.trailing,
    super.key,
  });

  final Widget leading;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.smd,
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            trailing,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
