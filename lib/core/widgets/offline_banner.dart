import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/socket_io_client.dart' show ConnectionStatus;
import '../i18n/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme/app_tokens.dart';

/// A prominent banner displayed when the device is offline or
/// the socket is disconnected.
///
/// Two states:
/// - **No network** (red) — device has no WiFi/cellular.
/// - **Reconnecting** (orange) — network available but socket
///   not yet connected.
///
/// Collapses to zero height with animation when everything is
/// healthy.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(networkNotifierProvider);
    final socketStatus = ref.watch(connectionNotifierProvider);

    final isConnected =
        socketStatus == ConnectionStatus.connected;

    // Nothing to show — network is up and socket is connected.
    if (isOnline && isConnected) {
      return const _AnimatedBannerShell(visible: false);
    }

    if (!isOnline) {
      return _AnimatedBannerShell(
        visible: true,
        child: _BannerContent(
          icon: Icons.wifi_off_rounded,
          label: AppLocalizations.of(context)
              .offlineBannerNoConnection,
          isError: true,
        ),
      );
    }

    // Online but socket not connected — reconnecting.
    return _AnimatedBannerShell(
      visible: true,
      child: _BannerContent(
        icon: Icons.sync_rounded,
        label: AppLocalizations.of(context)
            .offlineBannerReconnecting,
        isError: false,
      ),
    );
  }
}

/// Smoothly animates between visible (banner shown) and hidden
/// (zero height) using [AnimatedSize] + [AnimatedOpacity].
class _AnimatedBannerShell extends StatelessWidget {
  const _AnimatedBannerShell({
    required this.visible,
    this.child,
  });

  final bool visible;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppDuration.normal,
      curve: AppCurve.standard,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: AppDuration.normal,
        curve: AppCurve.standard,
        child: visible
            ? (child ?? const SizedBox.shrink())
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// The actual banner content — icon + label on a tinted
/// background.
class _BannerContent extends StatelessWidget {
  const _BannerContent({
    required this.icon,
    required this.label,
    required this.isError,
  });

  final IconData icon;
  final String label;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isError ? cs.errorContainer : cs.tertiaryContainer;
    final fg =
        isError ? cs.onErrorContainer : cs.onTertiaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppFontSize.sm,
                color: fg,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
