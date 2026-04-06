import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/components/app_loading_indicator.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/codex_usage_summary.dart';
import '../../core/models/machine.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

class CodexUsageScreen extends ConsumerStatefulWidget {
  const CodexUsageScreen({super.key});

  @override
  ConsumerState<CodexUsageScreen> createState() => _CodexUsageScreenState();
}

class _CodexUsageScreenState extends ConsumerState<CodexUsageScreen> {
  String? _selectedMachineId;
  CodexUsageSummary? _report;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_autoSelectMachine);
  }

  void _autoSelectMachine() {
    final machines = ref.read(machinesNotifierProvider).values.toList();
    final online = machines.where(_isMachineOnline).toList();
    final target = online.isNotEmpty ? online.first : null;
    if (target != null) {
      setState(() => _selectedMachineId = target.id);
      _loadUsage(target.id);
    }
  }

  bool _isMachineOnline(Machine machine) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const onlineThresholdMs = 120 * 1000;
    return now - machine.activeAt < onlineThresholdMs;
  }

  Future<void> _loadUsage(String machineId) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _report = null;
    });

    final response = await Sync().machineGetCodexUsage(machineId: machineId);

    if (!mounted) return;

    if (!response.success || response.data == null) {
      setState(() {
        _error = response.error ?? 'Unknown error';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _report = response.data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final machines = ref.watch(machinesNotifierProvider);

    if (machines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.codexUsageTitle)),
        body: AppEmptyState(
          icon: Icons.code,
          title: l10n.codexUsageNoMachines,
          subtitle: l10n.codexUsageNoMachinesSubtitle,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.codexUsageTitle)),
      body: _isLoading
          ? const AppLoadingIndicator()
          : _error != null
          ? _CodexUsageErrorBody(
              error: _error!,
              onRetry: () {
                if (_selectedMachineId != null) {
                  _loadUsage(_selectedMachineId!);
                }
              },
            )
          : _report != null
          ? _CodexUsageBody(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              report: _report!,
              onMachineChanged: (id) {
                setState(() => _selectedMachineId = id);
                if (id != null) _loadUsage(id);
              },
            )
          : _CodexUsageEmptyBody(
              machines: machines,
              selectedMachineId: _selectedMachineId,
              onMachineChanged: (id) {
                setState(() => _selectedMachineId = id);
                if (id != null) _loadUsage(id);
              },
            ),
    );
  }
}

class _CodexUsageBody extends StatelessWidget {
  const _CodexUsageBody({
    required this.machines,
    required this.selectedMachineId,
    required this.report,
    required this.onMachineChanged,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final CodexUsageSummary report;
  final ValueChanged<String?> onMachineChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: AppScreenPadding.settings,
      children: [
        _CodexMachinePicker(
          machines: machines,
          selectedMachineId: selectedMachineId,
          onChanged: onMachineChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsSection(
          title: l10n.codexUsageTitle,
          children: [
            _CodexUsageStatRow(
              icon: Icons.token,
              title: l10n.totalTokens,
              value: _formatCount(report.totalTokens),
              iconColor: AppColors.info,
            ),
            _CodexUsageStatRow(
              icon: Icons.forum_outlined,
              title: l10n.codexUsageThreads,
              value: _formatCount(report.threadCount),
              iconColor: AppColors.success,
            ),
            _CodexUsageStatRow(
              icon: Icons.update,
              title: l10n.codexUsageLastUpdated,
              value: _formatTimestamp(report.lastSeenAt),
              iconColor: AppColors.warning,
            ),
            if (report.databasePath.isNotEmpty)
              _CodexUsageStatRow(
                icon: Icons.storage_outlined,
                title: l10n.codexUsageDatabase,
                value: report.databasePath,
                iconColor: AppColors.info,
              ),
          ],
        ),
        if (report.byModel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.reports,
            children: [
              for (final model in report.byModel)
                _CodexUsageModelRow(model: model),
            ],
          ),
        ],
      ],
    );
  }

  static String _formatCount(int value) {
    return NumberFormat.decimalPattern().format(value);
  }

  static String _formatTimestamp(int value) {
    if (value <= 0) return '-';
    final date = DateTime.fromMillisecondsSinceEpoch(value);
    return DateFormat('MMM d, yyyy HH:mm').format(date);
  }
}

class _CodexUsageModelRow extends StatelessWidget {
  const _CodexUsageModelRow({required this.model});

  final CodexUsageSummaryByModel model;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        '${_CodexUsageBody._formatCount(model.totalTokens)} tokens • '
        '${_CodexUsageBody._formatCount(model.threadCount)} threads';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      leading: const Icon(Icons.memory_outlined, color: AppColors.info),
      title: Text(model.model),
      subtitle: Text(subtitle),
    );
  }
}

class _CodexUsageEmptyBody extends StatelessWidget {
  const _CodexUsageEmptyBody({
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
          child: _CodexMachinePicker(
            machines: machines,
            selectedMachineId: selectedMachineId,
            onChanged: onMachineChanged,
          ),
        ),
        const Spacer(),
        AppEmptyState(
          icon: Icons.code,
          title: l10n.codexUsageNotAvailable,
          subtitle: l10n.codexUsageNotAvailableSubtitle,
        ),
        const Spacer(),
      ],
    );
  }
}

class _CodexUsageErrorBody extends StatelessWidget {
  const _CodexUsageErrorBody({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      icon: Icons.error_outline,
      title: l10n.codexUsageNotAvailable,
      subtitle: error,
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(l10n.commonRetry),
      ),
    );
  }
}

class _CodexMachinePicker extends StatelessWidget {
  const _CodexMachinePicker({
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
    final cs = Theme.of(context).colorScheme;

    return SettingsSection(
      title: l10n.codexUsageSelectMachine,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DropdownButtonFormField<String>(
            initialValue: selectedMachineId,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              isDense: true,
            ),
            items: machines.values.map((machine) {
              final name =
                  machine.metadata?.displayName ??
                  machine.metadata?.host ??
                  machine.id;
              final now = DateTime.now().millisecondsSinceEpoch;
              const threshold = 120 * 1000;
              final online = now - machine.activeAt < threshold;
              return DropdownMenuItem<String>(
                value: machine.id,
                child: Row(
                  children: [
                    Icon(
                      online ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: online ? AppColors.success : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(name, overflow: TextOverflow.ellipsis),
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

class _CodexUsageStatRow extends StatelessWidget {
  const _CodexUsageStatRow({
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
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: textTheme.bodyMedium)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
