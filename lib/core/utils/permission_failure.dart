import '../i18n/app_localizations.dart';

/// Whether a permission failure is the expected race where the session
/// resolved, expired or restarted before the decision arrived.
bool isExpectedPermissionRace(String error) =>
    error.contains('restarted') ||
    error.contains('expired') ||
    error.contains('no pending permission') ||
    error.contains('not available') ||
    error.contains('failed to resolve');

/// User-facing label for a failed permission decision.
String permissionFailureLabel(AppLocalizations l10n, String error) {
  if (error.contains('restarted') || error.contains('expired')) {
    return l10n.permissionExpiredRestarted;
  }
  if (error.contains('no pending permission') ||
      error.contains('not available') ||
      error.contains('failed to resolve')) {
    return l10n.permissionExpiredNoPending;
  }
  return l10n.permissionActionFailed;
}
