import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/usage_api.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/usage.dart';
import '../../core/providers/app_providers.dart';
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.usageTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null
              ? _buildErrorState(cs, l10n)
              : _buildUsageContent(cs, l10n),
    );
  }

  Widget _buildErrorState(ColorScheme cs, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: cs.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.failedToLoad,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton.icon(
              onPressed: _loadUsage,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageContent(ColorScheme cs, AppLocalizations l10n) {
    final summary = _usageSummary;
    if (summary == null) {
      return _buildEmptyState(cs, l10n);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildPeriodSelector(cs, l10n),
        const SizedBox(height: AppSpacing.lg),
        _buildTotalsSection(cs, summary.totals, l10n),
        const SizedBox(height: AppSpacing.lg),
        _buildModelsSection(cs, summary.totals, l10n),
        const SizedBox(height: AppSpacing.lg),
        _buildStatsSection(cs, summary, l10n),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme cs, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.noUsageData,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.noUsageDataSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ColorScheme cs, AppLocalizations l10n) {
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
            selected: {_selectedPeriod},
            onSelectionChanged: (selection) {
              _onPeriodChanged(selection.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsSection(
    ColorScheme cs,
    UsageTotals totals,
    AppLocalizations l10n,
  ) {
    return SettingsSection(
      title: l10n.totals,
      children: [
        _buildStatRow(
          cs,
          icon: Icons.token,
          title: l10n.totalTokens,
          value: _formatNumber(totals.totalTokens),
          iconColor: cs.primary,
        ),
        _buildStatRow(
          cs,
          icon: Icons.attach_money,
          title: l10n.totalCost,
          value: '\$${totals.totalCost.toStringAsFixed(2)}',
          iconColor: Colors.green,
        ),
        _buildStatRow(
          cs,
          icon: Icons.description,
          title: l10n.reports,
          value: _usageSummary?.totalReportCount.toString() ?? '0',
          iconColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildModelsSection(
    ColorScheme cs,
    UsageTotals totals,
    AppLocalizations l10n,
  ) {
    if (totals.tokensByModel.isEmpty && totals.costByModel.isEmpty) {
      return const SizedBox.shrink();
    }

    return SettingsSection(
      title: l10n.byModel,
      children: [
        ...totals.tokensByModel.entries.map((entry) {
          final cost = totals.costByModel[entry.key] ?? 0.0;
          return _buildStatRow(
            cs,
            icon: Icons.smart_toy,
            title: entry.key,
            value:
                '${_formatNumber(entry.value)} tokens '
                '(\$${cost.toStringAsFixed(2)})',
            iconColor: Colors.orange,
          );
        }),
      ],
    );
  }

  Widget _buildStatsSection(
    ColorScheme cs,
    UsageSummary summary,
    AppLocalizations l10n,
  ) {
    return SettingsSection(
      title: l10n.statistics,
      children: [
        _buildStatRow(
          cs,
          icon: Icons.trending_up,
          title: l10n.avgCostPerDay,
          value: '\$${summary.averageCostPerDay.toStringAsFixed(2)}',
          iconColor: cs.primary,
        ),
        _buildStatRow(
          cs,
          icon: Icons.speed,
          title: l10n.avgTokensPerDay,
          value: _formatNumber(summary.averageTokensPerDay.round()),
          iconColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildStatRow(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
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
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
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
