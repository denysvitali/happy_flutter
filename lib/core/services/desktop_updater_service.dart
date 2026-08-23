// Desktop (Linux) self-update engine.
//
// The release pipeline publishes `happy-flutter-linux-x64.tar.gz` as an
// asset on every GitHub Release (`v<semver>-<build>`). When the app runs
// from the managed install directory created by `scripts/install-linux.sh`
// (`$XDG_DATA_HOME/happy_flutter`), this service can:
//
// 1. Poll the GitHub API for the latest release and compare it against
//    the installed build (manifest.json, falling back to PackageInfo).
// 2. Download the tarball and extract it into a sibling staging dir.
// 3. Atomically swap staging <-> install dir so launchers, the
//    `~/.local/bin/happy_flutter` symlink and any running process stay
//    valid mid-update.
// 4. Restart into the new build on user request.
//
// Network and filesystem I/O are injectable so unit tests can drive the
// whole flow without touching GitHub or real install dirs. State is
// published through [onStateChanged]; `DesktopUpdaterNotifier` bridges it
// to Riverpod and the update banner UI.

import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        Directory,
        File,
        FileLock,
        FileMode,
        Platform,
        Process,
        ProcessStartMode,
        RandomAccessFile,
        exit;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/package_info_cache.dart';
import 'desktop_updater_models.dart';
import 'logger_service.dart';

Future<DesktopRemoteRelease?> fetchReleaseFromGitHub(Uri uri) async {
  final client = http.Client();
  try {
    final response = await client
        .get(
          uri,
          headers: const {
            'Accept': 'application/vnd.github+json',
            // GitHub API rejects requests without a user agent.
            'User-Agent': 'happy-flutter-updater',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;
    return DesktopRemoteRelease.fromJson(decoded);
  } finally {
    client.close();
  }
}

/// Streams [url] to [savePath], reporting 0-100 progress via [onProgress]
/// (null while the total size is unknown).
Future<void> downloadFileToPath(
  Uri url,
  String savePath,
  void Function(int?) onProgress,
) async {
  final client = http.Client();
  try {
    final request = http.Request('GET', url)
      ..followRedirects = true
      ..maxRedirects = 5;
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('download failed with HTTP ${response.statusCode}');
    }
    final totalBytes = response.contentLength;
    final sink = File(savePath).openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress(
          totalBytes != null && totalBytes > 0
              ? ((received / totalBytes) * 100).clamp(0, 99).toInt()
              : null,
        );
      }
      await sink.flush();
      onProgress(100);
    } finally {
      await sink.close();
    }
  } finally {
    client.close();
  }
}

/// Self-update engine. One instance per app run; state changes are pushed
/// through [onStateChanged].
class DesktopUpdaterService {
  DesktopUpdaterService({
    Future<DesktopRemoteRelease?> Function(Uri uri)? fetchLatestRelease,
    Future<void> Function(Uri url, String savePath, void Function(int?))?
    downloadFile,
    String? Function()? installDirResolver,
    this.checkInterval = defaultCheckInterval,
    this.initialCheckDelay = defaultInitialCheckDelay,
    this.autoDownload = true,
  }) : _fetchLatestRelease = fetchLatestRelease ?? fetchReleaseFromGitHub,
       _downloadFile = downloadFile ?? downloadFileToPath,
       _installDirResolver =
           installDirResolver ?? (() => resolveInstallDir().dir);

  /// App-wide engine wired to Riverpod via `DesktopUpdaterNotifier`.
  /// Tests construct fresh instances with injected I/O instead.
  static final DesktopUpdaterService shared = DesktopUpdaterService();

  /// Wire format shared with `scripts/update-linux.sh`.
  static const bundleAssetName = 'happy-flutter-linux-x64.tar.gz';
  static const manifestFileName = 'manifest.json';

