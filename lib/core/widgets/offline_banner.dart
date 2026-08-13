import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/socket_io_client.dart'
    show ConnectionStatus, DisconnectReason, socketIoClient;
import '../i18n/app_localizations.dart';
import '../providers/app_providers.dart';
import '../services/sync_service.dart';
import '../theme/app_tokens.dart';

/// A prominent banner displayed when the device is offline or
/// the socket is disconnected.
///
/// Two states:
/// - **No network** (red) — device has no WiFi/cellular.
/// - **Reconnecting** (orange) — network available but socket
///   not yet connected. Shows a countdown to the next attempt
///   and a "Reconnect now" button.
///
/// Collapses to zero height with animation when everything is
/// healthy.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  /// Socket handshakes are expected during every cold start and resume.
  /// Only promote the transient state to a user-facing outage when it lasts
  /// long enough to be actionable.
  static const reconnectGracePeriod = Duration(seconds: 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(networkNotifierProvider);
    final socketStatus = ref.watch(connectionNotifierProvider);

    final isConnected = socketStatus == ConnectionStatus.connected;

    // Nothing to show — network is up and socket is connected.
    if (isOnline && isConnected) {
      return const _AnimatedBannerShell(visible: false);
    }

    if (!isOnline) {
      return _AnimatedBannerShell(
        visible: true,
        child: _BannerContent(
          icon: Icons.wifi_off_rounded,
          label: AppLocalizations.of(context).offlineBannerNoConnection,
          isError: true,
        ),
      );
    }

    // A socket handshake is routine on startup/resume. Avoid flashing an
    // outage banner over every chat while the connection is still within its
    // normal grace period. The reconnect watchdog continues running during
    // this delay, and a persistent failure still surfaces with a manual
    // recovery action.
    return _DelayedReconnectingBanner(status: socketStatus);
  }
}

class _DelayedReconnectingBanner extends StatefulWidget {
  const _DelayedReconnectingBanner({required this.status});

  final ConnectionStatus status;

  @override
  State<_DelayedReconnectingBanner> createState() =>
      _DelayedReconnectingBannerState();
}

class _DelayedReconnectingBannerState
    extends State<_DelayedReconnectingBanner> {
  Timer? _graceTimer;
  late bool _visible;

  @override
  void initState() {
    super.initState();
    _visible = widget.status == ConnectionStatus.error;
    if (!_visible) {
      _graceTimer = Timer(OfflineBanner.reconnectGracePeriod, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _DelayedReconnectingBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ConnectionStatus.error && !_visible) {
      _graceTimer?.cancel();
      _graceTimer = null;
      _visible = true;
    }
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AnimatedBannerShell(
    visible: _visible,
    child: _visible ? const _ReconnectingBanner() : null,
  );
}

/// Banner body for the "reconnecting" state. Manages a per-second
/// countdown driven by [SocketIoClient.nextReconnectDelayStream] and
/// provides a "Reconnect now" button.
class _ReconnectingBanner extends StatefulWidget {
  const _ReconnectingBanner();

  @override
  State<_ReconnectingBanner> createState() => _ReconnectingBannerState();
}

class _ReconnectingBannerState extends State<_ReconnectingBanner> {
  // Remaining seconds until the next internal reconnect attempt.
  // null = no countdown yet (socket just disconnected, waiting for
  // the first reconnect_attempt event).
  int? _secondsRemaining;

  Timer? _ticker;
  StreamSubscription<int>? _delaySub;

  @override
  void initState() {
    super.initState();
    _delaySub = socketIoClient.nextReconnectDelayStream.listen(_onNextDelay);
  }

  void _onNextDelay(int seconds) {
    if (!mounted) return;
    _ticker?.cancel();
    setState(() => _secondsRemaining = seconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = _secondsRemaining;
      if (current == null || current <= 1) {
        // Countdown expired — clear so we show "Reconnecting…" until
        // the next reconnect_attempt event fires.
        setState(() => _secondsRemaining = null);
        _ticker?.cancel();
      } else {
        setState(() => _secondsRemaining = current - 1);
      }
    });
  }

  void _forceReconnect() {
    // Cancel the countdown immediately — the banner will show the
    // plain "Reconnecting…" label while the new connection handshake
    // is in progress.
    _ticker?.cancel();
    setState(() => _secondsRemaining = null);
    // Route through Sync (not a bare socketIoClient.reconnect()) so the
    // reconnect watchdog is armed: if this dial also fails — common right
    // after the device wakes — the app keeps retrying on a bounded cadence
    // instead of leaving the user staring at a dead banner.
    sync.forceReconnect(reason: 'offline_banner');
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _delaySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final bg = cs.tertiaryContainer;
    final fg = cs.onTertiaryContainer;

    final remaining = _secondsRemaining;
    final disconnectReason = socketIoClient.lastDisconnectReason;
    final baseLabel = disconnectReason == DisconnectReason.ioServerDisconnect
        ? l10n.offlineBannerServiceUnavailable
        : l10n.offlineBannerLiveUpdatesDisconnected;
    final label = remaining != null && remaining > 0
        ? l10n.offlineBannerReconnectingIn(remaining)
        : baseLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      color: bg,
      // Wrap rather than Row: at large system text the label and the
      // "Reconnect now" button no longer fit on one line, so the button
      // moves to a second run instead of overflowing the banner.
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          Semantics(
            container: true,
            liveRegion: true,
            label: l10n.a11yConnectionStatusBanner(label),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_rounded, size: AppIconSize.md, color: fg),
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
          ),
          TextButton(
            onPressed: _forceReconnect,
            style: TextButton.styleFrom(
              foregroundColor: fg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              minimumSize: const Size(AppTouchTarget.min, AppTouchTarget.min),
              textStyle: const TextStyle(
                fontSize: AppFontSize.sm,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(
              l10n.offlineBannerReconnectNow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Smoothly animates between visible (banner shown) and hidden
/// (zero height) using [AnimatedSize] + [AnimatedOpacity].
class _AnimatedBannerShell extends StatelessWidget {
  const _AnimatedBannerShell({required this.visible, this.child});

  final bool visible;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDuration.normal;
    return AnimatedSize(
      duration: duration,
      curve: AppCurve.standard,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: duration,
        curve: AppCurve.standard,
        child: visible
            ? (child ?? const SizedBox.shrink())
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// The actual banner content — icon + label on a tinted
/// background. Used for the "no connection" (error) state.
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
    final l10n = AppLocalizations.of(context);
    final bg = isError ? cs.errorContainer : cs.tertiaryContainer;
    final fg = isError ? cs.onErrorContainer : cs.onTertiaryContainer;

    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.a11yConnectionStatusBanner(label),
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        color: bg,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppIconSize.md, color: fg),
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
      ),
    );
  }
}
