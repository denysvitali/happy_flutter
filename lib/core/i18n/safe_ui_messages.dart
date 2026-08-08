import 'app_localizations.dart';

/// User-safe failure categories for surfaces that also log technical detail.
///
/// Exceptions and daemon-provided prose can contain hostnames, paths, tokens,
/// or implementation details. Keep those values in diagnostics only and map
/// every user-visible failure through this bounded localized vocabulary.
enum SafeUiFailure {
  chatSend,
  chatClear,
  workflowLoad,
  workflowRun,
  workflowAgent,
}

String safeUiFailureMessage(AppLocalizations l10n, SafeUiFailure failure) =>
    switch (failure) {
      SafeUiFailure.chatSend => l10n.chatFailedToSend,
      SafeUiFailure.chatClear => l10n.chatClearFailedSafe,
      SafeUiFailure.workflowLoad => l10n.workflowLoadFailedSafe,
      SafeUiFailure.workflowRun => l10n.workflowRunFailedSafe,
      SafeUiFailure.workflowAgent => l10n.workflowAgentFailedSafe,
    };

typedef SafeLifecycleIssueCopy = ({
  String title,
  String message,
  String blockedMessage,
});

SafeLifecycleIssueCopy safeLifecycleIssueCopy(AppLocalizations l10n) => (
  title: l10n.chatLifecycleFailedTitle,
  message: l10n.chatLifecycleRecoverableMessage,
  blockedMessage: l10n.chatLifecycleBlockedMessage,
);
