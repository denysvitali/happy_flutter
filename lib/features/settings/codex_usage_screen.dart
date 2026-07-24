import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/codex_usage_summary.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/machine_picker.dart';

class CodexUsageScreen extends ConsumerStatefulWidget {
  const CodexUsageScreen({super.key});

  @override
  ConsumerState<CodexUsageScreen> createState() => _CodexUsageScreenState();
}

class _CodexUsageScreenState extends ConsumerState<CodexUsageScreen> {
  String? _selectedMachineId;
  CodexUsageSummary? _report;
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

    final response = await Sync().machineGetCodexUsage(machineId: machineId);
    final resetCredits = response.success
        ? await Sync().machineGetCodexResetCredits(machineId: machineId)
        : null;

    if (!mounted) return;

    if (!response.success || response.data == null) {
      setState(() {
        _error = response.error ?? 'Unknown error';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _report = resetCredits == null
          ? response.data
          : response.data!.withResetCredits(resetCredits);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final machines = ref.watch(machinesNotifierProvider);

    if (machines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.codexUsageTitle)),
        body: AppEmptyState(
          icon: Icons.code,
          title: l10n.codexUsageNoMachines,
          subtitle: l10n.codexUsageNoMachinesSubtitle,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.codexUsageTitle)),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null
          ? _CodexUsageErrorBody(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              onMachineChanged: (id) {
                setState(() => _selectedMachineId = id);
                if (id != null) _loadUsage(id);
              },
              error: _error!,
              onRetry: () {
                if (_selectedMachineId != null) {
                  _loadUsage(_selectedMachineId!);
                }
              },
            )
          : _report != null
          ? _CodexUsageBody(
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
              pickerTitle: l10n.codexUsageSelectMachine,
              icon: Icons.code,
              title: l10n.codexUsageNotAvailable,
              subtitle: l10n.codexUsageNotAvailableSubtitle,
            ),
    );
  }
}

