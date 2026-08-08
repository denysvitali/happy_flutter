import 'package:flutter/material.dart';

/// Represents a single command that can be executed from the command palette.
class CommandItem {
  const CommandItem({
    required this.id,
    required this.title,
    required this.action,
    this.subtitle,
    this.icon,
    this.shortcut,
    this.category,
    this.isPinned = false,
    this.searchOnly = false,
  });

  /// Unique identifier for the command
  final String id;

  /// Display title of the command
  final String title;

  /// Optional subtitle/description
  final String? subtitle;

  /// Icon name (from Material Icons)
  final IconData? icon;

  /// Keyboard shortcut display (e.g., 'Ctrl+K')
  final String? shortcut;

  /// Category for grouping commands
  final String? category;

  /// Action to execute when command is selected
  final VoidCallback action;

  /// Whether this command is a pinned session.
  final bool isPinned;

  /// Indexed by fuzzy search but omitted from the empty-query shortlist.
  final bool searchOnly;

  /// Creates a copy with optional field overrides
  CommandItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    IconData? icon,
    String? shortcut,
    String? category,
    VoidCallback? action,
    bool? isPinned,
    bool? searchOnly,
  }) {
    return CommandItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      shortcut: shortcut ?? this.shortcut,
      category: category ?? this.category,
      action: action ?? this.action,
      isPinned: isPinned ?? this.isPinned,
      searchOnly: searchOnly ?? this.searchOnly,
    );
  }
}

/// Represents a category of commands in the command palette.
class CommandCategory {
  const CommandCategory({
    required this.id,
    required this.title,
    required this.commands,
  });

  /// Unique identifier for the category
  final String id;

  /// Display title of the category
  final String title;

  /// List of commands in this category
  final List<CommandItem> commands;
}
