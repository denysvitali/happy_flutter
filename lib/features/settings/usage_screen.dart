import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/usage_api.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/usage.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Usage screen - token usage, costs, and limits display.
///
/// Shows real usage data from the API with time period filters.
class UsageScreen extends ConsumerStatefulWidget {
  const UsageScreen({super.key});

  @override
  ConsumerState<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends ConsumerState<UsageScreen> {
  UsageSummary? _usageSummary;
  bool _isLoading = true;
  String? _error;
  late UsagePeriod _selectedPeriod;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _selectedPeriod = _periodFromString(settings.usagePeriod);
    _loadUsage();
  }

  UsagePeriod _periodFromString(String value) {
    switch (value) {
      case 'today':
        return UsagePeriod.today;
      case 'sevenDays':
        return UsagePeriod.sevenDays;
      case 'thirtyDays':
      default:
        return UsagePeriod.thirtyDays;
    }
  }

  String _periodToString(UsagePeriod period) {
    switch (period) {
      case UsagePeriod.today:
        return 'today';
      case UsagePeriod.sevenDays:
        return 'sevenDays';
      case UsagePeriod.thirtyDays:
        return 'thirtyDays';
    }
  }

  Future<void> _loadUsage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final usageApi = UsageApi();
      final summary = await usageApi.getUsageSummary(_selectedPeriod);
      setState(() {
        _usageSummary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onPeriodChanged(UsagePeriod period) async {
    if (period == _selectedPeriod) return;

    // Save preference to settings
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);
    await settingsNotifier.updateSetting(
      'usagePeriod',
      _periodToString(period),
    );

    setState(() {
      _selectedPeriod = period;
    });

    await _loadUsage();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.usageTitle),
      ),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null
              ? _UsageErrorState(
                  error: _error ?? l10n.commonUnknown,
                  onRetry: _loadUsage,
                )
              : _UsageContent(
                  summary: _usageSummary,
                  selectedPeriod: _selectedPeriod,
                  onPeriodChanged: _onPeriodChanged,
                  formatNumber: _formatNumber,
                ),
    );
  }

  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}

class _UsageContent extends StatelessWidget {
  const _UsageContent({
    required this.summary,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.formatNumber,
  });

  final UsageSummary? summary;
  final UsagePeriod selectedPeriod;
  final ValueChanged<UsagePeriod> onPeriodChanged;
  final String Function(int value) formatNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final summary = this.summary;

    if (summary == null) {
      return const _UsageEmptyState();
    }

    return ListView(
      padding: AppScreenPadding.settings,
      children: [
        _PeriodSelector(
          selected: selectedPeriod,
          onChanged: onPeriodChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: l10n.totals,
          children: [
            _UsageStatRow(
              icon: Icons.token,
              title: l10n.totalTokens,
              value: formatNumber(summary.totals.totalTokens),
              iconColor: cs.primary,
            ),
            _UsageStatRow(
              icon: Icons.attach_money,
              title: l10n.totalCost,
              value: '\$${summary.totals.totalCost.toStringAsFixed(2)}',
              iconColor: AppColors.success,
            ),
            _UsageStatRow(
              icon: Icons.description,
              title: l10n.reports,
              value: summary.totalReportCount.toString(),
              iconColor: cs.primary,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (summary.totals.tokensByModel.isNotEmpty ||
            summary.totals.costByModel.isNotEmpty)
          SettingsSection(
            title: l10n.byModel,
            children: [
              ...summary.totals.tokensByModel.entries.map((entry) {
                final cost = summary.totals.costByModel[entry.key] ?? 0.0;
                return _UsageStatRow(
                  icon: Icons.smart_toy,
                  title: entry.key,
                  value:
                      '${formatNumber(entry.value)} tokens '
                      '(\$${cost.toStringAsFixed(2)})',
                  iconColor: AppColors.warning,
                );
              }),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: l10n.statistics,
          children: [
            _UsageStatRow(
              icon: Icons.trending_up,
              title: l10n.avgCostPerDay,
              value: '\$${summary.averageCostPerDay.toStringAsFixed(2)}',
              iconColor: cs.primary,
            ),
            _UsageStatRow(
              icon: Icons.speed,
              title: l10n.avgTokensPerDay,
              value: formatNumber(summary.averageTokensPerDay.round()),
              iconColor: cs.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _UsageErrorState extends StatelessWidget {
  const _UsageErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      icon: Icons.error_outline,
      title: l10n.failedToLoad,
      subtitle: error,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.commonRetry),
      ),
    );
  }
}

class _UsageEmptyState extends StatelessWidget {
  const _UsageEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      icon: Icons.bar_chart_outlined,
      title: l10n.noUsageData,
      subtitle: l10n.noUsageDataSubtitle,
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  final UsagePeriod selected;
  final ValueChanged<UsagePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.timePeriod,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SegmentedButton<UsagePeriod>(
            segments: [
              ButtonSegment(
                value: UsagePeriod.today,
                label: Text(l10n.today),
                icon: const Icon(Icons.today),
              ),
              ButtonSegment(
                value: UsagePeriod.sevenDays,
                label: Text(l10n.sevenDays),
                icon: const Icon(Icons.date_range),
              ),
              ButtonSegment(
                value: UsagePeriod.thirtyDays,
                label: Text(l10n.thirtyDays),
                icon: const Icon(Icons.calendar_month),
              ),
            ],
            selected: {selected},
            onSelectionChanged: (selection) {
              onChanged(selection.first);
            },
          ),
        ),
      ],
    );
  }
}

class _UsageStatRow extends StatelessWidget {
  const _UsageStatRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

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
          SettingsIconContainer(icon: icon, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
