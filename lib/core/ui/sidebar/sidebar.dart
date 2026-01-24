import 'package:flutter/material.dart';

/// Connection status for sidebar
enum ConnectionStatus {
  connected,
  connecting,
  disconnected,
  error,
  unknown,
}

/// Sidebar variant for different layouts
enum SidebarVariant {
  sidebar, // Full sidebar with title
  compact, // Compact version
}

/// Collapsible sidebar with connection status indicator
class Sidebar extends StatefulWidget {
  final Widget child;
  final ConnectionStatus connectionStatus;
  final String statusText;
  final Color? statusColor;
  final bool isPulsing;
  final bool isCollapsed;
  final double width;
  final SidebarVariant variant;
  final VoidCallback? onNewSession;
  final VoidCallback? onSettings;
  final VoidCallback? onInbox;
  final int? inboxBadgeCount;
  final bool showInboxBadge;
  final bool showZenButton;
  final Widget? headerLeading;
  final List<Widget>? headerActions;
  final Widget? floatingActionButton;

  const Sidebar({
    required this.child,
    this.connectionStatus = ConnectionStatus.unknown,
    this.statusText = '',
    this.statusColor,
    this.isPulsing = false,
    this.isCollapsed = false,
    this.width = 280,
    this.variant = SidebarVariant.sidebar,
    this.onNewSession,
    this.onSettings,
    this.onInbox,
    this.inboxBadgeCount,
    this.showInboxBadge = false,
    this.showZenButton = false,
    this.headerLeading,
    this.headerActions,
    this.floatingActionButton,
    super.key,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with SingleTickerProviderStateMixin {
  late AnimationController _collapseController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _collapseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _widthAnimation = Tween<double>(begin: widget.width, end: widget.width * 0.4)
        .animate(CurvedAnimation(parent: _collapseController, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(Sidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCollapsed != widget.isCollapsed) {
      if (widget.isCollapsed) {
        _collapseController.forward();
      } else {
        _collapseController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        return Container(
          width: _widthAnimation.value,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(theme),
              if (widget.variant == SidebarVariant.sidebar) _buildConnectionStatus(theme),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          if (widget.headerLeading != null) ...[
            widget.headerLeading!,
            const SizedBox(width: 8),
          ],
          if (widget.variant == SidebarVariant.sidebar) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sessions',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.headerActions != null) ...[
            ...widget.headerActions!.map((action) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: action,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(ThemeData theme) {
    final statusColor = widget.statusColor ?? _getStatusColor(theme);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _StatusDot(
            color: statusColor,
            isPulsing: widget.isPulsing,
            size: 6,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.statusText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ThemeData theme) {
    switch (widget.connectionStatus) {
      case ConnectionStatus.connected:
        return theme.colorScheme.primary;
      case ConnectionStatus.connecting:
        return theme.colorScheme.tertiary;
      case ConnectionStatus.disconnected:
        return theme.colorScheme.outline;
      case ConnectionStatus.error:
        return theme.colorScheme.error;
      case ConnectionStatus.unknown:
        return theme.colorScheme.outlineVariant;
    }
  }
}

/// Status dot with optional pulsing animation
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool isPulsing;
  final double size;

  const _StatusDot({
    required this.color,
    this.isPulsing = false,
    this.size = 6,
  });

  @override
  State<_StatusDot> createState() => __StatusDotState();
}

class __StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isPulsing) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPulsing != widget.isPulsing) {
      if (widget.isPulsing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _scaleAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Sidebar navigation item
class SidebarNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool hasIndicator;

  const SidebarNavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onTap,
    this.badgeCount,
    this.hasIndicator = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  if (hasIndicator)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeCount! > 99 ? '99+' : badgeCount.toString(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onError,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isActive ? colorScheme.primary : colorScheme.onSurface,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension to get status color from theme
extension ConnectionStatusExtension on ConnectionStatus {
  Color getColor(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    switch (this) {
      case ConnectionStatus.connected:
        return colorScheme.primary;
      case ConnectionStatus.connecting:
        return colorScheme.tertiary;
      case ConnectionStatus.disconnected:
        return colorScheme.outline;
      case ConnectionStatus.error:
        return colorScheme.error;
      case ConnectionStatus.unknown:
        return colorScheme.outlineVariant;
    }
  }
}
