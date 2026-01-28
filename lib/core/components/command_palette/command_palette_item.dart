import 'package:flutter/material.dart';
import 'command_model.dart';
import 'command_icons.dart';

/// Individual command item widget for the command palette.
class CommandPaletteItem extends StatefulWidget {
  /// The command to display.
  final Command command;

  /// Whether this item is currently selected.
  final bool isSelected;

  /// Callback when the item is pressed.
  final VoidCallback onTap;

  /// Callback when the item is hovered (web only).
  final VoidCallback onHover;

  /// Creates a new [CommandPaletteItem] instance.
  const CommandPaletteItem({
    super.key,
    required this.command,
    required this.isSelected,
    required this.onTap,
    required this.onHover,
  });

  @override
  State<CommandPaletteItem> createState() => _CommandPaletteItemState();
}

class _CommandPaletteItemState extends State<CommandPaletteItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeb = kIsWeb;

    Color backgroundColor = Colors.transparent;
    Color borderColor = Colors.transparent;
    Color iconColor = theme.colorScheme.onSurfaceVariant;
    Color titleColor = theme.colorScheme.onSurface;
    Color subtitleColor = theme.colorScheme.onSurfaceVariant;

    if (widget.isSelected) {
      backgroundColor = theme.colorScheme.primaryContainer.withOpacity(0.3);
      borderColor = theme.colorScheme.primary.withOpacity(0.2);
      iconColor = theme.colorScheme.primary;
      titleColor = theme.colorScheme.onSurface;
    } else if (isWeb && _isHovered) {
      backgroundColor = theme.colorScheme.surfaceVariant.withOpacity(0.5);
    }

    return MouseRegion(
      onEnter: isWeb ? (_) => _handleMouseEnter() : null,
      onExit: isWeb ? (_) => _handleMouseExit() : null,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              _buildIcon(iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.command.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.command.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.command.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.command.shortcut != null) ...[
                const SizedBox(width: 12),
                _buildShortcut(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    final iconData = CommandPaletteIcons.getIcon(widget.command.icon);
    if (iconData == null) return const SizedBox(width: 32, height: 32);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: widget.isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        size: 20,
        color: color,
      ),
    );
  }

  Widget _buildShortcut(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        widget.command.shortcut!,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  void _handleMouseEnter() {
    if (mounted) {
      setState(() => _isHovered = true);
    }
    widget.onHover();
  }

  void _handleMouseExit() {
    if (mounted) {
      setState(() => _isHovered = false);
    }
  }
}
