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

  /// The previous pod of this conversation did not terminate in time, so
  /// its replacement was never created.
  stopTimeout,
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
  if (has('confirm pod') && has('stopped') && has('deadline exceeded')) {
    return SessionFailureKind.stopTimeout;
  }
  if (has('made no startup progress') || has('did not start within')) {
    return SessionFailureKind.startTimeout;
  }
  if (has('pod no longer exists') ||
      has('was deleted while starting') ||
      has('evicted')) {
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
  SessionFailureKind.stopTimeout => l10n.sessionFailureStopTimeout,
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

/// A failure sentence split into its cause and the daemon's diagnostic facts.
///
/// The daemon appends `[phase Pending; node n; init: a running 1m29s, ...]`
/// to a start failure: where the pod was stuck, which step, which events.
/// [summary] is everything before it; [facts] are its `;`-separated parts.
typedef SessionFailureParts = ({String summary, List<String> facts});

SessionFailureParts splitSessionFailureDiagnosis(String detail) {
  final text = detail.trim();
  final open = text.indexOf(' [');
  if (open < 0 || !text.endsWith(']')) {
    return (summary: text, facts: const []);
  }
  final facts = text
      .substring(open + 2, text.length - 1)
      .split(';')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  return (summary: text.substring(0, open).trim(), facts: facts);
}
