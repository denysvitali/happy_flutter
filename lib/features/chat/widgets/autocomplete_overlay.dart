import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// Represents a single autocomplete suggestion
class AutocompleteSuggestion {
  AutocompleteSuggestion({
    required this.id,
    required this.label,
    required this.type,
    this.description,
    this.icon,
  });
  final String id;
  final String label;
  final String? description;
  final IconData? icon;
  final SuggestionType type;
}

/// Types of autocomplete suggestions
enum SuggestionType { file, folder, command }

/// Autocomplete overlay widget for @file mentions and /commands
class AutocompleteOverlay extends StatefulWidget {
  const AutocompleteOverlay({
    required this.suggestions,
    required this.onSelect,
    super.key,
    this.selectedIndex = -1,
    this.itemHeight = 48,
    this.maxHeight = 240,
    this.padding,
  });
  final List<AutocompleteSuggestion> suggestions;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double itemHeight;
  final double maxHeight;
  final EdgeInsets? padding;

  @override
  State<AutocompleteOverlay> createState() => _AutocompleteOverlayState();
}

class _AutocompleteOverlayState extends State<AutocompleteOverlay> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(AutocompleteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (widget.selectedIndex < 0) return;

    final scrollOffset = widget.selectedIndex * widget.itemHeight;
    _scrollController.animateTo(
      scrollOffset,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final effectivePadding =
        widget.padding ?? const EdgeInsets.symmetric(horizontal: 8);

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: theme.colorScheme.surface,
        child: ClipRRect(
          clipBehavior: Clip.hardEdge,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Scrollbar(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              shrinkWrap: true,
              padding: effectivePadding,
              itemCount: widget.suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final suggestion = widget.suggestions[index];
                final isSelected = index == widget.selectedIndex;

                return _SuggestionItem(
                  suggestion: suggestion,
                  isSelected: isSelected,
                  onTap: () => widget.onSelect(index),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  const _SuggestionItem({
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
  });
  final AutocompleteSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Icon
              _buildIcon(context),
              const SizedBox(width: AppSpacing.md),
              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      suggestion.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (suggestion.description != null)
                      Text(
                        suggestion.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Type badge
              _buildTypeBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    final theme = Theme.of(context);
    final iconData = suggestion.icon ?? _getDefaultIcon();
    final iconColor = _getIconColor(theme);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(iconData, size: 18, color: iconColor),
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    String badgeText;

    switch (suggestion.type) {
      case SuggestionType.file:
        badgeText = l10n.commonFile;
        break;
      case SuggestionType.folder:
        badgeText = l10n.commonFolder;
        break;
      case SuggestionType.command:
        badgeText = l10n.commonCmd;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xsm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        badgeText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }

  IconData _getDefaultIcon() {
    switch (suggestion.type) {
      case SuggestionType.file:
        return Icons.description_outlined;
      case SuggestionType.folder:
        return Icons.folder_outlined;
      case SuggestionType.command:
        return Icons.code;
    }
  }

  Color _getIconColor(ThemeData theme) {
    switch (suggestion.type) {
      case SuggestionType.file:
        return theme.colorScheme.primary;
      case SuggestionType.folder:
        return theme.colorScheme.tertiary;
      case SuggestionType.command:
        return theme.colorScheme.secondary;
    }
  }
}

/// Autocomplete controller for managing suggestion state.
///
/// Extends [ChangeNotifier] so that widgets can listen to selection changes
/// without requiring a full parent [setState] rebuild.
class AutocompleteController extends ChangeNotifier {
  List<AutocompleteSuggestion> _suggestions = [];
  int _selectedIndex = -1;
  String _currentQuery = '';

  List<AutocompleteSuggestion> get suggestions => _suggestions;
  int get selectedIndex => _selectedIndex;
  bool get hasSuggestions => _suggestions.isNotEmpty;
  String get currentQuery => _currentQuery;

  void setSuggestions(List<AutocompleteSuggestion> suggestions, String query) {
    _suggestions = suggestions;
    _currentQuery = query;
    _selectedIndex = suggestions.isNotEmpty ? 0 : -1;
    notifyListeners();
  }

  void clear() {
    _suggestions = [];
    _selectedIndex = -1;
    _currentQuery = '';
    notifyListeners();
  }

  void moveSelectionUp() {
    if (_suggestions.isEmpty) return;
    _selectedIndex =
        (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
    notifyListeners();
  }

  void moveSelectionDown() {
    if (_suggestions.isEmpty) return;
    _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
    notifyListeners();
  }

  AutocompleteSuggestion? selectCurrent() {
    if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
      return _suggestions[_selectedIndex];
    }
    return null;
  }

  AutocompleteSuggestion? get selectedSuggestion {
    if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
      return _suggestions[_selectedIndex];
    }
    return null;
  }
}
