import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/socket_io_client.dart' show ConnectionStatus;
import '../providers/app_providers.dart';
import '../services/sync_service.dart' show SyncProgress;
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A compact status bar for connection and sync activity.
class SyncProgressBar extends ConsumerWidget {
  const SyncProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateNotifierProvider);
    final isOnline = ref.watch(networkNotifierProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final progress = syncState.progress;
    final status = _StatusBarState.resolve(
      isOnline: isOnline,
      connectionStatus: connectionStatus,
      isSyncing: syncState.isSyncing,
      progress: progress,
    );
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedSize(
      duration: AppDuration.fast,
      curve: AppCurve.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppDuration.fast,
        child: status != null
            ? Container(
                key: ValueKey(status.key),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: status.backgroundColor(cs),
                  border: Border(
                    bottom: BorderSide(
                      color: status.foregroundColor(cs).withValues(alpha: 0.16),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 30,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: status.showSpinner
                                  ? CircularProgressIndicator(
                                      strokeWidth: 2,
                                      value: status.progressValue,
                                      color: status.foregroundColor(cs),
                                      backgroundColor: status
                                          .foregroundColor(cs)
                                          .withValues(alpha: 0.18),
                                    )
                                  : Icon(
                                      status.icon,
                                      size: 15,
                                      color: status.foregroundColor(cs),
                                    ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              flex: 0,
                              child: Text(
                                status.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: status.foregroundColor(cs),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                status.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: status
                                      .foregroundColor(cs)
                                      .withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (status.showProgressLine)
                      SizedBox(
                        height: 2,
                        // Always render a determinate value. A null value puts
                        // LinearProgressIndicator into its indeterminate
                        // animation path, whose _controller getter force-
                        // unwraps an ancestor lookup
                        // (findAncestorWidgetOfExactType<Theme>()!). While the
                        // surrounding AnimatedSwitcher/AnimatedSize transition
                        // is in flight (e.g. entering a freshly created
                        // session's ChatScreen) the indicator can tick after
                        // its element is deactivated, so that ancestor is null
                        // and the build crashes with "Null check operator used
                        // on a null value" (Flutter 3.44 progress_indicator
                        // regression). A determinate value skips the animated
                        // path entirely.
                        child: LinearProgressIndicator(
                          value: status.progressValue ?? 0,
                          backgroundColor: Colors.transparent,
                          color: status.foregroundColor(cs),
                          minHeight: 2,
                        ),
                      ),
                  ],
                ),
              )
            : const SizedBox.shrink(key: ValueKey('idle')),
      ),
    );
  }
}

/// Paints [SyncProgressBar] over [child] so transient sync/connection
/// states do not change page layout height.
class SyncProgressOverlay extends StatelessWidget {
  const SyncProgressOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(child: SyncProgressBar()),
        ),
      ],
    );
  }
}

class _StatusBarState {
  const _StatusBarState({
    required this.key,
    required this.title,
    required this.detail,
    required this.icon,
    required this.kind,
    this.progressValue,
    this.showSpinner = false,
  });

  final String key;
  final String title;
  final String detail;
  final IconData icon;
  final _StatusBarKind kind;
  final double? progressValue;
  final bool showSpinner;

  bool get showProgressLine => kind == _StatusBarKind.sync;

  static _StatusBarState? resolve({
    required bool isOnline,
    required ConnectionStatus connectionStatus,
    required bool isSyncing,
    required SyncProgress? progress,
  }) {
    if (!isOnline) {
      return const _StatusBarState(
        key: 'offline',
        title: 'Offline',
        detail: 'Changes will sync when the network returns',
        icon: Icons.wifi_off_rounded,
        kind: _StatusBarKind.error,
      );
    }

    if (connectionStatus == ConnectionStatus.error) {
      return const _StatusBarState(
        key: 'socket-error',
        title: 'Connection issue',
        detail: 'Retrying the live update connection',
        icon: Icons.error_outline_rounded,
        kind: _StatusBarKind.warning,
      );
    }

    if (connectionStatus != ConnectionStatus.connected) {
      return _StatusBarState(
        key: 'reconnecting',
        title: connectionStatus == ConnectionStatus.connecting
            ? 'Connecting'
            : 'Reconnecting',
        detail: isSyncing
            ? 'Sync is waiting for live updates to reconnect'
            : 'Restoring live updates',
        icon: Icons.sync_rounded,
        kind: _StatusBarKind.warning,
      );
    }

    if (isSyncing || progress != null) {
      return _StatusBarState(
        key: 'syncing',
        title: 'Syncing',
        detail: _syncDetail(progress),
        icon: Icons.cloud_sync_rounded,
        kind: _StatusBarKind.sync,
        progressValue: progress?.fraction,
        showSpinner: true,
      );
    }

    return null;
  }

  static String _syncDetail(SyncProgress? progress) {
    final completed = progress?.completed;
    final total = progress?.total;
    if (progress == null) {
      return 'Refreshing app data';
    }
    if (completed == null || total == null || total <= 0) {
      return progress.label;
    }
    return '${progress.label} - $completed of $total complete';
  }

  Color backgroundColor(ColorScheme cs) {
    return switch (kind) {
      _StatusBarKind.sync => Color.alphaBlend(
        AppColors.iosBlue.withValues(alpha: 0.12),
        cs.surface,
      ),
      _StatusBarKind.warning => Color.alphaBlend(
        AppColors.warning.withValues(alpha: 0.16),
        cs.surface,
      ),
      _StatusBarKind.error => cs.errorContainer,
    };
  }

  Color foregroundColor(ColorScheme cs) {
    return switch (kind) {
      _StatusBarKind.sync => AppColors.iosBlue,
      _StatusBarKind.warning => AppColors.warning,
      _StatusBarKind.error => cs.onErrorContainer,
    };
  }
}

enum _StatusBarKind { sync, warning, error }
