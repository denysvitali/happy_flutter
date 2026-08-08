import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/app_section_header.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/provider_usage.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/snack.dart';
import 'widgets/add_provider_dialog.dart';
import 'widgets/provider_usage_card.dart';
import 'widgets/rename_provider_dialog.dart';

/// Tab screen showing usage across third-party LLM providers.
///
/// Displays configured Kimi, MiniMax, Claude Code, and Codex accounts with
/// their usage windows and allows adding or removing accounts.
class ProvidersUsageScreen extends ConsumerStatefulWidget {
  const ProvidersUsageScreen({super.key});

  @override
  ConsumerState<ProvidersUsageScreen> createState() =>
      _ProvidersUsageScreenState();
}

class _ProvidersUsageScreenState extends ConsumerState<ProvidersUsageScreen> {
  final Set<String> _selectedAccountIds = <String>{};
  bool _initialLoadComplete = false;
  String? _initialLoadError;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      try {
        final notifier = ref.read(providerUsageNotifierProvider.notifier);
        await notifier.loadAccounts();
        if (mounted) {
          setState(() => _initialLoadComplete = true);
          await notifier.refreshUsage();
        }
      } on Object catch (error, stack) {
        logger.warning('Provider account load failed', error, stack);
        if (mounted) {
          setState(() => _initialLoadError = error.toString());
        }
      } finally {
        if (mounted && !_initialLoadComplete) {
          setState(() => _initialLoadComplete = true);
        }
      }
    });
  }

  Future<void> _showAddProviderDialog() async {
    final result = await showDialog<ProviderAccountInput?>(
      context: context,
      builder: (_) => const AddProviderDialog(),
    );
    if (result == null || !mounted) return;

    final success = await ref
        .read(providerUsageNotifierProvider.notifier)
        .addAccount(
          type: result.type,
          credentials: result.credentials,
          name: result.name,
        );

    if (!mounted) return;

    if (!success) {
      context.showSnack(context.l10n.providersAddAccountFailed);
    }
  }

  void _toggleSelection(String accountId) {
    setState(() {
      if (!_selectedAccountIds.add(accountId)) {
        _selectedAccountIds.remove(accountId);
      }
    });
  }

  void _selectAccount(String accountId) {
    setState(() => _selectedAccountIds.add(accountId));
  }

  void _clearSelection() {
    setState(_selectedAccountIds.clear);
  }

  Future<void> _renameAccount(ProviderUsage usage) async {
    final l10n = context.l10n;
    final outcome = await showRenameProviderDialog(
      context,
      accountId: usage.accountId,
      currentName: usage.accountName,
      type: usage.type,
    );
    if (outcome == null || !mounted) return;

    // No-op when the user re-saves the same label they had before.
    final prior = usage.accountName?.trim();
    if ((prior == null || prior.isEmpty) && outcome.name == null) return;
    if (prior != null && prior == outcome.name) return;

    final success = await ref
        .read(providerUsageNotifierProvider.notifier)
        .renameAccount(usage.accountId, outcome.name);

    if (!mounted) return;
    if (!success) {
      context.showSnack(l10n.providersRenameAccountFailed);
    }
  }

  Future<void> _removeSelectedAccounts(List<ProviderUsage> usages) async {
    final l10n = context.l10n;
    if (usages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.commonDeleteConfirmTitle),
        content: Text(
          usages.length == 1
              ? l10n.providersDeleteConfirmMessage(
                  usages.single.accountName ?? usages.single.type.name,
                )
              : l10n.providersDeleteSelectedConfirmMessage(usages.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(
                dialogContext,
              ).colorScheme.onErrorContainer,
              backgroundColor: Theme.of(
                dialogContext,
              ).colorScheme.errorContainer,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    var success = true;
    final notifier = ref.read(providerUsageNotifierProvider.notifier);
    for (final usage in usages) {
      final removed = await notifier.removeAccount(usage.accountId);
      success = success && removed;
    }

    if (!mounted) return;

    if (success) {
      _clearSelection();
    } else {
      context.showSnack(context.l10n.providersRemoveAccountFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = ref.watch(providerUsageNotifierProvider);
    final visibleSummary = _initialLoadError == null
        ? summary
        : summary.copyWith(globalError: _initialLoadError);
    final visibleSelectedUsages = visibleSummary.usages
        .where((usage) => _selectedAccountIds.contains(usage.accountId))
        .toList();
    final isSelectionMode = visibleSelectedUsages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.commonCancel,
                onPressed: _clearSelection,
              )
            : null,
        title: Text(
          isSelectionMode
              ? l10n.providersSelectedCount(visibleSelectedUsages.length)
              : l10n.providersTitle,
        ),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.commonDelete,
              onPressed: () => _removeSelectedAccounts(visibleSelectedUsages),
            )
          else
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.providersAddAccount,
              onPressed: _showAddProviderDialog,
            ),
        ],
      ),
      body: !_initialLoadComplete
          ? const AppLoadingIndicator()
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoint.contentMax,
                ),
                child: RefreshIndicator(
                  onRefresh: _refreshUsage,
                  child: _ProvidersUsageBody(
                    summary: visibleSummary,
                    onRefresh: _refreshUsage,
                    onAddProvider: _showAddProviderDialog,
                    selectedAccountIds: _selectedAccountIds,
                    onSelectAccount: _selectAccount,
                    onToggleSelection: _toggleSelection,
                    onTapAccount: _renameAccount,
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _refreshUsage() async {
    try {
      final notifier = ref.read(providerUsageNotifierProvider.notifier);
      await notifier.loadAccounts();
      await notifier.refreshUsage();
      if (mounted && _initialLoadError != null) {
        setState(() => _initialLoadError = null);
      }
    } on Object catch (error, stack) {
      logger.warning('Provider usage refresh failed', error, stack);
      if (mounted) setState(() => _initialLoadError = error.toString());
    }
  }
}

class _ProvidersUsageBody extends StatelessWidget {
  const _ProvidersUsageBody({
    required this.summary,
    required this.onRefresh,
    required this.onAddProvider,
    required this.selectedAccountIds,
    required this.onSelectAccount,
    required this.onToggleSelection,
    required this.onTapAccount,
  });

  final ProviderUsageSummary summary;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddProvider;
  final Set<String> selectedAccountIds;
  final ValueChanged<String> onSelectAccount;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<ProviderUsage> onTapAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final orderedUsages = [...summary.usages]
      ..sort((a, b) {
        final aAttention = a.error != null ? 0 : 1;
        final bAttention = b.error != null ? 0 : 1;
        return aAttention.compareTo(bAttention);
      });

    if (summary.usages.isEmpty && summary.globalError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppScreenPadding.standard,
        children: [
          AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.providersUsageStale,
            subtitle: summary.globalError,
            action: FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ),
        ],
      );
    }

    if (summary.usages.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppScreenPadding.standard,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                _ProviderOverview(summary: summary),
                const SizedBox(height: AppSpacing.lg),
                AppEmptyState(
                  icon: Icons.cloud_outlined,
                  title: l10n.providersEmptyTitle,
                  subtitle: l10n.providersEmptySubtitle,
                  action: ElevatedButton.icon(
                    onPressed: onAddProvider,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.providersAddAccount),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _ProviderUsageDestinations(),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppScreenPadding.standard,
      children: [
        _ProviderOverview(summary: summary),
        if (summary.globalError != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ProviderRefreshError(
            message: summary.globalError!,
            onRetry: onRefresh,
          ),
        ],
        AppSectionHeader(
          title: l10n.providersConnectedAccounts,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
        ),
        for (final usage in orderedUsages)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: ProviderUsageCard(
              usage: usage,
              isSelectionMode: selectedAccountIds.isNotEmpty,
              isSelected: selectedAccountIds.contains(usage.accountId),
              onTap: () {
                if (selectedAccountIds.isNotEmpty) {
                  onToggleSelection(usage.accountId);
                } else {
                  onTapAccount(usage);
                }
              },
              onLongPress: () => onSelectAccount(usage.accountId),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        const _ProviderUsageDestinations(),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _ProviderOverview extends StatelessWidget {
  const _ProviderOverview({required this.summary});

  final ProviderUsageSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final attentionCount = summary.usages
        .where((usage) => usage.error != null)
        .length;
    final hasAttention = attentionCount > 0 || summary.globalError != null;
    final subtitle = summary.globalError != null
        ? l10n.providersUsageStale
        : summary.usages.isEmpty
        ? l10n.providersEmptySubtitle
        : l10n.providersAttentionSummary(attentionCount);
    final statusColor = hasAttention ? cs.error : cs.primary;

    return Semantics(
      container: true,
      liveRegion: summary.isLoading || hasAttention,
      label:
          '${l10n.providersAccountSummary(summary.usages.length)}. '
          '$subtitle',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: AppOpacity.medium),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: AppTouchTarget.min,
                  height: AppTouchTarget.min,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: AppOpacity.faint),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    hasAttention
                        ? Icons.cloud_off_outlined
                        : Icons.cloud_done_outlined,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.providersAccountSummary(summary.usages.length),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (summary.isLoading) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                label: l10n.providersUpdatingUsage,
                child: const LinearProgressIndicator(),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.providersUpdatingUsage,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProviderRefreshError extends StatelessWidget {
  const _ProviderRefreshError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.errorContainer,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onErrorContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderUsageDestinations extends StatelessWidget {
  const _ProviderUsageDestinations();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.providersBuiltInLimits,
      children: [
        SettingsNavRow(
          icon: Icons.speed,
          title: l10n.claudeCodeLimits,
          subtitle: l10n.claudeCodeLimitsSubtitle,
          onTap: () => context.pushNamed('claude-limits'),
        ),
        SettingsNavRow(
          icon: Icons.code,
          title: l10n.codexUsageTitle,
          subtitle: l10n.codexUsageSubtitle,
          onTap: () => context.pushNamed('codex-usage'),
        ),
        SettingsNavRow(
          icon: Icons.auto_awesome,
          title: l10n.grokUsageTitle,
          subtitle: l10n.grokUsageSubtitle,
          onTap: () => context.pushNamed('grok-usage'),
        ),
      ],
    );
  }
}
