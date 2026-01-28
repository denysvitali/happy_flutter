import 'package:flutter/material.dart';
import 'command_model.dart';

/// Controller for managing command palette state and actions.
class CommandPaletteController extends ChangeNotifier {
  bool _isOpen = false;
  List<Command> _commands = const [];
  VoidCallback? _onClose;

  _CommandPaletteState? _state;

  /// Whether the command palette is currently open.
  bool get isOpen => _isOpen;

  /// Available commands.
  List<Command> get commands => _commands;

  /// Opens the command palette.
  void open() {
    if (!_isOpen) {
      _isOpen = true;
      notifyListeners();
    }
  }

  /// Closes the command palette.
  void close() {
    if (_isOpen) {
      _isOpen = false;
      _state?._close();
      notifyListeners();
    }
  }

  /// Toggles the command palette open/closed state.
  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  /// Sets the commands to display in the palette.
  void setCommands(List<Command> commands) {
    _commands = commands;
    notifyListeners();
  }

  /// Sets the callback when the palette closes.
  void setOnClose(VoidCallback onClose) {
    _onClose = onClose;
  }

  /// Called internally to attach state.
  void _attach(_CommandPaletteState state) {
    _state = state;
  }

  /// Called internally when palette is closed.
  void _onPaletteClose() {
    _isOpen = false;
    _onClose?.call();
    notifyListeners();
  }
}
