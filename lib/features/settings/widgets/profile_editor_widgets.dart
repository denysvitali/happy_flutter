import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../profile_setup_catalog.dart';

/// Quick-setup template chips for choosing a pre-configured
/// AI backend profile.
class TemplateSelector extends StatelessWidget {
  const TemplateSelector({
    required this.selectedTemplate,
    required this.onSelect,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
    super.key,
  });

  final String? selectedTemplate;
  final void Function(String) onSelect;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profilesQuickSetup,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.profilesQuickSetupHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: profileSetupOptions
              .map(
                (option) => TemplateChip(
                  label: option.label,
                  icon: option.icon,
                  color: colorForProfile(option.id),
                  isSelected: selectedTemplate == option.id,
                  onTap: () => onSelect(option.id),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

/// Single selectable chip inside [TemplateSelector].
class TemplateChip extends StatelessWidget {
  const TemplateChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withAlpha(40) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Environment-variables section with add/remove/import controls.
class EnvVarsSection extends StatelessWidget {
  const EnvVarsSection({
    required this.envRows,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
    required this.onImport,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final List<EnvRow> envRows;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final VoidCallback onImport;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                TextButton.icon(
                  onPressed: onImport,
                  icon: const Icon(Icons.paste, size: 18),
                  label: Text(l10n.profilesImportLabelShort),
                ),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.commonCreate),
                ),
              ],
            );
            final title = Text(
              l10n.profilesEnvVarsTitle,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            );

            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: AppSpacing.xs),
                  actions,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.sm),
                actions,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.profilesEnvVarsHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (envRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              l10n.profilesEnvVarsEmpty,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ...envRows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useStackedLayout = constraints.maxWidth < 420;
                final keyField = TextFormField(
                  controller: row.nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.profilesEnvKeyLabel,
                    hintText: l10n.profilesEnvKeyHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.smd,
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.md,
                  ),
                  maxLines: 2,
                  minLines: 1,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => onChanged(),
                );
                final removeButton = IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    color: colorScheme.error,
                  ),
                  onPressed: () => onRemove(i),
                );

                if (useStackedLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: keyField),
                          const SizedBox(width: AppSpacing.xs),
                          removeButton,
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ValueField(row: row),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: keyField),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(flex: 3, child: ValueField(row: row)),
                    removeButton,
                  ],
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

/// Collapsible startup-script section with toggle header.
class ScriptSection extends StatelessWidget {
  const ScriptSection({
    required this.show,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
    required this.controller,
    required this.onToggle,
    super.key,
  });

  final bool show;
  final AppLocalizations l10n;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final TextEditingController controller;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(
                  show ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.profilesScriptTitle,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.commonOptional,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (show) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.profilesScriptDescription,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.profilesScriptLabel,
              hintText: 'export MY_VAR=value\nsource ~/.env',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// Mutable row state for a single env variable entry.
class EnvRow {
  EnvRow({String name = '', String value = ''})
    : nameCtrl = TextEditingController(text: name),
      valueCtrl = TextEditingController(text: value);

  final TextEditingController nameCtrl;
  final TextEditingController valueCtrl;

  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
  }
}

/// Value field with toggle to show/hide the value (sensitive data).
class ValueField extends StatefulWidget {
  const ValueField({required this.row, super.key});
  final EnvRow row;

  @override
  State<ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<ValueField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.row.valueCtrl,
      obscureText: _obscure,
      maxLines: _obscure ? 1 : 3,
      minLines: _obscure ? 1 : 2,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).profilesEnvValueLabel,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            size: 18,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      style: const TextStyle(fontFamily: 'monospace', fontSize: AppFontSize.md),
    );
  }
}
