import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme/app_tokens.dart';

/// Slim banner surfacing desktop self-update progress on the sessions and
/// chat screens. Mirrors [OfflineBanner]'s shell so the two stack cleanly.
///
/// Visible states:
/// - **available** — new release found; "Download" action (+ dismiss).
/// - **downloading** — progress line, no actions.
/// - **readyToRestart** — swap complete; "Restart now" applies it.
///
/// Everything else collapses to zero height.
class DesktopUpdateBanner extends ConsumerWidget {
  const DesktopUpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(desktopUpdaterNotifierProvider);
    final l10n = AppLocalizations.of(context);

    final Widget? content = switch (state.status) {
      DesktopUpdateStatus.available when !state.dismissed => _Row(
        icon: Icons.system_update_alt_rounded,
        label: l10n.desktopUpdateAvailable(
          _versionLabel(state.availableVersion),
        ),
        actionLabel: l10n.desktopUpdateDownload,
        onAction: () => ref
            .read(desktopUpdaterNotifierProvider.notifier)
            .downloadAndApply(),
        onDismiss: () =>
            ref.read(desktopUpdaterNotifierProvider.notifier).dismissBanner(),
      ),
      DesktopUpdateStatus.downloading => _Row(
        icon: Icons.downloading_rounded,
        label: state.downloadProgress != null
            ? l10n.desktopUpdateDownloadingProgress(state.downloadProgress!)
            : l10n.desktopUpdateDownloading,
      ),
      DesktopUpdateStatus.readyToRestart => _Row(
        icon: Icons.restart_alt_rounded,
        label: l10n.desktopUpdateReady,
        actionLabel: l10n.desktopUpdateRestart,
        onAction: () => ref
            .read(desktopUpdaterNotifierProvider.notifier)
            .restartIntoUpdatedVersion(),
      ),
      _ => null,
    };

    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDuration.normal,
      curve: AppCurve.standard,
      alignment: Alignment.topCenter,
      child: content ?? const SizedBox.shrink(),
    );
  }

  String _versionLabel(String? version) {
    if (version == null || version.isEmpty) return '';
    return version;
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final IconData icon;
  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.secondaryContainer;
    final fg = cs.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      color: bg,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
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
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
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
                actionLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: AppIconSize.lg, color: fg),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
        ],
      ),
    );
  }
}
