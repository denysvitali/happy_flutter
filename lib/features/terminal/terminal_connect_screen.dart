import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/components/app_card.dart';
import '../../core/components/app_status_dot.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Terminal connect screen — select a machine and enter a terminal ID
/// to establish a terminal connection.
class TerminalConnectScreen extends ConsumerStatefulWidget {
  const TerminalConnectScreen({super.key});

  @override
  ConsumerState<TerminalConnectScreen> createState() =>
      _TerminalConnectScreenState();
}

class _TerminalConnectScreenState extends ConsumerState<TerminalConnectScreen> {
  String? _selectedMachineId;
  final _terminalIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _terminalIdController.dispose();
    super.dispose();
  }

  void _handleConnect() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final machineId = _selectedMachineId;
    final terminalId = _terminalIdController.text.trim();

    context.push(
      '/terminal',
      extra: {'machineId': machineId, 'terminalId': terminalId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final machineSortNow = DateTime.now().millisecondsSinceEpoch;
    final machineList = ref.watch(machinesListProvider).toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(machineSortNow, a, b));
    final hasOnlineMachine = machineList.any((machine) => machine.isOnline);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.terminalConnect,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: AppOpacity.faint),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(Icons.terminal, color: cs.primary, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        context.l10n.terminalConnectInfo,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  context.l10n.sessionSelectMachine.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (machineList.isEmpty)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.computer_outlined,
                        color: cs.onSurfaceVariant,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          context.l10n.terminalNoMachines,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMachineId,
                    selectedItemBuilder: (context) => machineList
                        .map(
                          (machine) => Text(
                            machine.displayLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                        .toList(),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      prefixIcon: const Icon(Icons.computer_outlined),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: AppTouchTarget.min,
                        minHeight: AppTouchTarget.min,
                      ),
                    ),
                    hint: Text(context.l10n.terminalSelectMachineHint),
                    isExpanded: true,
                    items: machineList.map((machine) {
                      final online = machine.isOnline;
                      return DropdownMenuItem<String>(
                        value: machine.id,
                        enabled: online,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppStatusDot(
                              color: online
                                  ? AppColors.success
                                  : cs.onSurfaceVariant,
                              size: 8,
                              semanticLabel: online
                                  ? context.l10n.machineOnline
                                  : context.l10n.machineOffline,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                machine.displayLabel,
                                overflow: TextOverflow.ellipsis,
                                style: online
                                    ? null
                                    : theme.textTheme.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                              ),
                            ),
                            if (!online) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                ),
                                child: Text(
                                  context.l10n.machineOffline,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final machine = _machineById(machineList, value);
                        if (machine != null && !machine.isOnline) {
                          return;
                        }
                      }
                      setState(() {
                        _selectedMachineId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.l10n.terminalSelectMachineError;
                      }
                      final machine = _machineById(machineList, value);
                      if (machine != null && !machine.isOnline) {
                        return context.l10n.terminalSelectMachineError;
                      }
                      return null;
                    },
                  ),
                ),

              const SizedBox(height: AppSpacing.xxl),

              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  context.l10n.terminalIdLabel.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: TextFormField(
                  controller: _terminalIdController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    prefixIcon: const Icon(Icons.tag),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: AppTouchTarget.min,
                      minHeight: AppTouchTarget.min,
                    ),
                    hintText: context.l10n.terminalIdHint,
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant.withValues(
                        alpha: AppOpacity.half,
                      ),
                    ),
                  ),
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleConnect(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.terminalIdError;
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              FilledButton.icon(
                onPressed: hasOnlineMachine ? _handleConnect : null,
                icon: const Icon(Icons.link),
                label: Text(context.l10n.commonContinue),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    AppTouchTarget.comfortable,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Machine? _machineById(List<Machine> machines, String id) {
  for (final machine in machines) {
    if (machine.id == id) return machine;
  }
  return null;
}
