import 'package:flutter/material.dart';
import 'command_model.dart';
import 'command_palette_item.dart';

/// Results list widget with category headers for the command palette.
class CommandPaletteResults extends StatefulWidget {
  /// Categories to display.
  final List<CommandCategory> categories;

  /// Currently selected index in the flattened command list.
  final int selectedIndex;

  /// Callback when a command is selected.
  final ValueChanged<Command> onSelectCommand;

  /// Callback when selection changes (e.g., on hover).
  final ValueChanged<int> onSelectionChange;

  /// Creates a new [CommandPaletteResults] instance.
  const CommandPaletteResults({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelectCommand,
    required this.onSelectionChange,
  });

  @override
  State<CommandPaletteResults> createState() => _CommandPaletteResultsState();
}

class _CommandPaletteResultsState extends State<CommandPaletteResults> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(CommandPaletteResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelectedItem();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCommands = widget.categories.expand((c) => c.commands).toList();

    if (allCommands.isEmpty) {
      return _buildEmptyState(context);
    }

    return Scrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: true,
        itemCount: _buildItemCount(),
        itemBuilder: _buildItem,
      ),
    );
  }

  int _buildItemCount() {
    int count = 0;
    for (final category in widget.categories) {
      if (category.commands.isEmpty) continue;
      count += 1; // Category header
      count += category.commands.length; // Commands in category
    }
    return count;
  }

  Widget _buildItem(BuildContext context, int index) {
    int currentIndex = 0;

    for (final category in widget.categories) {
      if (category.commands.isEmpty) continue;

      // Category header
      if (currentIndex == index) {
        return _buildCategoryHeader(category.title);
      }
      currentIndex++;

      // Commands in this category
      for (int i = 0; i < category.commands.length; i++) {
        if (currentIndex == index) {
          final commandIndex = _getFlattenedCommandIndex(category, i);
          return CommandPaletteItem(
            command: category.commands[i],
            isSelected: commandIndex == widget.selectedIndex,
            onTap: () => widget.onSelectCommand(category.commands[i]),
            onHover: () => widget.onSelectionChange(commandIndex),
          );
        }
        currentIndex++;
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildCategoryHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  int _getFlattenedCommandIndex(CommandCategory category, int commandIndex) {
    int index = 0;
    for (final cat in widget.categories) {
      if (cat == category) {
        return index + commandIndex;
      }
      index += cat.commands.length;
    }
    return commandIndex;
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Text(
          'No commands found',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  void _scrollToSelectedItem() {
    // Calculate the scroll position for the selected item
    final allCommands = widget.categories.expand((c) => c.commands).toList();
    if (allCommands.isEmpty) return;

    final selectedIndex = widget.selectedIndex.clamp(0, allCommands.length - 1);
    if (selectedIndex < 0 || selectedIndex >= allCommands.length) return;

    // Approximate item height (56px padding + 48px content)
    const itemHeight = 60.0;
    final targetScroll = selectedIndex * itemHeight;

    _scrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 100),
      curve: Curves.linear,
    );
  }
}
