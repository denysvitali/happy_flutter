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
/// Each entry points at a Piper-style archive (`.tar.bz2`) hosted on
/// the k2-fsa/sherpa-onnx releases page. After extraction the layout
/// is the same for every voice: an `.onnx` file, a `tokens.txt` and
/// an `espeak-ng-data/` directory.
///
/// [archiveSha256] is optional. If provided, the downloaded archive
/// is verified against it; if empty, only TLS-level integrity is
/// relied upon. The default Amy voice keeps a pinned hash; new
/// voices added in bulk leave it empty so users can sample them
/// without us having to pre-fetch every archive.
class OfflineTtsModel {
  const OfflineTtsModel({
    required this.id,
    required this.displayName,
    required this.locale,
    required this.gender,
    required this.quality,
    required this.archiveUrl,
    required this.approximateBytes,
    required this.archiveRoot,
    required this.modelRelPath,
    required this.tokensRelPath,
    required this.dataDirRelPath,
    this.archiveSha256 = '',
    this.expectedSampleRate = 22050,
  });

  /// Stable identifier used for the local cache directory and the
  /// `ttsVoiceId` setting. Bump the suffix when changing the file
  /// layout to safely invalidate old downloads.
  final String id;

  /// Human-readable label shown in the voice picker.
  final String displayName;

  /// BCP-47-ish locale code (`en_US`, `de_DE`, …) used for grouping.
  final String locale;

  /// `'F'`, `'M'` or `'?'`. Surfaced in the picker for context.
  final String gender;

  /// Piper quality tier: `low`, `medium`, `high`, `x_low`. Higher
  /// quality is larger and slower but sounds better.
  final String quality;

  final String archiveUrl;
  final String archiveSha256;

  /// Approximate compressed archive size in bytes — used to render a
  /// rough size hint in the UI before download starts.
  final int approximateBytes;

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

  String get sizeLabel {
    if (approximateBytes <= 0) return '';
    final mb = approximateBytes / (1024 * 1024);
    return '~${mb < 10 ? mb.toStringAsFixed(1) : mb.round()}MB';
  }

  static const piperEnUsAmyLow = OfflineTtsModel(
    id: 'vits-piper-en_US-amy-low-v1',
    displayName: 'Amy (US English)',
    locale: 'en_US',
    gender: 'F',
    quality: 'low',
    archiveUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
        'tts-models/vits-piper-en_US-amy-low.tar.bz2',
    // sha256 of the upstream archive published by k2-fsa. If GitHub
    // ever republishes the asset, this will need to be refreshed.
    archiveSha256:
        'c70f5284a09a7fd4ed203b39b2ff51cac1432b422b852eb647b481dade3cf639',
    approximateBytes: 30 * 1024 * 1024,
    archiveRoot: 'vits-piper-en_US-amy-low',
    modelRelPath: 'en_US-amy-low.onnx',
    tokensRelPath: 'tokens.txt',
    dataDirRelPath: 'espeak-ng-data',
  );
}

/// Curated catalog of Piper voices the user can download from the
/// in-app voice picker. All entries follow the k2-fsa/sherpa-onnx
/// `tts-models` release naming convention; the picker is the only
/// place that lists them, so adding a new voice is a single-list
/// edit.
class OfflineTtsCatalog {
  const OfflineTtsCatalog._();

  static OfflineTtsModel _piper({
    required String locale,
    required String voice,
    required String quality,
    required String displayName,
    required String gender,
    required int approxMb,
    String sha256 = '',
  }) {
    final base = 'vits-piper-$locale-$voice-$quality';
    return OfflineTtsModel(
      id: '$base-v1',
      displayName: displayName,
      locale: locale,
      gender: gender,
      quality: quality,
      archiveUrl:
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
          'tts-models/$base.tar.bz2',
      archiveSha256: sha256,
      approximateBytes: approxMb * 1024 * 1024,
      archiveRoot: base,
      modelRelPath: '$locale-$voice-$quality.onnx',
      tokensRelPath: 'tokens.txt',
      dataDirRelPath: 'espeak-ng-data',
    );
  }

