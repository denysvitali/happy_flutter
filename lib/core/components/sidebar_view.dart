import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../i18n/app_localizations.dart';
import '../../core/models/session.dart';
import '../../core/providers/app_providers.dart';
import '../../core/api/websocket_client.dart';
import 'status_dot.dart';
import 'voice_assistant_status_bar.dart';

/// Sidebar navigation widget matching React Native's SidebarView.tsx.
///
/// Features:
/// - Header with logo and connection status
/// - Dynamic width calculation (min 250, max 360, 30% of window)
/// - Status dot with pulsing animation for connecting state
/// - Navigation icons: experiments (if enabled), inbox (badge), settings, new session
/// - Voice assistant status bar (conditionally shown)
/// - Content area for session list
class SidebarView extends ConsumerStatefulWidget {
  /// Callback when new session is requested
  final VoidCallback? onNewSession;

  /// Content widget for the session list area
  final Widget? content;

  const SidebarView({
    super.key,
    this.onNewSession,
    this.content,
  });

  @override
  ConsumerState<SidebarView> createState() => _SidebarViewState();
}

class _SidebarViewState extends ConsumerState<SidebarView> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsNotifierProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final friendRequests = ref.watch(friendsNotifierProvider);
    final inboxState = ref.watch(feedNotifierProvider);

    // Calculate sidebar width - same formula as SidebarNavigator.tsx
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidebarWidth =
        _calculateSidebarWidth(screenWidth, settings.experiments);

    // Determine title positioning
    final shouldLeftJustify =
        settings.experiments || sidebarWidth < 340;

    // Connection status info
    final connectionInfo = _getConnectionInfo(connectionStatus, l10n);

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(
            context,
            l10n,
            settings.experiments,
            connectionInfo,
            shouldLeftJustify,
            friendRequests.incomingRequests.length,
            inboxState.unreadNotifications > 0,
          ),

          // Voice assistant status bar (shown when connected or connecting)
          if (connectionStatus != ConnectionStatus.disconnected)
            VoiceAssistantStatusBar(variant: 'sidebar'),

          // Content area for session list
          Expanded(
            child: widget.content ?? const _DefaultSessionContent(),
          ),
        ],
      ),
    );
  }

  /// Calculate sidebar width matching React Native's formula
  /// min: 250, max: 360, default: 30% of window
  double _calculateSidebarWidth(double windowWidth, bool experimentsEnabled) {
    final rawWidth = (windowWidth * 0.3).floorToDouble();
    if (experimentsEnabled) {
      // With experiments icon: threshold 408px > max 360px -> always use max(250, calc)
      return rawWidth.clamp(250, 360);
    }
    // Without experiments: threshold 328px -> left-justify below ~340px
    return rawWidth.clamp(250, 360);
  }

  _ConnectionInfo _getConnectionInfo(
    ConnectionStatus status,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case ConnectionStatus.connected:
        return _ConnectionInfo(
          color: Colors.green,
          isPulsing: false,
          text: l10n.sidebarStatusConnected,
        );
      case ConnectionStatus.connecting:
        return _ConnectionInfo(
          color: Colors.orange,
          isPulsing: true,
          text: l10n.sidebarStatusConnecting,
        );
      case ConnectionStatus.disconnected:
        return _ConnectionInfo(
          color: Colors.grey,
          isPulsing: false,
          text: l10n.sidebarStatusDisconnected,
        );
      case ConnectionStatus.error:
        return _ConnectionInfo(
          color: Colors.red,
          isPulsing: false,
          text: l10n.sidebarStatusError,
        );
    }
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    bool experimentsEnabled,
    _ConnectionInfo connectionInfo,
    bool shouldLeftJustify,
    int friendRequestCount,
    bool inboxHasContent,
  ) {
    final theme = Theme.of(context);
    final headerTintColor = theme.appBarTheme.titleTextStyle?.color ??
        theme.colorScheme.onSurface;

    return SizedBox(
      height: kToolbarHeight + MediaQuery.paddingOf(context).top,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          left: 16,
          right: 8,
        ),
        child: Row(
          children: [
            // Logo (using icon since assets don't exist yet)
            SizedBox(
              width: 32,
              height: 24,
              child: Icon(
                Icons.terminal,
                size: 24,
                color: headerTintColor,
              ),
            ),

            // Left-justified title (when experiments enabled or sidebar is narrow)
            if (shouldLeftJustify)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sidebarSessionsTitle,
                      style: theme.appBarTheme.titleTextStyle?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (connectionInfo.text.isNotEmpty)
                      Row(
                        children: [
                          StatusDot(
                            color: connectionInfo.color,
                            isPulsing: connectionInfo.isPulsing,
                            size: 6,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            connectionInfo.text,
                            style: TextStyle(
                              fontSize: 11,
                              color: connectionInfo.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

            const Spacer(),

            // Navigation icons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Experiments icon (only if enabled)
                if (experimentsEnabled)
                  _buildNavIcon(
                    context,
                    icon: Icons.science_outlined,
                    onTap: () => context.push('/zen'),
                    tintColor: headerTintColor,
                  ),

                // Inbox icon with badge
                _buildInboxIcon(
                  context,
                  friendRequestCount: friendRequestCount,
                  hasContent: inboxHasContent,
                  tintColor: headerTintColor,
                ),

                // Settings icon
                _buildNavIcon(
                  context,
                  icon: Icons.settings_outlined,
                  onTap: () => context.push('/settings'),
                  tintColor: headerTintColor,
                ),

                // New session icon
                _buildNavIcon(
                  context,
                  icon: Icons.add,
                  onTap: widget.onNewSession ?? () => _showNewSessionDialog(context),
                  tintColor: headerTintColor,
                  size: 28,
                ),
              ],
            ),

            // Centered title (when experiments disabled and sidebar is wide)
            if (!shouldLeftJustify)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.sidebarSessionsTitle,
                      style: theme.appBarTheme.titleTextStyle?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (connectionInfo.text.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          StatusDot(
                            color: connectionInfo.color,
                            isPulsing: connectionInfo.isPulsing,
                            size: 6,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            connectionInfo.text,
                            style: TextStyle(
                              fontSize: 11,
                              color: connectionInfo.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required Color tintColor,
    double size = 32,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: size,
          color: tintColor,
        ),
      ),
    );
  }

  Widget _buildInboxIcon(
    BuildContext context, {
    required int friendRequestCount,
    required bool hasContent,
    required Color tintColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => context.push('/inbox'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.inbox_outlined,
              size: 32,
              color: tintColor,
            ),
          ),
        ),
        // Badge for friend requests
        if (friendRequestCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                friendRequestCount > 99 ? '99+' : friendRequestCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        // Indicator dot for inbox content
        if (hasContent && friendRequestCount == 0)
          Positioned(
            top: 0,
            right: -2,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  void _showNewSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('New Session'),
        content: Text('New session dialog would go here'),
      ),
    );
  }
}

/// Default content for the sidebar session list area.
class _DefaultSessionContent extends ConsumerWidget {
  const _DefaultSessionContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessions = ref.watch(sessionsNotifierProvider);
    final sessionList = sessions.values.toList();

    if (sessionList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.computer_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.sessionNoSessionsYet,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Sort sessions by updatedAt (newest first)
    sessionList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sessionList.length,
      itemBuilder: (context, index) {
        final session = sessionList[index];
        return _SessionListItem(session: session);
      },
    );
  }
}

class _SessionListItem extends StatelessWidget {
  final Session session;

  const _SessionListItem({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () => context.push('/chat/${session.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: session.active ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Session name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.metadata?.name ?? session.id,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (session.metadata?.path != null)
                      Text(
                        session.metadata!.path!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              // Timestamp
              Text(
                _formatTimestamp(session.updatedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class _ConnectionInfo {
  final Color color;
  final bool isPulsing;
  final String text;

  _ConnectionInfo({
    required this.color,
    required this.isPulsing,
    required this.text,
  });
}
