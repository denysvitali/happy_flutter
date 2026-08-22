import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_tokens.dart';
import 'profile_editor_widgets.dart';

/// Mutable row state for a single model entry.
/// Mutable row state for a single model entry.
class ModelRow {
  ModelRow({String model = ''})
      : modelCtrl = TextEditingController(text: model);

  final TextEditingController modelCtrl;

  void dispose() {
    modelCtrl.dispose();
  }
}

/// Section for configuring the models available when this profile is selected.
class ModelsSection extends StatelessWidget {
  const ModelsSection({
    required this.modelRows,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final List<ModelRow> modelRows;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AuroraPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSectionHeader(
            icon: Icons.memory_outlined,
            title: l10n.profilesModelsTitle,
            hint: l10n.profilesModelsHint,
          ),
          const SizedBox(height: AppSpacing.md),
          if (modelRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  l10n.profilesModelsEmpty,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.textSubtle),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...modelRows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: row.modelCtrl,
                        decoration: auroraField(
                          context: context,
                          labelText: l10n.profilesModelLabel,
                          hintText: 'e.g. claude-opus-4-6',
                        ),
                        textCapitalization: TextCapitalization.none,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: AppIconSize.md,
                        color: context.textSubtle,
                      ),
                      tooltip: l10n.profilesModelRemove,
                      onPressed: () => onRemove(i),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: AppIconSize.md),
              label: Text(l10n.profilesModelAdd),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppTouchTarget.comfortable),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Context-window size selector for a profile. Backed by a nullable token
/// count: `null` means "provider default"; [extendedContextWindowTokens]
/// (1M) requests the Claude Code `[1m]` extended window at send time.
class ContextWindowSection extends StatelessWidget {
  const ContextWindowSection({
    required this.contextWindow,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
    required this.onChanged,
    super.key,
  });

  final int? contextWindow;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final ValueChanged<int?> onChanged;

  /// Sentinel for "provider default" in the dropdown, since a null dropdown
  /// value reads as "no selection" and shows the hint instead.
  static const int _defaultSentinel = 0;

  @override
  Widget build(BuildContext context) {
    return AuroraPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSectionHeader(
            icon: Icons.width_normal_outlined,
            title: l10n.profilesContextWindowTitle,
            hint: l10n.profilesContextWindowHint,
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            initialValue: contextWindow ?? _defaultSentinel,
            // Bound the selected item to the available width — without
            // this the intrinsic-size row overflows narrow phones.
            isExpanded: true,
            dropdownColor: Theme.of(context).colorScheme.surfaceContainerLow,
            decoration: auroraField(
              context: context,
              labelText: l10n.profilesContextWindowTitle,
            ),
            items: [
              DropdownMenuItem(
                value: _defaultSentinel,
                child: Text(l10n.profilesContextWindowDefault),
              ),
              DropdownMenuItem(
                value: extendedContextWindowTokens,
                child: Text(l10n.profilesContextWindow1M),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              onChanged(value == _defaultSentinel ? null : value);
            },
          ),
        ],
      ),
    );
  }
}
