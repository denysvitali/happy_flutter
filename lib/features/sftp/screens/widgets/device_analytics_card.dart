import 'package:flutter/material.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/settings_section.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';

/// Analytics summary card for a single SFTP device
class DeviceAnalyticsCard extends StatelessWidget {
  const DeviceAnalyticsCard({
    required this.deviceId,
    required this.stats,
    super.key,
  });

  final String deviceId;
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalDuration = stats['totalDuration'] as Duration;
    final avgDuration = stats['avgDuration'] as Duration;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SettingsIconContainer(
                icon: Icons.dns_outlined,
                color: cs.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  deviceId,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              AnalyticsItem(
                label: 'Connections',
                value: stats['totalConnections'].toString(),
                icon: Icons.link,
                color: cs.primary,
              ),
              AnalyticsItem(
                label: 'Sessions',
                value: stats['totalSessions'].toString(),
                icon: Icons.terminal,
                color: cs.tertiary,
              ),
              AnalyticsItem(
                label: 'Auth Failures',
                value: stats['authFailures'].toString(),
                icon: Icons.gpp_bad,
                color: cs.error,
              ),
              AnalyticsItem(
                label: 'Unique Users',
                value: stats['uniqueUsers'].toString(),
                icon: Icons.people,
                color: cs.secondary,
              ),
              AnalyticsItem(
                label: 'Total Time',
                value: _formatDuration(totalDuration),
                icon: Icons.timer,
                color: AppColors.warning,
              ),
              AnalyticsItem(
                label: 'Avg Session',
                value: _formatDuration(avgDuration),
                icon: Icons.av_timer,
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

/// A single analytics metric item
class AnalyticsItem extends StatelessWidget {
  const AnalyticsItem({
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
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
