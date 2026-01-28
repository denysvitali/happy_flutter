import 'package:flutter/material.dart';
import 'command_model.dart';
import 'command_palette_input.dart';
import 'command_palette_results.dart';
import 'command_palette_controller.dart';

/// Main command palette widget.
///
/// Displays a modal dialog with search input and filtered command results.
class CommandPalette extends StatefulWidget {
  /// Available commands to display.
  final List<Command> commands;

  /// Controller for managing command palette state.
  final CommandPaletteController? controller;

  /// Callback when the palette should close.
  final VoidCallback onClose;

  /// Whether to show the palette (controlled externally).
  final bool isOpen;

  /// Creates a new [CommandPalette] instance.
  const CommandPalette({
    super.key,
    required this.commands,
    this.controller,
    required this.onClose,
    this.isOpen = true,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  late String _searchQuery;
  late int _selectedIndex;

  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _searchQuery = '';
    _selectedIndex = 0;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.spring(
          spring: SpringDescription(
            mass: 1.0,
            stiffness: 250,
            damping: 25,
          ),
        ),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    if (widget.controller != null) {
      widget.controller!._attach(this);
    }

    // Start opening animation
    _animationController.forward();
  }

  @override
  void didUpdateWidget(CommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isOpen != widget.isOpen) {
      if (widget.isOpen) {
        _animationController.forward();
        _inputFocusNode.requestFocus();
      }
    }

    if (widget.controller != null && oldWidget.controller != widget.controller) {
      widget.controller!._attach(this);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredCategories = _filterCommands();

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            // Backdrop
            FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: _handleClose,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
            // Palette content
            Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildPaletteContainer(theme, filteredCategories),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaletteContainer(
    ThemeData theme,
    List<CommandCategory> categories,
  ) {
    final maxHeight = kIsWeb ? MediaQuery.of(context).size.height * 0.6 : 500.0;
    final maxWidth = kIsWeb ? 800.0 : double.infinity;

    return Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      margin: EdgeInsets.only(
        top: kIsWeb ? MediaQuery.of(context).size.height * 0.2 : 100,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CommandPaletteInput(
            value: _searchQuery,
            onChanged: _handleSearchChange,
            onKeyPress: _handleKeyPress,
            focusNode: _inputFocusNode,
          ),
          Flexible(
            child: CommandPaletteResults(
              categories: categories,
              selectedIndex: _selectedIndex,
              onSelectCommand: _handleSelectCommand,
              onSelectionChange: _handleSelectionChange,
            ),
          ),
        ],
      ),
    );
  }

  List<CommandCategory> _filterCommands() {
    if (_searchQuery.trim().isEmpty) {
      return _groupByCategory(widget.commands);
    }

    final query = _searchQuery.toLowerCase();
    final filtered = widget.commands.where((command) {
      final titleMatch = command.title.toLowerCase().contains(query);
      final subtitleMatch =
          command.subtitle?.toLowerCase().contains(query) ?? false;
      return titleMatch || subtitleMatch;
    }).toList();

    if (filtered.isEmpty) {
      return [];
    }

    return _groupByCategory(filtered);
  }

  List<CommandCategory> _groupByCategory(List<Command> commands) {
    final grouped = <String, List<Command>>{};

    for (final command in commands) {
      final category = command.category ?? 'General';
      grouped.putIfAbsent(category, () => []).add(command);
    }

    final categories = grouped.entries.map((entry) {
      return CommandCategory(
        id: entry.key.toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
        title: entry.key,
        commands: entry.value,
      );
    }).toList();

    // Sort categories: predefined first, then alphabetically
    const priorityOrder = ['Sessions', 'Navigation', 'Recent Sessions', 'System'];
    categories.sort((a, b) {
      final aIndex = priorityOrder.indexOf(a.title);
      final bIndex = priorityOrder.indexOf(b.title);
      if (aIndex != -1 && bIndex != -1) return aIndex.compareTo(bIndex);
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      return a.title.compareTo(b.title);
    });

    return categories;
  }

  void _handleSearchChange(String value) {
    setState(() {
      _searchQuery = value;
      _selectedIndex = 0;
    });
  }

  void _handleKeyPress(String key) {
    switch (key) {
      case 'Escape':
        _handleClose();
        break;
      case 'ArrowDown':
        _moveSelection(1);
        break;
      case 'ArrowUp':
        _moveSelection(-1);
        break;
      case 'Enter':
        _selectCurrent();
        break;
    }
  }

  void _moveSelection(int delta) {
    final categories = _filterCommands();
    final allCommands = categories.expand((c) => c.commands).toList();
    if (allCommands.isEmpty) return;

    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, allCommands.length - 1);
    });
  }

  void _selectCurrent() {
    final categories = _filterCommands();
    final allCommands = categories.expand((c) => c.commands).toList();
    if (allCommands.isEmpty) return;

    final command = allCommands[_selectedIndex];
    command.action();
    _handleClose();
  }

  void _handleSelectCommand(Command command) {
    command.action();
    _handleClose();
  }

  void _handleSelectionChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleClose() {
    _animationController.reverse().whenComplete(() {
      widget.onClose();
    });
  }

  // Called by controller
  void _close() {
    _handleClose();
  }
}
