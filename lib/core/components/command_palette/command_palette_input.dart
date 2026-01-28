import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'command_icons.dart';

/// Search input widget for the command palette.
class CommandPaletteInput extends StatefulWidget {
  /// Current search query.
  final String value;

  /// Callback when the search query changes.
  final ValueChanged<String> onChanged;

  /// Callback when a key is pressed.
  final ValueChanged<String> onKeyPress;

  /// Focus node for the input.
  final FocusNode? focusNode;

  /// Creates a new [CommandPaletteInput] instance.
  const CommandPaletteInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onKeyPress,
    this.focusNode,
  });

  @override
  State<CommandPaletteInput> createState() => _CommandPaletteInputState();
}

class _CommandPaletteInputState extends State<CommandPaletteInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommandPaletteInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Type a command or search...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                // Remove outline on web
                ...(kIsWeb
                    ? {
                        'outlineStyle': OutlineStyle.none,
                        'outlineWidth': 0,
                      }
                    : {}),
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.none,
              maxLines: 1,
              onChanged: widget.onChanged,
              onEditingComplete: () {
                // Prevent default behavior
              },
            ),
          ),
          if (widget.value.isNotEmpty) ...[
            GestureDetector(
              onTap: () => widget.onChanged(''),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          _buildKeyboardHint(theme),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildKeyboardHint(ThemeData theme) {
    // Show Ctrl/Cmd+K hint on web
    if (kIsWeb) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kIsWeb ? '⌘K' : 'Ctrl+K',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Hook to handle keyboard events for the command palette.
class _CommandPaletteKeyboardHandler extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onKeyPress;

  const _CommandPaletteKeyboardHandler({
    required this.child,
    required this.onKeyPress,
  });

  @override
  State<_CommandPaletteKeyboardHandler> createState() =>
      _CommandPaletteKeyboardHandlerState();
}

class _CommandPaletteKeyboardHandlerState
    extends State<_CommandPaletteKeyboardHandler> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      RawKeyboard.instance.addListener(_handleKeyEvent);
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      RawKeyboard.instance.removeListener(_handleKeyEvent);
    }
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (!kIsWeb) return;

    // Only handle when no text field is focused
    if (FocusManager.instance.primaryFocus != null &&
        FocusManager.instance.primaryFocus!.hasFocus) {
      return;
    }

    if (event is RawKeyDownEvent) {
      final isMeta = event.isMetaPressed || event.isControlPressed;
      if (isMeta && event.logicalKey == LogicalKeyboardKey.keyK) {
        // Let the parent handle this
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onKeyPress('Escape');
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.onKeyPress('ArrowDown');
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.onKeyPress('ArrowUp');
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        widget.onKeyPress('Enter');
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
