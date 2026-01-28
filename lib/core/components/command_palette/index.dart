/// Command Palette components for Flutter.
///
/// A keyboard-driven command palette modal for quick navigation and actions.
///
/// ## Usage
///
/// 1. Wrap your app with [CommandPaletteProvider]:
///
/// ```dart
/// MaterialApp(
///   home: CommandPaletteProvider(
///     child: MyApp(),
///   ),
/// );
/// ```
///
/// 2. Access the controller via Riverpod:
///
/// ```dart
/// final controller = ref.watch(commandPaletteControllerProvider);
/// controller.open(); // Show the palette
/// ```
///
/// 3. Use keyboard shortcuts on web:
///    - `Ctrl/Cmd+K`: Toggle palette
///    - `Arrow Up/Down`: Navigate results
///    - `Enter`: Select command
///    - `Escape`: Close palette

export 'command_model.dart';
export 'command_icons.dart';
export 'command_palette.dart';
export 'command_palette_controller.dart';
export 'command_palette_item.dart';
export 'command_palette_results.dart';
export 'command_palette_input.dart';
export 'command_palette_provider.dart';
export 'command_palette_service.dart';