  /// All voices, in the order they should appear in the picker.
  ///
  /// First entry is the default selection. Sizes are approximate;
  /// the picker shows them so users with limited storage can pick
  /// accordingly.
  static final List<OfflineTtsModel> all = <OfflineTtsModel>[
    OfflineTtsModel.piperEnUsAmyLow,
    _piper(
      locale: 'en_US',
      voice: 'lessac',
      quality: 'medium',
      displayName: 'Lessac (US English, medium)',
      gender: 'F',
      approxMb: 63,
    ),
    _piper(
      locale: 'en_US',
      voice: 'ryan',
      quality: 'medium',
      displayName: 'Ryan (US English, medium)',
      gender: 'M',
      approxMb: 63,
    ),
    _piper(
      locale: 'en_US',
      voice: 'libritts_r',
      quality: 'medium',
      displayName: 'LibriTTS-R (US English, medium)',
      gender: 'F',
      approxMb: 78,
    ),
    _piper(
      locale: 'en_GB',
      voice: 'alan',
      quality: 'medium',
      displayName: 'Alan (UK English, medium)',
      gender: 'M',
      approxMb: 63,
    ),
    _piper(
      locale: 'en_GB',
      voice: 'jenny_dioco',
      quality: 'medium',
      displayName: 'Jenny (UK English, medium)',
      gender: 'F',
      approxMb: 63,
    ),
    _piper(
      locale: 'de_DE',
      voice: 'thorsten',
      quality: 'medium',
      displayName: 'Thorsten (German, medium)',
      gender: 'M',
      approxMb: 63,
    ),
    _piper(
      locale: 'fr_FR',
      voice: 'siwis',
      quality: 'medium',
      displayName: 'Siwis (French, medium)',
      gender: 'F',
      approxMb: 63,
    ),
    _piper(
      locale: 'es_ES',
      voice: 'mls_10246',
      quality: 'low',
      displayName: 'MLS 10246 (Spanish, low)',
      gender: 'M',
      approxMb: 30,
    ),
    _piper(
      locale: 'it_IT',
      voice: 'riccardo',
      quality: 'x_low',
      displayName: 'Riccardo (Italian, x-low)',
      gender: 'M',
      approxMb: 18,
    ),
    _piper(
      locale: 'pt_BR',
      voice: 'faber',
      quality: 'medium',
      displayName: 'Faber (Brazilian Portuguese, medium)',
      gender: 'M',
      approxMb: 63,
    ),
    _piper(
      locale: 'nl_NL',
      voice: 'mls_5809',
      quality: 'low',
      displayName: 'MLS 5809 (Dutch, low)',
      gender: 'M',
      approxMb: 30,
    ),
    _piper(
      locale: 'pl_PL',
      voice: 'gosia',
      quality: 'medium',
      displayName: 'Gosia (Polish, medium)',
      gender: 'F',
      approxMb: 63,
    ),
    _piper(
      locale: 'ru_RU',
      voice: 'irina',
      quality: 'medium',
      displayName: 'Irina (Russian, medium)',
      gender: 'F',
      approxMb: 63,
    ),
    _piper(
      locale: 'ca_ES',
      voice: 'upc_ona',
      quality: 'medium',
      displayName: 'Ona (Catalan, medium)',
      gender: 'F',
      approxMb: 63,
    ),
  ];

  static OfflineTtsModel get defaultModel => all.first;

  static OfflineTtsModel? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
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

  /// Download or extraction failed. [OfflineTtsService.errorFor] has
  /// the cause.
  failed,
}