  /// Set `HAPPY_FORCE_UPDATER=1` to enable the updater in debug builds that
  /// were not launched from the managed install dir.
  static const forceEnvVar = 'HAPPY_FORCE_UPDATER';

  static const defaultCheckInterval = Duration(hours: 6);
  static const defaultInitialCheckDelay = Duration(seconds: 20);

  final Future<DesktopRemoteRelease?> Function(Uri) _fetchLatestRelease;
  final Future<void> Function(Uri, String, void Function(int?)) _downloadFile;
  final String? Function() _installDirResolver;

  /// Called on every state transition. `DesktopUpdaterNotifier` assigns
  /// this to mirror engine state into Riverpod.
  void Function(DesktopUpdateState)? onStateChanged;

  /// How often to re-check for releases after the startup check.
  final Duration checkInterval;
  final Duration initialCheckDelay;

  /// Start downloading immediately when an update is found (no prompt).
  final bool autoDownload;

  DesktopUpdateState _state = const DesktopUpdateState();
  Timer? _periodicTimer;
  Timer? _startupTimer;
  bool _started = false;
  bool _disposed = false;
  bool _operationInFlight = false;

  DesktopUpdateState get state => _state;

  Uri get feedUri => Uri.parse(
    'https://api.github.com/repos/'
    '${AppConfig.githubOrg}/${AppConfig.githubRepo}/releases/latest',
  );

  /// Resolved install target plus whether it looks like a managed bundle
  /// (contains the launcher binary) and can be replaced in place.
  ({String dir, bool isManaged, bool writable}) get installLocation {
    final dir = _currentInstallDir();
    if (dir.isEmpty) {
      return (dir: '', isManaged: false, writable: false);
    }
    final d = Directory(dir);
    final isManaged =
        File('$dir/$manifestFileName').existsSync() ||
        _normalize(dir) == _normalize(managedDefaultDir());
    return (
      dir: dir,
      isManaged: isManaged,
      writable: d.existsSync() && canWrite(d),
    );
  }

  /// Arms the startup check plus periodic re-checks. Idempotent and a no-op
  /// on unsupported platforms.
  void start() {
    if (_started || _disposed || !autoStartAllowed) return;
    _started = true;
    logger.info(
      '[DesktopUpdater] started (interval=${checkInterval.inMinutes}m)',
    );
    _startupTimer = Timer(initialCheckDelay, () {
      unawaited(checkForUpdates());
    });
    _periodicTimer = Timer.periodic(checkInterval, (_) {
      unawaited(checkForUpdates());
    });
  }

  void dispose() {
    _disposed = true;
    _periodicTimer?.cancel();
    _startupTimer?.cancel();
  }

  void dismissBanner() {
    if (_state.status == DesktopUpdateStatus.available) {
      _update(_state.copyWith(dismissed: true));
    }
  }

  /// Queries the release feed and transitions to [DesktopUpdateStatus]
  /// `.available` (auto-download follows), `.upToDate` or an error state.
  Future<bool> checkForUpdates() async {
    if (_disposed || !isPlatformSupported || _operationInFlight) return false;
    _operationInFlight = true;
    _update(
      _state.copyWith(status: DesktopUpdateStatus.checking, clearError: true),
    );
    try {
      final release = await _fetchLatestRelease(feedUri);
      if (release == null || release.info.tag.isEmpty) {
        throw Exception('release feed unavailable');
      }
      final installed = await resolveInstalledInfo();
      final available = release.info > installed;
      logger.info(
        '[DesktopUpdater] latest=${release.info.tag} '
        'installed=${installed.version}+${installed.buildNumber} '
        'updateAvailable=$available',
      );
      _lastCheckedNow();
      if (!available) {
        _update(
          _state.copyWith(
            status: DesktopUpdateStatus.upToDate,
            dismissed: false,
          ),
        );
        return false;
      }
      _update(
        _state.copyWith(
          status: DesktopUpdateStatus.available,
          availableVersion: release.info.version,
          availableBuildNumber: release.info.buildNumber,
          dismissed: false,
        ),
      );
      if (autoDownload) {
        unawaited(_apply(release));
      }
      return true;
    } catch (error) {
      logger.warning('[DesktopUpdater] check failed: $error');
      _update(
        _state.copyWith(
          status: _state.status == DesktopUpdateStatus.checking
              ? DesktopUpdateStatus.idle
              : _state.status,
          error: '$error',
        ),
      );
      return false;
    } finally {
      _operationInFlight = false;
    }
  }

