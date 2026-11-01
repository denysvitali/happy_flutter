import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'logger_service.dart' show logger;

/// Where the sherpa-onnx native libraries for this process live.
///
/// [dir] is null when the libraries ship inside the app (desktop, iOS,
/// debug APKs); otherwise it is the private directory holding the
/// on-demand Android download. Plain data so it crosses isolates.
class SherpaRuntimeLibs {
  const SherpaRuntimeLibs(this.dir);

  final String? dir;
}

/// Bind sherpa-onnx's FFI symbols in the current isolate.
///
/// Bindings are isolate-local, so every worker calls this first.
void bindSherpaRuntime(SherpaRuntimeLibs libs) {
  final dir = libs.dir;
  if (dir != null) {
    // Load the dependency by absolute path first so the C API's
    // DT_NEEDED entry resolves to the already-loaded soname.
    DynamicLibrary.open(p.join(dir, SherpaRuntime.onnxRuntimeLibrary));
  }
  sherpa.initBindings(dir);
}

/// On-demand sherpa-onnx runtime for release APKs.
///
/// onnxruntime and the sherpa C API are ~30MB of native code (~11MB of
/// the APK) used only by offline voice features, so release builds
/// exclude them (`android/app/build.gradle.kts`) and download the exact
/// pub.dev archive the Dart bindings were built against on first use.
/// The archive is pinned by SHA-256 and installed atomically.
abstract final class SherpaRuntime {
  /// Must match the resolved `sherpa_onnx` version in `pubspec.lock`.
  static const version = '1.13.3';
  static const archiveUrl =
      'https://pub.dev/api/archives/'
      'sherpa_onnx_android_arm64-$version.tar.gz';
  static const archiveSha256 =
      '4f51639037b0dd951a0e1af4632038e03ac9ffa226a5b92c6d8fdc495ce8a491';
  static const approximateBytes = 11984809;
  static const onnxRuntimeLibrary = 'libonnxruntime.so';
  static const cApiLibrary = 'libsherpa-onnx-c-api.so';
  static const libraries = <String>[onnxRuntimeLibrary, cApiLibrary];
  static const _archiveLibDir = 'android/src/main/jniLibs/arm64-v8a/';

  static Future<SherpaRuntimeLibs>? _installing;

  /// The usable runtime, or null when it still has to be downloaded.
  static Future<SherpaRuntimeLibs?> find() async {
    if (!Platform.isAndroid || _isBundled()) {
      return const SherpaRuntimeLibs(null);
    }
    final dir = await _installDir();
    final complete = libraries.every(
      (name) => File(p.join(dir.path, name)).existsSync(),
    );
    return complete ? SherpaRuntimeLibs(dir.path) : null;
  }

  /// The usable runtime, downloading it first when necessary.
  ///
  /// Concurrent callers share one download. [onProgress] receives
  /// received bytes and the total when known.
  static Future<SherpaRuntimeLibs> ensure({
    void Function(int received, int? total)? onProgress,
  }) async {
    final found = await find();
    if (found != null) return found;
    final running = _installing;
    if (running != null) return running;
    final future = _install(onProgress);
    _installing = future;
    try {
      return await future;
    } finally {
      _installing = null;
    }
  }

  static bool? _bundled;

  /// Debug APKs keep the plugin's libraries for every ABI.
  static bool _isBundled() {
    final cached = _bundled;
    if (cached != null) return cached;
    try {
      DynamicLibrary.open(cApiLibrary);
      return _bundled = true;
    } on ArgumentError {
      return _bundled = false;
    }
  }

  static Future<Directory> _installDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'speech', 'runtime', version));
  }

  static Future<SherpaRuntimeLibs> _install(
    void Function(int received, int? total)? onProgress,
  ) async {
    if (Abi.current() != Abi.androidArm64) {
      throw UnsupportedError(
        'Offline speech runtime is only published for arm64 Android',
      );
    }
    final dir = await _installDir();
    final temp = await getTemporaryDirectory();
    final archive = File(p.join(temp.path, 'sherpa_runtime_$version.tgz'));
    final staging = Directory('${dir.path}.partial');
    try {
      await _download(archive, onProgress);
      if (staging.existsSync()) await staging.delete(recursive: true);
      await staging.create(recursive: true);
      final archivePath = archive.path;
      final stagingPath = staging.path;
      await Isolate.run(() => _verifyAndExtract(archivePath, stagingPath));
      if (dir.existsSync()) await dir.delete(recursive: true);
      await staging.rename(dir.path);
      logger.info('[SherpaRuntime] installed $version at ${dir.path}');
      return SherpaRuntimeLibs(dir.path);
    } finally {
      if (archive.existsSync()) await archive.delete();
      if (staging.existsSync()) {
        try {
          await staging.delete(recursive: true);
        } catch (_) {
          // best effort
        }
      }
    }
  }

  static Future<void> _download(
    File target,
    void Function(int received, int? total)? onProgress,
  ) async {
    logger.info('[SherpaRuntime] download: GET $archiveUrl');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 5)
      ..userAgent = 'happy_flutter/sherpa-runtime';
    try {
      final request = await client.getUrl(Uri.parse(archiveUrl))
        // pub.dev redirects archive downloads to its storage bucket.
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Speech runtime download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(archiveUrl),
        );
      }
      final total = response.contentLength > 0
          ? response.contentLength
          : approximateBytes;
      var received = 0;
      final sink = target.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close(force: true);
    }
  }
}

Future<void> _verifyAndExtract(String archivePath, String outDir) async {
  final digest = await sha256.bind(File(archivePath).openRead()).single;
  if (digest.toString() != SherpaRuntime.archiveSha256) {
    throw StateError(
      'Speech runtime checksum mismatch (got ${digest.toString()})',
    );
  }
  final tarPath = p.join(outDir, 'runtime.tar');
  await File(
    archivePath,
  ).openRead().transform(gzip.decoder).pipe(File(tarPath).openWrite());
  final input = InputFileStream(tarPath);
  try {
    final wanted = SherpaRuntime.libraries.toSet();
    final extracted = <String>{};
    for (final entry in TarDecoder().decodeStream(input).files) {
      if (!entry.isFile ||
          !entry.name.startsWith(SherpaRuntime._archiveLibDir)) {
        continue;
      }
      final name = p.basename(entry.name);
      if (!wanted.contains(name)) continue;
      final out = OutputFileStream(p.join(outDir, name));
      try {
        entry.writeContent(out);
      } finally {
        await out.close();
      }
      extracted.add(name);
    }
    final missing = wanted.difference(extracted);
    if (missing.isNotEmpty) {
      throw StateError('Speech runtime archive lacks ${missing.join(', ')}');
    }
  } finally {
    await input.close();
    await File(tarPath).delete();
  }
}
