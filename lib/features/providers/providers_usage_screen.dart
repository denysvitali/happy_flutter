import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/provider_usage.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
import 'widgets/add_provider_dialog.dart';
import 'widgets/provider_usage_card.dart';

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

class _ProvidersUsageScreenState
    extends ConsumerState<ProvidersUsageScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.providersAddAccountFailed),
        ),
      );
    }
  }

  Future<void> _removeAccount(String accountId) async {
    final success = await ref
        .read(providerUsageNotifierProvider.notifier)
        .removeAccount(accountId);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.providersRemoveAccountFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = ref.watch(providerUsageNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.providersTitle),
        actions: [
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
        child: _buildBody(context, summary),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProviderUsageSummary summary) {
    final l10n = context.l10n;

    if (summary.usages.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: AppEmptyState(
              icon: Icons.cloud_outlined,
              title: l10n.providersEmptyTitle,
              subtitle: l10n.providersEmptySubtitle,
              action: ElevatedButton.icon(
                onPressed: _showAddProviderDialog,
                icon: const Icon(Icons.add),
                label: Text(l10n.providersAddAccount),
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppScreenPadding.standard,
      itemCount: summary.usages.length + 1,
      itemBuilder: (context, index) {
        if (index == summary.usages.length) {
          return SizedBox(height: AppSpacing.xxxl);
        }
        final usage = summary.usages[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: ProviderUsageCard(
            usage: usage,
            onRemove: () => _removeAccount(usage.accountId),
          ),
        );
      },
    );
  }
}
