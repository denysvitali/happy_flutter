import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

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
      appBar: AppBar(title: const Text('Connect Terminal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Card(
                color: theme.colorScheme.primaryContainer,
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
              const SizedBox(height: AppSpacing.xxl),

              // Machine selector
              Text(
                'MACHINE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (machineList.isEmpty)
                Card(
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
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMachineId,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 4,
                      ),
                      prefixIcon: Icon(Icons.computer_outlined),
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

              const SizedBox(height: AppSpacing.xxl),

              // Terminal ID input
              Text(
                'TERMINAL / SESSION ID',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Card(
                child: TextFormField(
                  controller: _terminalIdController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    prefixIcon: Icon(Icons.tag),
                    hintText: 'e.g. main, dev, 1234',
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
                label: const Text('Connect'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
