import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'logger_service.dart' show logger;

/// Identifies a sherpa-onnx TTS voice model.
///
/// The default ([piperEnUsAmyLow]) is a small (~30MB) English VITS
/// voice from rhasspy/piper. Adding new voices is a matter of
/// recording the archive URL, expected SHA-256, and the relative
/// paths of the model files inside the archive.
class OfflineTtsModel {
  const OfflineTtsModel({
    required this.id,
    required this.archiveUrl,
    required this.archiveSha256,
    required this.archiveRoot,
    required this.modelRelPath,
    required this.tokensRelPath,
    required this.dataDirRelPath,
    this.expectedSampleRate = 22050,
  });

  /// Stable identifier used for the local cache directory. Bumping
  /// this when changing the file layout safely invalidates old
  /// downloads.
  final String id;
  final String archiveUrl;
  final String archiveSha256;

  /// The folder name at the root of the .tar.bz2 archive.
  final String archiveRoot;

  /// Path of the .onnx file relative to [archiveRoot].
  final String modelRelPath;

  /// Path of tokens.txt relative to [archiveRoot].
  final String tokensRelPath;

  /// Path of the espeak-ng-data folder (or empty for non-Piper
  /// models) relative to [archiveRoot].
  final String dataDirRelPath;

  /// Hint used to size playback buffers. The actual sample rate is
  /// taken from the engine's [sherpa.GeneratedAudio.sampleRate].
  final int expectedSampleRate;

  static const piperEnUsAmyLow = OfflineTtsModel(
    id: 'vits-piper-en_US-amy-low-v1',
    archiveUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
        'tts-models/vits-piper-en_US-amy-low.tar.bz2',
    // sha256 of the upstream archive published by k2-fsa. If GitHub
    // ever republishes the asset, this will need to be refreshed.
    archiveSha256:
        'c70f5284a09a7fd4ed203b39b2ff51cac1432b422b852eb647b481dade3cf639',
    archiveRoot: 'vits-piper-en_US-amy-low',
    modelRelPath: 'en_US-amy-low.onnx',
    tokensRelPath: 'tokens.txt',
    dataDirRelPath: 'espeak-ng-data',
  );
}

class OfflineTtsException implements Exception {
  const OfflineTtsException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum OfflineTtsStatus {
  /// No model present; nothing has been attempted.
  notDownloaded,

  /// The model is currently being downloaded/extracted.
  downloading,

  /// Files are present on disk and ready for use.
  ready,

  /// Download or extraction failed. [OfflineTtsService.lastError] has
  /// the cause.
  failed,
}

/// Sherpa-onnx-backed offline text-to-speech service.
///
/// Mirrors [OfflineDictationService] in spirit: an opt-in heavyweight
/// engine guarded behind a one-time model download. The first call
/// to [ensureReady] kicks off the archive download; subsequent calls
/// are no-ops once the files are on disk.
///
/// All sherpa interaction happens on a background isolate so the UI
/// thread stays responsive. Generated WAV files are persisted to the
/// app cache and played through [AudioPlayer]; [currentToken] tracks
/// what's playing so the chat playback bar can react.
class OfflineTtsService {
  factory OfflineTtsService() => _instance;
  OfflineTtsService._();
  static final OfflineTtsService _instance = OfflineTtsService._();

  final OfflineTtsModel _model = OfflineTtsModel.piperEnUsAmyLow;

  final ValueNotifier<OfflineTtsStatus> _status =
      ValueNotifier<OfflineTtsStatus>(OfflineTtsStatus.notDownloaded);
  final ValueNotifier<String?> _currentToken = ValueNotifier<String?>(null);
  Object? _lastError;

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  Future<_ResolvedModelFiles>? _filesFuture;
  int _generationGen = 0;

  /// Listenable for the currently-playing token (caller-supplied id,
  /// usually a message id).
  ValueListenable<String?> get currentToken => _currentToken;

  /// Listenable for the model availability status.
  ValueListenable<OfflineTtsStatus> get status => _status;

