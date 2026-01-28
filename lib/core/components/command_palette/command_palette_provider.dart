import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import 'command_model.dart';
import 'command_palette_controller.dart';
import 'command_palette.dart';

/// Provider for the command palette controller.
final commandPaletteControllerProvider = ChangeNotifierProvider<
    CommandPaletteController>((ref) {
  return CommandPaletteController();
});

/// Global keyboard shortcut handler for web.
class _GlobalKeyboardHandler extends StatefulWidget {
  final Widget child;
  final CommandPaletteController controller;

  const _GlobalKeyboardHandler({
    required this.child,
    required this.controller,
  });

  @override
  State<_GlobalKeyboardHandler> createState() => _GlobalKeyboardHandlerState();
}

class _GlobalKeyboardHandlerState extends State<_GlobalKeyboardHandler> {
  StreamSubscription<RawKeyEvent>? _keyboardSubscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _setupKeyboardListener();
    }
  }

  @override
  void didUpdateWidget(_GlobalKeyboardHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb) {
      _cleanupListener();
      _setupKeyboardListener();
    }
  }

  @override
  void dispose() {
    _cleanupListener();
    super.dispose();
  }

  void _setupKeyboardListener() {
    _keyboardSubscription =
        RawKeyboard.instance.keyEvents.listen(_handleKeyEvent);
  }

  void _cleanupListener() {
    _keyboardSubscription?.cancel();
    _keyboardSubscription = null;
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (!kIsWeb) return;

    // Only trigger if no text field is focused
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode != null && focusNode.hasFocus) {
      // Allow Escape to close even with focus
      if (event is RawKeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        if (widget.controller.isOpen) {
          widget.controller.close();
        }
      }
      return;
    }

    if (event is RawKeyDownEvent) {
      final isMeta = event.isMetaPressed || event.isControlPressed;
      if (isMeta && event.logicalKey == LogicalKeyboardKey.keyK) {
        event.preventDefault();
        widget.controller.toggle();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (widget.controller.isOpen) {
          widget.controller.close();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Provider widget that wraps the app and enables command palette.
class CommandPaletteProvider extends ConsumerStatefulWidget {
  final Widget child;

  const CommandPaletteProvider({super.key, required this.child});

  @override
  ConsumerState<CommandPaletteProvider> createState() =>
      _CommandPaletteProviderState();
}

class _CommandPaletteProviderState extends ConsumerState<CommandPaletteProvider> {
  late final CommandPaletteController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CommandPaletteController();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(sessionsNotifierProvider);
    final settings = ref.watch(settingsNotifierProvider);
    final theme = Theme.of(context);

    // Build commands based on current state
    final commands = _buildCommands(context, l10n, sessions, settings);

    return _GlobalKeyboardHandler(
      controller: _controller,
      child: Stack(
        children: [
          widget.child,
          if (_controller.isOpen)
            CommandPalette(
              commands: commands,
              controller: _controller,
              onClose: () {
                _controller._onPaletteClose();
              },
              isOpen: _controller.isOpen,
            ),
        ],
      ),
    );
  }

  List<Command> _buildCommands(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic> sessions,
    dynamic settings,
  ) {
    final cmds = <Command>[];
    final goRouter = GoRouter.of(context);

    // Navigation commands
    cmds.add(
      Command(
        id: 'new-session',
        title: l10n.sessionNewSession,
        subtitle: 'Start a new chat session',
        icon: 'add-circle-outline',
        category: 'Sessions',
        shortcut: kIsWeb ? '⌘N' : 'Ctrl+N',
        action: () => goRouter.push('/new'),
      ),
    );

    cmds.add(
      Command(
        id: 'sessions',
        title: 'View All Sessions',
        subtitle: l10n.sessionHistoryTitle,
        icon: 'chatbubbles-outline',
        category: 'Sessions',
        action: () => goRouter.push('/sessions'),
      ),
    );

    cmds.add(
      Command(
        id: 'settings',
        title: l10n.settingsTitle,
        subtitle: 'Configure your preferences',
        icon: 'settings-outline',
        category: 'Navigation',
        shortcut: kIsWeb ? '⌘,' : 'Ctrl+,',
        action: () => goRouter.push('/settings'),
      ),
    );

    cmds.add(
      Command(
        id: 'account',
        title: l10n.settingsAccount,
        subtitle: 'Manage your account',
        icon: 'person-circle-outline',
        category: 'Navigation',
        action: () => goRouter.push('/settings/account'),
      ),
    );

    // Add recent sessions
    final recentSessions = (sessions as Map<String, dynamic>)
        .values
        .where((s) => s is Map<String, dynamic>)
        .map((s) => s as Map<String, dynamic>)
        .toList()
      ..sort((a, b) {
        final aUpdated = a['updatedAt'] as int? ?? 0;
        final bUpdated = b['updatedAt'] as int? ?? 0;
        return bUpdated.compareTo(aUpdated);
      });

    for (int i = 0; i < min(5, recentSessions.length); i++) {
      final session = recentSessions[i];
      final sessionId = session['id'] as String;
      final metadata = session['metadata'] as Map<String, dynamic>?;
      final sessionName = (metadata?['name'] as String?) ?? 'Session ${sessionId.substring(0, 6)}';

      cmds.add(
        Command(
          id: 'session-$sessionId',
          title: sessionName,
          subtitle: 'Open session',
          icon: 'time-outline',
          category: 'Recent Sessions',
          action: () => goRouter.push('/chat/$sessionId'),
        ),
      );
    }

    // System commands
    cmds.add(
      Command(
        id: 'sign-out',
        title: l10n.settingsSignOut,
        subtitle: 'Sign out of your account',
        icon: 'log-out-outline',
        category: 'System',
        action: () async {
          await ref.read(authStateNotifierProvider.notifier).signOut();
          goRouter.push('/');
        },
      ),
    );

    // Developer commands
    if (settings.developerModeEnabled == true) {
      cmds.add(
        Command(
          id: 'developer',
          title: l10n.settingsDeveloper,
          subtitle: 'Access developer tools',
          icon: 'code-slash-outline',
          category: 'Developer',
          shortcut: '⌘D',
          action: () => goRouter.push('/settings/developer'),
        ),
      );
    }

    return cmds;
  }
}
