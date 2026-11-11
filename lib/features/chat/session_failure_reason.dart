import '../../core/i18n/app_localizations.dart';

/// Why a session's agent stopped, from the bounded vocabulary the chat may
/// show next to its recovery copy.
///
/// The daemon's own sentence (`lifecycleStateError`, a pod's container
/// message) can carry hostnames and paths, so banners show only the
/// classified [SessionFailureKind]; [sessionFailureDetail] keeps the original
/// for the surfaces that already print raw pod output and for Copy.
enum SessionFailureKind {
  /// Two pods ran for one conversation and the newer one could not take the
  /// message outbox over from the older one.
  duplicatePod,
  branchNotFound,
  repositoryAccess,
  checkoutFailed,
  imagePull,
  imageMissingAgent,
  outOfMemory,
  unschedulable,
  startTimeout,
  podGone,
  agentExited,
}

/// Classifies a daemon failure sentence, or null when it carries no cause the
/// app recognizes.
SessionFailureKind? classifySessionFailure(String? rawError) {
  final raw = rawError?.trim().toLowerCase() ?? '';
  if (raw.isEmpty) return null;
  bool has(String needle) => raw.contains(needle);
  if (has('message outbox is already in use')) {
    return SessionFailureKind.duplicatePod;
  }
  if (has("couldn't find remote ref") ||
      has('remote branch') && has('not found') ||
      has('does not exist in') && has('branch')) {
    return SessionFailureKind.branchNotFound;
  }
  if (has('authentication failed') ||
      has('could not read username') ||
      has('repository not found') ||
      has('the requested url returned error: 40')) {
    return SessionFailureKind.repositoryAccess;
  }
  if (has('imagepullbackoff') ||
      has('errimagepull') ||
      has('invalidimagename') ||
      has('errimageneverpull')) {
    return SessionFailureKind.imagePull;
  }
  if (has('is missing from kubernetes session image') ||
      has('is missing from the happy runtime image')) {
    return SessionFailureKind.imageMissingAgent;
  }
  if (has('oomkilled')) return SessionFailureKind.outOfMemory;
  if (has('unschedulable') || has('insufficient ')) {
    return SessionFailureKind.unschedulable;
  }
  if (has('made no startup progress') || has('did not start within')) {
    return SessionFailureKind.startTimeout;
  }
  if (has('pod no longer exists') || has('evicted')) {
    return SessionFailureKind.podGone;
  }
  // The daemon leads a container failure with the container's name.
  if (RegExp(r'(^|[\s:])checkout: ').hasMatch(raw)) {
    return SessionFailureKind.checkoutFailed;
  }
  if (has('exit code') || has('exit status') || has('signal: ')) {
    return SessionFailureKind.agentExited;
  }
  return null;
}

/// One localized sentence for [kind].
String sessionFailureReasonText(
  AppLocalizations l10n,
  SessionFailureKind kind,
) => switch (kind) {
  SessionFailureKind.duplicatePod => l10n.sessionFailureDuplicatePod,
  SessionFailureKind.branchNotFound => l10n.sessionFailureBranchNotFound,
  SessionFailureKind.repositoryAccess => l10n.sessionFailureRepositoryAccess,
  SessionFailureKind.checkoutFailed => l10n.sessionFailureCheckout,
  SessionFailureKind.imagePull => l10n.sessionFailureImagePull,
  SessionFailureKind.imageMissingAgent => l10n.sessionFailureImageMissingAgent,
  SessionFailureKind.outOfMemory => l10n.sessionFailureOutOfMemory,
  SessionFailureKind.unschedulable => l10n.sessionFailureUnschedulable,
  SessionFailureKind.startTimeout => l10n.sessionFailureStartTimeout,
  SessionFailureKind.podGone => l10n.sessionFailurePodGone,
  SessionFailureKind.agentExited => l10n.sessionFailureAgentExited,
};

/// The daemon's sentence without its boilerplate lead-in
/// (`kubernetes pod <name> failed to start: `), or null when empty.
String? sessionFailureDetail(String? rawError) {
  var raw = rawError?.trim() ?? '';
  if (raw.isEmpty) return null;
  final lead = RegExp(
    r'^kubernetes pod \S+ (failed to start|made no startup progress[^:]*|did not start within[^:]*):\s*',
    caseSensitive: false,
  ).firstMatch(raw);
  if (lead != null && lead.group(1)!.toLowerCase() == 'failed to start') {
    raw = raw.substring(lead.end).trim();
  }
  return raw.isEmpty ? null : raw;
}
