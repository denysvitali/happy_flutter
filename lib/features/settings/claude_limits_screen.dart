import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/claude_local_usage.dart';
import '../../core/models/claude_usage_limits.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/machine_usage_scaffold.dart';
import 'widgets/token_usage_chart.dart';

/// Screen showing Claude Code rate limits fetched from a connected
/// machine's local Claude credentials.
class ClaudeLimitsScreen extends ConsumerStatefulWidget {
  const ClaudeLimitsScreen({super.key});

  @override
  ConsumerState<ClaudeLimitsScreen> createState() =>
      _ClaudeLimitsScreenState();
}

class _ClaudeLimitsScreenState extends ConsumerState<ClaudeLimitsScreen> {
  // Local-usage state (scraped from ~/.claude/stats-cache.json).
  // Loaded in parallel with the OAuth limits; failures here do NOT
  // block the OAuth limits from rendering.
  ClaudeLocalUsage? _localUsage;
  bool _isLoadingLocal = false;
  String? _localError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MachineUsageScaffold<ClaudeUsageLimits>(
      title: l10n.claudeLimitsTitle,
      pickerTitle: l10n.claudeLimitsSelectMachine,
      noMachinesIcon: Icons.computer,
      noMachinesTitle: l10n.claudeLimitsNoMachines,
      noMachinesSubtitle: l10n.claudeLimitsNoMachinesSubtitle,
      emptyIcon: Icons.speed,
      emptyTitle: l10n.claudeLimitsNotAvailable,
      emptySubtitle: l10n.claudeLimitsNotAvailableSubtitle,
      fetch: _fetch,
      actionsBuilder: (controller) => [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: l10n.claudeLocalUsageRefresh,
          onPressed: controller.selectedMachineId == null
              ? null
              : controller.refresh,
        ),
      ],
      contentBuilder: (context, limits) => _buildSections(context, limits),
    );
  }

  /// Fetch round for the shared scaffold. Starts the local-usage side
  /// load first so both requests fly in parallel, then resolves with the
  /// OAuth limits; a local-usage failure never blocks this result.
  Future<MachineUsageSnapshot<ClaudeUsageLimits>> _fetch(
    String machineId,
  ) async {
    unawaited(_loadLocalUsage(machineId));

    final response = await Sync().machineGetClaudeUsageLimits(
      machineId: machineId,
    );

    if (!response.success || response.data == null) {
      return MachineUsageSnapshot<ClaudeUsageLimits>.error(
        response.error ?? 'Unknown error',
      );
    }

    try {
      final json = jsonDecode(response.data!) as Map<String, dynamic>;
      return MachineUsageSnapshot<ClaudeUsageLimits>.data(
        ClaudeUsageLimits.fromJson(json),
      );
    } catch (e) {
      return MachineUsageSnapshot<ClaudeUsageLimits>.error(
        'Failed to parse response: $e',
      );
    }
  }

  Future<void> _loadLocalUsage(String machineId) async {
    setState(() {
      _isLoadingLocal = true;
      _localError = null;
      _localUsage = null;
    });

    final response = await Sync().machineGetClaudeLocalUsage(
      machineId: machineId,
    );

    if (!mounted) return;

    if (!response.success || response.data == null) {
      setState(() {
        _localError = response.error ?? 'Unknown error';
        _isLoadingLocal = false;
      });
      return;
    }

    try {
      final json = jsonDecode(response.data!) as Map<String, dynamic>;
      setState(() {
        _localUsage = ClaudeLocalUsage.fromJson(json);
        _isLoadingLocal = false;
      });
    } catch (e) {
      setState(() {
        _localError = 'Failed to parse response: $e';
        _isLoadingLocal = false;
      });
    }
  }

  List<Widget> _buildSections(BuildContext context, ClaudeUsageLimits limits) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final windows = limits.activeWindows;
    final extraUsage = limits.extraUsage;
    final monthlyLimit = extraUsage?.monthlyLimit;
    final usedCredits = extraUsage?.usedCredits;
    final monthlyLimitLabel = monthlyLimit == null
        ? null
        : '\$${monthlyLimit.toStringAsFixed(2)}';
    final usedCreditsLabel = usedCredits == null
        ? null
        : '\$${usedCredits.toStringAsFixed(2)}';

    return [
      if (windows.isNotEmpty)
        SettingsSection(
          title: l10n.claudeLimitsUsage,
          children: [
            for (final (label, window) in windows)
              UsageWindowRow(
                title: label,
                percent: window.utilization,
                footer: _usageWindowFooter(context, window),
              ),
          ],
        ),
      if (extraUsage != null && extraUsage.isEnabled) ...[
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: l10n.claudeLimitsExtraUsage,
          children: [
            if (monthlyLimitLabel != null)
              ContainerUsageStatRow(
                icon: Icons.credit_card,
                title: l10n.claudeLimitsMonthlyLimit,
                value: monthlyLimitLabel,
                iconColor: cs.primary,
              ),
            if (usedCreditsLabel != null)
              ContainerUsageStatRow(
                icon: Icons.receipt_long,
                title: l10n.claudeLimitsUsedCredits,
                value: usedCreditsLabel,
                iconColor: AppColors.warning,
              ),
          ],
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      _LocalUsageSection(
        usage: _localUsage,
        isLoading: _isLoadingLocal,
        error: _localError,
      ),
    ];
  }

  Widget? _usageWindowFooter(BuildContext context, ClaudeUsageWindow window) {
    final resetsIn = _formatResetsAt(window.resetsAt);
    if (resetsIn == null) return null;
    final theme = Theme.of(context);
    return Text(
      resetsIn,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String? _formatResetsAt(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return null;
    if (diff.inHours >= 24) {
      final days = diff.inDays;
      return 'Resets in ${days}d ${diff.inHours % 24}h';
    }
    if (diff.inHours >= 1) {
      return 'Resets in ${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return 'Resets in ${diff.inMinutes}m';
  }
}

/// Section rendering the local token usage scraped from
/// `~/.claude/stats-cache.json` on the selected machine.
class _LocalUsageSection extends StatelessWidget {
  const _LocalUsageSection({
    required this.usage,
    required this.isLoading,
    required this.error,
  });

  final ClaudeLocalUsage? usage;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final children = <Widget>[];

    if (isLoading && usage == null) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: AppLoadingIndicator(),
        ),
      );
    } else if (usage == null) {
      // Error / no data branch — never block the OAuth limits.
      final isOldDaemon =
          error != null &&
          error!.toLowerCase().contains('rpc method not available');
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                isOldDaemon ? Icons.system_update_alt : Icons.error_outline,
                color: isOldDaemon ? cs.primary : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  isOldDaemon
                      ? l10n.claudeLocalUsageRequiresUpdate
                      : (l10n.claudeLocalUsageFailed +
                            (error != null ? ' — $error' : '')),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final u = usage!;
      // Total row.
      children.add(
        ContainerUsageStatRow(
          icon: Icons.functions,
          title: l10n.claudeLocalUsageTotal,
          value:
              '${ClaudeLocalUsage.formatTokenCount(u.totalTokens)} '
              'tokens',
          iconColor: cs.primary,
        ),
      );
      if (u.lastComputedDate != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              '${l10n.claudeLocalUsageLifetime}: '
              '${u.lastComputedDate}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      }

      // Quick metrics row.
      children.addAll([
        const SizedBox(height: AppSpacing.md),
        TokenUsageMetrics(usage: u),
        const SizedBox(height: AppSpacing.md),
      ]);

      // Per-model breakdown (sorted by tokens desc).
      if (u.sortedTokensByModel.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.claudeLocalUsageNoData,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.claudeLocalUsageNoDataSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        for (final entry in u.sortedTokensByModel) {
          final pct = u.totalTokens == 0
              ? 0
              : ((entry.value * 100) / u.totalTokens).round();
          children.add(
            _ModelTokenRow(
              modelName: ClaudeLocalUsage.formatModelName(entry.key),
              rawModelId: entry.key,
              tokens: entry.value,
              percentage: pct,
            ),
          );
        }
      }

      // Trend chart + daily breakdown.
      if (u.dailyModelTokens.isNotEmpty) {
        children
          ..add(const SizedBox(height: AppSpacing.md))
          ..add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                l10n.claudeLocalUsageLast30Days,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )
          ..add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: TokenUsageChart(
                dailyModelTokens: u.dailyModelTokens,
                maxDays: 30,
              ),
            ),
          );

        final last7 = u.dailyModelTokens.length > 7
            ? u.dailyModelTokens.sublist(u.dailyModelTokens.length - 7)
            : u.dailyModelTokens;
        for (final day in last7) {
          final dayTotal = day.tokensByModel.values.fold<int>(
            0,
            (a, b) => a + b,
          );
          // Top model for the day.
          var topModel = '';
          var topTokens = 0;
          day.tokensByModel.forEach((model, tokens) {
            if (tokens > topTokens) {
              topModel = model;
              topTokens = tokens;
            }
          });
          children.add(
            _DailyTokenRow(
              date: day.date,
              totalTokens: dayTotal,
              topModelName: topModel.isEmpty
                  ? null
                  : ClaudeLocalUsage.formatModelName(topModel),
            ),
          );
        }
      }
    }

    return SettingsSection(
      title: l10n.claudeLocalUsageSection,
      children: children,
    );
  }
}

class _ModelTokenRow extends StatelessWidget {
  const _ModelTokenRow({
    required this.modelName,
    required this.rawModelId,
    required this.tokens,
    required this.percentage,
  });

  final String modelName;
  final String rawModelId;
  final int tokens;
  final int percentage;

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modelName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  rawModelId,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${ClaudeLocalUsage.formatTokenCount(tokens)} ($percentage%)',
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

class _DailyTokenRow extends StatelessWidget {
  const _DailyTokenRow({
    required this.date,
    required this.totalTokens,
    required this.topModelName,
  });

  final String date;
  final int totalTokens;
  final String? topModelName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(date, style: theme.textTheme.bodySmall)),
          if (topModelName != null) ...[
            Text(
              topModelName!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            ClaudeLocalUsage.formatTokenCount(totalTokens),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
