import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/settings.dart';
import '../../../core/theme/app_tokens.dart';
import 'model_mode.dart';

// ---------------------------------------------------------------------------
// Model picker bottom sheet
// ---------------------------------------------------------------------------

IconData iconForModel(ChatModelMode model) {
  if (model.isCodex) return Icons.psychology_alt_outlined;
  if (model.isCustom) return Icons.tune_outlined;
  if (model.modelSlug == 'opus') return Icons.diamond_outlined;
  if (model.modelSlug == 'sonnet') return Icons.auto_awesome_outlined;
  if (model == ChatModelMode.defaultModel) return Icons.smart_toy_outlined;
  return Icons.smart_toy_outlined;
}

/// Shared circular leading icon so every picker row aligns its label at the
/// same horizontal offset, regardless of row type.
Widget _modelLeading(
  ColorScheme cs, {
  required IconData icon,
  required bool highlighted,
  Color? accent,
}) {
  final color = accent ?? cs.primary;
  return Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: highlighted
          ? color.withValues(alpha: 0.12)
          : cs.onSurface.withValues(alpha: 0.05),
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      size: 16,
      color: highlighted ? color : cs.onSurfaceVariant,
    ),
  );
}

Widget _buildModelTile(
  BuildContext ctx,
  ChatModelMode model,
  ChatModelMode current,
  ThemeData theme,
  ValueChanged<ChatModelMode> onChanged, {
  String? labelOverride,
}) {
  final cs = theme.colorScheme;
  final isSelected = model == current;

  return InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      Navigator.pop(ctx);
      onChanged(model);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _modelLeading(
            cs,
            icon: iconForModel(model),
            highlighted: isSelected,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              labelOverride ?? model.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 18, color: cs.primary),
        ],
      ),
    ),
  );
}

/// Shows a bottom sheet for selecting a [ChatModelMode].
void showModelPickerSheet(
  BuildContext context,
  ChatModelMode current,
  List<ChatModelMode> models,
  ValueChanged<ChatModelMode> onChanged, {
  Settings? settings,
  ValueChanged<List<String>>? onCustomModelsChanged,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final hasGroupedModels = models.any((m) => m.modelSlug != null);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: !hasGroupedModels
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        'Model',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final model in models)
                            _buildModelTile(
                              ctx,
                              model,
                              current,
                              theme,
                              onChanged,
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              : _GroupedModelPickerContent(
                  current: current,
                  models: models,
                  onChanged: onChanged,
                  settings: settings,
                  onCustomModelsChanged: onCustomModelsChanged,
                ),
        ),
      ),
    ),
  );
}

class _GroupedModelPickerContent extends StatefulWidget {
  const _GroupedModelPickerContent({
    required this.current,
    required this.models,
    required this.onChanged,
    this.settings,
    this.onCustomModelsChanged,
  });

  final ChatModelMode current;
  final List<ChatModelMode> models;
  final ValueChanged<ChatModelMode> onChanged;
  final Settings? settings;
  final ValueChanged<List<String>>? onCustomModelsChanged;

  @override
  State<_GroupedModelPickerContent> createState() =>
      _GroupedModelPickerContentState();
}

