import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that tracks whether the sidebar is collapsed.
///
/// Consumed by [AppSidebar] (via [ResponsiveNavLayout]) and by
/// [CommandPaletteKeyboardHandler] for the Ctrl/Cmd+B shortcut.
final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );

/// Notifier for sidebar collapsed state.
class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Collapses the sidebar.
  void collapse() => state = true;

  /// Expands the sidebar.
  void expand() => state = false;

  /// Toggles the sidebar between collapsed and expanded.
  void toggle() => state = !state;
}