/// Sherpa-onnx-backed offline text-to-speech service.
///
/// Manages a *catalog* of voices: any number can be downloaded and
/// kept on disk, but only the [selectedVoiceId] is used by [speak].
/// All sherpa interaction happens on a background isolate so the UI
/// thread stays responsive.
class OfflineTtsService {
  factory OfflineTtsService() => _instance;
  OfflineTtsService._() {
    _statuses = ValueNotifier<Map<String, OfflineTtsStatus>>(
      _initialStatuses(),
    );
    _selectedStatus = ValueNotifier<OfflineTtsStatus>(
      OfflineTtsStatus.notDownloaded,
    );
  }
  static final OfflineTtsService _instance = OfflineTtsService._();

  String _selectedVoiceId = OfflineTtsCatalog.defaultModel.id;

  late final ValueNotifier<Map<String, OfflineTtsStatus>> _statuses;
  late final ValueNotifier<OfflineTtsStatus> _selectedStatus;
  final ValueNotifier<String?> _currentToken = ValueNotifier<String?>(null);
  final Map<String, Object?> _errors = <String, Object?>{};
  final Map<String, Future<_ResolvedModelFiles>> _inflight =
      <String, Future<_ResolvedModelFiles>>{};

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  int _generationGen = 0;

  /// One-shot lazy initialisation: probes the sherpa-onnx native
  /// library and walks the on-disk voice cache so [statuses] reflect
  /// reality before any caller invokes [speak]. Every offline op
  /// awaits this before touching sherpa, so a user tapping
  /// "Speak this message" right after launch can't race past the
  /// FFI symbol binding and trip "Please initialize sherpa-onnx first".
  Future<void>? _readyFuture;

  /// `true` once [_doInitialize] has completed successfully. Callers
  /// (TtsService) use this to decide whether to fall back to system
  /// TTS instead of paying the init cost on a user-initiated tap.
  bool _ready = false;

  /// Whether the offline engine has finished its one-shot
  /// initialisation. `false` until [initialize] resolves; once true,
  /// stays true for the lifetime of the process.
  bool get isReady => _ready;

  /// Listenable for the currently-playing token (caller-supplied id,
  /// usually a message id).
  ValueListenable<String?> get currentToken => _currentToken;

  /// Per-voice download status (map snapshot is replaced atomically
  /// on every transition so [ValueListenableBuilder] re-renders).
  ValueListenable<Map<String, OfflineTtsStatus>> get statuses => _statuses;

  /// Convenience listenable that always reflects the [selectedVoiceId]
  /// status — kept for backward compatibility with the previous
  /// single-voice API.
  ValueListenable<OfflineTtsStatus> get status => _selectedStatus;

  /// Last error from the *selected* voice's download/extract pipeline,
  /// or `null` if the pipeline never failed in this process.
  Object? get lastError => _errors[_selectedVoiceId];

  Object? errorFor(String voiceId) => _errors[voiceId];

  bool get isSpeaking => _currentToken.value != null;

  /// Whether the offline engine is usable on this platform.
  bool get isSupported => !kIsWeb;

  /// All voices the user can choose from.
  List<OfflineTtsModel> get voices =>
      List<OfflineTtsModel>.unmodifiable(OfflineTtsCatalog.all);

  String get selectedVoiceId => _selectedVoiceId;

  OfflineTtsModel get selectedVoice =>
      OfflineTtsCatalog.byId(_selectedVoiceId) ??
      OfflineTtsCatalog.defaultModel;

  /// Switch the active voice. Persisting the choice is the caller's
  /// responsibility (typically the [Settings] layer).
  void selectVoice(String voiceId) {
    final resolved =
        OfflineTtsCatalog.byId(voiceId)?.id ??
        OfflineTtsCatalog.defaultModel.id;
    if (_selectedVoiceId == resolved) return;
    _selectedVoiceId = resolved;
    _refreshSelectedStatus();
  }

  OfflineTtsStatus statusFor(String voiceId) {
    return _statuses.value[voiceId] ?? OfflineTtsStatus.notDownloaded;
  }

