import 'package:flutter/material.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Connection status badge in the app bar.
///
/// Shows a pulsing indicator while connecting. Each state uses a
/// distinct glyph as well as a distinct colour — colour alone is not
/// perceivable for colourblind users — and carries a localized
/// [Semantics] label for screen readers.
class ConnectionStatusBadge extends StatefulWidget {
  const ConnectionStatusBadge({required this.status, super.key});

  /// The current connection status.
  final ConnectionStatus status;

  @override
  State<ConnectionStatusBadge> createState() => _ConnectionStatusBadgeState();
}

class _ConnectionStatusBadgeState extends State<ConnectionStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(ConnectionStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _updateAnimation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _pulseController
        ..stop()
        ..value = 1;
    } else {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (widget.status == ConnectionStatus.connecting) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final color = switch (widget.status) {
      ConnectionStatus.connected => AppColors.success,
      ConnectionStatus.connecting => AppColors.warning,
      ConnectionStatus.error => cs.error,
      ConnectionStatus.disconnected => cs.onSurfaceVariant,
    };
    // Shape carries the state too: filled = connected, ring =
    // connecting, hollow = disconnected, warning glyph = error.
    final icon = switch (widget.status) {
      ConnectionStatus.connected => Icons.circle,
      ConnectionStatus.connecting => Icons.radio_button_checked,
      ConnectionStatus.error => Icons.error_outline,
      ConnectionStatus.disconnected => Icons.circle_outlined,
    };
    final label = switch (widget.status) {
      // `statusConnected` declares a placeholder it never uses, so the
      // equivalent placeholder-free string is used here.
      ConnectionStatus.connected => l10n.statusOnline,
      ConnectionStatus.connecting => l10n.statusConnecting,
      ConnectionStatus.error => l10n.statusError,
      ConnectionStatus.disconnected => l10n.statusDisconnected,
    };

    final isConnecting = widget.status == ConnectionStatus.connecting;
    final animate = isConnecting && !AppMotion.reduceMotion(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: Semantics(
          label: label,
          child: animate
              ? AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final opacity = 0.35 + 0.65 * _pulseAnimation.value;
                    final scale = 0.75 + 0.5 * _pulseAnimation.value;
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        icon,
                        size: AppIconSize.xs,
                        color: color.withValues(alpha: opacity),
                      ),
                    );
                  },
                )
              : Icon(icon, size: AppIconSize.xs, color: color),
        ),
      ),
    );
  }
}
