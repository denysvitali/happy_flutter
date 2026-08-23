import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/codex_usage_summary.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/machine_usage_scaffold.dart';

class CodexUsageScreen extends StatelessWidget {
  const CodexUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MachineUsageScaffold<CodexUsageSummary>(
      title: l10n.codexUsageTitle,
      pickerTitle: l10n.codexUsageSelectMachine,
      noMachinesIcon: Icons.code,
      noMachinesTitle: l10n.codexUsageNoMachines,
      noMachinesSubtitle: l10n.codexUsageNoMachinesSubtitle,
      emptyIcon: Icons.code,
      emptyTitle: l10n.codexUsageNotAvailable,
      emptySubtitle: l10n.codexUsageNotAvailableSubtitle,
      fetch: (machineId) async {
        final response = await Sync().machineGetCodexUsage(
          machineId: machineId,
        );
        final resetCredits = response.success
            ? await Sync().machineGetCodexResetCredits(machineId: machineId)
            : null;

        if (!response.success || response.data == null) {
          return MachineUsageSnapshot<CodexUsageSummary>.error(
            response.error ?? 'Unknown error',
          );
        }

        return MachineUsageSnapshot<CodexUsageSummary>.data(
          resetCredits == null
              ? response.data!
              : response.data!.withResetCredits(resetCredits),
        );
      },
      contentBuilder: (context, report) {
        final l10n = AppLocalizations.of(context);

        return [
          SettingsSection(
            title: l10n.codexUsageAccount,
            children: [
              UsageStatRow(
                icon: Icons.alternate_email,
                title: l10n.codexUsageEmail,
                value: report.email ?? '-',
                iconColor: AppColors.info,
              ),
              UsageStatRow(
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
                  UsageWindowRow(
                    icon: Icons.schedule,
                    title: l10n.codexUsageFiveHourWindow,
                    percent: report
                        .rateLimit!
                        .primaryWindow!
                        .usedPercent
                        .toDouble(),
                    iconColor: AppColors.warning,
                    footer: _windowFooter(
                      context,
                      report.rateLimit!.primaryWindow!,
                    ),
                  ),
                if (report.rateLimit!.secondaryWindow != null)
                  UsageWindowRow(
                    icon: Icons.date_range_outlined,
                    title: l10n.codexUsageWeeklyWindow,
                    percent: report
                        .rateLimit!
                        .secondaryWindow!
                        .usedPercent
                        .toDouble(),
                    iconColor: AppColors.success,
                    footer: _windowFooter(
                      context,
                      report.rateLimit!.secondaryWindow!,
                    ),
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
                  UsageWindowRow(
                    icon: Icons.schedule,
                    title: l10n.codexUsagePrimaryWindow,
                    percent: report
                        .codeReviewRateLimit!
                        .primaryWindow!
                        .usedPercent
                        .toDouble(),
                    iconColor: AppColors.warning,
                    footer: _windowFooter(
                      context,
                      report.codeReviewRateLimit!.primaryWindow!,
                    ),
                  ),
                if (report.codeReviewRateLimit!.secondaryWindow != null)
                  UsageWindowRow(
                    icon: Icons.date_range_outlined,
                    title: l10n.codexUsageSecondaryWindow,
                    percent: report
                        .codeReviewRateLimit!
                        .secondaryWindow!
                        .usedPercent
                        .toDouble(),
                    iconColor: AppColors.success,
                    footer: _windowFooter(
                      context,
                      report.codeReviewRateLimit!.secondaryWindow!,
                    ),
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
                UsageStatRow(
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
        ];
      },
    );
  }
}

/// Footer line under a [UsageWindowRow]: the localized absolute reset
/// time when known, else a "Resets in …" duration.
Widget? _windowFooter(BuildContext context, CodexUsageWindow window) {
  final description = _formatResetDescription(context, window);
  if (description == null) return null;
  final theme = Theme.of(context);
  return Text(
    description,
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
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
        UsageStatRow(
          icon: Icons.restart_alt,
          title: l10n.codexUsageResetsAvailable,
          value: resetCredits.availableCount.toString(),
          iconColor: AppColors.info,
        ),
        for (final credit in available)
          UsageStatRow(
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
          UsageWindowRow(
            icon: Icons.schedule,
            title: windowTitles.primary,
            percent: rateLimit.primaryWindow!.usedPercent.toDouble(),
            iconColor: AppColors.warning,
            footer: _windowFooter(context, rateLimit.primaryWindow!),
          ),
        if (rateLimit.secondaryWindow != null)
          UsageWindowRow(
            icon: Icons.date_range_outlined,
            title: windowTitles.secondary,
            percent: rateLimit.secondaryWindow!.usedPercent.toDouble(),
            iconColor: AppColors.success,
            footer: _windowFooter(context, rateLimit.secondaryWindow!),
          ),
      ],
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
    return UsageStatRow(
      icon: icon,
      title: title,
      value: value ? l10n.commonYes : l10n.commonNo,
      iconColor: iconColor,
    );
  }
}
