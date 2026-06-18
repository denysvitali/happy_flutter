import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/claude_local_usage.dart';
import '../../core/models/claude_usage_limits.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/token_usage_chart.dart';

/// Screen showing Claude Code rate limits fetched from a connected
/// machine's local Claude credentials.
class ClaudeLimitsScreen extends ConsumerStatefulWidget {
  const ClaudeLimitsScreen({super.key});

  @override
  ConsumerState<ClaudeLimitsScreen> createState() =>
      _ClaudeLimitsScreenState();
}

class _ClaudeLimitsScreenState
    extends ConsumerState<ClaudeLimitsScreen> {
  String? _selectedMachineId;
  ClaudeUsageLimits? _limits;
  bool _isLoading = false;
  String? _error;

  // Local-usage state (scraped from ~/.claude/stats-cache.json).
  // Loaded in parallel with the OAuth limits; failures here do NOT
  // block the OAuth limits from rendering.
  ClaudeLocalUsage? _localUsage;
  bool _isLoadingLocal = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      _autoSelectMachine();
    });
  }

  void _autoSelectMachine() {
    final machines =
        ref.read(machinesNotifierProvider).values.toList();
    final online = machines.where(_isMachineOnline).toList();
    final target = online.isNotEmpty ? online.first : null;
    if (target != null) {
      setState(() => _selectedMachineId = target.id);
      _loadAll(target.id);
    }
  }

  bool _isMachineOnline(Machine m) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const onlineThresholdMs = 120 * 1000; // 2 min
    return now - m.activeAt < onlineThresholdMs;
  }

  Future<void> _loadAll(String machineId) async {
    setState(() {
      _isLoading = true;
      _isLoadingLocal = true;
      _error = null;
      _localError = null;
      _limits = null;
      _localUsage = null;
    });
    await Future.wait([
      _loadLimits(machineId),
      _loadLocalUsage(machineId),
    ]);
  }

  Future<void> _loadLimits(String machineId) async {
    final response = await Sync().machineGetClaudeUsageLimits(
      machineId: machineId,
    );

    if (!mounted) return;

    if (!response.success || response.data == null) {
      setState(() {
        _error = response.error ?? 'Unknown error';
        _isLoading = false;
      });
      return;
    }

    try {
      final json =
          jsonDecode(response.data!) as Map<String, dynamic>;
      setState(() {
        _limits = ClaudeUsageLimits.fromJson(json);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to parse response: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocalUsage(String machineId) async {
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
      final json =
          jsonDecode(response.data!) as Map<String, dynamic>;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final machines = ref.watch(machinesNotifierProvider);

    if (machines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.claudeLimitsTitle)),
        body: AppEmptyState(
          icon: Icons.computer,
          title: l10n.claudeLimitsNoMachines,
          subtitle: l10n.claudeLimitsNoMachinesSubtitle,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.claudeLimitsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.claudeLocalUsageRefresh,
            onPressed: _selectedMachineId == null
                ? null
                : () => _loadAll(_selectedMachineId!),
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null
              ? _ErrorBody(
                  error: _error!,
                  onRetry: () {
                    if (_selectedMachineId != null) {
                      _loadAll(_selectedMachineId!);
                    }
                  },
                )
              : _limits != null
                  ? _LimitsBody(
                      machines: machines,
                      selectedMachineId: _selectedMachineId,
                      limits: _limits!,
                      localUsage: _localUsage,
                      isLoadingLocal: _isLoadingLocal,
                      localError: _localError,
                      onMachineChanged: (id) {
                        setState(
                          () => _selectedMachineId = id,
                        );
                        if (id != null) _loadAll(id);
                      },
                    )
                  : _NoDataBody(
                      machines: machines,
                      selectedMachineId: _selectedMachineId,
                      onMachineChanged: (id) {
                        setState(
                          () => _selectedMachineId = id,
                        );
                        if (id != null) _loadAll(id);
                      },
                    ),
    );
  }
}

class _LimitsBody extends StatelessWidget {
  const _LimitsBody({
    required this.machines,
    required this.selectedMachineId,
    required this.limits,
    required this.localUsage,
    required this.isLoadingLocal,
    required this.localError,
    required this.onMachineChanged,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final ClaudeUsageLimits limits;
  final ClaudeLocalUsage? localUsage;
  final bool isLoadingLocal;
  final String? localError;
  final ValueChanged<String?> onMachineChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final windows = limits.activeWindows;

    return ListView(
      padding: AppScreenPadding.settings,
      children: [
        _MachinePicker(
          machines: machines,
          selectedMachineId: selectedMachineId,
          onChanged: onMachineChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (windows.isNotEmpty)
          SettingsSection(
            title: l10n.claudeLimitsUsage,
            children: [
              for (final (label, window) in windows)
                _UsageWindowRow(label: label, window: window),
            ],
          ),
        if (limits.extraUsage != null &&
            limits.extraUsage!.isEnabled) ...[
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.claudeLimitsExtraUsage,
            children: [
              if (limits.extraUsage!.monthlyLimit != null)
                _StatRow(
                  icon: Icons.credit_card,
                  title: l10n.claudeLimitsMonthlyLimit,
                  value: '\$${limits.extraUsage!.monthlyLimit!
                      .toStringAsFixed(2)}',
                  iconColor: cs.primary,
                ),
              if (limits.extraUsage!.usedCredits != null)
                _StatRow(
                  icon: Icons.receipt_long,
                  title: l10n.claudeLimitsUsedCredits,
                  value: '\$${limits.extraUsage!.usedCredits!
                      .toStringAsFixed(2)}',
                  iconColor: AppColors.warning,
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _LocalUsageSection(
          usage: localUsage,
          isLoading: isLoadingLocal,
          error: localError,
        ),
      ],
    );
  }
}

class _NoDataBody extends StatelessWidget {
  const _NoDataBody({
    required this.machines,
    required this.selectedMachineId,
    required this.onMachineChanged,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final ValueChanged<String?> onMachineChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: AppScreenPadding.settings,
          child: _MachinePicker(
            machines: machines,
            selectedMachineId: selectedMachineId,
            onChanged: onMachineChanged,
          ),
        ),
        const Spacer(),
        AppEmptyState(
          icon: Icons.speed,
          title: l10n.claudeLimitsNotAvailable,
          subtitle: l10n.claudeLimitsNotAvailableSubtitle,
        ),
        const Spacer(),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
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
      title: l10n.claudeLimitsNotAvailable,
      subtitle: error,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.commonRetry),
      ),
    );
  }
}

class _MachinePicker extends StatelessWidget {
  const _MachinePicker({
    required this.machines,
    required this.selectedMachineId,
    required this.onChanged,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SettingsSection(
      title: l10n.claudeLimitsSelectMachine,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DropdownButtonFormField<String>(
            initialValue: selectedMachineId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppRadius.sm),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              isDense: true,
            ),
            items: machines.values.map((m) {
              final name = m.metadata?.displayName ??
                  m.metadata?.host ??
                  m.id;
              final now =
                  DateTime.now().millisecondsSinceEpoch;
              const threshold = 120 * 1000; // 2 min
              final online = now - m.activeAt < threshold;
              return DropdownMenuItem(
                value: m.id,
                child: Row(
                  children: [
                    Icon(
                      online
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 10,
                      color: online
                          ? AppColors.success
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _UsageWindowRow extends StatelessWidget {
  const _UsageWindowRow({
    required this.label,
    required this.window,
  });

  final String label;
  final ClaudeUsageWindow window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final resetsIn = _formatResetsAt(window.resetsAt);

    // Pick colour based on utilization.
    final Color barColor;
    if (window.utilization >= 90) {
      barColor = AppColors.error;
    } else if (window.utilization >= 70) {
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
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${window.utilization.toStringAsFixed(0)}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius:
                BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: window.fraction,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor:
                  AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (resetsIn != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              resetsIn,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
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

class _StatRow extends StatelessWidget {
  const _StatRow({
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
          SettingsIconContainer(
            icon: icon,
            color: iconColor,
          ),
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
      final isOldDaemon = error != null &&
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
        _StatRow(
          icon: Icons.functions,
          title: l10n.claudeLocalUsageTotal,
          value: '${ClaudeLocalUsage.formatTokenCount(u.totalTokens)} '
              'tokens',
          iconColor: cs.primary,
        ),
      );
      if (u.lastComputedDate != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
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
          Expanded(
            child: Text(
              date,
              style: theme.textTheme.bodySmall,
            ),
          ),
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