  Object? get lastError => _lastError;

  bool get isSpeaking => _currentToken.value != null;

  /// Whether the offline engine is usable on this platform.
  bool get isSupported => !kIsWeb;

  /// Trigger a download/extract if needed. Safe to call repeatedly;
  /// concurrent callers share the same future.
  Future<void> ensureReady() async {
    if (!isSupported) {
      throw const OfflineTtsException(
        'Offline TTS is not supported on this platform',
      );
    }
    await _ensureFilesOnce();
  }

  /// Generate speech for [text] and play it.
  ///
  /// [token] is forwarded to listeners via [currentToken]; the chat
  /// playback bar uses it to map back to a source message id.
  ///
  /// Returns once playback has been *started*. The completion event
  /// arrives asynchronously via [currentToken] flipping back to
  /// `null`.
  Future<void> speak(String text, {String? token}) async {
    if (!isSupported) {
      throw const OfflineTtsException(
        'Offline TTS is not supported on this platform',
      );
    }
    final clean = text.trim();
    if (clean.isEmpty) return;

    logger.info(
      '[OfflineTTS] speak: ${clean.length} chars, token=$token',
    );

    final files = await _ensureFilesOnce();

    // Increment the generation counter; if a newer call arrives
    // before this one finishes generating, we'll bail out instead of
    // playing stale audio over the latest request.
    final gen = ++_generationGen;

    // Build the request before spawning the isolate so the closure
    // captures only this sendable object — never `this`, which has
    // an unsendable AudioPlayer / Future field.
    final ttsReq = _TtsRequest(
      text: clean,
      model: files.model,
      tokens: files.tokens,
      dataDir: files.dataDir,
    );
    final swGen = Stopwatch()..start();
    final samples = await Isolate.run(() => _generateInWorker(ttsReq));
    swGen.stop();
    if (gen != _generationGen) {
      logger.info('[OfflineTTS] superseded generation $gen, dropping audio');
      return;
    }
    if (samples.samples.isEmpty || samples.sampleRate <= 0) {
      logger.error(
        '[OfflineTTS] generate produced no audio '
        '(samples=${samples.samples.length}, '
        'sampleRate=${samples.sampleRate})',
      );
      return;
    }
    logger.info(
      '[OfflineTTS] generate: ${samples.samples.length} samples '
      '@ ${samples.sampleRate}Hz '
      '(${(samples.samples.length / samples.sampleRate).toStringAsFixed(2)}s '
      'audio in ${swGen.elapsedMilliseconds}ms)',
    );

    final wavPath = await _writeWavTempFile(
      samples.samples,
      samples.sampleRate,
    );
    if (gen != _generationGen) return;
    final wavSize = await File(wavPath).length();
    logger.info('[OfflineTTS] wrote WAV: $wavPath ($wavSize bytes)');
    await _playFile(wavPath, token: token);
  }

  /// Stop any in-progress playback and clear the current token.
  Future<void> stop() async {
    _generationGen++;
    _currentToken.value = null;
    final player = _player;
    if (player == null) return;
    try {
      await player.stop();
    } catch (e, st) {
      logger.warning('[OfflineTTS] stop failed', e, st);
    }
  }

  /// Release the audio engine. The model files stay on disk so the
  /// next session doesn't have to download again.
  Future<void> dispose() async {
    await stop();
    await _stateSub?.cancel();
    _stateSub = null;
    final player = _player;
    _player = null;
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {
        // The plugin may not be initialised on this platform.
      }
    }
  }

  Future<_ResolvedModelFiles> _ensureFilesOnce() {
    final existing = _filesFuture;
    if (existing != null) return existing;
    final future = _ensureFiles();
    _filesFuture = future;
    unawaited(
      future.then<void>(
        (_) => _setStatus(OfflineTtsStatus.ready),
        onError: (Object e, StackTrace st) {
          _lastError = e;
          if (identical(_filesFuture, future)) _filesFuture = null;
          // Use error level so the failure shows up under the dev
          // logs "errors" filter and gets forwarded to Sentry.
          logger.error('[OfflineTTS] ensureReady failed: $e', e, st);
          _setStatus(OfflineTtsStatus.failed);
        },
      ),
    );
    return future;
  }

