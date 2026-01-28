import 'package:flutter/material.dart';
import 'command_model.dart';
import 'command_palette_controller.dart';

/// Service for showing the command palette from anywhere in the app.
class CommandPaletteService {
  static CommandPaletteController? _controller;

  /// Initializes the service with a controller.
  static void initialize(CommandPaletteController controller) {
    _controller = controller;
  }

  /// Shows the command palette.
  static void show() {
    _controller?.open();
  }

  /// Hides the command palette.
  static void hide() {
    _controller?.close();
  }

  /// Toggles the command palette open/closed state.
  static void toggle() {
    _controller?.toggle();
  }

  /// Returns whether the palette is currently open.
  static bool get isVisible => _controller?.isOpen ?? false;

  /// Sets the commands to display.
  static void setCommands(List<Command> commands) {
    _controller?.setCommands(commands);
  }
}
