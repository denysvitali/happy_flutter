import 'package:flutter/material.dart';

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
  });

  final Map<String, Machine> machines;
  final String? selectedMachineId;
  final ValueChanged<String?> onChanged;
  final String sectionTitle;

  /// When true (default), offline machines cannot be selected.
  final bool onlyOnlineSelectable;

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
              return DropdownMenuItem<String>(
                value: machine.id,
                enabled: !onlyOnlineSelectable || online,
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
                        style: online
                            ? null
                            : theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                      ),
                    ),
                    if (!online) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.machineOffline,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
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
              if (onlyOnlineSelectable &&
                  !(machines[id]?.isOnline ?? false)) {
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
