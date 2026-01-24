import 'package:flutter/material.dart';

/// Represents a single autocomplete suggestion
class AutocompleteSuggestion {
  final String id;
  final String label;
  final String? description;
  final IconData? icon;
  final SuggestionType type;

  AutocompleteSuggestion({
    required this.id,
    required this.label,
    this.description,
    this.icon,
    required this.type,
  });
}

/// Types of autocomplete suggestions
enum SuggestionType { file, folder, command }

/// Autocomplete overlay widget for @file mentions and /commands
class AutocompleteOverlay extends StatefulWidget {
  final List<AutocompleteSuggestion> suggestions;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double itemHeight;
  final double maxHeight;
  final EdgeInsets? padding;

  const AutocompleteOverlay({
    super.key,
    required this.suggestions,
    this.selectedIndex = -1,
    required this.onSelect,
    this.itemHeight = 48,
    this.maxHeight = 240,
    this.padding,
  });

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
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Scrollbar(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              shrinkWrap: true,
              padding: effectivePadding,
              itemCount: widget.suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: theme.dividerColor.withOpacity(0.5),
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
  final AutocompleteSuggestion suggestion;
  final bool isSelected;
  final VoidCallback onTap;

  const _SuggestionItem({
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Icon
              _buildIcon(context),
              const SizedBox(width: 12),
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
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, size: 18, color: iconColor),
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    final theme = Theme.of(context);
    String badgeText;

    switch (suggestion.type) {
      case SuggestionType.file:
        badgeText = 'File';
        break;
      case SuggestionType.folder:
        badgeText = 'Folder';
        break;
      case SuggestionType.command:
        badgeText = 'Cmd';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
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

/// Autocomplete controller for managing suggestion state
class AutocompleteController {
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
  }

  void clear() {
    _suggestions = [];
    _selectedIndex = -1;
    _currentQuery = '';
  }

  void moveSelectionUp() {
    if (_suggestions.isEmpty) return;
    _selectedIndex =
        (_selectedIndex - 1 + _suggestions.length) % _suggestions.length;
  }

  void moveSelectionDown() {
    if (_suggestions.isEmpty) return;
    _selectedIndex = (_selectedIndex + 1) % _suggestions.length;
  }

  void selectCurrent() {
    if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
      _suggestions[_selectedIndex];
    }
  }

  AutocompleteSuggestion? get selectedSuggestion {
    if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
      return _suggestions[_selectedIndex];
    }
    return null;
  }
}
