import 'package:flutter/material.dart';

import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/grok_usage_summary.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/machine_usage_scaffold.dart';

/// Grok Build monthly billing usage for a selected machine.
class GrokUsageScreen extends StatelessWidget {
  const GrokUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MachineUsageScaffold<GrokUsageSummary>(
      title: l10n.grokUsageTitle,
      pickerTitle: l10n.grokUsageSelectMachine,
      noMachinesIcon: Icons.auto_awesome,
      noMachinesTitle: l10n.grokUsageNoMachines,
      noMachinesSubtitle: l10n.grokUsageNoMachinesSubtitle,
      emptyIcon: Icons.auto_awesome,
      emptyTitle: l10n.grokUsageNotAvailable,
      emptySubtitle: l10n.grokUsageNotAvailableSubtitle,
      fetch: (machineId) async {
        final response = await Sync().machineGetGrokUsage(
          machineId: machineId,
        );
        if (!response.success || response.data == null) {
          return MachineUsageSnapshot<GrokUsageSummary>.error(
            response.error ?? 'Unknown error',
          );
        }
        return MachineUsageSnapshot<GrokUsageSummary>.data(response.data!);
      },
      contentBuilder: (context, report) {
        final l10n = AppLocalizations.of(context);
        final periodLabel = _formatPeriod(
          report.billingPeriodStart,
          report.billingPeriodEnd,
        );
        final usedLabel = GrokUsageSummary.formatDollars(report.usedDollars);
        final limitLabel = GrokUsageSummary.formatDollars(
          report.monthlyLimitDollars,
        );
        final remainingLabel = GrokUsageSummary.formatDollars(
          report.remainingDollars,
        );

        return [
          SettingsSection(
            title: l10n.grokUsageAccount,
            children: [
              UsageStatRow(
                icon: Icons.alternate_email,
                title: l10n.grokUsageEmail,
                value: report.email ?? '-',
                iconColor: AppColors.info,
                flexValue: true,
              ),
              if (periodLabel != null)
                UsageStatRow(
                  icon: Icons.date_range_outlined,
                  title: l10n.grokUsageBillingPeriod,
                  value: periodLabel,
                  iconColor: AppColors.success,
                  flexValue: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.grokUsageMonthlyAllowance,
            children: [
              UsageWindowRow(
                icon: Icons.calendar_month_outlined,
                title: l10n.grokUsageMonthlyLimit,
                percent: report.usedPercent,
                iconColor: AppColors.warning,
                emphasizedTitle: false,
                percentUsesBarColor: false,
                dense: false,
                footer: Text(
                  '$usedLabel / $limitLabel · $remainingLabel left',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              UsageStatRow(
                icon: Icons.payments_outlined,
                title: l10n.grokUsageOnDemandCap,
                value: report.onDemandCapCents > 0
                    ? GrokUsageSummary.formatDollars(report.onDemandCapDollars)
                    : l10n.grokUsageOnDemandDisabled,
                iconColor: AppColors.info,
                flexValue: true,
              ),
            ],
          ),
        ];
      },
    );
  }

  String? _formatPeriod(String? start, String? end) {
    if (start == null && end == null) return null;
    final startLabel = _shortDate(start);
    final endLabel = _shortDate(end);
    if (startLabel != null && endLabel != null) {
      return '$startLabel – $endLabel';
    }
    return startLabel ?? endLabel;
  }

  String? _shortDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
