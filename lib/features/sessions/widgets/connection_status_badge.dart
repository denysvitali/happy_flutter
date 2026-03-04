import 'package:flutter/material.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Connection status badge in the app bar.
///
/// Shows a pulsing indicator while connecting.
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
    final color = switch (widget.status) {
      ConnectionStatus.connected => AppColors.success,
      ConnectionStatus.connecting => AppColors.warning,
      ConnectionStatus.error => cs.error,
      ConnectionStatus.disconnected => cs.onSurfaceVariant,
    };

    final isConnecting = widget.status == ConnectionStatus.connecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: isConnecting
            ? AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final opacity = 0.35 + 0.65 * _pulseAnimation.value;
                  final scale = 0.75 + 0.5 * _pulseAnimation.value;
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: color.withValues(alpha: opacity),
                    ),
                  );
                },
              )
            : Icon(Icons.circle, size: 12, color: color),
      ),
    );
  }
}
