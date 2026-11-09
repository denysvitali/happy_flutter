import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/components/app_badge.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/codex_usage_summary.dart';
import '../../core/services/opentelemetry_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/machine_usage_scaffold.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

class CodexUsageScreen extends StatelessWidget {
  const CodexUsageScreen({this.initialMachineId, super.key});

  final String? initialMachineId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MachineUsageScaffold<CodexUsageSummary>(
      initialMachineId: initialMachineId,
      title: l10n.codexUsageTitle,
      pickerTitle: l10n.codexUsageSelectMachine,
      noMachinesIcon: Icons.code,
      noMachinesTitle: l10n.codexUsageNoMachines,
      noMachinesSubtitle: l10n.codexUsageNoMachinesSubtitle,
      emptyIcon: Icons.code,
      emptyTitle: l10n.codexUsageNotAvailable,
      emptySubtitle: l10n.codexUsageNotAvailableSubtitle,
      operationName: 'providers.codex_usage.load',
      fetch: (machineId) async {
        final usageFuture = Sync().machineGetCodexUsage(machineId: machineId);
        final resetCreditsFuture = _fetchResetCredits(machineId);
        final response = await usageFuture;

        if (!response.success || response.data == null) {
          return MachineUsageSnapshot<CodexUsageSummary>.error(
            response.error ?? 'Unknown error',
          );
        }

        final resetCredits = await resetCreditsFuture;
        return MachineUsageSnapshot<CodexUsageSummary>.data(
          resetCredits == null
              ? response.data!
              : response.data!.withResetCredits(resetCredits),
        );
      },
      contentBuilder: (context, report) {
        final l10n = AppLocalizations.of(context);
        final windowTitles = _CodexUsageWindowTitles(
          primary: l10n.codexUsagePrimaryWindow,
          secondary: l10n.codexUsageSecondaryWindow,
        );

        return [
          SettingsSection(
            title: l10n.codexUsageAccount,
            children: [
              UsageStatRow(
                icon: Icons.alternate_email,
                title: l10n.codexUsageEmail,
                value: report.email ?? '-',
                flexValue: true,
              ),
              UsageStatRow(
                icon: Icons.workspace_premium_outlined,
                title: l10n.codexUsagePlan,
                value: _formatPlan(report.planType),
              ),
            ],
          ),
          if (report.rateLimit != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _CodexUsageRateLimitSection(
              title: l10n.codexUsageSessionLimits,
              rateLimit: report.rateLimit!,
              windowTitles: windowTitles,
              leadingIcon: Icons.verified_outlined,
            ),
          ],
          if (report.codeReviewRateLimit != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _CodexUsageRateLimitSection(
              title: l10n.codexUsageCodeReview,
              rateLimit: report.codeReviewRateLimit!,
              windowTitles: windowTitles,
              leadingIcon: Icons.rate_review_outlined,
            ),
          ],
          for (final additionalLimit in report.additionalRateLimits) ...[
            if (additionalLimit.rateLimit != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _CodexUsageRateLimitSection(
                title: additionalLimit.displayName,
                rateLimit: additionalLimit.rateLimit!,
                windowTitles: windowTitles,
                leadingIcon: Icons.auto_awesome_outlined,
              ),
            ],
          ],
          if (report.modelUsage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.codexUsageModelAvailability,
              children: [
                for (final entry in report.modelUsage.entries)
                  UsageStatRow(
                    icon: Icons.auto_awesome_outlined,
                    title: entry.key,
                    valueWidget: _modelAvailabilityBadge(context, entry.value),
                  ),
              ],
            ),
          ],
          if (report.resetCredits != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _CodexResetCreditsSection(resetCredits: report.resetCredits!),
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
                ),
                UsageStatRow(
                  icon: Icons.payments_outlined,
                  title: l10n.codexUsageCreditsBalance,
                  value: report.credits!.unlimited
                      ? l10n.codexUsageUnlimited
                      : _formatBalance(context, report.credits!.balance),
                ),
              ],
            ),
          ],
        ];
      },
    );
  }
}

/// Plan types arrive as lowercase wire values (`plus`, `pro`, `team`).
String _formatPlan(String? plan) {
  final trimmed = plan?.trim();
  if (trimmed == null || trimmed.isEmpty) return '-';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

/// Credit balances arrive as raw decimal strings with ten fraction digits
/// (`73740.1767735000`); show a grouped number with at most two decimals.
String _formatBalance(BuildContext context, String? balance) {
  if (balance == null || balance.trim().isEmpty) return '-';
  final parsed = double.tryParse(balance.trim());
  if (parsed == null) return balance;
  final locale = Localizations.localeOf(context).toLanguageTag();
  return NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: parsed == parsed.truncateToDouble() ? 0 : 2,
  ).format(parsed);
}

Widget _modelAvailabilityBadge(BuildContext context, CodexModelUsage usage) {
  final l10n = AppLocalizations.of(context);
  if (usage.available) {
    return AppBadge(
      label: l10n.codexUsageAvailable,
      tone: AppBadgeTone.success,
    );
  }
  final availableAt = usage.availableAt;
  if (availableAt != null) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return AppBadge(
      label: l10n.codexUsageResetsAt(
        DateFormat.MMMd(locale).add_jm().format(availableAt.toLocal()),
      ),
      tone: AppBadgeTone.warning,
    );
  }
  if (usage.creditsWouldEnable) {
    return AppBadge(
      label: l10n.codexUsageCreditsRequired,
      tone: AppBadgeTone.warning,
    );
  }
  return AppBadge(label: l10n.commonNo, tone: AppBadgeTone.danger);
}

