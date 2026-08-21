import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/env_secrets.dart';
import '../profile_setup_catalog.dart';

/// Resolves the app's [AppColorScheme] extension with Material-role
/// fallbacks for themes that do not carry the extension (bare
/// MaterialApp tests, third-party hosts).
extension AuroraCs on BuildContext {
  AppColorScheme? get _aurora => Theme.of(this).extension<AppColorScheme>();

  Color get textPrimary =>
      _aurora?.textPrimary ?? Theme.of(this).colorScheme.onSurface;

  Color get textSecondary =>
      _aurora?.textSecondary ?? Theme.of(this).colorScheme.onSurfaceVariant;

  Color get textMuted =>
      _aurora?.textMuted ?? Theme.of(this).colorScheme.outline;

  Color get textSubtle =>
      _aurora?.textSubtle ?? Theme.of(this).colorScheme.outlineVariant;

  List<Color> get accentGradient => _aurora?.accentGradient ??
      [
        Theme.of(this).colorScheme.primary,
        Theme.of(this).colorScheme.secondary,
      ];

  Color get glassBorder =>
      _aurora?.glassBorder ?? Theme.of(this).colorScheme.outlineVariant;
}

/// Shared glass-panel container: one calm surface per section.
class AuroraPanel extends StatelessWidget {
  const AuroraPanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerLow
            .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: context.glassBorder,
          width: AppBorder.hairline,
        ),
        boxShadow: AppShadow.floating,
      ),
      child: child,
    );
  }
}

/// Section header: muted icon + overline label + subtle hint below.
class AuroraSectionHeader extends StatelessWidget {
  const AuroraSectionHeader({
    required this.icon,
    required this.title,
    required this.hint,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String hint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: AppIconSize.md, color: context.textSubtle),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFontSize.xs + 1,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          hint,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.textSubtle),
        ),
      ],
    );
  }
}

/// Filled, quiet input decoration shared by every field in the editor.
InputDecoration auroraField({
  required BuildContext context,
  required String labelText,
  String? hintText,
  Widget? suffixIcon,
  bool alignLabelWithHint = false,
}) {
  return InputDecoration(
    filled: true,
    fillColor: Theme.of(context)
        .colorScheme
        .surfaceContainerHigh
        .withValues(alpha: 0.5),
    labelText: labelText,
    labelStyle: TextStyle(color: context.textSubtle),
    hintText: hintText,
    hintStyle: TextStyle(color: context.textSubtle),
    alignLabelWithHint: alignLabelWithHint,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.smd,
    ),
    border: _outline(context.glassBorder),
    enabledBorder: _outline(context.glassBorder),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.smd),
      borderSide: BorderSide(
        color: context.accentGradient.first,
        width: AppBorder.thick,
      ),
    ),
    errorBorder: _outline(Theme.of(context).colorScheme.error),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.smd),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.error,
        width: AppBorder.thin,
      ),
    ),
    suffixIcon: suffixIcon,
    isDense: true,
  );
}

OutlineInputBorder _outline(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.smd),
    borderSide: BorderSide(color: color, width: AppBorder.thin),
  );
}

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
    return AuroraPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSectionHeader(
            icon: Icons.auto_awesome_outlined,
            title: l10n.profilesQuickSetup,
            hint: l10n.profilesQuickSetupHint,
          ),
          const SizedBox(height: AppSpacing.lg),
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
      ),
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
      color:
          isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? color : context.glassBorder,
          width: isSelected ? AppBorder.thin : AppBorder.hairline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTarget.min),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_circle : icon,
                  size: AppIconSize.md,
                  color: isSelected ? color : context.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? color : context.textPrimary,
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
    return AuroraPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSectionHeader(
            icon: Icons.data_object_outlined,
            title: l10n.profilesEnvVarsTitle,
            hint: l10n.profilesEnvVarsHint,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              Tooltip(
                message: l10n.profilesImportLabelShort,
                child: TextButton.icon(
                  onPressed: onImport,
                  icon: Icon(
                    Icons.paste,
                    size: AppIconSize.md,
                    color: context.textSecondary,
                  ),
                  label: Text(l10n.profilesImportLabelShort),
                  style: TextButton.styleFrom(
                    foregroundColor: context.textSecondary,
                    minimumSize: const Size(0, AppTouchTarget.comfortable),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              Tooltip(
                message: l10n.profilesEnvAddRow,
                child: FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: AppIconSize.md),
                  label: Text(l10n.profilesEnvAddRow),
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
          const SizedBox(height: AppSpacing.sm),
          if (envRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  l10n.profilesEnvVarsEmpty,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.textSubtle),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
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
      ),
    );
  }
}

/// A single environment-variable entry: monospace key field with a
/// ghost remove button centred across both lines, value field below.
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHigh
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: row.nameCtrl,
                  decoration: auroraField(
                    context: context,
                    labelText: l10n.profilesEnvKeyLabel,
                    hintText: l10n.profilesEnvKeyHint,
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
                const SizedBox(height: AppSpacing.xs),
                ValueField(row: row),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Tooltip(
            message: l10n.profilesEnvRemoveRow,
            child: IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                size: AppIconSize.lg,
                color: context.textSubtle,
              ),
              hoverColor: Theme.of(context)
                  .colorScheme
                  .error
                  .withValues(alpha: 0.12),
              highlightColor: Theme.of(context)
                  .colorScheme
                  .error
                  .withValues(alpha: 0.16),
              onPressed: onRemove,
            ),
          ),
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
    return AuroraPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: onToggle,
            child: AuroraSectionHeader(
              icon: Icons.terminal_outlined,
              title: l10n.profilesScriptTitle,
              hint: show
                  ? l10n.profilesScriptDescription
                  : l10n.commonOptional,
              trailing: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  show ? Icons.expand_less : Icons.expand_more,
                  size: AppIconSize.lg,
                  color: context.textSubtle,
                ),
              ),
            ),
          ),
          if (show) ...[
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: controller,
              decoration: auroraField(
                context: context,
                labelText: l10n.profilesScriptLabel,
                hintText: 'export MY_VAR=value\nsource ~/.env',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              minLines: 4,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSize.md,
              ),
            ),
          ],
        ],
      ),
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
      decoration: auroraField(
        context: context,
        labelText: l10n.profilesEnvValueLabel,
        suffixIcon: isSecret
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  size: AppIconSize.lg,
                  color: context.textSubtle,
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