class _GroupedModelPickerContentState
    extends State<_GroupedModelPickerContent> {
  late String? _selectedSlug = widget.current.modelSlug ?? _firstSlug;
  late final List<String> _customModels = List<String>.from(
    widget.settings?.customModelModes ?? const [],
  );

  String? get _firstSlug {
    for (final model in widget.models) {
      if (model.modelSlug != null) return model.modelSlug;
    }
    return null;
  }

  String _displayNameForSlug(List<ChatModelMode> variants) {
    // Prefer a labelled effort variant so we can strip its effort suffix.
    final withEffort = variants.firstWhere(
      (m) => m.hasEffort,
      orElse: () => variants.first,
    );
    if (withEffort.hasEffort) {
      return withEffort.label.replaceFirst(
        RegExp(' ${withEffort.reasoningEffortLabel}\$'),
        '',
      );
    }
    return withEffort.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final defaultModel = widget.models
        .where((model) => model == ChatModelMode.defaultModel)
        .toList();
    final grouped = <String, List<ChatModelMode>>{};
    for (final model in widget.models.where((m) => m.modelSlug != null)) {
      grouped.putIfAbsent(model.modelSlug!, () => []).add(model);
    }
    final selectedModels = grouped[_selectedSlug] ?? const [];

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              'Model',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (defaultModel.isNotEmpty)
            _buildModelTile(
              context,
              defaultModel.first,
              widget.current,
              theme,
              widget.onChanged,
            ),
          for (final entry in grouped.entries)
            _buildGroupedModelRow(
              context,
              entry.value.first,
              displayName: _displayNameForSlug(entry.value),
              selected: entry.key == _selectedSlug,
            ),
          if (selectedModels.isNotEmpty) ...[
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                'Effort',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final model in selectedModels)
              _buildModelTile(
                context,
                model,
                widget.current,
                theme,
                widget.onChanged,
                labelOverride: model.hasEffort
                    ? model.reasoningEffortLabel
                    : 'Auto',
              ),
          ],
          if (_recentCustomModels.isNotEmpty) ...[
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                'Custom',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final model in _recentCustomModels)
              _buildCustomModelTile(context, model, theme),
          ],
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
          _buildCustomTile(context, cs, theme),
        ],
      ),
    );
  }

  Widget _buildGroupedModelRow(
    BuildContext context,
    ChatModelMode model, {
    required String displayName,
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedSlug = model.modelSlug);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            _modelLeading(
              cs,
              icon: iconForModel(model),
              highlighted: selected,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                displayName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.chevron_right_rounded, size: 18, color: cs.primary),
          ],
        ),
      ),
    );
  }

  List<ChatModelMode> get _recentCustomModels {
    return _customModels
        .map((slug) => ChatModelMode.custom(slug: slug))
        .toList();
  }

  void _removeCustomModel(String slug) {
    setState(() => _customModels.remove(slug));
    widget.onCustomModelsChanged?.call(List<String>.from(_customModels));
  }

  void _addCustomModel(String slug) {
    if (slug.isEmpty || _customModels.contains(slug)) return;
    setState(() => _customModels.insert(0, slug));
    widget.onCustomModelsChanged?.call(List<String>.from(_customModels));
  }

  Widget _buildCustomModelTile(
    BuildContext context,
    ChatModelMode model,
    ThemeData theme,
  ) {
    final cs = theme.colorScheme;
    final isSelected = model == widget.current;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pop(context);
        widget.onChanged(model);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            _modelLeading(
              cs,
              icon: iconForModel(model),
              highlighted: isSelected,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                model.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? cs.primary : cs.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: cs.primary),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: cs.onSurfaceVariant,
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                HapticFeedback.selectionClick();
                _removeCustomModel(model.modelSlug!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTile(
    BuildContext context,
    ColorScheme cs,
    ThemeData theme,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _showCustomModelDialog(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            _modelLeading(
              cs,
              icon: Icons.add_rounded,
              highlighted: false,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Custom…',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomModelDialog(BuildContext context) async {
    final slugController = TextEditingController();
    String? selectedEffort;

    final result = await showDialog<ChatModelMode>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Custom Model'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: slugController,
                decoration: const InputDecoration(
                  hintText: 'claude-opus-4-8',
                  labelText: 'Model slug',
                ),
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: selectedEffort,
                decoration: const InputDecoration(
                  labelText: 'Effort (optional)',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  for (final effort in ChatModelMode.claudeEfforts)
                    DropdownMenuItem(
                      value: effort,
                      child: Text(ChatModelMode.custom(
                        slug: '',
                        effort: effort,
                      ).reasoningEffortLabel),
                    ),
                ],
                onChanged: (v) => setDialogState(() => selectedEffort = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final slug = slugController.text.trim();
                if (slug.isEmpty) return;
                Navigator.pop(
                  ctx,
                  ChatModelMode.custom(slug: slug, effort: selectedEffort),
                );
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (result != null && context.mounted) {
      _addCustomModel(result.modelSlug!);
      Navigator.pop(context);
      widget.onChanged(result);
    }
  }
}

// ---------------------------------------------------------------------------
// Profile picker bottom sheet
// ---------------------------------------------------------------------------

Widget _buildProfileTile(
  BuildContext ctx,
  AIBackendProfile profile,
  AIBackendProfile? current,
  ThemeData theme,
  ValueChanged<AIBackendProfile?> onChanged,
) {
  final cs = theme.colorScheme;
  final isSelected = current?.id == profile.id;

  return InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      Navigator.pop(ctx);
      onChanged(profile);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.tertiary.withValues(alpha: 0.12)
                  : cs.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: isSelected ? cs.tertiary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? cs.tertiary : cs.onSurface,
                  ),
                ),
                if (profile.description != null)
                  Text(
                    profile.description!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 18, color: cs.tertiary),
        ],
      ),
    ),
  );
}

/// Shows a bottom sheet for selecting an
/// [AIBackendProfile].
void showProfilePickerSheet(
  BuildContext context,
  AIBackendProfile? current,
  List<AIBackendProfile> profiles,
  ValueChanged<AIBackendProfile?> onChanged,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) {
      final sheetL10n = AppLocalizations.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  sheetL10n.chatInputProfileTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Default (no profile) option
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                          onChanged(null);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: current == null
                                      ? cs.tertiary.withValues(alpha: 0.12)
                                      : cs.onSurface.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.settings_outlined,
                                  size: 16,
                                  color: current == null
                                      ? cs.tertiary
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sheetL10n.chatInputProfileDefault,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: current == null
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            color: current == null
                                                ? cs.tertiary
                                                : cs.onSurface,
                                          ),
                                    ),
                                    Text(
                                      sheetL10n.chatInputProfileDefaultSubtitle,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (current == null)
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: cs.tertiary,
                                ),
                            ],
                          ),
                        ),
                      ),
                      for (final profile in profiles)
                        _buildProfileTile(
                          ctx,
                          profile,
                          current,
                          theme,
                          onChanged,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
