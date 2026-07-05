import 'package:flutter/material.dart';

/// Slash command suggestions
final class SlashCommand {
  /// Creates a slash command entry.
  const SlashCommand({
    required this.command,
    required this.description,
    required this.icon,
  });

  /// The slash command name, e.g. `test`.
  final String command;

  /// Short human-readable description.
  final String description;

  /// Icon to display alongside this command.
  final IconData icon;
}

/// Available slash commands
const List<SlashCommand> slashCommands = [
  SlashCommand(
    command: 'clear',
    description: 'Clear conversation history',
    icon: Icons.delete_sweep_outlined,
  ),
  SlashCommand(
    command: 'test',
    description: 'Run tests',
    icon: Icons.check_circle_outline,
  ),
  SlashCommand(
    command: 'lint',
    description: 'Run linter',
    icon: Icons.warning_amber_outlined,
  ),
  SlashCommand(
    command: 'review',
    description: 'Code review',
    icon: Icons.rate_review_outlined,
  ),
  SlashCommand(
    command: 'goal',
    description: 'Set or update the current goal',
    icon: Icons.flag_outlined,
  ),
  SlashCommand(
    command: 'explain',
    description: 'Explain code',
    icon: Icons.info_outline,
  ),
  SlashCommand(
    command: 'refactor',
    description: 'Refactor code',
    icon: Icons.restart_alt_outlined,
  ),
  SlashCommand(
    command: 'docs',
    description: 'Generate docs',
    icon: Icons.description_outlined,
  ),
  SlashCommand(
    command: 'loop',
    description: 'Schedule a recurring prompt (e.g. /loop 5m check the deploy)',
    icon: Icons.repeat,
  ),
];

/// Merges built-in slash commands with the commands advertised by the
/// running agent in session metadata.
List<SlashCommand> buildSlashCommands(Iterable<String> availableCommands) {
  final merged = <String, SlashCommand>{};
  for (final command in slashCommands) {
    merged[command.command] = command;
  }
  for (final raw in availableCommands) {
    final command = normalizeSlashCommand(raw);
    if (command == null || merged.containsKey(command)) continue;
    merged[command] = SlashCommand(
      command: command,
      description: 'Agent slash command',
      icon: Icons.terminal_outlined,
    );
  }
  return merged.values.toList(growable: false);
}

/// Converts `/goal` and `goal` to the same stored command name.
String? normalizeSlashCommand(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final withoutSlash = trimmed.startsWith('/')
      ? trimmed.substring(1).trim()
      : trimmed;
  return withoutSlash.isEmpty ? null : withoutSlash;
}