  /// Downloads the newest release and swaps it onto disk. Resolves true
  /// when the new version is ready and only a restart is left.
  Future<bool> applyUpdate() async {
    if (_operationInFlight) return false;
    _operationInFlight = true;
    try {
      final release = await _fetchLatestRelease(feedUri);
      if (release == null) throw Exception('release feed unavailable');
      return await _apply(release);
    } catch (error) {
      logger.error('[DesktopUpdater] apply failed: $error');
      _update(_state.copyWith(error: '$error'));
      return false;
    } finally {
      _operationInFlight = false;
    }
  }

  Future<bool> _apply(DesktopRemoteRelease release) async {
    final url = release.assetUrls[bundleAssetName];
    if (url == null) {
      throw Exception('release ${release.info.tag} lacks $bundleAssetName');
    }
    final location = installLocation;
    if (!location.isManaged || !location.writable) {
      logger.warning(
        '[DesktopUpdater] install dir not writable '
        '(dir=${location.dir} managed=${location.isManaged})',
      );
      _update(
        _state.copyWith(
          status: DesktopUpdateStatus.available,
          error: 'install directory is not writable',
        ),
      );
      return false;
    }

    // Same advisory lock `scripts/update-linux.sh` takes, so the systemd
    // timer and an in-app update never swap concurrently.
    if (!_acquireUpdateLock(location.dir)) {
      logger.info('[DesktopUpdater] skipped: another updater holds the lock');
      return false;
    }
    try {
      return await _applyLocked(release, location, url);
    } finally {
      _releaseUpdateLock();
    }
  }

  RandomAccessFile? _lockHandle;

  bool _acquireUpdateLock(String installDir) {
    final parent = Directory(installDir).parent.path;
    try {
      final handle = File(
        '$parent/.happy_flutter.update.lock',
      ).openSync(mode: FileMode.append);
      try {
        // Non-blocking: contention means another updater is mid-swap.
        handle.lockSync(FileLock.exclusive);
      } catch (_) {
        handle.closeSync();
        return false;
      }
      _lockHandle = handle;
      return true;
    } catch (error) {
      logger.warning('[DesktopUpdater] lock acquire failed: $error');
      return true; // Fail open: swapping is still safe in practice.
    }
  }

  void _releaseUpdateLock() {
    try {
      _lockHandle?.closeSync();
    } catch (_) {}
    _lockHandle = null;
  }

