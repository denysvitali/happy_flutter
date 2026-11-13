import 'package:flutter/material.dart';

import '../../core/components/app_banner.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/pod_operations_notifier.dart';
import '../../core/theme/app_tokens.dart';

/// Menu/button label for a pod action ("Pause pod", "Kill pod", ...).
String kubernetesPodActionLabel(
  AppLocalizations l10n,
  KubernetesPodAction action,
) => switch (action) {
  KubernetesPodAction.pause => l10n.sessionPodPause,
  KubernetesPodAction.resume => l10n.sessionPodResume,
  KubernetesPodAction.kill => l10n.sessionPodKill,
};

/// Progress label while a pod action syncs ("Pausing…", "Deleting…", ...).
String kubernetesPodPendingLabel(
  AppLocalizations l10n,
  KubernetesPodAction action,
) => switch (action) {
  KubernetesPodAction.pause => l10n.kubernetesPodPausing,
  KubernetesPodAction.resume => l10n.kubernetesPodResuming,
  KubernetesPodAction.kill => l10n.kubernetesPodDeleting,
};

/// Inline, persistent outcome of a failed pod operation, with Retry and
/// Dismiss. Stays until the user acts on it, unlike a snack bar.
class PodOperationFailureBanner extends StatelessWidget {
  const PodOperationFailureBanner({
    required this.operation,
    required this.onRetry,
    required this.onDismiss,
    super.key,
  });

  final PodOperation operation;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppBanner(
      key: Key('pod-operation-failed-${operation.key}'),
      tone: AppBadgeTone.danger,
      message: l10n.kubernetesActionFailed(
        kubernetesPodActionLabel(l10n, operation.action),
        operation.error ?? '',
      ),
      footer: Wrap(
        spacing: AppSpacing.sm,
        children: [
          TextButton(
            key: const Key('pod-operation-retry'),
            onPressed: onRetry,
            child: Text(l10n.commonRetry),
          ),
          TextButton(
            key: const Key('pod-operation-dismiss'),
            onPressed: onDismiss,
            child: Text(l10n.commonDismiss),
          ),
        ],
      ),
    );
  }
}
