import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../sessions/widgets/new_session_dialog.dart';
import 'command_item.dart';
import 'command_palette_overlay.dart';

/// Provider for command palette visibility state
final commandPaletteVisibleProvider =
    NotifierProvider<CommandPaletteVisibleNotifier, bool>(
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
    final l10n = AppLocalizations.of(context);

    final commands = <CommandItem>[];

    // Pinned sessions appear at the very top
    final pinnedSessions = sessions.values.where((s) => s.pinned).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    for (final session in pinnedSessions) {
      final sessionName =
          session.metadata?.name ?? 'Session ${session.id.substring(0, 6)}';
      commands.add(
        CommandItem(
          id: 'session-${session.id}',
          title: sessionName,
          subtitle: session.metadata?.path ?? 'Switch to session',
          icon: Icons.push_pin,
          category: l10n.commandCategoryRecentSessions,
          isPinned: true,
          action: () {
            router.go('/chat/${session.id}');
          },
        ),
      );
    }

    // Navigation commands
    commands.addAll([
      CommandItem(
        id: 'new-session',
        title: l10n.commandNewSessionTitle,
        subtitle: l10n.commandNewSessionSubtitle,
        icon: Icons.add_circle_outline,
        category: l10n.commandCategorySessions,
        shortcut: 'Ctrl+N',
        action: () {
          _showNewSessionDialog(context);
        },
      ),
      CommandItem(
        id: 'sessions',
        title: l10n.commandViewSessionsTitle,
        subtitle: l10n.commandViewSessionsSubtitle,
        icon: Icons.chat_bubble_outline,
        category: l10n.commandCategorySessions,
        action: () {
          router.go('/sessions');
        },
      ),
      CommandItem(
        id: 'settings',
        title: l10n.commandSettingsTitle,
        subtitle: l10n.commandSettingsSubtitle,
        icon: Icons.settings_outlined,
        category: l10n.commandCategoryNavigation,
        shortcut: 'Ctrl+,',
        action: () {
          router.go('/settings');
        },
      ),
      CommandItem(
        id: 'account',
        title: l10n.commandAccountTitle,
        subtitle: l10n.commandAccountSubtitle,
        icon: Icons.account_circle_outlined,
        category: l10n.commandCategoryNavigation,
        action: () {
          router.go('/settings/account');
        },
      ),
      CommandItem(
        id: 'connect-device',
        title: l10n.commandConnectDeviceTitle,
        subtitle: l10n.commandConnectDeviceSubtitle,
        icon: Icons.link_outlined,
        category: l10n.commandCategoryNavigation,
        action: () {
          router.go('/terminal/connect');
        },
      ),
      CommandItem(
        id: 'artifacts',
        title: l10n.commandArtifactsTitle,
        subtitle: l10n.commandArtifactsSubtitle,
        icon: Icons.folder_outlined,
        category: l10n.commandCategoryNavigation,
        action: () {
          router.go('/artifacts');
        },
      ),
      CommandItem(
        id: 'terminal',
        title: l10n.commandTerminalTitle,
        subtitle: l10n.commandTerminalSubtitle,
        icon: Icons.terminal,
        category: l10n.commandCategoryNavigation,
        action: () {
          router.go('/terminal');
        },
      ),
    ]);

    // Add recent sessions (up to 5, excluding already-pinned)
    final pinnedIds = pinnedSessions.map((s) => s.id).toSet();
    final recentSessions = sessions.values
        .where((s) => !pinnedIds.contains(s.id))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final recentCount = recentSessions.length > 5 ? 5 : recentSessions.length;

    for (var i = 0; i < recentCount; i++) {
      final session = recentSessions[i];
      final sessionName =
          session.metadata?.name ?? 'Session ${session.id.substring(0, 6)}';

      commands.add(
        CommandItem(
          id: 'session-${session.id}',
          title: sessionName,
          subtitle: session.metadata?.path ?? 'Switch to session',
          icon: Icons.access_time,
          category: l10n.commandCategoryRecentSessions,
          isPinned: session.pinned,
          action: () {
            router.go('/chat/${session.id}');
          },
        ),
      );
    }

    return commands;
  }
}

/// Provider for command palette controller
final commandPaletteControllerProvider = Provider<CommandPaletteController>(
  (ref) => CommandPaletteController(ref),
);

Future<void> _showNewSessionDialog(BuildContext context) async {
  final sessionId = await showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const NewSessionDialog(),
  );
  if (sessionId != null && context.mounted) {
    GoRouter.of(context).goNamed(
      'chat',
      pathParameters: {'sessionId': sessionId},
    );
  }
}

/// Global keyboard shortcut handler for command palette
class CommandPaletteKeyboardHandler extends ConsumerStatefulWidget {
  const CommandPaletteKeyboardHandler({required this.child, super.key});

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
      ref.read(commandPaletteControllerProvider).show();
      return KeyEventResult.handled;
    }

    // Check for Ctrl+N or Cmd+N for new session
    if (isCommandPressed && event.logicalKey == LogicalKeyboardKey.keyN) {
      _showNewSessionDialog(context);
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
