import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/env_secrets.dart';
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isSelected
          ? color.withValues(
              alpha: isDark ? AppOpacity.subtle : AppOpacity.faint,
            )
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? color : cs.outlineVariant,
                width: isSelected ? AppBorder.thick : AppBorder.thin,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: AppIconSize.md, color: color),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? color : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Environment-variables section with add/remove/import controls.
///
/// Uses a single stacked row layout at every width: the key field and
/// remove button sit on the first line, the value field spans the full
/// width below. Value masking is secret-aware — see [ValueField].
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
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.profilesEnvVarsTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.profilesEnvVarsHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Tooltip(
              message: l10n.profilesImportLabelShort,
              child: OutlinedButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.paste, size: AppIconSize.md),
                label: Text(l10n.profilesImportLabelShort),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, AppTouchTarget.comfortable),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            Tooltip(
              message: l10n.profilesEnvAddRow,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: AppIconSize.md),
                label: Text(l10n.profilesEnvAddRow),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, AppTouchTarget.comfortable),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (envRows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(
              child: Text(
                l10n.profilesEnvVarsEmpty,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...envRows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Padding(
            key: ObjectKey(row),
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: EnvVarRow(
              row: row,
              l10n: l10n,
              onChanged: onChanged,
              onRemove: () => onRemove(i),
            ),
          );
        }),
      ],
    );
  }
}

/// A single environment-variable entry: key field with a remove
/// button on top, value field spanning the full width below.
class EnvVarRow extends StatelessWidget {
  const EnvVarRow({
    required this.row,
    required this.l10n,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final EnvRow row;
  final AppLocalizations l10n;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rowCardBg = cs.surfaceContainerLow;
    return Container(
      decoration: BoxDecoration(
        color: rowCardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.nameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.profilesEnvKeyLabel,
                    hintText: l10n.profilesEnvKeyHint,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.md,
                  ),
                  maxLines: 1,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Tooltip(
                message: l10n.profilesEnvRemoveRow,
                child: IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline,
                    size: AppIconSize.lg,
                    color: cs.error,
                  ),
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ValueField(row: row),
        ],
      ),
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
                Expanded(
                  child: Text(
                    l10n.profilesScriptTitle,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    l10n.commonOptional,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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
            autocorrect: false,
            enableSuggestions: false,
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

/// Value field that masks only secrets.
///
/// Whether the value is obscured derives from the *key name* via
/// [isSecretEnvName]: credentials (API keys, tokens, passwords) start
/// masked with an eye toggle; plain configuration (URLs, model names,
/// timeouts) stays visible with full text width and no toggle.
///
/// The field listens to the row's key-name controller and re-masks
/// whenever the name changes — a manual reveal never survives a key
/// edit (fail-closed).
class ValueField extends StatefulWidget {
  const ValueField({required this.row, super.key});
  final EnvRow row;

  @override
  State<ValueField> createState() => _ValueFieldState();
}

class _ValueFieldState extends State<ValueField> {
  bool _userRevealed = false;

  @override
  void initState() {
    super.initState();
    widget.row.nameCtrl.addListener(_onNameChanged);
  }

  @override
  void didUpdateWidget(ValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.nameCtrl != widget.row.nameCtrl) {
      oldWidget.row.nameCtrl.removeListener(_onNameChanged);
      widget.row.nameCtrl.addListener(_onNameChanged);
    }
  }

  @override
  void dispose() {
    widget.row.nameCtrl.removeListener(_onNameChanged);
    super.dispose();
  }

  void _onNameChanged() {
    // Fail-closed: renaming the key re-masks the value even if the
    // user had manually revealed it.
    setState(() => _userRevealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final envName = widget.row.nameCtrl.text.trim();
    final isSecret = envName.isNotEmpty && isSecretEnvName(envName);
    final obscure = isSecret && !_userRevealed;
    return TextFormField(
      controller: widget.row.valueCtrl,
      obscureText: obscure,
      minLines: 1,
      maxLines: obscure ? 1 : (isSecret ? 3 : 1),
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: l10n.profilesEnvValueLabel,
        suffixIcon: isSecret
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: AppIconSize.lg,
                ),
                tooltip: obscure
                    ? l10n.profilesEnvShowValue
                    : l10n.profilesEnvHideValue,
                onPressed: () =>
                    setState(() => _userRevealed = !_userRevealed),
              )
            : null,
      ),
      style: const TextStyle(fontFamily: 'monospace', fontSize: AppFontSize.md),
    );
  }
}
