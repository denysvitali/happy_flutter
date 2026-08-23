/// Single source for the download-state strings shared by the voice
/// settings hub nav rows (`voice_settings_screen.dart`) and the two
/// manager screens (`offline_voices_screen.dart`,
/// `offline_stt_models_screen.dart`).
///
/// The helpers are pure: callers own the `BuildContext`, look up their
/// `AppLocalizations`, and pass the localized strings in via
/// [DownloadStatusStrings], so this file never imports l10n.
library;

/// The localized download-state strings, as resolved by a caller from
/// its `AppLocalizations`.
class DownloadStatusStrings {
  /// Creates the bundle of localized strings.
  const DownloadStatusStrings({
    required this.ready,
    required this.downloading,
    required this.failed,
    required this.notDownloaded,
    required this.failedRetrySuffix,
    required this.notDownloadedSuffix,
  });

  /// Download finished and usable ("ready").
  final String ready;

  /// Download in progress ("downloading…").
  final String downloading;

  /// Last download attempt failed ("download failed").
  final String failed;

  /// Never downloaded ("not downloaded").
  final String notDownloaded;

  /// Full row suffix for a failed state without error detail
  /// (" · download failed, tap retry").
  final String failedRetrySuffix;

  /// Full row suffix for the not-downloaded state
  /// (" · not downloaded").
  final String notDownloadedSuffix;
}

/// Human label for a download state, as used by the settings-hub nav
/// rows ("Piper Voice · ready", " · N installed").
///
/// [failed] wins over [downloading], which wins over [ready]; the
/// fallthrough is the not-downloaded state.
String downloadStatusLabel({
  required bool ready,
  required bool downloading,
  required bool failed,
  required DownloadStatusStrings strings,
}) {
  if (failed) return strings.failed;
  if (downloading) return strings.downloading;
  if (ready) return strings.ready;
  return strings.notDownloaded;
}

/// Suffix appended to a manager-row subtitle for the download state,
/// including its leading separator, or '' when [ready] (nothing to
/// append after the descriptive parts).
///
/// [failureDetail] replaces the generic failed copy with a short error
/// string; [downloadingLabel] replaces the generic "downloading…" with
/// live progress text. Exact shapes:
///
/// - failed without detail: `' · download failed, tap retry'`
/// - failed with detail:    `' · <failureDetail>'`
/// - downloading:           `' · <downloadingLabel>'`
/// - not downloaded:        `' · not downloaded'`
String downloadStatusSuffix({
  required bool ready,
  required bool downloading,
  required bool failed,
  required DownloadStatusStrings strings,
  String? failureDetail,
  String? downloadingLabel,
}) {
  if (failed) {
    final detail = failureDetail;
    if (detail != null && detail.isNotEmpty) {
      return ' · $detail';
    }
    return strings.failedRetrySuffix;
  }
  if (downloading) {
    return ' · ${downloadingLabel ?? strings.downloading}';
  }
  if (!ready) {
    return strings.notDownloadedSuffix;
  }
  return '';
}
