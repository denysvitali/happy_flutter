/// Command model for the command palette.
class Command {
  /// Unique identifier for the command.
  final String id;

  /// Display title of the command.
  final String title;

  /// Optional subtitle/description shown below the title.
  final String? subtitle;

  /// Icon name (uses Material Icons naming convention).
  final String? icon;

  /// Keyboard shortcut hint to display.
  final String? shortcut;

  /// Category for grouping commands.
  final String? category;

  /// Action to execute when the command is selected.
  final VoidCallback action;

  /// Creates a new [Command] instance.
  const Command({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.shortcut,
    this.category,
    required this.action,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Command && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Category for grouping commands in the results.
class CommandCategory {
  /// Unique identifier for the category.
  final String id;

  /// Display title of the category.
  final String title;

  /// Commands in this category.
  final List<Command> commands;

  /// Creates a new [CommandCategory] instance.
  const CommandCategory({
    required this.id,
    required this.title,
    required this.commands,
  });
}
