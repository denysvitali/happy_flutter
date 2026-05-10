import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
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
  StreamSubscription<void>? _completeSub;
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

    final files = await _ensureFilesOnce();

    // Increment the generation counter; if a newer call arrives
    // before this one finishes generating, we'll bail out instead of
    // playing stale audio over the latest request.
    final gen = ++_generationGen;

    final samples = await Isolate.run(() => _generateInWorker(_TtsRequest(
          text: clean,
          model: files.model,
          tokens: files.tokens,
          dataDir: files.dataDir,
        )));
    if (gen != _generationGen) {
      logger.info('[OfflineTTS] superseded generation $gen, dropping audio');
      return;
    }
    if (samples.samples.isEmpty || samples.sampleRate <= 0) {
      logger.warning('[OfflineTTS] generation produced no audio');
      return;
    }

    final wavPath = await _writeWavTempFile(
      samples.samples,
      samples.sampleRate,
    );
    if (gen != _generationGen) return;
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
    await _completeSub?.cancel();
    _completeSub = null;
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
          _setStatus(OfflineTtsStatus.failed);
        },
      ),
    );
    return future;
  }

  Future<_ResolvedModelFiles> _ensureFiles() async {
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory(
      p.join(supportDir.path, 'speech', 'tts', _model.id),
    );
    await modelDir.create(recursive: true);
    final resolved = _resolve(modelDir);
    if (resolved.allExist) {
      _setStatus(OfflineTtsStatus.ready);
      return resolved;
    }

    _setStatus(OfflineTtsStatus.downloading);
    await _downloadAndExtract(modelDir);
    final after = _resolve(modelDir);
    if (!after.allExist) {
      throw const OfflineTtsException(
        'Offline TTS model download is incomplete',
      );
    }
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
      await Isolate.run(
        () => _verifyAndExtractInWorker(_ExtractRequest(
          archivePath: archive.path,
          modelDirPath: modelDir.path,
          archiveRoot: _model.archiveRoot,
          expectedSha256: _model.archiveSha256,
        )),
      );
    } catch (e, st) {
      logger.warning('[OfflineTTS] model download failed', e, st);
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
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(_model.archiveUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OfflineTtsException(
          'TTS model download failed (${response.statusCode})',
        );
      }
      await response.pipe(target.openWrite());
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
      _completeSub = player.onPlayerComplete.listen((_) {
        _currentToken.value = null;
        // Clean up temp file in the background.
        unawaited(_cleanupOldWavs());
      });
    } else {
      await player.stop();
    }
    _currentToken.value = token;
    await player.play(DeviceFileSource(path));
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
  final bytes = await File(req.archivePath).readAsBytes();
  final actualSha = sha256.convert(bytes).toString();
  if (actualSha != req.expectedSha256) {
    throw const OfflineTtsException(
      'Offline TTS model checksum mismatch',
    );
  }

  final tarBytes = BZip2Decoder().decodeBytes(bytes, verify: true);
  final archive = TarDecoder().decodeBytes(tarBytes);
  final rootPrefix = '${req.archiveRoot}/';

  for (final file in archive) {
    final name = file.name;
    if (!name.startsWith(rootPrefix)) continue;
    final rel = name.substring(rootPrefix.length);
    if (rel.isEmpty) continue;
    final outPath = p.join(req.modelDirPath, rel);
    if (file.isFile) {
      await File(outPath).parent.create(recursive: true);
      await File(outPath).writeAsBytes(file.content as List<int>, flush: true);
    } else {
      await Directory(outPath).create(recursive: true);
    }
  }
}