  Future<_ResolvedModelFiles> _ensureFiles() async {
    logger.info('[OfflineTTS] ensureFiles: model=${_model.id}');
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory(
      p.join(supportDir.path, 'speech', 'tts', _model.id),
    );
    await modelDir.create(recursive: true);
    final resolved = _resolve(modelDir);
    if (resolved.allExist) {
      logger.info(
        '[OfflineTTS] ensureFiles: cache hit at ${modelDir.path}',
      );
      _setStatus(OfflineTtsStatus.ready);
      return resolved;
    }

    logger.info(
      '[OfflineTTS] ensureFiles: cache miss; '
      'will download into ${modelDir.path}',
    );
    _setStatus(OfflineTtsStatus.downloading);
    await _downloadAndExtract(modelDir);
    final after = _resolve(modelDir);
    if (!after.allExist) {
      // Enumerate what's missing so the dev-log breadcrumb is
      // actionable rather than a blanket "incomplete".
      final missing = <String>[];
      if (!File(after.model).existsSync()) {
        missing.add('model:${after.model}');
      }
      if (!File(after.tokens).existsSync()) {
        missing.add('tokens:${after.tokens}');
      }
      if (after.dataDir.isNotEmpty &&
          !Directory(after.dataDir).existsSync()) {
        missing.add('dataDir:${after.dataDir}');
      }
      throw OfflineTtsException(
        'Offline TTS model is incomplete after extract: '
        '${missing.join(", ")}',
      );
    }
    logger.info(
      '[OfflineTTS] ensureFiles: ready at ${modelDir.path}',
    );
    return after;
  }

  _ResolvedModelFiles _resolve(Directory modelDir) {
    return _ResolvedModelFiles(
      model: p.join(modelDir.path, _model.modelRelPath),
      tokens: p.join(modelDir.path, _model.tokensRelPath),
      dataDir: _model.dataDirRelPath.isEmpty
          ? ''
          : p.join(modelDir.path, _model.dataDirRelPath),
    );
  }

  Future<void> _downloadAndExtract(Directory modelDir) async {
    final tempDir = await getTemporaryDirectory();
    final archive = File(p.join(tempDir.path, '${_model.id}.tar.bz2'));
    try {
      await _downloadArchive(archive);
      logger.info(
        '[OfflineTTS] extract: starting from '
        '${archive.path} (${archive.lengthSync()} bytes) '
        'into ${modelDir.path}',
      );
      // Build the request from local variables so the Isolate.run
      // closure doesn't implicitly capture `this` (the singleton's
      // _filesFuture / AudioPlayer aren't sendable, and a captured
      // `_model.field` reference would drag them into the
      // serialized message → "object is unsendable" Future).
      //
      // The isolate worker rethrows as a plain string-bearing
      // Exception so the message survives the isolate boundary
      // intact (custom exception types don't always serialize
      // cleanly through Isolate.run).
      final extractReq = _ExtractRequest(
        archivePath: archive.path,
        modelDirPath: modelDir.path,
        archiveRoot: _model.archiveRoot,
        expectedSha256: _model.archiveSha256,
      );
      await Isolate.run(() => _verifyAndExtractInWorker(extractReq));
      logger.info('[OfflineTTS] extract: completed');
    } catch (e, st) {
      logger.error(
        '[OfflineTTS] download/extract failed: $e',
        e,
        st,
      );
      rethrow;
    } finally {
      if (archive.existsSync()) {
        try {
          await archive.delete();
        } catch (_) {/* best effort */}
      }
    }
  }