  /// One-shot bootstrap. Safe to call repeatedly; concurrent callers
  /// share the same future. Must complete before any FFI call into
  /// sherpa-onnx so we don't trip "Please initialize sherpa-onnx
  /// first" on first speak.
  ///
  /// Performs two things:
  /// 1. Probes [sherpa.initBindings] inside a worker isolate so a
  ///    broken native library surfaces *now* (logged + cached) rather
  ///    than mid-speak.
  /// 2. Walks the cache directory so [statuses] is populated.
  Future<void> initialize() => _readyFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    if (!isSupported) {
      _ready = true;
      return;
    }
    try {
      // Run a tiny probe in a worker isolate to bind FFI symbols and
      // catch missing/incompatible libraries up front. We don't keep
      // the bindings — they're per-isolate — but a successful probe
      // means subsequent generate workers will succeed too.
      await Isolate.run(_initBindingsProbe);
    } catch (e, st) {
      logger.warning(
        '[OfflineTTS] initialize: sherpa-onnx probe failed: $e',
        e,
        st,
      );
      // Still walk the disk so the UI can show statuses even when the
      // engine isn't usable on this device.
    }
    try {
      await refreshStatuses();
    } catch (e, st) {
      logger.warning('[OfflineTTS] initialize: refreshStatuses failed', e, st);
    }
    _ready = true;
  }

  /// Walk the cache directory once and update every voice's status
  /// based on what's already extracted. Cheap; safe to call on
  /// startup and after disk-affecting operations.
  Future<void> refreshStatuses() async {
    if (!isSupported) return;
    final supportDir = await getApplicationSupportDirectory();
    final next = <String, OfflineTtsStatus>{};
    for (final voice in OfflineTtsCatalog.all) {
      // Preserve in-progress / failed states — disk presence alone
      // doesn't tell us whether a download is mid-flight.
      final current = _statuses.value[voice.id];
      if (current == OfflineTtsStatus.downloading ||
          current == OfflineTtsStatus.failed) {
        next[voice.id] = current!;
        continue;
      }
      final dir = Directory(p.join(supportDir.path, 'speech', 'tts', voice.id));
      final resolved = _resolveFor(voice, dir);
      next[voice.id] = resolved.allExist
          ? OfflineTtsStatus.ready
          : OfflineTtsStatus.notDownloaded;
    }
    _setStatuses(next);
  }

  /// Trigger a download/extract for the *selected* voice if needed.
  Future<void> ensureReady() => ensureVoice(_selectedVoiceId);

  /// Trigger a download/extract for [voiceId]. Safe to call
  /// repeatedly; concurrent callers share the same future.
  Future<void> ensureVoice(String voiceId) async {
    if (!isSupported) {
      throw const OfflineTtsException(
        'Offline TTS is not supported on this platform',
      );
    }
    final voice = OfflineTtsCatalog.byId(voiceId);
    if (voice == null) {
      throw OfflineTtsException('Unknown offline voice: $voiceId');
    }
    // Wait for the one-shot init so subsequent isolate workers don't
    // race the FFI binding step.
    await initialize();
    await _ensureFilesOnce(voice);
  }

  /// Remove an extracted voice from disk. No-op if it isn't present.
  /// Refuses to delete a voice while it's being downloaded.
  Future<void> deleteVoice(String voiceId) async {
    if (!isSupported) return;
    if (_inflight.containsKey(voiceId)) {
      throw const OfflineTtsException(
        'Cannot delete a voice while it is downloading',
      );
    }
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'speech', 'tts', voiceId));
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } catch (e, st) {
        logger.warning('[OfflineTTS] delete failed for $voiceId: $e', e, st);
        rethrow;
      }
    }
    _errors.remove(voiceId);
    _setStatusFor(voiceId, OfflineTtsStatus.notDownloaded);
  }

  /// Generate speech for [text] and play it using [voiceId] (or the
  /// currently selected voice if omitted).
  ///
  /// [token] is forwarded to listeners via [currentToken]; the chat
  /// playback bar uses it to map back to a source message id.
  Future<void> speak(String text, {String? token, String? voiceId}) async {
    if (!isSupported) {
      throw const OfflineTtsException(
        'Offline TTS is not supported on this platform',
      );
    }
    final clean = text.trim();
    if (clean.isEmpty) return;

    if (voiceId != null && voiceId.isNotEmpty) {
      selectVoice(voiceId);
    }
    final voice = selectedVoice;

    // Block until the one-shot init resolves. This guarantees the
    // sherpa-onnx native library has been probed and the per-voice
    // status map is populated before we spawn the generation worker.
    // Without this, a fast tap on "Speak this message" right after
    // launch can hit the worker before its isolate-local FFI symbols
    // are usable and surface "Please initialize sherpa-onnx first".
    await initialize();

    logger.info(
      '[OfflineTTS] speak: ${clean.length} chars, voice=${voice.id}, '
      'token=$token',
    );

    final files = await _ensureFilesOnce(voice);

    // Increment the generation counter; if a newer call arrives
    // before this one finishes generating, we'll bail out instead of
    // playing stale audio over the latest request.
    final gen = ++_generationGen;
    final wavPath = await _allocateWavPath(gen);

    // Build the request before spawning the isolate so `compute`
    // receives only this sendable object, never `this` (which has
    // an unsendable AudioPlayer / Future field).
    //
    // The worker generates samples AND writes the WAV file inside
    // the same isolate. Doing the WAV write in the worker matters:
    // sherpa-onnx's bindings are isolate-local, and calling
    // `sherpa.writeWave` from the main isolate would throw
    // "Please initialize sherpa-onnx first" because the main
    // isolate never bound the FFI symbols.
    final ttsReq = _TtsRequest(
      text: clean,
      model: files.model,
      tokens: files.tokens,
      dataDir: files.dataDir,
      outputWavPath: wavPath,
    );
    final swGen = Stopwatch()..start();
    final result = await compute(_generateInWorker, ttsReq);
    swGen.stop();
    if (gen != _generationGen) {
      logger.info('[OfflineTTS] superseded generation $gen, dropping audio');
      return;
    }
    if (result.sampleCount == 0 || result.sampleRate <= 0) {
      logger.error(
        '[OfflineTTS] generate produced no audio '
        '(samples=${result.sampleCount}, '
        'sampleRate=${result.sampleRate})',
      );
      return;
    }
    final wavSize = File(wavPath).existsSync()
        ? await File(wavPath).length()
        : 0;
    logger.info(
      '[OfflineTTS] generate: ${result.sampleCount} samples '
      '@ ${result.sampleRate}Hz '
      '(${(result.sampleCount / result.sampleRate).toStringAsFixed(2)}s '
      'audio in ${swGen.elapsedMilliseconds}ms, WAV $wavSize bytes)',
    );
    await _playFile(wavPath, token: token);
  }

  Future<String> _allocateWavPath(int gen) async {
    final tempDir = await getTemporaryDirectory();
    final wavDir = Directory(p.join(tempDir.path, 'tts_wav'));
    await wavDir.create(recursive: true);
    return p.join(
      wavDir.path,
      'tts_${DateTime.now().millisecondsSinceEpoch}_$gen.wav',
    );
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

  /// Release the audio engine. Model files stay on disk so the next
  /// session doesn't have to download again.
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

  Future<_ResolvedModelFiles> _ensureFilesOnce(OfflineTtsModel voice) {
    final existing = _inflight[voice.id];
    if (existing != null) return existing;
    final future = _ensureFiles(voice);
    _inflight[voice.id] = future;
    unawaited(
      future.then<void>(
        (_) {
          _inflight.remove(voice.id);
          _errors.remove(voice.id);
          _setStatusFor(voice.id, OfflineTtsStatus.ready);
        },
        onError: (Object e, StackTrace st) {
          _inflight.remove(voice.id);
          _errors[voice.id] = e;
          // Use error level so the failure shows up under the dev
          // logs "errors" filter and gets forwarded to Sentry.
          logger.error(
            '[OfflineTTS] ensureReady failed for ${voice.id}: $e',
            e,
            st,
          );
          _setStatusFor(voice.id, OfflineTtsStatus.failed);
        },
      ),
    );
    return future;
  }

  Future<_ResolvedModelFiles> _ensureFiles(OfflineTtsModel voice) async {
    logger.info('[OfflineTTS] ensureFiles: model=${voice.id}');
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory(
      p.join(supportDir.path, 'speech', 'tts', voice.id),
    );
    await modelDir.create(recursive: true);
    final resolved = _resolveFor(voice, modelDir);
    if (resolved.allExist) {
      logger.info('[OfflineTTS] ensureFiles: cache hit at ${modelDir.path}');
      _setStatusFor(voice.id, OfflineTtsStatus.ready);
      return resolved;
    }

    logger.info(
      '[OfflineTTS] ensureFiles: cache miss; '
      'will download into ${modelDir.path}',
    );
    _setStatusFor(voice.id, OfflineTtsStatus.downloading);
    await _downloadAndExtract(voice, modelDir);
    final after = _resolveFor(voice, modelDir);
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
      if (after.dataDir.isNotEmpty && !Directory(after.dataDir).existsSync()) {
        missing.add('dataDir:${after.dataDir}');
      }
      throw OfflineTtsException(
        'Offline TTS model is incomplete after extract: '
        '${missing.join(", ")}',
      );
    }
    logger.info('[OfflineTTS] ensureFiles: ready at ${modelDir.path}');
    return after;
  }

  _ResolvedModelFiles _resolveFor(OfflineTtsModel voice, Directory modelDir) {
    return _ResolvedModelFiles(
      model: p.join(modelDir.path, voice.modelRelPath),
      tokens: p.join(modelDir.path, voice.tokensRelPath),
      dataDir: voice.dataDirRelPath.isEmpty
          ? ''
          : p.join(modelDir.path, voice.dataDirRelPath),
    );
  }

  Future<void> _downloadAndExtract(
    OfflineTtsModel voice,
    Directory modelDir,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final archive = File(p.join(tempDir.path, '${voice.id}.tar.bz2'));
    try {
      await _downloadArchive(voice, archive);
      logger.info(
        '[OfflineTTS] extract: starting from '
        '${archive.path} (${archive.lengthSync()} bytes) '
        'into ${modelDir.path}',
      );
      // Build the request from local variables so `compute` receives a
      // plain sendable message rather than a closure that may retain
      // `this` (the singleton's Future / AudioPlayer aren't sendable).
      //
      // The isolate worker rethrows as a plain string-bearing
      // Exception so the message survives the isolate boundary
      // intact (custom exception types don't always serialize
      // cleanly through isolate message passing).
      final extractReq = _ExtractRequest(
        archivePath: archive.path,
        modelDirPath: modelDir.path,
        archiveRoot: voice.archiveRoot,
        // Empty SHA means "skip integrity check" — relied on for the
        // bulk of the catalog where we don't pin checksums.
        expectedSha256: voice.archiveSha256,
      );
      await compute(_verifyAndExtractInWorker, extractReq);
      logger.info('[OfflineTTS] extract: completed');
    } catch (e, st) {
      logger.error('[OfflineTTS] download/extract failed: $e', e, st);
      rethrow;
    } finally {
      if (archive.existsSync()) {
        try {
          await archive.delete();
        } catch (_) {
          /* best effort */
        }
      }
    }
  }

  Future<void> _downloadArchive(OfflineTtsModel voice, File target) async {
    logger.info(
      '[OfflineTTS] download: GET ${voice.archiveUrl} -> ${target.path}',
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..userAgent = 'happy_flutter/offline-tts';
    try {
      final request = await client.getUrl(Uri.parse(voice.archiveUrl))
        // Default already, but make explicit so a future Dart change
        // doesn't silently break GitHub release redirects.
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await request.close();
      logger.info(
        '[OfflineTTS] download: status=${response.statusCode} '
        'contentLength=${response.contentLength}',
      );
      if (response.statusCode == 404) {
        throw OfflineTtsException(
          'Voice "${voice.displayName}" is not available on the upstream '
          'mirror (HTTP 404 from ${voice.archiveUrl}). '
          'Pick a different voice.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OfflineTtsException(
          'TTS model download failed: HTTP ${response.statusCode} '
          'from ${voice.archiveUrl}',
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
        (_) {
          /* state changes are handled above */
        },
        onError: (Object e, StackTrace st) {
          logger.error('[OfflineTTS] playback engine error: $e', e, st);
          _currentToken.value = null;
        },
      );
    } else {
      try {
        await player.stop();
      } catch (_) {
        /* best effort */
      }
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
        } catch (_) {
          /* best effort */
        }
      }
    } catch (_) {
      /* best effort */
    }
  }

  Map<String, OfflineTtsStatus> _initialStatuses() {
    return <String, OfflineTtsStatus>{
      for (final voice in OfflineTtsCatalog.all)
        voice.id: OfflineTtsStatus.notDownloaded,
    };
  }

  void _setStatuses(Map<String, OfflineTtsStatus> next) {
    _statuses.value = Map<String, OfflineTtsStatus>.unmodifiable(next);
    _refreshSelectedStatus();
  }

  void _setStatusFor(String voiceId, OfflineTtsStatus status) {
    final current = _statuses.value;
    if (current[voiceId] == status) return;
    final next = Map<String, OfflineTtsStatus>.from(current);
    next[voiceId] = status;
    _setStatuses(next);
  }

  void _refreshSelectedStatus() {
    final s =
        _statuses.value[_selectedVoiceId] ?? OfflineTtsStatus.notDownloaded;
    if (_selectedStatus.value != s) _selectedStatus.value = s;
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
    required this.outputWavPath,
  });
  final String text;
  final String model;
  final String tokens;
  final String dataDir;
  final String outputWavPath;
}

