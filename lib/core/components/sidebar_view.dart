import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../i18n/app_localizations.dart';
import 'app_status_dot.dart';
import 'voice_assistant_status_bar.dart';
import '../utils/utils.dart';

/// Sidebar navigation widget matching React Native's SidebarView.tsx.
///
/// Features:
/// - Header with logo and connection status
/// - Dynamic width calculation (min 250, max 360, 30% of window)
/// - Status dot with pulsing animation for connecting state
/// - Voice assistant status bar (conditionally shown)
/// - Content area for session list
class SidebarView extends ConsumerStatefulWidget {
  const SidebarView({super.key, this.onNewSession, this.content});

  /// Callback when new session is requested
  final VoidCallback? onNewSession;

  /// Content widget for the session list area
  final Widget? content;

  @override
  ConsumerState<SidebarView> createState() => _SidebarViewState();
}

class _SidebarViewState extends ConsumerState<SidebarView> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final experimentsEnabled = ref.watch(
      settingsNotifierProvider.select((s) => s.experiments),
    );
    final connectionStatus = ref.watch(connectionNotifierProvider);

    // Calculate sidebar width - same formula as SidebarNavigator.tsx
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidebarWidth = _calculateSidebarWidth(
      screenWidth,
      experimentsEnabled,
    );

    // Determine title positioning
    final shouldLeftJustify = experimentsEnabled || sidebarWidth < 340;

    // Connection status info
    final cs = Theme.of(context).colorScheme;
    final connectionInfo = _getConnectionInfo(connectionStatus, l10n, cs);

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: AppOpacity.medium),
            width: AppBorder.hairline,
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
            experimentsEnabled,
            connectionInfo,
            shouldLeftJustify,
          ),

          // Voice assistant status bar (shown when connected or connecting)
          if (connectionStatus != ConnectionStatus.disconnected)
            VoiceAssistantStatusBar(variant: 'sidebar'),

          // Content area for session list
          Expanded(child: widget.content ?? const _DefaultSessionContent()),
        ],
      ),
    );
  }

  /// Calculate sidebar width matching React Native's formula
  /// min: 250, max: 360, default: 30% of window
  double _calculateSidebarWidth(double windowWidth, bool experimentsEnabled) {
    final rawWidth = (windowWidth * 0.3).floorToDouble();
    if (experimentsEnabled) {
      // With experiments icon: threshold 408px > max 360px
      return rawWidth.clamp(250, 360);
    }
    // Without experiments: threshold 328px -> left-justify below ~340px
    return rawWidth.clamp(250, 360);
  }

  _ConnectionInfo _getConnectionInfo(
    ConnectionStatus status,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    switch (status) {
      case ConnectionStatus.connected:
        return _ConnectionInfo(
          color: AppColors.success,
          isPulsing: false,
          text: l10n.sidebarStatusConnected,
        );
      case ConnectionStatus.connecting:
        return _ConnectionInfo(
          color: AppColors.warning,
          isPulsing: true,
          text: l10n.sidebarStatusConnecting,
        );
      case ConnectionStatus.disconnected:
        return _ConnectionInfo(
          color: cs.onSurfaceVariant,
          isPulsing: false,
          text: l10n.sidebarStatusDisconnected,
        );
      case ConnectionStatus.error:
        return _ConnectionInfo(
          color: cs.error,
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
  ) {
    final theme = Theme.of(context);
    final headerTintColor =
        theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onSurface;

    return SizedBox(
      height: kToolbarHeight + MediaQuery.paddingOf(context).top,
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          left: AppSpacing.lg,
          right: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Logo (using icon since assets don't exist yet)
            SizedBox(
              width: AppSpacing.xxxl - AppSpacing.xxl + AppSpacing.lg,
              height: AppSpacing.xxxl - AppSpacing.lg,
              child: Icon(
                Icons.terminal,
                size: AppSpacing.xxxl - AppSpacing.lg,
                color: headerTintColor,
              ),
            ),

            // Left-justified title (when experiments enabled
            if (shouldLeftJustify)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
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
                          AppStatusDot(
                            color: connectionInfo.color,
                            pulse: connectionInfo.isPulsing,
                            size: AppSpacing.xs + AppSpacing.xs,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            connectionInfo.text,
                            style: theme.textTheme.labelSmall?.copyWith(
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
                  onTap:
                      widget.onNewSession ??
                      () => _showNewSessionDialog(context),
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
                          AppStatusDot(
                            color: connectionInfo.color,
                            pulse: connectionInfo.isPulsing,
                            size: AppSpacing.xs + AppSpacing.xs,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            connectionInfo.text,
                            style: theme.textTheme.labelSmall?.copyWith(
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
    double size = AppSpacing.xxl,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Icon(icon, size: size, color: tintColor),
      ),
    );
  }

  void _showNewSessionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.sessionsNew),
          content: Text(l10n.sessionsNewDialogPlaceholder),
        );
      },
    );
  }
}

/// Default content for the sidebar session list area.
class _DefaultSessionContent extends ConsumerWidget {
  const _DefaultSessionContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final sessionIds = ref.watch(recentSessionIdsProvider);

    if (sessionIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.computer_outlined, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.sessionNoSessionsYet,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: sessionIds.length,
      itemBuilder: (context, index) {
        final sessionId = sessionIds[index];
        return _SidebarSessionListItem(
          key: ValueKey(sessionId),
          sessionId: sessionId,
        );
      },
    );
  }
}

class _SidebarSessionListItem extends ConsumerWidget {
  const _SidebarSessionListItem({required this.sessionId, super.key});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));
    if (session == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final lastMessageTimestamp = sync.getLastMessageTimestamp(session.id);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      elevation: 0,
      color: cs.surface,
      child: InkWell(
        onTap: () => context.push('/chat/${session.id}'),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: AppSpacing.sm + AppSpacing.xs,
                height: AppSpacing.sm + AppSpacing.xs,
                decoration: BoxDecoration(
                  color: session.active
                      ? AppColors.success
                      : cs.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
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
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                  ],
                ),
              ),
              // Timestamp
              Text(
                _formatTimestamp(lastMessageTimestamp ?? session.updatedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int timestamp) => formatRelativeTime(
    DateTime.fromMillisecondsSinceEpoch(timestamp),
    compact: true,
    absoluteFallback: (d) => '${d.month}/${d.day}',
  );
}

class _ConnectionInfo {
  _ConnectionInfo({
    required this.color,
    required this.isPulsing,
    required this.text,
  });
  final Color color;
  final bool isPulsing;
  final String text;
}
