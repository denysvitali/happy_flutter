import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/provider_usage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/utils.dart' show formatDuration;

/// Card displaying usage for a single provider account.
class ProviderUsageCard extends StatelessWidget {
  const ProviderUsageCard({
    required this.usage,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final ProviderUsage usage;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          width: isSelected ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: AppScreenPadding.listItem,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ProviderIcon(type: usage.type),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usage.accountName ?? _defaultAccountName(usage.type),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _providerDisplayName(usage.type),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelectionMode) ...[
                    const SizedBox(width: AppSpacing.md),
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              if (usage.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorBanner(error: usage.error!),
              ] else if (usage.windows.isEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.providersNoUsageData,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                for (final window in usage.windows) ...[
                  _UsageWindowRow(window: window),
                  if (window != usage.windows.last)
                    const SizedBox(height: AppSpacing.md),
                ],
              ],
              if (usage.extra.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _ExtraInfo(extra: usage.extra),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _defaultAccountName(ProviderUsageType type) {
    return switch (type) {
      ProviderUsageType.kimi => 'Kimi',
      ProviderUsageType.minimax => 'MiniMax',
      ProviderUsageType.claudeCode => 'Claude Code',
      ProviderUsageType.codex => 'Codex',
    };
  }

  static String _providerDisplayName(ProviderUsageType type) {
    return switch (type) {
      ProviderUsageType.kimi => 'Kimi',
      ProviderUsageType.minimax => 'MiniMax',
      ProviderUsageType.claudeCode => 'Claude Code',
      ProviderUsageType.codex => 'Codex',
    };
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({required this.type});

  final ProviderUsageType type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      ProviderUsageType.kimi => AppColors.info,
      ProviderUsageType.minimax => AppColors.success,
      ProviderUsageType.claudeCode => AppColors.warning,
      ProviderUsageType.codex => AppColors.error,
    };

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: AppOpacity.faint),
      child: Icon(
        switch (type) {
          ProviderUsageType.kimi => Icons.auto_awesome,
          ProviderUsageType.minimax => Icons.cloud,
          ProviderUsageType.claudeCode => Icons.psychology,
          ProviderUsageType.codex => Icons.code,
        },
        color: color,
        size: AppSpacing.xl,
      ),
    );
  }
}

class _UsageWindowRow extends StatelessWidget {
  const _UsageWindowRow({required this.window});

  final ProviderUsageWindow window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final barColor = _utilizationColor(window.utilization);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(window.label, style: theme.textTheme.bodyMedium),
            ),
            Text(
              '${window.utilization.toStringAsFixed(1)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xsm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: window.utilization / 100,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: AppSpacing.smd,
          ),
        ),
        if (window.limit != null && window.used != null) ...[
          const SizedBox(height: AppSpacing.xsm),
          Text(
            '${_formatNumber(window.used!)} / ${_formatNumber(window.limit!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_resetLabel(context, window.resetsAtMs) case final reset?) ...[
          const SizedBox(height: AppSpacing.xsm),
          Text(
            reset,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Localized "Resets in …" label, or null when there is no future reset.
  String? _resetLabel(BuildContext context, int? resetsAtMs) {
    if (resetsAtMs == null) return null;
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      resetsAtMs,
    ).difference(DateTime.now());
    if (remaining.inSeconds <= 0) return null;
    return context.l10n.providersResetsIn(formatDuration(remaining));
  }

  Color _utilizationColor(double utilization) {
    if (utilization >= 90) return AppColors.error;
    if (utilization >= 75) return AppColors.warning;
    return AppColors.success;
  }

  String _formatNumber(double value) {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: AppScreenPadding.compact,
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.error,
            size: AppSpacing.lg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtraInfo extends StatelessWidget {
  const _ExtraInfo({required this.extra});

  final Map<String, dynamic> extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: AppScreenPadding.compact,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.providersSubscription,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xsm),
          _formatExtra(extra, theme, colorScheme),
        ],
      ),
    );
  }

  Widget _formatExtra(
    Map<String, dynamic> data,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final entries = data.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.map((entry) {
        return Text(
          '${entry.key}: ${entry.value}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }
}
