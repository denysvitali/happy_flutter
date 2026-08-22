import 'package:flutter/material.dart';

import '../../../core/theme/app_color_scheme.dart';
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Bare-MaterialApp test hosts have no AppColorScheme extension; fall
    // back so the glass shell still renders.
    final appScheme =
        theme.extension<AppColorScheme>() ?? AppColorScheme.dark();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          // Aurora-glass popover: near-opaque translucent fill, hairline
          // glass border and a floating shadow.
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: 0.97),
            borderRadius:
                BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: appScheme.glassBorder,
              width: AppBorder.hairline,
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
