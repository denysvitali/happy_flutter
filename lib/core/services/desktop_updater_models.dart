// Value types for the desktop (Linux) self-updater.
//
// Consumed by the engine in `desktop_updater_service.dart`, the Riverpod
// bridge (`DesktopUpdaterNotifier`) and the update banner UI. Kept separate
// from the engine so UI and tests can import them without pulling in
// network/disk machinery.

import '../utils/version_utils.dart';

/// Lifecycle of the desktop updater.
enum DesktopUpdateStatus {
  /// No check has completed yet (or the updater is unsupported).
  idle,

  /// A release check is in flight.
  checking,

  /// The installed build matches the newest release.
  upToDate,

  /// A newer release exists and can be downloaded.
  available,

  /// Download / extraction / swap in progress.
  downloading,

  /// New version applied to disk; restart pending (user-initiated).
  readyToRestart,
}

/// Immutable snapshot of the updater state consumed by Riverpod + banner UI.
class DesktopUpdateState {
  const DesktopUpdateState({
    this.status = DesktopUpdateStatus.idle,
    this.currentVersion,
    this.currentBuildNumber,
    this.availableVersion,
    this.availableBuildNumber,
    this.downloadProgress,
    this.error,
    this.lastCheckedAtMs,
    this.dismissed = false,
  });

  final DesktopUpdateStatus status;
  final String? currentVersion;
  final int? currentBuildNumber;
  final String? availableVersion;
  final int? availableBuildNumber;

  /// 0-100 while downloading; null when indeterminate.
  final int? downloadProgress;

  /// Failure detail of the last check/apply operation.
  final String? error;
  final int? lastCheckedAtMs;

  /// User pressed "later"; suppressed until the status changes again.
  final bool dismissed;

  bool get isBusy =>
      status == DesktopUpdateStatus.checking ||
      status == DesktopUpdateStatus.downloading;

  DesktopUpdateState copyWith({
    DesktopUpdateStatus? status,
    String? currentVersion,
    int? currentBuildNumber,
    String? availableVersion,
    int? availableBuildNumber,
    int? downloadProgress,
    bool clearDownloadProgress = false,
    String? error,
    bool clearError = false,
    int? lastCheckedAtMs,
    bool? dismissed,
  }) {
    return DesktopUpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuildNumber: currentBuildNumber ?? this.currentBuildNumber,
      availableVersion: availableVersion ?? this.availableVersion,
      availableBuildNumber: availableBuildNumber ?? this.availableBuildNumber,
      downloadProgress: clearDownloadProgress
          ? null
          : (downloadProgress ?? this.downloadProgress),
      error: clearError ? null : (error ?? this.error),
      lastCheckedAtMs: lastCheckedAtMs ?? this.lastCheckedAtMs,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// Metadata stamped into every shipped bundle as `manifest.json`.
///
/// Written by CI at archive time, refreshed by `install-linux.sh` and by the
/// updater after each applied update. It is the authoritative version source
/// on Linux because `flutter build linux` does not receive `--build-number`
/// (unlike Android).
class DesktopInstallManifest {
  const DesktopInstallManifest({
    required this.version,
    required this.buildNumber,
    this.name = 'happy_flutter',
    this.channel = 'stable',
    this.installedAtMs,
  });

  factory DesktopInstallManifest.fromJson(Map<String, dynamic> json) {
    return DesktopInstallManifest(
      version: json['version'] as String? ?? '',
      buildNumber: _asInt(json['buildNumber']),
      name: json['name'] as String? ?? 'happy_flutter',
      channel: json['channel'] as String? ?? 'stable',
      installedAtMs: json['installedAtMs'] is int
          ? json['installedAtMs'] as int
          : null,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  final String name;
  final String version;
  final int buildNumber;
  final String channel;
  final int? installedAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'version': version,
    'buildNumber': buildNumber,
    'channel': channel,
    if (installedAtMs != null) 'installedAtMs': installedAtMs,
  };

  @override
  bool operator ==(Object other) =>
      other is DesktopInstallManifest &&
      other.version == version &&
      other.buildNumber == buildNumber &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(version, buildNumber, channel);
}

/// Parsed `v<semver>-<build>` release tag.
class DesktopReleaseInfo {
  const DesktopReleaseInfo({
    required this.tag,
    required this.version,
    required this.buildNumber,
  });

  /// Accepts `v1.2.3-4200`, `V1.2.3-4200`, plain `1.2.3` (build defaults 0).
  static DesktopReleaseInfo? parse(String raw) {
    var tag = raw.trim();
    if (tag.isEmpty) return null;
    if (tag.startsWith('v') || tag.startsWith('V')) {
      tag = tag.substring(1);
    }
    var semver = tag;
    var build = 0;
    final dash = tag.indexOf('-');
    if (dash >= 0) {
      semver = tag.substring(0, dash);
      final suffix = tag.substring(dash + 1);
      // Only treat the suffix as a build number when fully numeric;
      // pre-release labels like `-beta.1` compare on semver alone.
      build = int.tryParse(suffix) ?? 0;
    }
    if (parseVersion(semver) == null) return null;
    return DesktopReleaseInfo(
      tag: raw.trim(),
      version: semver,
      buildNumber: build,
    );
  }

  final String tag;
  final String version;
  final int buildNumber;

  /// Semver first, numeric build suffix as tiebreak — CI bumps the build
  /// number on every commit while the semver part often stays put.
  int compareTo(DesktopReleaseInfo other) {
    final bySemver = compareVersions(version, other.version);
    if (bySemver != 0) return bySemver;
    return buildNumber.compareTo(other.buildNumber);
  }

  bool operator >(DesktopReleaseInfo other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is DesktopReleaseInfo && other.tag == tag;

  @override
  int get hashCode => tag.hashCode;
}

/// Subset of the GitHub releases API response the updater consumes.
class DesktopRemoteRelease {
  const DesktopRemoteRelease({required this.info, required this.assetUrls});

  factory DesktopRemoteRelease.fromJson(Map<String, dynamic> json) {
    final info =
        DesktopReleaseInfo.parse(json['tag_name'] as String? ?? '') ??
        const DesktopReleaseInfo(tag: '', version: '0.0.0', buildNumber: 0);
    final assets = <String, String>{};
    final rawAssets = json['assets'];
    if (rawAssets is List) {
      for (final asset in rawAssets) {
        if (asset is! Map) continue;
        final assetName = asset['name'];
        final url = asset['browser_download_url'];
        if (assetName is String && url is String) {
          assets[assetName] = url;
        }
      }
    }
    return DesktopRemoteRelease(
      info: info,
      assetUrls: Map<String, String>.unmodifiable(assets),
    );
  }

  final DesktopReleaseInfo info;

  /// Asset name -> browser_download_url.
  final Map<String, String> assetUrls;
}
