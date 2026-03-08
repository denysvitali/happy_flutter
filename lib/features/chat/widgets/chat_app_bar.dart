import 'package:flutter/material.dart';
import '../../../core/components/app_status_dot.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import 'path_chip.dart';
import 'session_header_chip.dart';

/// App bar for the chat screen showing session title, path, and status.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a chat app bar
  const ChatAppBar({
    required this.session,
    required this.sessionTitle,
    required this.relativePath,
    required this.machine,
    required this.statusText,
    required this.statusColor,
    required this.isThinking,
    required this.onMenuTap,
    super.key,
  });

  /// The current session
  final Session? session;

  /// The title to display for the session
  final String sessionTitle;

  /// The relative path to display
  final String relativePath;

  /// The machine associated with the session
  final Machine? machine;

  /// The status text to display
  final String statusText;

  /// The color of the status indicator
  final Color statusColor;

  /// Whether the session is currently thinking
  final bool isThinking;

  /// Callback when the menu button is tapped
  final VoidCallback onMenuTap;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _buildTitle(context),
      scrolledUnderElevation: 0.5,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded),
          iconSize: 22,
          tooltip: context.l10n.chatMoreOptions,
          onPressed: onMenuTap,
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    if (session == null) {
      return Text(context.l10n.chatChat);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final machineName = machine?.metadata?.displayName ??
        machine?.metadata?.host;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sessionTitle,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (relativePath.isNotEmpty) ...[
              PathChip(path: relativePath),
              const SizedBox(width: 6),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) =>
                  FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
              child: isThinking
                  ? _TypingIndicator(
                      key: const ValueKey('typing'),
                      color: colorScheme.primary,
                    )
                  : SessionHeaderChip(
                      key: const ValueKey('status'),
                      text: statusText,
                      leading: AppStatusDot(
                        color: statusColor,
                        pulse: false,
                        size: 6,
                      ),
                    ),
            ),
            if (machineName != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: SessionHeaderChip(
                  text: machineName,
                  leading: Icon(
                    Icons.computer_outlined,
                    size: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Animated three-dot typing indicator shown when the
/// assistant is actively processing.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({
    required this.color,
    super.key,
  });

  final Color color;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final phase = (_ctrl.value + i * 0.2) % 1.0;
              final y = -2.0 * (phase < 0.5
                  ? phase * 2
                  : 2.0 - phase * 2);
              return Transform.translate(
                offset: Offset(0, y),
                child: child,
              );
            },
            child: Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(
                horizontal: 1.5,
              ),
              decoration: BoxDecoration(
                color: widget.color.withAlpha(180),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
