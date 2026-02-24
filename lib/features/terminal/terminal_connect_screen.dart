import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart'
    show AppSpacing, AppRadius, AppTouchTarget;

/// Terminal connect screen — select a machine and enter a terminal ID
/// to establish a terminal connection.
class TerminalConnectScreen extends ConsumerStatefulWidget {
  const TerminalConnectScreen({super.key});

  @override
  ConsumerState<TerminalConnectScreen> createState() =>
      _TerminalConnectScreenState();
}

class _TerminalConnectScreenState
    extends ConsumerState<TerminalConnectScreen> {
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
    final machines = ref.watch(machinesNotifierProvider);
    final machineList = machines.values.toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.terminalConnect)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                color: theme.colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Connect to a terminal session running on one'
                          ' of your machines.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Machine selector
              Text(
                context.l10n.sessionSelectMachine.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (machineList.isEmpty)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'No machines connected. Start the Happy CLI on a'
                      ' machine first.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMachineId,
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
                    hint: const Text('Select machine'),
                    isExpanded: true,
                    items: machineList.map((machine) {
                      final meta = machine.metadata;
                      final label =
                          meta?.displayName ?? meta?.host ?? machine.id;
                      return DropdownMenuItem<String>(
                        value: machine.id,
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMachineId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a machine';
                      }
                      return null;
                    },
                  ),
                ),

              const SizedBox(height: AppSpacing.xxxl),

              // Terminal ID input
              Text(
                'TERMINAL / SESSION ID',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
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
                    hintText: 'e.g. main, dev, 1234',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleConnect(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a terminal or session ID';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Connect button
              FilledButton.icon(
                onPressed: machineList.isEmpty ? null : _handleConnect,
                icon: const Icon(Icons.link),
                label: Text(context.l10n.commonContinue),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
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
