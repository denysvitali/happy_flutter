import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzy/fuzzy.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import 'command_item.dart';

/// Modal overlay that displays the command palette with search and navigation.
class CommandPaletteOverlay extends StatefulWidget {
  const CommandPaletteOverlay({
    required this.commands,
    required this.onClose,
    super.key,
  });

  /// List of available commands
  final List<CommandItem> commands;

  /// Callback when palette should close
  final VoidCallback onClose;

  /// Shows the command palette as an overlay
  static Future<void> show(
    BuildContext context,
    List<CommandItem> commands,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: AppDuration.normal,
      transitionBuilder: (context, animation, _, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.02),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return CommandPaletteOverlay(
          commands: commands,
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }

  @override
  State<CommandPaletteOverlay> createState() => _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends State<CommandPaletteOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  String _searchQuery = '';
  int _selectedIndex = 0;

  List<CommandCategory> _filteredCategories = [];
  List<CommandItem> _allCommands = [];
  /// Pre-computed start index per category so itemBuilder is O(1).
  List<int> _categoryStartIndex = [];

  @override
  void initState() {
    super.initState();
    _filterCommands();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterCommands() {
    final query = _searchQuery.trim();

    List<CommandItem> filtered;
    if (query.isEmpty) {
      filtered = widget.commands;
    } else {
      // Use fuzzy matching for typo-tolerant search with relevance scoring.
      final fuzzy = Fuzzy<CommandItem>(
        widget.commands,
        options: FuzzyOptions(
          keys: [
            WeightedKey(
              name: 'title',
              getter: (item) => item.title,
              weight: 1.0,
            ),
            WeightedKey(
              name: 'subtitle',
              getter: (item) => item.subtitle ?? '',
              weight: 0.5,
            ),
          ],
          threshold: 0.4,
        ),
      );
      final results = fuzzy.search(query);
      // Fuzzy results are already sorted by score (lower = better match).
      filtered = results.map((r) => r.item).toList();
    }

    // Store all commands for keyboard navigation
    _allCommands = filtered;

    // Group by category
    final grouped = <String, List<CommandItem>>{};
    for (final command in filtered) {
      final category = command.category ?? 'General';
      grouped.putIfAbsent(category, () => []).add(command);
    }

    _filteredCategories = grouped.entries
        .map(
          (entry) => CommandCategory(
            id: entry.key.toLowerCase().replaceAll(' ', '-'),
            title: entry.key,
            commands: entry.value,
          ),
        )
        .toList();

    // Pre-compute category start indices so itemBuilder is O(1).
    var runningIndex = 0;
    _categoryStartIndex = List<int>.generate(
      _filteredCategories.length,
      (i) {
        final start = runningIndex;
        runningIndex += _filteredCategories[i].commands.length;
        return start;
      },
    );

    // Reset selection if out of bounds
    if (_selectedIndex >= _allCommands.length) {
      _selectedIndex = _allCommands.isEmpty ? 0 : _allCommands.length - 1;
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, _allCommands.length - 1);
      });
      _ensureSelectedVisible();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, _allCommands.length - 1);
      });
      _ensureSelectedVisible();
    } else if (key == LogicalKeyboardKey.enter) {
      _executeSelected();
    }
  }

  void _ensureSelectedVisible() {
    if (_allCommands.isEmpty) return;

    // Calculate approximate position of selected item
    const itemHeight = 64.0; // Approximate height per item
    final targetOffset = _selectedIndex * itemHeight;

    if (_scrollController.hasClients) {
      final viewportHeight = _scrollController.position.viewportDimension;
      final currentOffset = _scrollController.offset;

      if (targetOffset < currentOffset) {
        _scrollController.animateTo(
          targetOffset,
          duration: AppDuration.fast,
          curve: AppCurve.enter,
        );
      } else if (targetOffset > currentOffset + viewportHeight - itemHeight) {
        _scrollController.animateTo(
          targetOffset - viewportHeight + itemHeight,
          duration: AppDuration.fast,
          curve: AppCurve.enter,
        );
      }
    }
  }

  void _executeSelected() {
    if (_selectedIndex >= 0 && _selectedIndex < _allCommands.length) {
      final command = _allCommands[_selectedIndex];
      widget.onClose();
      command.action();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 500),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.modal,
              border: Border.all(
                color: colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search input
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: colorScheme.onSurfaceVariant,
                        size: AppSpacing.xl - AppSpacing.sm,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: l10n.commandSearchHint,
                            hintStyle: TextStyle(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(
                            fontSize: AppFontSize.lg,
                            color: colorScheme.onSurface,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                              _filterCommands();
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(
                            alpha: 0.06,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(
                            fontSize: AppFontSize.xs,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Results
                Flexible(
                  child: _filteredCategories.isEmpty
                      ? _buildEmptyState(colorScheme)
                      : _buildResultsList(colorScheme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: AppSpacing.xxxl + AppSpacing.xxxl,
            color: colorScheme.onSurface.withValues(alpha: 0.38),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No commands found',
            style: TextStyle(
              fontSize: AppFontSize.lg,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: AppFontSize.base,
              color: colorScheme.onSurface.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(ColorScheme colorScheme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: _filteredCategories.length,
      itemBuilder: (context, categoryIndex) {
        final category = _filteredCategories[categoryIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                category.title,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Category commands
            ...category.commands.asMap().entries.map((entry) {
              final commandIndex = entry.key;
              final command = entry.value;

              final globalIndex =
                  _categoryStartIndex[categoryIndex] + commandIndex;

              return _CommandPaletteItem(
                command: command,
                isSelected: globalIndex == _selectedIndex,
                colorScheme: colorScheme,
                onTap: () {
                  widget.onClose();
                  command.action();
                },
                onHover: (hovering) {
                  if (hovering) {
                    setState(() {
                      _selectedIndex = globalIndex;
                    });
                  }
                },
              );
            }),
          ],
        );
      },
    );
  }
}

class _CommandPaletteItem extends StatefulWidget {
  const _CommandPaletteItem({
    required this.command,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
    required this.onHover,
  });

  final CommandItem command;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final void Function(bool) onHover;

  @override
  State<_CommandPaletteItem> createState() => _CommandPaletteItemState();
}

class _CommandPaletteItemState extends State<_CommandPaletteItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected || _isHovered;
    final colorScheme = widget.colorScheme;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover(true);
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        widget.onHover(false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              width: AppBorder.thick,
            ),
          ),
          child: Row(
            children: [
              // Icon
              if (widget.command.icon != null)
                Container(
                  width:
                      AppSpacing.xxxl - AppSpacing.xxl + AppSpacing.lg,
                  height:
                      AppSpacing.xxxl - AppSpacing.xxl + AppSpacing.lg,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    widget.command.icon,
                    size: AppSpacing.xl - AppSpacing.sm,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.command.title,
                      style: TextStyle(
                        fontSize: AppFontSize.base,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (widget.command.subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.command.subtitle!,
                        style: TextStyle(
                          fontSize: AppFontSize.md,
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Pin indicator
              if (widget.command.isPinned)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Icon(
                    Icons.push_pin,
                    size: AppSpacing.lg,
                    color: colorScheme.primary,
                  ),
                ),

              // Shortcut
              if (widget.command.shortcut != null)
                Tooltip(
                  message:
                      'Press ${widget.command.shortcut} to run this command',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      widget.command.shortcut!,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