Future<CodexRateLimitResetCredits?> _fetchResetCredits(String machineId) async {
  final stopwatch = Stopwatch()..start();
  var outcome = 'ok';
  try {
    final result = await Sync()
        .machineGetCodexResetCredits(machineId: machineId)
        .timeout(const Duration(seconds: 2));
    if (result == null) outcome = 'unavailable';
    return result;
  } on TimeoutException {
    outcome = 'timeout';
    return null;
  } catch (_) {
    outcome = 'error';
    return null;
  } finally {
    OpenTelemetryService().recordDuration(
      'app.operation.stage',
      stopwatch.elapsed,
      attributes: {
        'operation': 'providers.codex_usage.load',
        'stage': 'reset_credits',
        'outcome': outcome,
      },
    );
  }
}

/// Footer line under a [UsageWindowRow]: "Resets in 4h 50m · 1:24 PM" —
/// the countdown first (what the user acts on), then the wall-clock time.
Widget? _windowFooter(BuildContext context, CodexUsageWindow window) {
  final description = _formatResetDescription(context, window);
  if (description == null) return null;
  final theme = Theme.of(context);
  return Text(
    description,
    style: AppText.secondary(theme, theme.colorScheme.onSurfaceVariant),
  );
}

String? _formatResetDescription(BuildContext context, CodexUsageWindow window) {
  final expiresAt = window.expiresAt?.toLocal();
  final seconds = window.resetAfterSeconds;
  final remaining = expiresAt != null
      ? expiresAt.difference(DateTime.now())
      : seconds != null
      ? Duration(seconds: seconds)
      : null;
  final relative = remaining == null || remaining <= Duration.zero
      ? null
      : _formatRemaining(remaining);
  if (expiresAt == null) return relative;

  final locale = Localizations.localeOf(context).toLanguageTag();
  final now = DateTime.now();
  final sameDay =
      expiresAt.year == now.year &&
      expiresAt.month == now.month &&
      expiresAt.day == now.day;
  final formatted = sameDay
      ? DateFormat.jm(locale).format(expiresAt)
      : DateFormat.MMMEd(locale).add_jm().format(expiresAt);
  final absolute = AppLocalizations.of(context).codexUsageResetsAt(formatted);
  return relative == null ? absolute : '$relative · $formatted';
}

String _formatRemaining(Duration dur) {
  if (dur.inHours >= 24) {
    return 'Resets in ${dur.inDays}d ${dur.inHours % 24}h';
  }
  if (dur.inHours >= 1) {
    return 'Resets in ${dur.inHours}h ${dur.inMinutes % 60}m';
  }
  return 'Resets in ${dur.inMinutes < 1 ? 1 : dur.inMinutes}m';
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
        ),
        for (final credit in available)
          UsageStatRow(
            icon: Icons.event_outlined,
            title: (credit.title?.trim().isNotEmpty ?? false)
                ? credit.title!
                : l10n.codexUsageLimitReset,
            value: _formatResetCreditExpiry(context, credit.expiresAt),
            flexValue: true,
          ),
      ],
    );
  }

  String _formatResetCreditExpiry(BuildContext context, DateTime? expiresAt) {
    final l10n = AppLocalizations.of(context);
    if (expiresAt == null) return l10n.codexUsageDoesNotExpire;
    final localExpiry = expiresAt.toLocal();
    final remaining = localExpiry.difference(DateTime.now());
    final locale =
        Intl.defaultLocale ?? Localizations.localeOf(context).toLanguageTag();
    final expiryTime = DateFormat.yMMMd(locale).add_jms().format(localExpiry);
    final days = remaining.isNegative
        ? 0
        : (remaining.inMinutes / Duration.minutesPerDay).ceil();
    return l10n.codexUsageExpiresInDays(days, expiryTime);
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
          title: l10n.codexUsageAllowed,
          value: rateLimit.allowed,
        ),
        if (rateLimit.primaryWindow != null)
          UsageWindowRow(
            icon: Icons.schedule_outlined,
            title: _windowTitle(
              context,
              rateLimit.primaryWindow!,
              windowTitles.primary,
            ),
            percent: rateLimit.primaryWindow!.usedPercent.toDouble(),
            footer: _windowFooter(context, rateLimit.primaryWindow!),
          ),
        if (rateLimit.secondaryWindow != null)
          UsageWindowRow(
            icon: Icons.calendar_today_outlined,
            title: _windowTitle(
              context,
              rateLimit.secondaryWindow!,
              windowTitles.secondary,
            ),
            percent: rateLimit.secondaryWindow!.usedPercent.toDouble(),
            footer: _windowFooter(context, rateLimit.secondaryWindow!),
          ),
      ],
    );
  }
}

/// Yes/no stat as a toned pill, so allowed/blocked states read at a glance
/// instead of as bare "Yes"/"No" text.
class _CodexUsageBooleanRow extends StatelessWidget {
  const _CodexUsageBooleanRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return UsageStatRow(
      icon: icon,
      title: title,
      valueWidget: AppBadge(
        label: value ? l10n.commonYes : l10n.commonNo,
        tone: value ? AppBadgeTone.success : AppBadgeTone.danger,
      ),
    );
  }
}

String _windowTitle(
  BuildContext context,
  CodexUsageWindow window,
  String fallback,
) {
  final l10n = AppLocalizations.of(context);
  return switch (window.limitWindowSeconds) {
    18000 => l10n.codexUsageFiveHourWindow,
    604800 => l10n.codexUsageWeeklyWindow,
    _ => fallback,
  };
}