  Future<bool> _applyLocked(
    DesktopRemoteRelease release,
    ({String dir, bool isManaged, bool writable}) location,
    String url,
  ) async {
    final parent = Directory(location.dir).parent.path;
    final stagingPath =
        '$parent/.happy_flutter.update.'
        '${DateTime.now().millisecondsSinceEpoch}';
    final backupPath =
        '$parent/.happy_flutter.backup.'
        '${DateTime.now().millisecondsSinceEpoch}';
    try {
      _update(_state.copyWith(status: DesktopUpdateStatus.downloading));
      final staging = Directory(stagingPath)..createSync(recursive: true);
      final archivePath = '$stagingPath.tar.gz';
      await _downloadFile(Uri.parse(url), archivePath, (progress) {
        _update(_state.copyWith(downloadProgress: progress));
      });
      _extractArchive(archivePath, staging);
      File(archivePath).deleteSync();

      final binary = File('$stagingPath/happy_flutter');
      if (!binary.existsSync()) {
        throw Exception('bundle missing happy_flutter binary');
      }
      _makeExecutable(binary.path);
      for (final script in const ['install-linux.sh', 'update-linux.sh']) {
        final f = File('$stagingPath/$script');
        if (f.existsSync()) _makeExecutable(f.path);
      }
      _writeManifest(
        '$stagingPath/$manifestFileName',
        DesktopInstallManifest(
          version: release.info.version,
          buildNumber: release.info.buildNumber,
        ),
      );

      // Atomic-ish swap: rename old aside, move staging in, drop backup.
      final installDir = Directory(location.dir);
      var movedOld = false;
      try {
        installDir.renameSync(backupPath);
        movedOld = true;
        Directory(stagingPath).renameSync(location.dir);
      } catch (_) {
        if (movedOld && !Directory(location.dir).existsSync()) {
          Directory(backupPath).renameSync(location.dir);
        }
        rethrow;
      }
      _deleteRecursively(Directory(backupPath));

      logger.info('[DesktopUpdater] applied ${release.info.tag}');
      _update(
        _state.copyWith(
          status: DesktopUpdateStatus.readyToRestart,
          currentVersion: release.info.version,
          currentBuildNumber: release.info.buildNumber,
          downloadProgress: null,
          error: null,
        ),
      );
      return true;
    } catch (error) {
      logger.error('[DesktopUpdater] apply failed: $error');
      _deleteRecursively(Directory(stagingPath));
      _deleteRecursively(Directory(backupPath));
      _update(
        _state.copyWith(
          status: DesktopUpdateStatus.available,
          error: '$error',
          downloadProgress: null,
        ),
      );
      return false;
    }
  }

  /// Launches the freshly-installed binary detached and exits. Never call
  /// without a preceding successful [applyUpdate].
  void restartIntoUpdatedVersion() {
    if (_state.status != DesktopUpdateStatus.readyToRestart) return;
    final dir = _currentInstallDir();
    final binary = '$dir/happy_flutter';
    if (!File(binary).existsSync()) {
      logger.error('[DesktopUpdater] cannot restart, binary missing: $binary');
      return;
    }
    logger.info('[DesktopUpdater] restarting into $binary');
    try {
      unawaited(Process.run('chmod', ['+x', binary]));
      unawaited(
        Process.start(binary, [], mode: ProcessStartMode.detached).then((_) {
          exit(0);
        }),
      );
    } catch (error) {
      logger.error('[DesktopUpdater] restart failed: $error');
    }
  }

  // ── Internals ────────────────────────────────────────────────────────────

  String _currentInstallDir() {
    final resolved = _installDirResolver() ?? '';
    return resolved.isNotEmpty ? resolved : _exeDirectory() ?? '';
  }

  String? _exeDirectory() {
    try {
      return File(Platform.resolvedExecutable).parent.path;
    } catch (_) {
      return null;
    }
  }

  /// Installed version: manifest.json first, PackageInfo fallback.
  Future<DesktopReleaseInfo> resolveInstalledInfo() async {
    final manifest = readManifestFrom(_currentInstallDir());
    if (manifest != null &&
        (manifest.version.isNotEmpty || manifest.buildNumber > 0)) {
      return DesktopReleaseInfo(
        tag: 'v${manifest.version}-${manifest.buildNumber}',
        version: manifest.version,
        buildNumber: manifest.buildNumber,
      );
    }
    try {
      final info = await PackageInfoCache.get();
      final build = int.tryParse(info.buildNumber) ?? 0;
      return DesktopReleaseInfo(
        tag: 'v${info.version}+$build',
        version: info.version,
        buildNumber: build,
      );
    } catch (_) {
      return const DesktopReleaseInfo(
        tag: '',
        version: '0.0.0',
        buildNumber: 0,
      );
    }
  }

