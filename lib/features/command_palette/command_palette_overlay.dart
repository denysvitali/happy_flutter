import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import 'command_item.dart';

/// Modal overlay that displays the command palette with search and navigation.
class CommandPaletteOverlay extends StatefulWidget {
  const CommandPaletteOverlay({
    super.key,
    required this.commands,
    required this.onClose,
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
      barrierColor: Colors.black54,
      transitionDuration: AppDuration.fast,
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
    final query = _searchQuery.toLowerCase().trim();

    List<CommandItem> filtered;
    if (query.isEmpty) {
      filtered = widget.commands;
    } else {
      filtered = widget.commands.where((command) {
        final titleMatch = command.title.toLowerCase().contains(query);
        final subtitleMatch = command.subtitle != null &&
            command.subtitle!.toLowerCase().contains(query);
        return titleMatch || subtitleMatch;
      }).toList();
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
        .map((entry) => CommandCategory(
              id: entry.key.toLowerCase().replaceAll(' ', '-'),
              title: entry.key,
              commands: entry.value,
            ))
        .toList();

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 640,
              maxHeight: 500,
            ),
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadow.modal,
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
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
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: isDark ? Colors.white54 : Colors.black54,
                        size: AppSpacing.xl - AppSpacing.sm,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search commands...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black,
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
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.black54,
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
                      ? _buildEmptyState(isDark)
                      : _buildResultsList(isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: AppSpacing.xxxl + AppSpacing.xxxl,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No commands found',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      shrinkWrap: true,
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Category commands
            ...category.commands.asMap().entries.map((entry) {
              final commandIndex = entry.key;
              final command = entry.value;

              // Calculate global index
              int globalIndex = 0;
              for (var i = 0; i < categoryIndex; i++) {
                globalIndex += _filteredCategories[i].commands.length;
              }
              globalIndex += commandIndex;

              return _CommandPaletteItem(
                command: command,
                isSelected: globalIndex == _selectedIndex,
                isDark: isDark,
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
    required this.isDark,
    required this.onTap,
    required this.onHover,
  });

  final CommandItem command;
  final bool isSelected;
  final bool isDark;
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
                ? (widget.isDark
                    ? const Color(0xFF0A84FF).withOpacity(0.15)
                    : const Color(0xFFF0F7FF))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF007AFF).withOpacity(0.2)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Icon
              if (widget.command.icon != null)
                Container(
                  width: AppSpacing.xxxl - AppSpacing.xxl + AppSpacing.lg,
                  height: AppSpacing.xxxl - AppSpacing.xxl + AppSpacing.lg,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    widget.command.icon,
                    size: AppSpacing.xl - AppSpacing.sm,
                    color: isSelected
                        ? const Color(0xFF007AFF)
                        : (widget.isDark ? Colors.white54 : Colors.black54),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (widget.command.subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        widget.command.subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isDark ? Colors.white54 : Colors.black54,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Shortcut
              if (widget.command.shortcut != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    widget.command.shortcut!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white54 : Colors.black54,
                      fontFamily: 'monospace',
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
