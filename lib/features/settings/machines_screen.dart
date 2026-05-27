import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/components/app_empty_state.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/sync_subscription_mixin.dart';

class MachinesScreen extends ConsumerStatefulWidget {
  const MachinesScreen({super.key});

  @override
  ConsumerState<MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends ConsumerState<MachinesScreen>
    with SyncSubscriptionMixin {
  final Set<String> _deletingMachineIds = <String>{};

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(machinesNotifierProvider.notifier).refreshFromSync(),
    );
    subscribeToDomains([SyncDomain.machines], () {
      ref.read(machinesNotifierProvider.notifier).loadFromSync();
    });
  }

  Future<void> _deleteMachine(Machine machine) async {
    final machineId = machine.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.commonDelete),
          content: Text(
            l10n.machineRemoveConfirm(
              machine.metadata?.displayName ??
                  machine.metadata?.host ??
                  machine.id,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingMachineIds.add(machineId);
    });

    final response = await ApiClient().delete('/v1/machines/$machineId');

    if (!mounted) {
      return;
    }

    setState(() {
      _deletingMachineIds.remove(machineId);
    });

    if (ApiClient().isSuccess(response)) {
      ref.read(machinesNotifierProvider.notifier).remove(machineId);
      sync.machinesSync.invalidate();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.machineDeleteFailed(response.statusCode ?? 0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final machines = ref.watch(machinesNotifierProvider);
    final machineList = machines.values.toList()
      ..sort((a, b) {
        if (a.active == b.active) {
          return b.activeAt.compareTo(a.activeAt);
        }
        return a.active ? -1 : 1;
      });

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsMachines)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(machinesNotifierProvider.notifier).refreshFromSync(),
        child: machineList.isEmpty
            ? const _MachinesEmptyState()
            : _MachinesList(
                machines: machineList,
                deletingIds: _deletingMachineIds,
                onDelete: _deleteMachine,
              ),
      ),
    );
  }
}

class _MachinesList extends StatelessWidget {
  const _MachinesList({
    required this.machines,
    required this.deletingIds,
    required this.onDelete,
  });

  final List<Machine> machines;
  final Set<String> deletingIds;
  final void Function(Machine machine) onDelete;

  String _machineTitle(Machine machine) {
    final metadata = machine.metadata;
    return metadata?.displayName ?? metadata?.host ?? machine.id;
  }

  String _machineSubtitle(BuildContext context, Machine machine) {
    final l10n = AppLocalizations.of(context);
    final platform = machine.metadata?.platform ?? l10n.commonUnknown;
    final status = machine.active ? l10n.machineOnline : l10n.machineOffline;
    return '$platform • $status';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppScreenPadding.settings,
      children: [
        SettingsSection(
          title: context.l10n.settingsMachines,
          children: [
            for (final machine in machines)
              SettingsRow(
                icon: Icons.computer_outlined,
                iconColor: machine.active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: AppOpacity.medium),
                title: _machineTitle(machine),
                subtitle: _machineSubtitle(context, machine),
                onTap: () => context.pushNamed(
                  'machine-detail',
                  pathParameters: {'machineId': machine.id},
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppStatusDot(
                      color: machine.active
                          ? AppColors.success
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(
                                alpha: AppOpacity.medium,
                              ),
                      size: AppSpacing.sm,
                      pulse: machine.active,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (deletingIds.contains(machine.id))
                      const SizedBox(
                        width: AppSpacing.xl,
                        height: AppSpacing.xl,
                        child: Padding(
                          padding: EdgeInsets.all(
                            AppSpacing.xxs,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context)
                              .colorScheme
                              .error,
                        ),
                        onPressed: () => onDelete(machine),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MachinesEmptyState extends StatelessWidget {
  const _MachinesEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.15,
        ),
        AppEmptyState(
          icon: Icons.computer_outlined,
          title: context.l10n.machinesNoMachines,
        ),
      ],
    );
  }
}