  Future<void> _downloadArchive(File target) async {
    logger.info(
      '[OfflineTTS] download: GET ${_model.archiveUrl} -> ${target.path}',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..userAgent = 'happy_flutter/offline-tts';
    try {
      final request = await client.getUrl(Uri.parse(_model.archiveUrl))
        // Default already, but make explicit so a future Dart change
        // doesn't silently break GitHub release redirects.
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await request.close();
      logger.info(
        '[OfflineTTS] download: status=${response.statusCode} '
        'contentLength=${response.contentLength}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OfflineTtsException(
          'TTS model download failed: HTTP ${response.statusCode} '
          'from ${_model.archiveUrl}',
        );
      }

      final sink = target.openWrite();
      var written = 0;
      var lastLogged = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          written += chunk.length;
          // Log roughly every 8MB so the dev log shows progress
          // for users investigating a stuck download.
          if (written - lastLogged >= 8 * 1024 * 1024) {
            lastLogged = written;
            logger.info(
              '[OfflineTTS] download: progress '
              '${(written / (1024 * 1024)).toStringAsFixed(1)}MB',
            );
          }
        }
      } finally {
        await sink.close();
      }
      logger.info(
        '[OfflineTTS] download: completed '
        '${(written / (1024 * 1024)).toStringAsFixed(1)}MB',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _writeWavTempFile(Float32List samples, int sampleRate) async {
    final tempDir = await getTemporaryDirectory();
    final wavDir = Directory(p.join(tempDir.path, 'tts_wav'));
    await wavDir.create(recursive: true);
    // Use a generation-tagged filename so concurrent speak() calls
    // never clobber each other's files mid-playback.
    final wavPath = p.join(
      wavDir.path,
      'tts_${DateTime.now().millisecondsSinceEpoch}_$_generationGen.wav',
    );
    final ok = sherpa.writeWave(
      filename: wavPath,
      samples: samples,
      sampleRate: sampleRate,
    );
    if (!ok) {
      throw const OfflineTtsException('Failed to write generated WAV');
    }
    return wavPath;
  }

  Future<void> _playFile(String path, {String? token}) async {
    var player = _player;
    if (player == null) {
      player = AudioPlayer();
      _player = player;
      // just_audio emits a stream of PlayerState; we react to the
      // `completed` processing-state by clearing the token so the
      // chat playback bar collapses.
      _stateSub = player.playerStateStream.listen((state) {
        logger.info(
          '[OfflineTTS] player state: playing=${state.playing} '
          'processing=${state.processingState.name}',
        );
        if (state.processingState == ProcessingState.completed) {
          _currentToken.value = null;
          unawaited(_cleanupOldWavs());
        }
      });
      // The playback-event stream surfaces engine errors that
      // setFilePath()/play() don't always raise synchronously
      // (codec mismatches, audio focus failures, etc.).
      player.playbackEventStream.listen(
        (_) {/* state changes are handled above */},
        onError: (Object e, StackTrace st) {
          logger.error('[OfflineTTS] playback engine error: $e', e, st);
          _currentToken.value = null;
        },
      );
    } else {
      try {
        await player.stop();
      } catch (_) {/* best effort */}
    }
    _currentToken.value = token;
    try {
      final dur = await player.setFilePath(path);
      logger.info(
        '[OfflineTTS] setFilePath ok, duration=${dur?.inMilliseconds}ms',
      );
    } catch (e, st) {
      logger.error('[OfflineTTS] setFilePath failed: $e', e, st);
      _currentToken.value = null;
      rethrow;
    }
    try {
      // Don't await play(); it returns when playback finishes which
      // we don't want to block the caller on. We still capture
      // errors via .catchError so a failed play doesn't go silent.
      unawaited(
        player.play().catchError((Object e, StackTrace st) {
          logger.error('[OfflineTTS] play() failed: $e', e, st);
          _currentToken.value = null;
        }),
      );
    } catch (e, st) {
      logger.error('[OfflineTTS] play() throw: $e', e, st);
      _currentToken.value = null;
      rethrow;
    }
  }

  Future<void> _cleanupOldWavs() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final wavDir = Directory(p.join(tempDir.path, 'tts_wav'));
      if (!wavDir.existsSync()) return;
      final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
      for (final entity in wavDir.listSync(followLinks: false)) {
        if (entity is! File) continue;
        try {
          final stat = entity.statSync();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {/* best effort */}
      }
    } catch (_) {/* best effort */}
  }

