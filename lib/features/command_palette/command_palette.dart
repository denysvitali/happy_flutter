import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import 'command_item.dart';
import 'command_palette_overlay.dart';

/// Provider for command palette visibility state
final commandPaletteVisibleProvider = NotifierProvider<CommandPaletteVisibleNotifier, bool>(
  CommandPaletteVisibleNotifier.new,
);

/// Notifier for command palette visibility
class CommandPaletteVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;
  void hide() => state = false;
  void toggle() => state = !state;
}

/// Provider for available commands
final commandPaletteCommandsProvider = Provider<List<CommandItem>>((ref) {
  // This will be rebuilt when sessions change
  return [];
});

/// Command Palette controller that manages the palette and provides commands
class CommandPaletteController {
  CommandPaletteController(this._ref);

  final Ref _ref;

  /// Shows the command palette
  void show() {
    _ref.read(commandPaletteVisibleProvider.notifier).show();
  }

  /// Hides the command palette
  void hide() {
    _ref.read(commandPaletteVisibleProvider.notifier).hide();
  }

  /// Toggles the command palette visibility
  void toggle() {
    _ref.read(commandPaletteVisibleProvider.notifier).toggle();
  }

  /// Builds commands based on current app state
  List<CommandItem> buildCommands(BuildContext context) {
    final sessions = _ref.read(sessionsNotifierProvider);
    final router = GoRouter.of(context);

    final commands = <CommandItem>[
      // Navigation commands
      CommandItem(
        id: 'new-session',
        title: 'New Session',
        subtitle: 'Start a new chat session',
        icon: Icons.add_circle_outline,
        category: 'Sessions',
        shortcut: 'Ctrl+N',
        action: () {
          router.go('/new');
        },
      ),
      CommandItem(
        id: 'sessions',
        title: 'View All Sessions',
        subtitle: 'Browse your chat history',
        icon: Icons.chat_bubble_outline,
        category: 'Sessions',
        action: () {
          router.go('/sessions');
        },
      ),
      CommandItem(
        id: 'settings',
        title: 'Settings',
        subtitle: 'Configure your preferences',
        icon: Icons.settings_outlined,
        category: 'Navigation',
        shortcut: 'Ctrl+,',
        action: () {
          router.go('/settings');
        },
      ),
      CommandItem(
        id: 'account',
        title: 'Account',
        subtitle: 'Manage your account',
        icon: Icons.account_circle_outlined,
        category: 'Navigation',
        action: () {
          router.go('/settings/account');
        },
      ),
      CommandItem(
        id: 'connect-device',
        title: 'Connect Device',
        subtitle: 'Connect a new device via web',
        icon: Icons.link_outlined,
        category: 'Navigation',
        action: () {
          router.go('/terminal/connect');
        },
      ),
      CommandItem(
        id: 'inbox',
        title: 'Inbox',
        subtitle: 'View your notifications',
        icon: Icons.inbox_outlined,
        category: 'Navigation',
        action: () {
          router.go('/inbox');
        },
      ),
      CommandItem(
        id: 'artifacts',
        title: 'Artifacts',
        subtitle: 'Browse your artifacts',
        icon: Icons.folder_outlined,
        category: 'Navigation',
        action: () {
          router.go('/artifacts');
        },
      ),
      CommandItem(
        id: 'zen',
        title: 'Zen Mode',
        subtitle: 'Focus mode with todos',
        icon: Icons.emoji_nature_outlined,
        category: 'Navigation',
        action: () {
          router.go('/zen');
        },
      ),
      CommandItem(
        id: 'terminal',
        title: 'Terminal',
        subtitle: 'Access terminal sessions',
        icon: Icons.terminal,
        category: 'Navigation',
        action: () {
          router.go('/terminal');
        },
      ),
      CommandItem(
        id: 'friends',
        title: 'Friends',
        subtitle: 'Manage your friends',
        icon: Icons.people_outline,
        category: 'Navigation',
        action: () {
          router.go('/friends');
        },
      ),
    ];

    // Add recent sessions (up to 5)
    final recentSessions = sessions.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final recentCount = recentSessions.length > 5 ? 5 : recentSessions.length;

    for (var i = 0; i < recentCount; i++) {
      final session = recentSessions[i];
      final sessionName = session.metadata?.name ??
          'Session ${session.id.substring(0, 6)}';

      commands.add(CommandItem(
        id: 'session-${session.id}',
        title: sessionName,
        subtitle: session.metadata?.path ?? 'Switch to session',
        icon: Icons.access_time,
        category: 'Recent Sessions',
        action: () {
          router.go('/chat/${session.id}');
        },
      ));
    }

    return commands;
  }
}

/// Provider for command palette controller
final commandPaletteControllerProvider = Provider<CommandPaletteController>(
  (ref) => CommandPaletteController(ref),
);

/// Global keyboard shortcut handler for command palette
class CommandPaletteKeyboardHandler extends ConsumerStatefulWidget {
  const CommandPaletteKeyboardHandler({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<CommandPaletteKeyboardHandler> createState() =>
      _CommandPaletteKeyboardHandlerState();
}

class _CommandPaletteKeyboardHandlerState
    extends ConsumerState<CommandPaletteKeyboardHandler> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isCommandPressed = isControlPressed || isMetaPressed;

    // Check for Ctrl+K or Cmd+K to open command palette
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyK) {
      final controller = ref.read(commandPaletteControllerProvider);
      controller.show();
      return KeyEventResult.handled;
    }

    // Check for Ctrl+N or Cmd+N for new session
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyN) {
      GoRouter.of(context).go('/new');
      return KeyEventResult.handled;
    }

    // Check for Ctrl+, or Cmd+, for settings
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.comma) {
      GoRouter.of(context).go('/settings');
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}

/// Command palette overlay widget that listens to visibility state
class CommandPaletteOverlayWrapper extends ConsumerWidget {
  const CommandPaletteOverlayWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(commandPaletteVisibleProvider);

    if (!isVisible) {
      return const SizedBox.shrink();
    }

    // Build commands dynamically
    final controller = ref.read(commandPaletteControllerProvider);
    final commands = controller.buildCommands(context);

    return CommandPaletteOverlay(
      commands: commands,
      onClose: () {
        ref.read(commandPaletteVisibleProvider.notifier).hide();
      },
    );
  }
}
