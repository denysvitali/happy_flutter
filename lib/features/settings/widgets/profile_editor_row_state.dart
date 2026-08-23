import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_tokens.dart';
import 'profile_editor_widgets.dart';

/// Mutable row state for a single model entry.
class ModelRow {
  ModelRow({String model = ''})
    : modelCtrl = TextEditingController(text: model);

  final TextEditingController modelCtrl;

  void dispose() {
    modelCtrl.dispose();
  }
}

/// Mutable row state for a custom Codex provider definition.
class CodexProviderRow {
  CodexProviderRow({
    String id = '',
    String name = '',
    String baseUrl = '',
    String envKey = 'OPENAI_API_KEY',
    String protocol = 'responses',
  }) : idCtrl = TextEditingController(text: id),
       nameCtrl = TextEditingController(text: name),
       baseUrlCtrl = TextEditingController(text: baseUrl),
       envKeyCtrl = TextEditingController(text: envKey),
       wireApi = protocol == 'chat' ? 'chat' : 'responses';

  final TextEditingController idCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController baseUrlCtrl;
  final TextEditingController envKeyCtrl;
  String wireApi;

  void dispose() {
    idCtrl.dispose();
    nameCtrl.dispose();
    baseUrlCtrl.dispose();
    envKeyCtrl.dispose();
  }
}

/// Section for configuring Codex `model_providers.<id>` definitions.
class CodexProvidersSection extends StatelessWidget {
  const CodexProvidersSection({
    required this.providerRows,
    required this.defaultProviderController,
    required this.l10n,
    required this.textTheme,
    required this.colorScheme,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    super.key,
  });

  final List<CodexProviderRow> providerRows;
  final TextEditingController defaultProviderController;
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
            icon: Icons.hub_outlined,
            title: l10n.profilesCodexProvidersTitle,
            hint: l10n.profilesCodexProvidersHint,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: defaultProviderController,
            decoration: auroraField(
              context: context,
              labelText: l10n.profilesCodexDefaultProviderLabel,
              hintText: l10n.profilesCodexDefaultProviderHint,
            ),
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.md),
          if (providerRows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  l10n.profilesCodexProvidersEmpty,
                  style: textTheme.bodySmall?.copyWith(
                    color: context.textSubtle,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...providerRows.asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              return Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _CodexProviderRow(
                  row: row,
                  l10n: l10n,
                  onChanged: onChanged,
                  onRemove: () => onRemove(i),
                ),
              );
            }),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: AppIconSize.md),
            label: Text(l10n.profilesCodexProviderAdd),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppTouchTarget.comfortable),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexProviderRow extends StatelessWidget {
  const _CodexProviderRow({
    required this.row,
    required this.l10n,
    required this.onChanged,
    required this.onRemove,
  });

  final CodexProviderRow row;
  final AppLocalizations l10n;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final fieldStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: AppFontSize.md,
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.idCtrl,
                  decoration: auroraField(
                    context: context,
                    labelText: l10n.profilesCodexProviderIdLabel,
                    hintText: l10n.profilesCodexProviderIdHint,
                  ),
                  style: fieldStyle,
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: (value) {
                    final id = value?.trim() ?? '';
                    if (id.isEmpty) return l10n.profilesNameRequired;
                    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
                      return l10n.profilesCodexProviderIdInvalid;
                    }
                    return null;
                  },
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  size: AppIconSize.lg,
                  color: context.textSubtle,
                ),
                tooltip: l10n.profilesCodexProviderRemove,
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: row.nameCtrl,
            decoration: auroraField(
              context: context,
              labelText: l10n.profilesCodexProviderNameLabel,
              hintText: l10n.profilesCodexProviderNameHint,
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: row.baseUrlCtrl,
            decoration: auroraField(
              context: context,
              labelText: l10n.profilesCodexProviderBaseUrlLabel,
              hintText: l10n.profilesCodexProviderBaseUrlHint,
            ),
            style: fieldStyle,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.url,
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.profilesNameRequired
                : null,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextFormField(
            controller: row.envKeyCtrl,
            decoration: auroraField(
              context: context,
              labelText: l10n.profilesCodexProviderEnvKeyLabel,
              hintText: l10n.profilesCodexProviderEnvKeyHint,
            ),
            style: fieldStyle,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              final key = value?.trim() ?? '';
              if (key.isEmpty) return l10n.profilesNameRequired;
              return RegExp(r'^[A-Z_][A-Z0-9_]*$').hasMatch(key)
                  ? null
                  : l10n.profilesCodexProviderEnvKeyInvalid;
            },
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.xs),
          DropdownButtonFormField<String>(
            initialValue: row.wireApi,
            decoration: auroraField(
              context: context,
              labelText: l10n.profilesCodexProviderWireApiLabel,
            ),
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: 'responses',
                child: Text(l10n.profilesCodexProviderResponses),
              ),
              DropdownMenuItem(
                value: 'chat',
                child: Text(l10n.profilesCodexProviderChat),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              row.wireApi = value;
              onChanged();
            },
          ),
        ],
      ),
    );
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.textSubtle),
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
