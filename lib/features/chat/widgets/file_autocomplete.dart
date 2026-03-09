import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'autocomplete_overlay.dart';

/// Floating autocomplete suggestion list rendered above
/// the input.
class FileAutocomplete extends StatelessWidget {
  const FileAutocomplete({
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  final List<AutocompleteSuggestion> suggestions;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: cs.outlineVariant
                  .withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: AppShadow.floating,
          ),
          child: ClipRRect(
            clipBehavior: Clip.hardEdge,
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            child: AutocompleteOverlay(
              suggestions: suggestions,
              selectedIndex: selectedIndex,
              onSelect: onSelect,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}
