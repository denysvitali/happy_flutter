import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/websocket_client.dart' show ConnectionStatus;
import '../../core/providers/app_providers.dart';
import '../i18n/app_localizations.dart';
import 'status_dot.dart';

/// Voice assistant status bar for sidebar variant.
///
/// Matches the React Native VoiceAssistantStatusBar.tsx behavior.
class VoiceAssistantStatusBar extends ConsumerWidget {

  const VoiceAssistantStatusBar({
    super.key,
    this.variant = 'sidebar',
    this.backgroundColor,
  });
  /// Variant of the status bar - 'full' for mobile, 'sidebar' for tablet
  final String variant;

  /// Optional background color override
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);

    // Don't render if disconnected
    if (connectionStatus == ConnectionStatus.disconnected) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);

    final statusInfo = _getStatusInfo(connectionStatus, l10n, theme);

    if (variant == 'full') {
      return _buildFullVariant(context, statusInfo, theme);
    }

    return _buildSidebarVariant(context, statusInfo, theme);
  }

  _StatusInfo _getStatusInfo(
    ConnectionStatus status,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final surfaceLow = theme.colorScheme.surfaceContainerLow;
    switch (status) {
      case ConnectionStatus.connected:
        return _StatusInfo(
          color: const Color(0xFF34C759),
          backgroundColor: surfaceLow,
          isPulsing: false,
          text: l10n.voiceAssistantActive,
          textColor: const Color(0xFF34C759),
        );
      case ConnectionStatus.connecting:
        return _StatusInfo(
          color: const Color(0xFFFF9500),
          backgroundColor: surfaceLow,
          isPulsing: true,
          text: l10n.voiceAssistantConnecting,
          textColor: const Color(0xFFFF9500),
        );
      case ConnectionStatus.error:
        return _StatusInfo(
          color: theme.colorScheme.error,
          backgroundColor: surfaceLow,
          isPulsing: false,
          text: l10n.voiceAssistantError,
          textColor: theme.colorScheme.error,
        );
      case ConnectionStatus.disconnected:
        return _StatusInfo(
          color: theme.colorScheme.onSurfaceVariant,
          backgroundColor: surfaceLow,
          isPulsing: false,
          text: l10n.voiceAssistantDefault,
          textColor: theme.colorScheme.onSurfaceVariant,
        );
    }
  }

  Widget _buildFullVariant(
    BuildContext context,
    _StatusInfo statusInfo,
    ThemeData theme,
  ) {
    return Container(
      height: 32,
      width: double.infinity,
      color: statusInfo.backgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Row(
                children: [
                  StatusDot(
                    color: statusInfo.color,
                    isPulsing: statusInfo.isPulsing,
                    size: 8,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.mic,
                    size: 16,
                    color: statusInfo.textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusInfo.text,
                    style: TextStyle(
                      color: statusInfo.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                context.l10n.voiceAssistantTapToEnd,
                style: TextStyle(
                  color: statusInfo.textColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarVariant(
    BuildContext context,
    _StatusInfo statusInfo,
    ThemeData theme,
  ) {
    return Container(
      height: 32,
      width: double.infinity,
      color: statusInfo.backgroundColor,
      child: Row(
        children: [
          const SizedBox(width: 12),
          StatusDot(
            color: statusInfo.color,
            isPulsing: statusInfo.isPulsing,
            size: 8,
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.mic,
            size: 16,
            color: statusInfo.textColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              statusInfo.text,
              style: TextStyle(
                color: statusInfo.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.close,
            size: 14,
            color: statusInfo.textColor,
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _StatusInfo {

  _StatusInfo({
    required this.color,
    required this.backgroundColor,
    required this.isPulsing,
    required this.text,
    required this.textColor,
  });
  final Color color;
  final Color backgroundColor;
  final bool isPulsing;
  final String text;
  final Color textColor;
}
