import 'package:flutter/material.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Shared machine dropdown used by machine-bound settings screens
/// (Codex / Grok / Claude usage, etc.).
///
/// Online machines are selectable; offline rows show a dimmed label
/// and are not choosable.
class MachinePicker extends StatelessWidget {
  const MachinePicker({
    required this.machines,
    required this.selectedMachineId,
    required this.onChanged,
    required this.sectionTitle,
    super.key,
    this.onlyOnlineSelectable = true,
    this.isMachineSelectable,
    this.unavailableReason,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final ValueChanged<String?> onChanged;
  final String sectionTitle;

  /// When true (default), offline machines cannot be selected.
  final bool onlyOnlineSelectable;

  /// Optional feature-specific eligibility in addition to online state.
  final bool Function(Machine machine)? isMachineSelectable;

  /// Explains why an otherwise-online machine is unavailable for this
  /// feature. The text is rendered on the disabled dropdown row.
  final String? Function(Machine machine)? unavailableReason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final machineSortNow = DateTime.now().millisecondsSinceEpoch;
    final machineList = machines.values.toList()
      ..sort((a, b) => compareMachinesByAvailabilityAt(machineSortNow, a, b));

    return SettingsSection(
      title: sectionTitle,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DropdownButtonFormField<String>(
            initialValue: selectedMachineId,
            selectedItemBuilder: (context) => machineList
                .map(
                  (machine) => Text(
                    machine.displayLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
                .toList(),
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
            items: machineList.map((machine) {
              final online = machine.isOnline;
              final featureSelectable =
                  isMachineSelectable?.call(machine) ?? true;
              final selectable =
                  (!onlyOnlineSelectable || online) && featureSelectable;
              final reason = online
                  ? unavailableReason?.call(machine)
                  : l10n.machineOffline;
              return DropdownMenuItem<String>(
                value: machine.id,
                enabled: selectable,
                child: Row(
                  children: [
                    Icon(
                      online ? Icons.circle : Icons.circle_outlined,
                      size: 10,
                      color: online ? AppColors.success : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        machine.displayLabel,
                        overflow: TextOverflow.ellipsis,
                        style: selectable
                            ? null
                            : theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                      ),
                    ),
                    if (reason != null && reason.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          reason,
                          overflow: TextOverflow.ellipsis,
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
            onChanged: (id) {
              if (id == null) {
                onChanged(null);
                return;
              }
              if (onlyOnlineSelectable && !(machines[id]?.isOnline ?? false)) {
                return;
              }
              final machine = machines[id];
              if (machine == null ||
                  !(isMachineSelectable?.call(machine) ?? true)) {
                return;
              }
              onChanged(id);
            },
          ),
        ),
      ],
    );
  }
}

/// "No data / error for this machine" body: a [MachinePicker] pinned to the
/// top with a centered empty state beneath it.
///
/// The picker is deliberately part of the error state too — when the
/// auto-selected machine lacks the provider, retrying re-queries the same
/// broken machine, so the user must be able to switch machines from here.
///
/// Shared by the Claude limits, Codex usage, and Grok usage screens, which
/// each carried two byte-identical copies (empty + error) differing only in
/// icon and copy.
class MachineScopedEmptyBody extends StatelessWidget {
  const MachineScopedEmptyBody({
    required this.machines,
    required this.selectedMachineId,
    required this.onMachineChanged,
    required this.pickerTitle,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onRetry,
    super.key,
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final ValueChanged<String?> onMachineChanged;
  final String pickerTitle;
  final IconData icon;
  final String title;
  final String subtitle;

  /// When set, the empty state gains a Retry button.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Column(
      children: [
        Padding(
          padding: AppScreenPadding.settings,
          child: MachinePicker(
            machines: machines,
            selectedMachineId: selectedMachineId,
            onChanged: onMachineChanged,
            sectionTitle: pickerTitle,
          ),
        ),
        const Spacer(),
        AppEmptyState(
          icon: icon,
          title: title,
          subtitle: subtitle,
          action: retry == null
              ? null
              : FilledButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context).commonRetry),
                ),
        ),
        const Spacer(),
      ],
    );
  }
}