class _TtsResult {
  const _TtsResult({required this.sampleCount, required this.sampleRate});
  final int sampleCount;
  final int sampleRate;
}

/// Worker that just binds the sherpa-onnx FFI symbols. Run from
/// [OfflineTtsService._doInitialize] as a fail-fast probe — if the
/// native library is missing or incompatible for this device's ABI
/// the exception fires here, well before a user-initiated speak.
void _initBindingsProbe() {
  sherpa.initBindings();
}

_TtsResult _generateInWorker(_TtsRequest req) {
  // Bindings are isolate-local; this also enables `sherpa.writeWave`
  // below to find the FFI symbols.
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
    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      return _TtsResult(sampleCount: 0, sampleRate: audio.sampleRate);
    }
    final ok = sherpa.writeWave(
      filename: req.outputWavPath,
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
    if (!ok) {
      throw Exception(
        'sherpa.writeWave returned false for ${req.outputWavPath}',
      );
    }
    return _TtsResult(
      sampleCount: audio.samples.length,
      sampleRate: audio.sampleRate,
    );
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
  // isolate boundary on every Dart version.
  final bytes = await File(req.archivePath).readAsBytes();
  if (req.expectedSha256.isNotEmpty) {
    final actualSha = sha256.convert(bytes).toString();
    if (actualSha != req.expectedSha256) {
      throw Exception(
        'Offline TTS model checksum mismatch '
        '(expected ${req.expectedSha256}, got $actualSha)',
      );
    }
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
      await File(outPath).writeAsBytes(entry.content as List<int>, flush: true);
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
