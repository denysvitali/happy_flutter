import 'package:flutter/material.dart';

import '../../../../core/components/app_card.dart';
import '../../../../core/components/settings_section.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../models/sftp_log.dart';
import '../../../../core/utils/utils.dart';
import '../../../../core/utils/datetime_extensions.dart';

/// A single log entry card with expandable details
class SftpLogEntryCard extends StatelessWidget {
  const SftpLogEntryCard({
    required this.log,
    super.key,
    this.onDeviceTap,
  });

  final SftpLogEntry log;
  final void Function(String deviceId)? onDeviceTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final levelColor = _getLevelColor(cs);
    final levelIcon = _getLevelIcon();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
          ),
          childrenPadding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
          ),
          leading: SettingsIconContainer(
            icon: levelIcon,
            color: levelColor,
          ),
          title: Text(
            log.message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xxs,
            ),
            child: Row(
              children: [
                Text(
                  _formatTime(log.timestamp),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                if (log.operation != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        AppRadius.xs,
                      ),
                    ),
                    child: Text(
                      log.operation!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall,
                    ),
                  ),
                ],
                if (log.username != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    log.username!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LogDetailRow(
                  label: 'Device',
                  value: log.deviceName,
                ),
                GestureDetector(
                  onTap: () =>
                      onDeviceTap?.call(log.deviceId),
                  child: LogDetailRow(
                    label: 'Device ID',
                    value: log.deviceId,
                    valueColor: cs.primary,
                  ),
                ),
                LogDetailRow(
                  label: 'Level',
                  value: log.level,
                ),
                if (log.username != null)
                  LogDetailRow(
                    label: 'Username',
                    value: log.username!,
                  ),
                if (log.ipAddress != null)
                  LogDetailRow(
                    label: 'IP Address',
                    value: log.ipAddress!,
                  ),
                if (log.operation != null)
                  LogDetailRow(
                    label: 'Operation',
                    value: log.operation!,
                  ),
                LogDetailRow(
                  label: 'Time',
                  value: log.timestamp.toIso8601String(),
                ),
                if (log.details != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Details',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(
                      AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        AppRadius.sm,
                      ),
                    ),
                    child: SelectableText(
                      log.details!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: AppFontSize.sm,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(ColorScheme cs) {
    switch (log.level) {
      case 'error':
        return cs.error;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  IconData _getLevelIcon() {
    switch (log.level) {
      case 'error':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
    }
  }

  String _formatTime(DateTime dt) => formatRelativeTime(
    dt,
    absoluteFallback: (d) => d.toIsoDateString(),
  );
}

/// A label/value detail row inside an expanded log entry
class LogDetailRow extends StatelessWidget {
  const LogDetailRow({
    required this.label,
    required this.value,
    super.key,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: (valueColor != null
                      ? Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: valueColor,
                            decoration:
                                TextDecoration.underline,
                          )
                      : Theme.of(context)
                          .textTheme
                          .bodySmall)
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
