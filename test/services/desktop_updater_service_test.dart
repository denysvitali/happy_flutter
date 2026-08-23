import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:happy_flutter/core/services/desktop_updater_models.dart';
import 'package:happy_flutter/core/services/desktop_updater_service.dart';

void main() {
  group('DesktopReleaseInfo.parse', () {
    test('parses v-prefixed tag with numeric build', () {
      final info = DesktopReleaseInfo.parse('v1.2.3-4200');
      expect(info, isNotNull);
      expect(info!.version, '1.2.3');
      expect(info.buildNumber, 4200);
      expect(info.tag, 'v1.2.3-4200');
    });

    test('accepts capital V and bare semver', () {
      expect(DesktopReleaseInfo.parse('V1.0.0-7')!.buildNumber, 7);
      final bare = DesktopReleaseInfo.parse('2.3.4');
      expect(bare!.version, '2.3.4');
      expect(bare.buildNumber, 0);
    });

    test('non-numeric suffix falls back to build 0', () {
      expect(DesktopReleaseInfo.parse('v1.0.0-beta.1')!.buildNumber, 0);
    });

    test('rejects garbage and empty tags', () {
      expect(DesktopReleaseInfo.parse(''), isNull);
      expect(DesktopReleaseInfo.parse('not-a-version'), isNull);
    });
  });

  group('release comparison', () {
    test('newer build number wins when semver ties', () {
      // CI bumps only the build number between main commits.
      final current = DesktopReleaseInfo.parse('v1.0.0-100')!;
      final newer = DesktopReleaseInfo.parse('v1.0.0-200')!;
      expect(newer > current, isTrue);
      expect(current > newer, isFalse);
      expect(current > DesktopReleaseInfo.parse('v1.0.0-100')!, isFalse);
    });

    test('semver outranks build number', () {
      final current = DesktopReleaseInfo.parse('v1.0.0-99999')!;
      expect(DesktopReleaseInfo.parse('v1.1.0')! > current, isTrue);
      expect(DesktopReleaseInfo.parse('v1.0.9-99999')! > current, isFalse);
    });
  });

  group('DesktopInstallManifest', () {
    test('roundtrips through JSON', () {
      const manifest = DesktopInstallManifest(
        version: '1.2.3',
        buildNumber: 4200,
        channel: 'stable',
        installedAtMs: 12345,
      );
      final decoded = DesktopInstallManifest.fromJson(
        jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.version, '1.2.3');
      expect(decoded.buildNumber, 4200);
      expect(decoded.installedAtMs, 12345);
      expect(decoded, manifest);
    });

    test('tolerates string buildNumber and missing fields', () {
      final manifest = DesktopInstallManifest.fromJson(const {
        'version': '9.9.9',
        'buildNumber': '123',
      });
      expect(manifest.buildNumber, 123);
      expect(manifest.channel, 'stable');
      expect(manifest.name, 'happy_flutter');
    });
  });

  group('DesktopRemoteRelease.fromJson', () {
    test('indexes assets by name', () {
      final release = DesktopRemoteRelease.fromJson(const {
        'tag_name': 'v1.0.0-200',
        'assets': [
          {
            'name': 'happy-flutter-linux-x64.tar.gz',
            'browser_download_url':
                'https://example.com/happy-flutter-linux-x64.tar.gz',
          },
          {'name': 'ignored.zip'},
        ],
      });
      expect(release.info.buildNumber, 200);
      expect(
        release.assetUrls['happy-flutter-linux-x64.tar.gz'],
        'https://example.com/happy-flutter-linux-x64.tar.gz',
      );
      expect(release.assetUrls.containsKey('ignored.zip'), isFalse);
    });
  });

  group('service flow', () {
    late Directory parent;
    late Directory installDir;
    late List<DesktopUpdateState> states;
    late DesktopUpdaterService service;

    // Builds a valid bundle archive with a marker script so tests can
    // verify the swap replaced the old payload.
    String makeBundleArchive({String marker = 'new', int? buildNumber = 300}) {
      final archive = Archive()
        ..addFile(
          ArchiveFile.bytes(
            'happy_flutter',
            utf8.encode('#!/bin/sh\necho $marker'),
          ),
        )
        ..addFile(
          ArchiveFile.bytes('install-linux.sh', utf8.encode('#!/bin/sh\ntrue')),
        );
      if (buildNumber != null) {
        archive.addFile(
          ArchiveFile.bytes(
            'manifest.json',
            utf8.encode(
              jsonEncode({
                'name': 'happy_flutter',
                'version': '1.0.0',
                'buildNumber': buildNumber,
                'channel': 'stable',
              }),
            ),
          ),
        );
      }
      final gzPath =
          '${parent.path}/bundle-${DateTime.now().microsecondsSinceEpoch}.tar.gz';
      File(
        gzPath,
      ).writeAsBytesSync(GZipEncoder().encode(TarEncoder().encode(archive)));
      return gzPath;
    }

    setUp(() {
      parent = Directory.systemTemp.createTempSync('desktop_updater_test');
      installDir = Directory('${parent.path}/happy_flutter')..createSync();
      File(
        '${installDir.path}/happy_flutter',
      ).writeAsStringSync('#!/bin/sh\necho old');
      File('${installDir.path}/manifest.json').writeAsStringSync(
        jsonEncode({
          'name': 'happy_flutter',
          'version': '1.0.0',
          'buildNumber': 100,
          'channel': 'stable',
        }),
      );
      states = [];
      service = DesktopUpdaterService(
        fetchLatestRelease: (_) async => throw UnimplementedError(),
        downloadFile: (_, _, _) async {},
        installDirResolver: () => installDir.path,
        autoDownload: false,
      )..onStateChanged = states.add;
    });

    tearDown(() {
      parent.deleteSync(recursive: true);
    });

    test('checkForUpdates flags newer release', () async {
      final newer = DesktopRemoteRelease(
        info: DesktopReleaseInfo.parse('v1.0.0-300')!,
        assetUrls: const {
          'happy-flutter-linux-x64.tar.gz': 'https://example.com/bundle.tgz',
        },
      );
      final svc = DesktopUpdaterService(
        fetchLatestRelease: (_) async => newer,
        downloadFile: (_, _, _) async {},
        installDirResolver: () => installDir.path,
        autoDownload: false,
      )..onStateChanged = states.add;

      final available = await svc.checkForUpdates();

      expect(available, isTrue);
      expect(svc.state.status, DesktopUpdateStatus.available);
      expect(svc.state.availableVersion, '1.0.0');
      expect(svc.state.availableBuildNumber, 300);
      expect(svc.state.lastCheckedAtMs, isNotNull);
    });

    test('checkForUpdates reports upToDate for equal builds', () async {
      final same = DesktopRemoteRelease(
        info: DesktopReleaseInfo.parse('v1.0.0-100')!,
        assetUrls: const {},
      );
      final svc = DesktopUpdaterService(
        fetchLatestRelease: (_) async => same,
        downloadFile: (_, _, _) async {},
        installDirResolver: () => installDir.path,
        autoDownload: false,
      )..onStateChanged = states.add;

      final available = await svc.checkForUpdates();

      expect(available, isFalse);
      expect(svc.state.status, DesktopUpdateStatus.upToDate);
    });

    test('check failure surfaces error state', () async {
      final svc = DesktopUpdaterService(
        fetchLatestRelease: (_) async => throw Exception('offline'),
        downloadFile: (_, _, _) async {},
        installDirResolver: () => installDir.path,
        autoDownload: false,
      )..onStateChanged = states.add;

      final available = await svc.checkForUpdates();

      expect(available, isFalse);
      expect(svc.state.error, contains('offline'));
    });

    test('applyUpdate swaps the bundle atomically', () async {
      final archivePath = makeBundleArchive();
      final release = DesktopRemoteRelease(
        info: DesktopReleaseInfo.parse('v1.0.0-300')!,
        assetUrls: const {'happy-flutter-linux-x64.tar.gz': 'unused://x'},
      );
      final svc = DesktopUpdaterService(
        fetchLatestRelease: (_) async => release,
        downloadFile: (_, savePath, _) async {
          // Mirror the real downloader: place the archive bytes at savePath.
          File(savePath).writeAsBytesSync(File(archivePath).readAsBytesSync());
        },
        installDirResolver: () => installDir.path,
      )..onStateChanged = states.add;

      final applied = await svc.applyUpdate();

      expect(applied, isTrue);
      expect(svc.state.status, DesktopUpdateStatus.readyToRestart);
      // New binary landed.
      expect(
        File('${installDir.path}/happy_flutter').readAsStringSync(),
        contains('echo new'),
      );
      // Manifest refreshed by the engine (not just the archive copy).
      final manifest =
          jsonDecode(
                File('${installDir.path}/manifest.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(manifest['buildNumber'], 300);
      // No staging/backup leftovers next to the install dir.
      expect(
        parent.listSync().whereType<Directory>().map((d) => d.path),
        everyElement(installDir.path),
      );
      // State walked through downloading before readyToRestart.
      expect(
        states.map((s) => s.status),
        containsAllInOrder([
          DesktopUpdateStatus.downloading,
          DesktopUpdateStatus.readyToRestart,
        ]),
      );
    });

    test('applyUpdate keeps old install on corrupt archive', () async {
      final release = DesktopRemoteRelease(
        info: DesktopReleaseInfo.parse('v1.0.0-300')!,
        assetUrls: const {'happy-flutter-linux-x64.tar.gz': 'unused://x'},
      );
      final svc = DesktopUpdaterService(
        fetchLatestRelease: (_) async => release,
        downloadFile: (_, savePath, _) async {
          File(savePath).writeAsStringSync('this is not gzip');
        },
        installDirResolver: () => installDir.path,
      )..onStateChanged = states.add;

      final applied = await svc.applyUpdate();

      expect(applied, isFalse);
      expect(svc.state.error, isNotNull);
      // Old binary + manifest untouched.
      expect(
        File('${installDir.path}/happy_flutter').readAsStringSync(),
        contains('echo old'),
      );
      expect(
        Directory(installDir.path).existsSync(),
        isTrue,
        reason: 'install dir must be restored after failed swap',
      );
    });

    test('applyUpdate fails cleanly when asset missing', () async {
      final release = DesktopRemoteRelease(
        info: DesktopReleaseInfo.parse('v1.0.0-300')!,
        assetUrls: const {},
      );
      final svc = DesktopUpdaterService(
        fetchLatestRelease: (_) async => release,
        downloadFile: (_, _, _) async {},
        installDirResolver: () => installDir.path,
      )..onStateChanged = states.add;

      final applied = await svc.applyUpdate();

      expect(applied, isFalse);
      expect(svc.state.error, isNotNull);
    });

    test('restartIntoUpdatedVersion ignores non-ready state', () {
      // Must not spawn anything or throw outside readyToRestart.
      service.restartIntoUpdatedVersion();
      expect(service.state.status, DesktopUpdateStatus.idle);
    });
  });
}
