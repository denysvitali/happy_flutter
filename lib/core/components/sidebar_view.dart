import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../core/providers/app_providers.dart';
import '../../core/services/chat_switch_metrics.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../i18n/app_localizations.dart';
import '../utils/utils.dart';
import 'app_status_dot.dart';
import 'voice_assistant_status_bar.dart';

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
    final cs = theme.colorScheme;
    final headerTintColor =
        theme.appBarTheme.titleTextStyle?.color ?? cs.onSurface;
    final top = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.only(
        top: top + AppSpacing.sm,
        left: AppSpacing.lg,
        right: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          cs.surfaceContainerLow.withValues(alpha: 0.35),
          cs.surface,
        ),
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: AppBorder.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: AppControlSize.md,
            height: AppControlSize.md,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.terminal_rounded, size: 18, color: cs.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.sidebarSessionsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(
                    theme,
                    headerTintColor,
                  ).copyWith(letterSpacing: -0.2),
                ),
                if (connectionInfo.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      AppStatusDot(
                        color: connectionInfo.color,
                        pulse: connectionInfo.isPulsing,
                        size: 8,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          connectionInfo.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label(theme, cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _buildNavIcon(
            context,
            icon: Icons.settings_outlined,
            onTap: () => context.push('/settings'),
            tintColor: cs.onSurfaceVariant,
            tooltip: AppLocalizations.of(context).commonSettings,
          ),
          _buildNavIcon(
            context,
            icon: Icons.add,
            onTap: widget.onNewSession ?? () => _showNewSessionDialog(context),
            tintColor: cs.onSurfaceVariant,
            tooltip: AppLocalizations.of(context).sessionsNew,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required Color tintColor,
    required String tooltip,
    double size = 20,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            mouseCursor: SystemMouseCursors.click,
            child: SizedBox(
              width: AppControlSize.md,
              height: AppControlSize.md,
              child: Icon(icon, size: size, color: tintColor),
            ),
          ),
        ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonClose),
            ),
          ],
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.sessionNoSessionsYet,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      itemCount: sessionIds.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ChatSwitchMetrics().begin(session.id, source: 'sidebar');
          context.push('/chat/${session.id}');
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: cs.onSurface.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: session.active
                      ? AppColors.success
                      : cs.outline.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.metadata?.name ?? session.id,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (session.metadata?.path != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        session.metadata!.path!,
                        style: AppText.secondary(theme, cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _formatTimestamp(
                  lastMessageTimestamp ??
                      session.lastMessageAt ??
                      session.updatedAt,
                  context,
                ),
                style: AppText.secondary(theme, cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact "2m" / "3h" / "5d" label, falling back to a day+month date in
  /// the *device* locale order ("31.7." in de, "7/31" in en_US) rather than a
  /// hardcoded US one.
  /// The date order deliberately comes from `Intl.defaultLocale` (seeded from
  /// the *platform* locale in `main()`), not `Localizations.localeOf` — the
  /// app only supports an English UI, so the resolved UI locale is always
  /// `en` and would pin every device to US order.
  String _formatTimestamp(int timestamp, BuildContext context) =>
      formatRelativeTime(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
        compact: true,
        l10n: context.l10n,
        absoluteFallback: formatShortDayMonth,
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
