import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/grok_usage_summary.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/machine_picker.dart';

/// Grok Build monthly billing usage for a selected machine.
class GrokUsageScreen extends ConsumerStatefulWidget {
  const GrokUsageScreen({super.key});

  @override
  ConsumerState<GrokUsageScreen> createState() => _GrokUsageScreenState();
}

class _GrokUsageScreenState extends ConsumerState<GrokUsageScreen> {
  String? _selectedMachineId;
  GrokUsageSummary? _report;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_autoSelectMachine);
  }

  void _autoSelectMachine() {
    final machineSortNow = DateTime.now().millisecondsSinceEpoch;
    final machines = ref.read(machinesNotifierProvider).values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(machineSortNow, a, b));
    final online = machines.where((machine) => machine.isOnline).toList();
    final target = online.isNotEmpty ? online.first : null;
    if (target != null) {
      setState(() => _selectedMachineId = target.id);
      _loadUsage(target.id);
    }
  }

  Future<void> _loadUsage(String machineId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });

    final response = await Sync().machineGetGrokUsage(machineId: machineId);

    if (!mounted) return;

    if (!response.success || response.data == null) {
      setState(() {
        _error = response.error ?? 'Unknown error';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _report = response.data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final machines = ref.watch(machinesNotifierProvider);

    if (machines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.grokUsageTitle)),
        body: AppEmptyState(
          icon: Icons.auto_awesome,
          title: l10n.grokUsageNoMachines,
          subtitle: l10n.grokUsageNoMachinesSubtitle,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.grokUsageTitle)),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null
          ? MachineScopedEmptyBody(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              onMachineChanged: (id) {
                setState(() => _selectedMachineId = id);
                if (id != null) _loadUsage(id);
              },
              pickerTitle: l10n.grokUsageSelectMachine,
              icon: Icons.error_outline,
              title: l10n.grokUsageNotAvailable,
              subtitle: _error!,
              onRetry: () {
                if (_selectedMachineId != null) {
                  _loadUsage(_selectedMachineId!);
                }
              },
            )
          : _report != null
          ? _GrokUsageBody(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              report: _report!,
              onMachineChanged: (id) {
                setState(() => _selectedMachineId = id);
                if (id != null) _loadUsage(id);
              },
            )
          : MachineScopedEmptyBody(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              onMachineChanged: (id) {
                setState(() => _selectedMachineId = id);
                if (id != null) _loadUsage(id);
              },
              pickerTitle: l10n.grokUsageSelectMachine,
              icon: Icons.auto_awesome,
              title: l10n.grokUsageNotAvailable,
              subtitle: l10n.grokUsageNotAvailableSubtitle,
            ),
    );
  }
}

class _GrokUsageBody extends StatelessWidget {
  const _GrokUsageBody({
    required this.machines,
    required this.selectedMachineId,
    required this.report,
    required this.onMachineChanged,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final GrokUsageSummary report;
  final ValueChanged<String?> onMachineChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final periodLabel = _formatPeriod(
      report.billingPeriodStart,
      report.billingPeriodEnd,
    );

    return ListView(
      padding: AppScreenPadding.settings,
      children: [
        MachinePicker(
          machines: machines,
          selectedMachineId: selectedMachineId,
          onChanged: onMachineChanged,
          sectionTitle: l10n.grokUsageSelectMachine,
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: l10n.grokUsageAccount,
          children: [
            _GrokUsageStatRow(
              icon: Icons.alternate_email,
              title: l10n.grokUsageEmail,
              value: report.email ?? '-',
              iconColor: AppColors.info,
            ),
            if (periodLabel != null)
              _GrokUsageStatRow(
                icon: Icons.date_range_outlined,
                title: l10n.grokUsageBillingPeriod,
                value: periodLabel,
                iconColor: AppColors.success,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: l10n.grokUsageMonthlyAllowance,
          children: [
            _GrokUsageWindowRow(
              icon: Icons.calendar_month_outlined,
              title: l10n.grokUsageMonthlyLimit,
              usedLabel: GrokUsageSummary.formatDollars(report.usedDollars),
              limitLabel: GrokUsageSummary.formatDollars(
                report.monthlyLimitDollars,
              ),
              percent: report.usedPercent,
              remainingLabel: GrokUsageSummary.formatDollars(
                report.remainingDollars,
              ),
              iconColor: AppColors.warning,
            ),
            _GrokUsageStatRow(
              icon: Icons.payments_outlined,
              title: l10n.grokUsageOnDemandCap,
              value: report.onDemandCapCents > 0
                  ? GrokUsageSummary.formatDollars(report.onDemandCapDollars)
                  : l10n.grokUsageOnDemandDisabled,
              iconColor: AppColors.info,
            ),
          ],
        ),
      ],
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





class _GrokUsageStatRow extends StatelessWidget {
  const _GrokUsageStatRow({
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
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: textTheme.bodyMedium)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrokUsageWindowRow extends StatelessWidget {
  const _GrokUsageWindowRow({
    required this.icon,
    required this.title,
    required this.usedLabel,
    required this.limitLabel,
    required this.percent,
    required this.remainingLabel,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String usedLabel;
  final String limitLabel;
  final double percent;
  final String remainingLabel;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final safePercent = percent.clamp(0, 100);
    final fraction = safePercent / 100.0;

    final Color barColor;
    if (safePercent >= 90) {
      barColor = AppColors.error;
    } else if (safePercent >= 70) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.success;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
              Text(
                '${safePercent.toStringAsFixed(0)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              color: barColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$usedLabel / $limitLabel · $remainingLabel left',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