  void _setStatus(OfflineTtsStatus next) {
    if (_status.value == next) return;
    _status.value = next;
  }
}

class _ResolvedModelFiles {
  const _ResolvedModelFiles({
    required this.model,
    required this.tokens,
    required this.dataDir,
  });

  final String model;
  final String tokens;
  final String dataDir;

  bool get allExist {
    if (!File(model).existsSync()) return false;
    if (!File(tokens).existsSync()) return false;
    if (dataDir.isNotEmpty && !Directory(dataDir).existsSync()) return false;
    return true;
  }
}

// ── isolate worker payloads ─────────────────────────────────────────────────

class _TtsRequest {
  const _TtsRequest({
    required this.text,
    required this.model,
    required this.tokens,
    required this.dataDir,
  });
  final String text;
  final String model;
  final String tokens;
  final String dataDir;
}

class _TtsResult {
  const _TtsResult({required this.samples, required this.sampleRate});
  final Float32List samples;
  final int sampleRate;
}

_TtsResult _generateInWorker(_TtsRequest req) {
  sherpa.initBindings();
  final config = sherpa.OfflineTtsConfig(
    model: sherpa.OfflineTtsModelConfig(
      vits: sherpa.OfflineTtsVitsModelConfig(
        model: req.model,
        tokens: req.tokens,
        dataDir: req.dataDir,
      ),
      numThreads: 2,
      debug: false,
      provider: 'cpu',
    ),
  );
  final tts = sherpa.OfflineTts(config);
  try {
    final audio = tts.generate(text: req.text);
    return _TtsResult(samples: audio.samples, sampleRate: audio.sampleRate);
  } finally {
    tts.free();
  }
}

class _ExtractRequest {
  const _ExtractRequest({
    required this.archivePath,
    required this.modelDirPath,
    required this.archiveRoot,
    required this.expectedSha256,
  });
  final String archivePath;
  final String modelDirPath;
  final String archiveRoot;
  final String expectedSha256;
}

Future<void> _verifyAndExtractInWorker(_ExtractRequest req) async {
  // Throws plain Exception instances so messages survive the
  // Isolate.run boundary on every Dart version.
  final bytes = await File(req.archivePath).readAsBytes();
  final actualSha = sha256.convert(bytes).toString();
  if (actualSha != req.expectedSha256) {
    throw Exception(
      'Offline TTS model checksum mismatch '
      '(expected ${req.expectedSha256}, got $actualSha)',
    );
  }

  final List<int> tarBytes;
  try {
    tarBytes = BZip2Decoder().decodeBytes(bytes, verify: true);
  } catch (e) {
    throw Exception('Offline TTS bzip2 decode failed: $e');
  }

  final Archive entries;
  try {
    entries = TarDecoder().decodeBytes(tarBytes);
  } catch (e) {
    throw Exception('Offline TTS tar decode failed: $e');
  }

  final rootPrefix = '${req.archiveRoot}/';
  var fileCount = 0;
  for (final entry in entries.files) {
    final name = entry.name;
    if (!name.startsWith(rootPrefix)) continue;
    final rel = name.substring(rootPrefix.length);
    if (rel.isEmpty) continue;
    final outPath = p.join(req.modelDirPath, rel);
    if (entry.isFile) {
      await File(outPath).parent.create(recursive: true);
      await File(outPath).writeAsBytes(
        entry.content as List<int>,
        flush: true,
      );
      fileCount++;
    } else {
      await Directory(outPath).create(recursive: true);
    }
  }
  if (fileCount == 0) {
    throw Exception(
      'Offline TTS archive contained no entries under '
      '"$rootPrefix"',
    );
  }
}
