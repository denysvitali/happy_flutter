import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/api/websocket_client.dart';
import 'status_dot.dart';

/// Voice assistant status bar for sidebar variant.
///
/// Matches the React Native VoiceAssistantStatusBar.tsx behavior.
class VoiceAssistantStatusBar extends ConsumerWidget {
  /// Variant of the status bar - 'full' for mobile, 'sidebar' for tablet
  final String variant;

  /// Optional style override
  final BoxStyle? style;

  const VoiceAssistantStatusBar({
    super.key,
    this.variant = 'sidebar',
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);

    // Don't render if disconnected
    if (connectionStatus == ConnectionStatus.disconnected) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final theme = Theme.of(context);

    final statusInfo = _getStatusInfo(connectionStatus, l10n);

    if (variant == 'full') {
      return _buildFullVariant(context, statusInfo, theme);
    }

    return _buildSidebarVariant(context, statusInfo, theme);
  }

  _StatusInfo _getStatusInfo(ConnectionStatus status, AppLocalizations l10n) {
    switch (status) {
      case ConnectionStatus.connected:
        return _StatusInfo(
          color: Colors.green,
          backgroundColor: Colors.grey[100]!,
          isPulsing: false,
          text: l10n.voiceAssistantActive,
          textColor: Colors.green,
        );
      case ConnectionStatus.connecting:
        return _StatusInfo(
          color: Colors.orange,
          backgroundColor: Colors.grey[100]!,
          isPulsing: true,
          text: l10n.voiceAssistantConnecting,
          textColor: Colors.orange,
        );
      case ConnectionStatus.error:
        return _StatusInfo(
          color: Colors.red,
          backgroundColor: Colors.grey[100]!,
          isPulsing: false,
          text: l10n.voiceAssistantError,
          textColor: Colors.red,
        );
      case ConnectionStatus.disconnected:
      default:
        return _StatusInfo(
          color: Colors.grey,
          backgroundColor: Colors.grey[100]!,
          isPulsing: false,
          text: l10n.voiceAssistantDefault,
          textColor: Colors.grey,
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
  final Color color;
  final Color backgroundColor;
  final bool isPulsing;
  final String text;
  final Color textColor;

  _StatusInfo({
    required this.color,
    required this.backgroundColor,
    required this.isPulsing,
    required this.text,
    required this.textColor,
  });
}
