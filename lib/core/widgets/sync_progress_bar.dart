import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/socket_io_client.dart' show ConnectionStatus;
import '../providers/app_providers.dart';
import '../services/sync_service.dart' show SyncProgress;
import '../theme/app_tokens.dart';
import 'app_circular_progress_indicator.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

/// Which work a [SyncProgressBar] reports.
enum SyncStatusScope {
  /// The session catalog and resume catch-up (sessions list).
  sessions,

  /// The open chat's message catch-up.
  chat,
}

/// A compact floating status pill for conversation sync.
///
/// Cached conversations are always on screen, so the pill is a hint rather
/// than a gate: it reports only the work the current screen is waiting on,
/// and stays hidden for [showDelay] so routine sub-second refreshes never
/// flash. Background refreshes (settings, machines, git status, other chats)
/// never surface here.
class SyncProgressBar extends ConsumerStatefulWidget {
  const SyncProgressBar({this.scope = SyncStatusScope.sessions, super.key});

  final SyncStatusScope scope;

  /// How long sync work must run before the pill appears.
  static const showDelay = Duration(milliseconds: 700);

  @override
  ConsumerState<SyncProgressBar> createState() => _SyncProgressBarState();
}

class _SyncProgressBarState extends ConsumerState<SyncProgressBar> {
  Timer? _delayTimer;
  bool _delayElapsed = false;

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  /// Arms the show delay while sync work runs; resets it once idle.
  void _trackSyncing(bool syncing) {
    if (!syncing) {
      _delayTimer?.cancel();
      _delayTimer = null;
      _delayElapsed = false;
      return;
    }
    if (_delayElapsed || _delayTimer != null) return;
    _delayTimer = Timer(SyncProgressBar.showDelay, () {
      _delayTimer = null;
      if (mounted) setState(() => _delayElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncStateNotifierProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final status = _StatusPillState.resolve(
      scope: widget.scope,
      connectionStatus: connectionStatus,
      syncState: syncState,
    );
    _trackSyncing(status?.kind == _StatusPillKind.sync);
    final visible =
        status != null &&
        (status.kind == _StatusPillKind.error || _delayElapsed);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDuration.fast;

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppCurve.standard,
      switchOutCurve: AppCurve.standard,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: visible
          ? _StatusPill(key: ValueKey(status.key), status: status)
          : const SizedBox.shrink(key: ValueKey('idle')),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, super.key});

  final _StatusPillState status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = status.foregroundColor(cs);
    final detail = status.detail;

    // Bottom/side room keeps the elevation shadow inside the
    // SizeTransition's clip and the pill off the screen edges.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Center(
        child: Semantics(
          container: true,
          liveRegion: true,
          label: detail == null ? status.title : '${status.title}, $detail',
          excludeSemantics: true,
          child: Material(
            color: status.backgroundColor(cs),
            elevation: 3,
            shadowColor: cs.shadow.withValues(alpha: 0.25),
            surfaceTintColor: Colors.transparent,
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xsm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: AppIconSize.sm,
                    child: status.kind == _StatusPillKind.sync
                        ? AppCircularProgressIndicator(
                            strokeWidth: 2,
                            value: status.progressValue,
                            color: fg,
                            backgroundColor: fg.withValues(alpha: 0.18),
                          )
                        : Icon(status.icon, size: AppIconSize.sm, color: fg),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        text: status.title,
                        children: [
                          if (detail != null)
                            TextSpan(
                              text: '  $detail',
                              style: AppText.label(
                                theme,
                                fg.withValues(alpha: 0.72),
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.badge(theme, fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [SyncProgressBar] over [child] so transient sync states do not
/// change page layout height.
class SyncProgressOverlay extends StatelessWidget {
  const SyncProgressOverlay({
    required this.child,
    this.scope = SyncStatusScope.sessions,
    super.key,
  });

  final Widget child;
  final SyncStatusScope scope;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(child: SyncProgressBar(scope: scope)),
        ),
      ],
    );
  }
}

class _StatusPillState {
  const _StatusPillState({
    required this.key,
    required this.title,
    required this.icon,
    required this.kind,
    this.detail,
    this.progressValue,
  });

  final String key;
  final String title;
  final String? detail;
  final IconData icon;
  final _StatusPillKind kind;
  final double? progressValue;

  static _StatusPillState? resolve({
    required SyncStatusScope scope,
    required ConnectionStatus connectionStatus,
    required SyncState syncState,
  }) {
    // OfflineBanner owns network/socket recovery. In particular, connecting
    // is the normal state during every startup and resume, not a sync error.
    // Suppressing progress here avoids stacking two banners and falsely
    // claiming that HTTP message catch-up is waiting on the socket.
    if (connectionStatus != ConnectionStatus.connected) {
      return null;
    }

    switch (scope) {
      case SyncStatusScope.sessions:
        final progress = syncState.catalogProgress;
        if (progress != null) {
          return _StatusPillState(
            key: 'syncing',
            title: progress.label,
            detail: _countDetail(progress),
            icon: Icons.cloud_sync_rounded,
            kind: _StatusPillKind.sync,
            progressValue: progress.fraction,
          );
        }
      case SyncStatusScope.chat:
        if (syncState.isVisibleChatSyncing) {
          return const _StatusPillState(
            key: 'syncing',
            title: 'Loading new messages',
            icon: Icons.cloud_sync_rounded,
            kind: _StatusPillKind.sync,
          );
        }
    }

    if (syncState.hasCriticalFailure) {
      return const _StatusPillState(
        key: 'data-refresh-error',
        title: 'Data refresh failed',
        detail: 'Sessions or machines may be out of date',
        icon: Icons.cloud_off_rounded,
        kind: _StatusPillKind.error,
      );
    }

    return null;
  }

  static String? _countDetail(SyncProgress progress) {
    final completed = progress.completed;
    final total = progress.total;
    if (completed == null || total == null || total <= 0) return null;
    return '$completed of $total';
  }

  Color backgroundColor(ColorScheme cs) {
    return switch (kind) {
      _StatusPillKind.sync => cs.surfaceContainerHighest,
      _StatusPillKind.error => cs.errorContainer,
    };
  }

  Color foregroundColor(ColorScheme cs) {
    return switch (kind) {
      _StatusPillKind.sync => cs.onSurface,
      _StatusPillKind.error => cs.onErrorContainer,
    };
  }
}

enum _StatusPillKind { sync, error }
