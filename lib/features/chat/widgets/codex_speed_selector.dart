import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'composer_selector_chip.dart';

/// Codex speed is independent of model and reasoning effort.
class CodexSpeedSelector extends StatelessWidget {
  const CodexSpeedSelector({required this.fastMode, this.onChanged, super.key});

  final bool? fastMode;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (fastMode) {
      true => l10n.codexSpeedFast,
      false => l10n.codexSpeedStandard,
      null => l10n.codexSpeedUnknown,
    };
    return Semantics(
      button: true,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => _showPicker(context),
      label: '${l10n.codexSpeedTitle}: $label',
      excludeSemantics: true,
      child: ComposerSelectorChip(
        key: const ValueKey('codex-speed-selector'),
        label: label,
        onTap: onChanged == null ? null : () => _showPicker(context),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.codexSpeedTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.codexSpeedApplyHint),
            ListTile(
              title: Text(l10n.codexSpeedStandard),
              subtitle: Text(l10n.codexSpeedStandardDescription),
              selected: fastMode == false,
              trailing: fastMode == false ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetContext, false),
            ),
            ListTile(
              title: Text(l10n.codexSpeedFast),
              subtitle: Text(l10n.codexSpeedFastDescription),
              selected: fastMode == true,
              trailing: fastMode == true ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              enabled: false,
              title: Text(l10n.codexSpeedUltraFast),
              subtitle: Text(l10n.codexSpeedUltraFastUnavailable),
            ),
          ],
        ),
      ),
    );
    if (context.mounted && selected != null && selected != fastMode) {
      onChanged?.call(selected);
    }
  }
}
