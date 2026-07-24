import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/provider_usage.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/add_provider_dialog.dart';
import 'widgets/provider_usage_card.dart';
import 'widgets/rename_provider_dialog.dart';
import '../../core/utils/snack.dart';

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

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(providerUsageNotifierProvider.notifier).loadAccounts();
      if (mounted) {
        await ref.read(providerUsageNotifierProvider.notifier).refreshUsage();
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
    final visibleSelectedUsages = summary.usages
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
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(providerUsageNotifierProvider.notifier).refreshUsage();
        },
        child: _ProvidersUsageBody(
          summary: summary,
          onAddProvider: _showAddProviderDialog,
          selectedAccountIds: _selectedAccountIds,
          onSelectAccount: _selectAccount,
          onToggleSelection: _toggleSelection,
          onTapAccount: _renameAccount,
        ),
      ),
    );
  }
}

class _ProvidersUsageBody extends StatelessWidget {
  const _ProvidersUsageBody({
    required this.summary,
    required this.onAddProvider,
    required this.selectedAccountIds,
    required this.onSelectAccount,
    required this.onToggleSelection,
    required this.onTapAccount,
  });

  final ProviderUsageSummary summary;
  final VoidCallback onAddProvider;
  final Set<String> selectedAccountIds;
  final ValueChanged<String> onSelectAccount;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<ProviderUsage> onTapAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (summary.usages.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppScreenPadding.standard,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const _ProviderUsageDestinations(),
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
        const _ProviderUsageDestinations(),
        const SizedBox(height: AppSpacing.md),
        for (final usage in summary.usages)
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
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _ProviderUsageDestinations extends StatelessWidget {
  const _ProviderUsageDestinations();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.providersUsageSectionTitle,
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