  static DesktopInstallManifest? readManifestFrom(String dir) {
    if (dir.isEmpty) return null;
    final file = File('$dir/$manifestFileName');
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) {
        return DesktopInstallManifest.fromJson(decoded);
      }
      if (decoded is Map) {
        return DesktopInstallManifest.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    } catch (error) {
      logger.warning('[DesktopUpdater] malformed manifest in $dir: $error');
    }
    return null;
  }

  void _extractArchive(String archivePath, Directory target) {
    final bytes = File(archivePath).readAsBytesSync();
    final tarBytes = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceFirst('./', '');
      if (name.isEmpty || name.contains('..')) continue;
      final outFile = File('${target.path}/$name');
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(entry.content as List<int>);
    }
  }

  void _makeExecutable(String path) {
    try {
      // dart:io exposes no chmod; shell out once per applied update.
      unawaited(Process.run('chmod', ['+x', path]));
    } catch (_) {}
  }

  void _writeManifest(String path, DesktopInstallManifest manifest) {
    File(path).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
  }

  void _deleteRecursively(Directory dir) {
    if (!dir.existsSync()) return;
    try {
      dir.deleteSync(recursive: true);
    } catch (error) {
      logger.warning('[DesktopUpdater] cleanup of ${dir.path}: $error');
    }
  }

  void _lastCheckedNow() {
    _update(
      _state.copyWith(lastCheckedAtMs: DateTime.now().millisecondsSinceEpoch),
    );
  }

  void _update(DesktopUpdateState next) {
    if (_disposed) return;
    _state = next;
    onStateChanged?.call(next);
  }

  /// Whether self-update applies on this platform at all (Linux today).
  static bool get isPlatformSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  /// Whether [start] may arm automatic checks. Debug builds launched via
  /// `flutter run` execute from the SDK build tree — replacing that would
  /// corrupt the dev workflow — unless [forceEnvVar] opts in. Manual
  /// "check now" still works in those sessions via [checkForUpdates].
  static bool get autoStartAllowed =>
      isPlatformSupported &&
      (!kDebugMode || Platform.environment[forceEnvVar] == '1');

  /// Mirrors `scripts/install-linux.sh`: managed when the executable lives
  /// inside the XDG data dir bundle, otherwise falls back to the default
  /// dir when it already holds a manifest (installer ran previously).
  static ({String dir, bool isManaged, bool writable}) resolveInstallDir() {
    final defaultDir = managedDefaultDir();
    String? exeDir;
    try {
      exeDir = File(Platform.resolvedExecutable).parent.path;
    } catch (_) {}
    final normalizedExe = _normalize(exeDir);
    final normalizedDefault = _normalize(defaultDir);
    if (normalizedExe != null && normalizedExe == normalizedDefault) {
      return (
        dir: defaultDir,
        isManaged: true,
        writable: canWrite(Directory(defaultDir)),
      );
    }
    final hasManifest =
        File('$defaultDir/$manifestFileName').existsSync() &&
        canWrite(Directory(defaultDir));
    if (hasManifest) return (dir: defaultDir, isManaged: true, writable: true);
    return (dir: defaultDir, isManaged: false, writable: false);
  }

  /// `$XDG_DATA_HOME/happy_flutter` — must stay identical to the installer.
  static String managedDefaultDir() {
    final xdg = Platform.environment['XDG_DATA_HOME'];
    final base = (xdg == null || xdg.isEmpty)
        ? '${Platform.environment['HOME'] ?? ''}/.local/share'
        : xdg;
    return '$base/happy_flutter';
  }

  static bool canWrite(Directory dir) {
    if (!dir.existsSync()) return false;
    final probe = File(
      '${dir.path}/.write_probe_${DateTime.now().millisecondsSinceEpoch}',
    );
    try {
      probe
        ..writeAsStringSync('')
        ..deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String? _normalize(String? path) {
    if (path == null || path.isEmpty) return null;
    var p = path;
    while (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}