class _CodexUsageBody extends StatelessWidget {
  const _CodexUsageBody({
    required this.machines,
    required this.selectedMachineId,
    required this.report,
    required this.onMachineChanged,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final CodexUsageSummary report;
  final ValueChanged<String?> onMachineChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: AppScreenPadding.settings,
      children: [
        MachinePicker(
          machines: machines,
          selectedMachineId: selectedMachineId,
          onChanged: onMachineChanged,
          sectionTitle: l10n.codexUsageSelectMachine,
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: l10n.codexUsageAccount,
          children: [
            _CodexUsageStatRow(
              icon: Icons.alternate_email,
              title: l10n.codexUsageEmail,
              value: report.email ?? '-',
              iconColor: AppColors.info,
            ),
            _CodexUsageStatRow(
              icon: Icons.workspace_premium_outlined,
              title: l10n.codexUsagePlan,
              value: report.planType ?? '-',
              iconColor: AppColors.success,
            ),
          ],
        ),
        if (report.rateLimit != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.codexUsageSessionLimits,
            children: [
              _CodexUsageBooleanRow(
                icon: Icons.check_circle_outline,
                title: l10n.codexUsageCreditsAvailable,
                value: report.rateLimit!.allowed,
                iconColor: AppColors.info,
              ),
              if (report.rateLimit!.primaryWindow != null)
                _CodexUsageWindowRow(
                  icon: Icons.schedule,
                  title: l10n.codexUsageFiveHourWindow,
                  window: report.rateLimit!.primaryWindow!,
                  iconColor: AppColors.warning,
                ),
              if (report.rateLimit!.secondaryWindow != null)
                _CodexUsageWindowRow(
                  icon: Icons.date_range_outlined,
                  title: l10n.codexUsageWeeklyWindow,
                  window: report.rateLimit!.secondaryWindow!,
                  iconColor: AppColors.success,
                ),
            ],
          ),
        ],
        if (report.codeReviewRateLimit != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.codexUsageCodeReview,
            children: [
              _CodexUsageBooleanRow(
                icon: Icons.rate_review_outlined,
                title: l10n.codexUsageCreditsAvailable,
                value: report.codeReviewRateLimit!.allowed,
                iconColor: AppColors.info,
              ),
              if (report.codeReviewRateLimit!.primaryWindow != null)
                _CodexUsageWindowRow(
                  icon: Icons.schedule,
                  title: l10n.codexUsagePrimaryWindow,
                  window: report.codeReviewRateLimit!.primaryWindow!,
                  iconColor: AppColors.warning,
                ),
              if (report.codeReviewRateLimit!.secondaryWindow != null)
                _CodexUsageWindowRow(
                  icon: Icons.date_range_outlined,
                  title: l10n.codexUsageSecondaryWindow,
                  window: report.codeReviewRateLimit!.secondaryWindow!,
                  iconColor: AppColors.success,
                ),
            ],
          ),
        ],
        if (report.resetCredits != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _CodexResetCreditsSection(resetCredits: report.resetCredits!),
        ],
        for (final additionalLimit in report.additionalRateLimits) ...[
          if (additionalLimit.rateLimit != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _CodexUsageRateLimitSection(
              title: additionalLimit.displayName,
              rateLimit: additionalLimit.rateLimit!,
              windowTitles: _CodexUsageWindowTitles(
                primary: l10n.codexUsagePrimaryWindow,
                secondary: l10n.codexUsageSecondaryWindow,
              ),
              leadingIcon: Icons.auto_awesome,
            ),
          ],
        ],
        if (report.credits != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.codexUsageCredits,
            children: [
              _CodexUsageBooleanRow(
                icon: Icons.account_balance_wallet_outlined,
                title: l10n.codexUsageCreditsAvailable,
                value: report.credits!.hasCredits,
                iconColor: AppColors.info,
              ),
              _CodexUsageStatRow(
                icon: Icons.payments_outlined,
                title: l10n.codexUsageCreditsBalance,
                value: report.credits!.unlimited
                    ? l10n.codexUsageUnlimited
                    : (report.credits!.balance ?? '-'),
                iconColor: AppColors.success,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CodexResetCreditsSection extends StatelessWidget {
  const _CodexResetCreditsSection({required this.resetCredits});

  final CodexRateLimitResetCredits resetCredits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = resetCredits.credits
        .where((credit) => credit.isAvailable)
        .toList(growable: false);
    return SettingsSection(
      title: l10n.codexUsageLimitResets,
      children: [
        _CodexUsageStatRow(
          icon: Icons.restart_alt,
          title: l10n.codexUsageResetsAvailable,
          value: resetCredits.availableCount.toString(),
          iconColor: AppColors.info,
        ),
        for (final credit in available)
          _CodexUsageStatRow(
            icon: Icons.event_outlined,
            title: (credit.title?.trim().isNotEmpty ?? false)
                ? credit.title!
                : l10n.codexUsageLimitReset,
            value: _formatResetCreditExpiry(context, credit.expiresAt),
            iconColor: AppColors.warning,
          ),
      ],
    );
  }

  String _formatResetCreditExpiry(BuildContext context, DateTime? expiresAt) {
    final l10n = AppLocalizations.of(context);
    if (expiresAt == null) return l10n.codexUsageDoesNotExpire;
    final localExpiry = expiresAt.toLocal();
    final remaining = localExpiry.difference(DateTime.now());
    final locale = Localizations.localeOf(context).toLanguageTag();
    final shortDate = DateFormat.MMMd(locale).format(localExpiry);
    final days = remaining.isNegative
        ? 0
        : (remaining.inMinutes / Duration.minutesPerDay).ceil();
    return l10n.codexUsageExpiresInDays(days, shortDate);
  }
}

class _CodexUsageWindowTitles {
  const _CodexUsageWindowTitles({
    required this.primary,
    required this.secondary,
  });

  final String primary;
  final String secondary;
}

class _CodexUsageRateLimitSection extends StatelessWidget {
  const _CodexUsageRateLimitSection({
    required this.title,
    required this.rateLimit,
    required this.windowTitles,
    required this.leadingIcon,
  });

  final String title;
  final CodexUsageSummaryRateLimit rateLimit;
  final _CodexUsageWindowTitles windowTitles;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SettingsSection(
      title: title,
      children: [
        _CodexUsageBooleanRow(
          icon: leadingIcon,
          title: l10n.codexUsageCreditsAvailable,
          value: rateLimit.allowed,
          iconColor: AppColors.info,
        ),
        if (rateLimit.primaryWindow != null)
          _CodexUsageWindowRow(
            icon: Icons.schedule,
            title: windowTitles.primary,
            window: rateLimit.primaryWindow!,
            iconColor: AppColors.warning,
          ),
        if (rateLimit.secondaryWindow != null)
          _CodexUsageWindowRow(
            icon: Icons.date_range_outlined,
            title: windowTitles.secondary,
            window: rateLimit.secondaryWindow!,
            iconColor: AppColors.success,
          ),
      ],
    );
  }
}


class _CodexUsageErrorBody extends StatelessWidget {
  const _CodexUsageErrorBody({
    required this.machines,
    required this.selectedMachineId,
    required this.onMachineChanged,
    required this.error,
    required this.onRetry,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final ValueChanged<String?> onMachineChanged;
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Picker included so the error state is escapable: when the
    // auto-selected machine lacks Codex, the user can switch to one that
    // has it instead of being stuck retrying the same broken machine.
    return Column(
      children: [
        Padding(
          padding: AppScreenPadding.settings,
          child: MachinePicker(
            machines: machines,
            selectedMachineId: selectedMachineId,
            onChanged: onMachineChanged,
            sectionTitle: l10n.codexUsageSelectMachine,
          ),
        ),
        const Spacer(),
        AppEmptyState(
          icon: Icons.error_outline,
          title: l10n.codexUsageNotAvailable,
          subtitle: error,
          action: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.commonRetry),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _CodexUsageStatRow extends StatelessWidget {
  const _CodexUsageStatRow({
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
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexUsageBooleanRow extends StatelessWidget {
  const _CodexUsageBooleanRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final bool value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CodexUsageStatRow(
      icon: icon,
      title: title,
      value: value ? l10n.commonYes : l10n.commonNo,
      iconColor: iconColor,
    );
  }
}

class _CodexUsageWindowRow extends StatelessWidget {
  const _CodexUsageWindowRow({
    required this.icon,
    required this.title,
    required this.window,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final CodexUsageWindow window;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final percent = window.usedPercent.clamp(0, 100);
    final fraction = percent / 100.0;
    final resetDescription = _formatResetDescription(context, window);

    final Color barColor;
    if (percent >= 90) {
      barColor = AppColors.error;
    } else if (percent >= 70) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.success;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.smd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
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
                '$percent%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (resetDescription != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              resetDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _formatResetDescription(
    BuildContext context,
    CodexUsageWindow window,
  ) {
    final expiresAt = window.expiresAt?.toLocal();
    if (expiresAt != null) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final formatted = DateFormat.yMMMd(locale).add_jm().format(expiresAt);
      return AppLocalizations.of(context).codexUsageResetsAt(formatted);
    }

    final seconds = window.resetAfterSeconds;
    if (seconds == null) return null;
    if (seconds <= 0) return null;
    final dur = Duration(seconds: seconds);
    if (dur.inHours >= 24) {
      final days = dur.inDays;
      return 'Resets in ${days}d ${dur.inHours % 24}h';
    }
    if (dur.inHours >= 1) {
      return 'Resets in ${dur.inHours}h '
          '${dur.inMinutes % 60}m';
    }
    return 'Resets in ${dur.inMinutes}m';
  }
}
