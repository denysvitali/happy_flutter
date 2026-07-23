import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'logger_service.dart' show logger;

/// Offline ASR model family. Drives how
/// [OfflineSttResolvedFiles] map onto sherpa-onnx's
/// [sherpa.OfflineModelConfig].
enum OfflineSttFamily {
  moonshine,
  transducer,
  whisper,
  senseVoice,
}

/// Catalog entry for a downloadable offline speech model.
///
/// Archives live on the k2-fsa/sherpa-onnx `asr-models` release.
/// After extract, files sit under
/// `speech/stt/<id>/` in the app support directory.
class OfflineSttModel {
  const OfflineSttModel({
    required this.id,
    required this.displayName,
    required this.languages,
    required this.tier,
    required this.archiveUrl,
    required this.archiveSha256,
    required this.approximateBytes,
    required this.archiveRoot,
    required this.requiredFiles,
    required this.family,
    required this.tokensRelPath,
    this.encoderRelPath,
    this.decoderRelPath,
    this.joinerRelPath,
    this.modelRelPath,
    this.preprocessorRelPath,
    this.uncachedDecoderRelPath,
    this.cachedDecoderRelPath,
    this.modelType = '',
  });

  /// Stable id used for the cache dir and `Settings.sttModelId`.
  /// Bump the `-vN` suffix when file layout changes.
  final String id;
  final String displayName;

  /// Short languages label shown in the picker (e.g. `EN`, `25 EU`).
  final String languages;

  /// `fast` / `balanced` / `quality` — groups the picker.
  final String tier;

  final String archiveUrl;
  final String archiveSha256;
  final int approximateBytes;
  final String archiveRoot;

  /// Basenames that must be present after extract.
  final Set<String> requiredFiles;
  final OfflineSttFamily family;

  final String tokensRelPath;
  final String? encoderRelPath;
  final String? decoderRelPath;
  final String? joinerRelPath;
  final String? modelRelPath;
  final String? preprocessorRelPath;
  final String? uncachedDecoderRelPath;
  final String? cachedDecoderRelPath;

  /// Passed to sherpa as `OfflineModelConfig.modelType`
  /// (e.g. `nemo_transducer` for Parakeet TDT).
  final String modelType;

  String get sizeLabel {
    if (approximateBytes <= 0) return '';
    final mb = approximateBytes / (1024 * 1024);
    return '~${mb < 10 ? mb.toStringAsFixed(1) : mb.round()}MB';
  }
}

/// Curated Core 6 offline STT catalog. First entry is not the
/// default — [defaultModel] is Parakeet for accuracy.
class OfflineSttCatalog {
  const OfflineSttCatalog._();

  static const String _baseUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';

  static final List<OfflineSttModel> all = <OfflineSttModel>[
    const OfflineSttModel(
      id: 'moonshine-tiny-en-int8-v1',
      displayName: 'Moonshine Tiny (EN)',
      languages: 'EN',
      tier: 'fast',
      archiveUrl: '$_baseUrl/sherpa-onnx-moonshine-tiny-en-int8.tar.bz2',
      archiveSha256:
          'd5fe6ec4334fef36255b2a4010412cad4c007e33103fec62fb5d17cad88086f2',
      approximateBytes: 103 * 1024 * 1024,
      archiveRoot: 'sherpa-onnx-moonshine-tiny-en-int8',
      requiredFiles: {
        'preprocess.onnx',
        'encode.int8.onnx',
        'uncached_decode.int8.onnx',
        'cached_decode.int8.onnx',
        'tokens.txt',
      },
      family: OfflineSttFamily.moonshine,
      tokensRelPath: 'tokens.txt',
      preprocessorRelPath: 'preprocess.onnx',
      encoderRelPath: 'encode.int8.onnx',
      uncachedDecoderRelPath: 'uncached_decode.int8.onnx',
      cachedDecoderRelPath: 'cached_decode.int8.onnx',
    ),
    const OfflineSttModel(
      id: 'moonshine-base-en-int8-v1',
      displayName: 'Moonshine Base (EN)',
      languages: 'EN',
      tier: 'balanced',
      archiveUrl: '$_baseUrl/sherpa-onnx-moonshine-base-en-int8.tar.bz2',
      archiveSha256:
          '21870cecaa2e44e4e2bf63e02d1072bed183ccd10284871353bd9d24dad14e5e',
      approximateBytes: 239 * 1024 * 1024,
      archiveRoot: 'sherpa-onnx-moonshine-base-en-int8',
      requiredFiles: {
        'preprocess.onnx',
        'encode.int8.onnx',
        'uncached_decode.int8.onnx',
        'cached_decode.int8.onnx',
        'tokens.txt',
      },
      family: OfflineSttFamily.moonshine,
      tokensRelPath: 'tokens.txt',
      preprocessorRelPath: 'preprocess.onnx',
      encoderRelPath: 'encode.int8.onnx',
      uncachedDecoderRelPath: 'uncached_decode.int8.onnx',
      cachedDecoderRelPath: 'cached_decode.int8.onnx',
    ),
    const OfflineSttModel(
      id: 'sense-voice-int8-2024-07-17-v1',
      displayName: 'SenseVoice (zh/en/ja/ko/yue)',
      languages: 'zh/en/ja/ko/yue',
      tier: 'balanced',
      archiveUrl: '$_baseUrl/'
          'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17.tar.bz2',
      archiveSha256:
          '7d1efa2138a65b0b488df37f8b89e3d91a60676e416f515b952358d83dfd347e',
      approximateBytes: 155 * 1024 * 1024,
      archiveRoot:
          'sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17',
      requiredFiles: {'model.int8.onnx', 'tokens.txt'},
      family: OfflineSttFamily.senseVoice,
      tokensRelPath: 'tokens.txt',
      modelRelPath: 'model.int8.onnx',
    ),
    const OfflineSttModel(
      id: 'whisper-tiny-en-v1',
      displayName: 'Whisper tiny.en',
      languages: 'EN',
      tier: 'fast',
      archiveUrl: '$_baseUrl/sherpa-onnx-whisper-tiny.en.tar.bz2',
      archiveSha256:
          '2bd6cf965c8bb3e068ef9fa2191387ee63a9dfa2a4e37582a8109641c20005dd',
      approximateBytes: 113 * 1024 * 1024,
      archiveRoot: 'sherpa-onnx-whisper-tiny.en',
      // Upstream names tokens `tiny.en-tokens.txt`, not `tokens.txt`.
      requiredFiles: {
        'tiny.en-encoder.int8.onnx',
        'tiny.en-decoder.int8.onnx',
        'tiny.en-tokens.txt',
      },
      family: OfflineSttFamily.whisper,
      tokensRelPath: 'tiny.en-tokens.txt',
      encoderRelPath: 'tiny.en-encoder.int8.onnx',
      decoderRelPath: 'tiny.en-decoder.int8.onnx',
      modelType: 'whisper',
    ),
    const OfflineSttModel(
      id: 'parakeet-tdt-0.6b-v3-int8-v1',
      displayName: 'Parakeet TDT 0.6B v3',
      languages: '25 EU',
      tier: 'quality',
      archiveUrl:
          '$_baseUrl/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2',
      archiveSha256:
          '5793d0fd397c5778d2cf2126994d58e9d56b1be7c04d13c7a15bb1b4eafb16bf',
      approximateBytes: 465 * 1024 * 1024,
      archiveRoot: 'sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8',
      requiredFiles: {
        'encoder.int8.onnx',
        'decoder.int8.onnx',
        'joiner.int8.onnx',
        'tokens.txt',
      },
      family: OfflineSttFamily.transducer,
      tokensRelPath: 'tokens.txt',
      encoderRelPath: 'encoder.int8.onnx',
      decoderRelPath: 'decoder.int8.onnx',
      joinerRelPath: 'joiner.int8.onnx',
      modelType: 'nemo_transducer',
    ),
    const OfflineSttModel(
      id: 'whisper-turbo-v1',
      displayName: 'Whisper large-v3 turbo',
      languages: 'multi',
      tier: 'quality',
      archiveUrl: '$_baseUrl/sherpa-onnx-whisper-turbo.tar.bz2',
      archiveSha256:
          'b11acbbcd660b44a8e0df33724feb5aaa709cf65668f2823d59f656312544f22',
      approximateBytes: 538 * 1024 * 1024,
      archiveRoot: 'sherpa-onnx-whisper-turbo',
      // Upstream uses turbo-* basenames, not large-v3-turbo-*.
      requiredFiles: {
        'turbo-encoder.int8.onnx',
        'turbo-decoder.int8.onnx',
        'turbo-tokens.txt',
      },
      family: OfflineSttFamily.whisper,
      tokensRelPath: 'turbo-tokens.txt',
      encoderRelPath: 'turbo-encoder.int8.onnx',
      decoderRelPath: 'turbo-decoder.int8.onnx',
      modelType: 'whisper',
    ),
  ];

  static OfflineSttModel get defaultModel =>
      byId('parakeet-tdt-0.6b-v3-int8-v1') ?? all.first;

  static OfflineSttModel? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}

enum OfflineSttStatus {
  notDownloaded,
  downloading,
  ready,
  failed,
}

/// Live download/extract progress for one model.
///
/// [fraction] is null when Content-Length is missing (indeterminate).
/// During extract, [phase] is `extracting` and [fraction] is null.
class OfflineSttDownloadProgress {
  const OfflineSttDownloadProgress({
    required this.modelId,
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes,
    this.fraction,
  });

  final String modelId;

  /// `downloading` or `extracting`.
  final String phase;
  final int receivedBytes;
  final int? totalBytes;

  /// 0.0–1.0 when known, else null (indeterminate).
  final double? fraction;

  String get label {
    if (phase == 'extracting') {
      return 'Extracting…';
    }
    final receivedMb = receivedBytes / (1024 * 1024);
    final total = totalBytes;
    if (total != null && total > 0) {
      final totalMb = total / (1024 * 1024);
      final pct = ((fraction ?? 0) * 100).clamp(0, 100).round();
      return '${receivedMb.toStringAsFixed(0)} / '
          '${totalMb.toStringAsFixed(0)} MB · $pct%';
    }
    if (receivedBytes > 0) {
      return '${receivedMb.toStringAsFixed(0)} MB…';
    }
    return 'Starting download…';
  }
}

class OfflineDictationException implements Exception {
  const OfflineDictationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolved on-disk paths for one catalog model. Sendable across
/// isolates (plain strings only).
class OfflineSttResolvedFiles {
  const OfflineSttResolvedFiles({
    required this.family,
    required this.tokens,
    required this.modelType,
    this.encoder = '',
    this.decoder = '',
    this.joiner = '',
    this.model = '',
    this.preprocessor = '',
    this.uncachedDecoder = '',
    this.cachedDecoder = '',
  });

  final OfflineSttFamily family;
  final String tokens;
  final String modelType;
  final String encoder;
  final String decoder;
  final String joiner;
  final String model;
  final String preprocessor;
  final String uncachedDecoder;
  final String cachedDecoder;

  bool get allExist {
    if (!File(tokens).existsSync()) return false;
    switch (family) {
      case OfflineSttFamily.moonshine:
        return File(preprocessor).existsSync() &&
            File(encoder).existsSync() &&
            File(uncachedDecoder).existsSync() &&
            File(cachedDecoder).existsSync();
      case OfflineSttFamily.transducer:
        return File(encoder).existsSync() &&
            File(decoder).existsSync() &&
            File(joiner).existsSync();
      case OfflineSttFamily.whisper:
        return File(encoder).existsSync() && File(decoder).existsSync();
      case OfflineSttFamily.senseVoice:
        return File(model).existsSync();
    }
  }

  /// Pure descriptor for unit tests — no sherpa FFI.
  Map<String, Object?> toConfigDescriptor() {
    return <String, Object?>{
      'family': family.name,
      'modelType': modelType,
      'tokens': tokens,
      'encoder': encoder,
      'decoder': decoder,
      'joiner': joiner,
      'model': model,
      'preprocessor': preprocessor,
      'uncachedDecoder': uncachedDecoder,
      'cachedDecoder': cachedDecoder,
    };
  }
}

/// Build resolved file paths for [model] under [modelDir].
/// Pure path join — safe for unit tests.
OfflineSttResolvedFiles resolveOfflineSttFiles(
  OfflineSttModel model,
  String modelDirPath,
) {
  String join(String? rel) =>
      rel == null || rel.isEmpty ? '' : p.join(modelDirPath, rel);
  return OfflineSttResolvedFiles(
    family: model.family,
    tokens: join(model.tokensRelPath),
    modelType: model.modelType,
    encoder: join(model.encoderRelPath),
    decoder: join(model.decoderRelPath),
    joiner: join(model.joinerRelPath),
    model: join(model.modelRelPath),
    preprocessor: join(model.preprocessorRelPath),
    uncachedDecoder: join(model.uncachedDecoderRelPath),
    cachedDecoder: join(model.cachedDecoderRelPath),
  );
}

class OfflineDictationService {
  OfflineDictationService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder() {
    _statuses = ValueNotifier<Map<String, OfflineSttStatus>>(
      _initialStatuses(),
    );
    _progress = ValueNotifier<Map<String, OfflineSttDownloadProgress>>(
      const <String, OfflineSttDownloadProgress>{},
    );
  }

  static const _sampleRate = 16000;

  final AudioRecorder _recorder;

  final List<Float32List> _sampleChunks = [];
  int _sampleCount = 0;
  StreamSubscription<Uint8List>? _audioSub;
  Timer? _liveTranscriptionTimer;
  void Function(String)? _onTranscript;
  bool _isTranscribingLive = false;
  String _lastTranscript = '';

  String _selectedModelId = OfflineSttCatalog.defaultModel.id;
  late final ValueNotifier<Map<String, OfflineSttStatus>> _statuses;
  late final ValueNotifier<Map<String, OfflineSttDownloadProgress>> _progress;
  final Map<String, Object?> _errors = <String, Object?>{};
  final Map<String, Future<OfflineSttResolvedFiles>> _inflight =
      <String, Future<OfflineSttResolvedFiles>>{};

  static Map<String, OfflineSttStatus> _initialStatuses() {
    return {
      for (final m in OfflineSttCatalog.all)
        m.id: OfflineSttStatus.notDownloaded,
    };
  }

  ValueListenable<Map<String, OfflineSttStatus>> get statuses => _statuses;

  /// Per-model download/extract progress while status is downloading.
  ValueListenable<Map<String, OfflineSttDownloadProgress>> get progress =>
      _progress;

  OfflineSttDownloadProgress? progressFor(String modelId) =>
      _progress.value[modelId];

  List<OfflineSttModel> get models =>
      List<OfflineSttModel>.unmodifiable(OfflineSttCatalog.all);

  String get selectedModelId => _selectedModelId;

  OfflineSttModel get selectedModel =>
      OfflineSttCatalog.byId(_selectedModelId) ??
      OfflineSttCatalog.defaultModel;

  OfflineSttStatus statusFor(String modelId) =>
      _statuses.value[modelId] ?? OfflineSttStatus.notDownloaded;

  Object? errorFor(String modelId) => _errors[modelId];

  /// In-memory selection only. Persist via Settings.sttModelId.
  void selectModel(String? modelId) {
    final resolved = OfflineSttCatalog.byId(modelId)?.id ??
        OfflineSttCatalog.defaultModel.id;
    _selectedModelId = resolved;
  }

  Stream<double> levels({
    Duration interval = const Duration(milliseconds: 200),
  }) {
    return _recorder
        .onAmplitudeChanged(interval)
        .map((amplitude) => amplitude.current);
  }

  /// Probe + refresh on-disk statuses. Does **not** auto-download.
  Future<void> initialize() async {
    await refreshStatuses();
  }

  Future<void> refreshStatuses() async {
    final Directory supportDir;
    try {
      supportDir = await getApplicationSupportDirectory();
    } catch (e) {
      logger.info(
        '[OfflineSTT] refreshStatuses skipped: path_provider unavailable: $e',
      );
      return;
    }
    final next = <String, OfflineSttStatus>{};
    for (final model in OfflineSttCatalog.all) {
      final current = _statuses.value[model.id];
      if (current == OfflineSttStatus.downloading ||
          current == OfflineSttStatus.failed) {
        next[model.id] = current!;
        continue;
      }
      final dir = Directory(p.join(supportDir.path, 'speech', 'stt', model.id));
      final resolved = resolveOfflineSttFiles(model, dir.path);
      next[model.id] = resolved.allExist
          ? OfflineSttStatus.ready
          : OfflineSttStatus.notDownloaded;
    }
    _statuses.value = next;
  }

  Future<void> ensureReady() => ensureModel(_selectedModelId);

  Future<void> ensureModel(String modelId) async {
    final model = OfflineSttCatalog.byId(modelId);
    if (model == null) {
      throw OfflineDictationException('Unknown offline STT model: $modelId');
    }
    await _ensureFilesOnce(model);
  }

  Future<void> deleteModel(String modelId) async {
    if (_inflight.containsKey(modelId)) {
      throw const OfflineDictationException(
        'Cannot delete a model while it is downloading',
      );
    }
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'speech', 'stt', modelId));
    if (dir.existsSync()) {
      try {
        await dir.delete(recursive: true);
      } catch (e, st) {
        logger.warning('[OfflineSTT] delete failed for $modelId: $e', e, st);
        rethrow;
      }
    }
    _errors.remove(modelId);
    _setStatusFor(modelId, OfflineSttStatus.notDownloaded);
  }

  Future<void> start({void Function(String text)? onTranscript}) async {
    if (await _recorder.isRecording()) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const OfflineDictationException(
        'Microphone permission is required',
      );
    }

    const encoder = AudioEncoder.pcm16bits;
    if (!await _recorder.isEncoderSupported(encoder)) {
      throw const OfflineDictationException(
        'Offline dictation requires PCM recording support',
      );
    }

    _sampleChunks.clear();
    _sampleCount = 0;
    _lastTranscript = '';
    _onTranscript = onTranscript;
    // Block until the selected model is on disk. Callers (chat mic)
    // show a "Downloading model…" state while this awaits so the user
    // never records into a model that isn't ready yet.
    await ensureReady();

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: encoder,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );
    _audioSub = stream.listen(
      _handleAudioChunk,
      onError: (Object error, StackTrace stack) {
        logger.warning('Offline dictation audio stream failed', error, stack);
      },
    );
    _startLiveTranscription();
  }

  Future<String?> stop() async {
    _stopLiveTranscription();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _audioSub?.cancel();
    _audioSub = null;
    return null;
  }

  Future<String> stopAndTranscribe() async {
    try {
      await stop();
      final samples = _capturedSamples();
      if (samples.isEmpty) {
        throw const OfflineDictationException('No recording was captured');
      }

      final text = await _transcribeSamples(samples, _sampleRate);
      if (text.isEmpty && _lastTranscript.isNotEmpty) {
        return _lastTranscript;
      }
      if (text.isEmpty) {
        throw const OfflineDictationException('No speech was transcribed');
      }
      return text;
    } on OfflineDictationException {
      rethrow;
    } catch (error, stack) {
      logger.warning('Offline dictation failed', error, stack);
      throw const OfflineDictationException('Transcription failed');
    }
  }

  Future<void> cancel() async {
    _stopLiveTranscription();
    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }
    await _audioSub?.cancel();
    _audioSub = null;
    _sampleChunks.clear();
    _sampleCount = 0;
    _lastTranscript = '';
  }

  Future<String> transcribe({required String audioPath}) async {
    try {
      await ensureReady();
      final files = await _ensureFilesOnce(selectedModel);
      final req = _OfflineTranscriptionRequest(
        audioPath: audioPath,
        files: files,
      );
      final text = await Isolate.run(() => _transcribeInWorker(req));
      if (text.isEmpty) {
        throw const OfflineDictationException('No speech was transcribed');
      }
      return text;
    } on OfflineDictationException {
      rethrow;
    } catch (error, stack) {
      logger.warning('Offline dictation failed', error, stack);
      throw const OfflineDictationException('Transcription failed');
    }
  }

  Future<void> dispose() async {
    _stopLiveTranscription();
    await _audioSub?.cancel();
    await _recorder.dispose();
    _statuses.dispose();
    _progress.dispose();
  }

  void _handleAudioChunk(Uint8List bytes) {
    final samples = _pcm16ToFloat32(bytes);
    if (samples.isEmpty) {
      return;
    }
    _sampleChunks.add(samples);
    _sampleCount += samples.length;
  }

  Float32List _pcm16ToFloat32(Uint8List bytes) {
    final sampleCount = bytes.length ~/ 2;
    if (sampleCount == 0) {
      return Float32List(0);
    }

    final data = ByteData.sublistView(bytes, 0, sampleCount * 2);
    final samples = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }

  Float32List _capturedSamples() {
    final samples = Float32List(_sampleCount);
    var offset = 0;
    for (final chunk in _sampleChunks) {
      samples.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return samples;
  }

  void _startLiveTranscription() {
    if (_onTranscript == null) {
      return;
    }
    _liveTranscriptionTimer = Timer.periodic(
      const Duration(milliseconds: 1400),
      (_) => unawaited(_transcribeLive()),
    );
  }

  void _stopLiveTranscription() {
    _liveTranscriptionTimer?.cancel();
    _liveTranscriptionTimer = null;
  }

  Future<void> _transcribeLive() async {
    if (_isTranscribingLive || _sampleCount < _sampleRate ~/ 2) {
      return;
    }

    _isTranscribingLive = true;
    try {
      final text = await _transcribeSamples(_capturedSamples(), _sampleRate);
      if (_liveTranscriptionTimer == null) {
        return;
      }
      if (text.isNotEmpty && text != _lastTranscript) {
        _lastTranscript = text;
        _onTranscript?.call(text);
      }
    } catch (error, stack) {
      logger.warning(
        'Offline dictation live transcription failed',
        error,
        stack,
      );
    } finally {
      _isTranscribingLive = false;
    }
  }

  Future<String> _transcribeSamples(Float32List samples, int sampleRate) async {
    final files = await _ensureFilesOnce(selectedModel);
    final req = _OfflineTranscriptionRequest(
      files: files,
      samples: samples,
      sampleRate: sampleRate,
    );
    return Isolate.run(() => _transcribeInWorker(req));
  }

  Future<OfflineSttResolvedFiles> _ensureFilesOnce(OfflineSttModel model) {
    final existing = _inflight[model.id];
    if (existing != null) return existing;
    final future = _ensureFiles(model);
    _inflight[model.id] = future;
    unawaited(
      future.then<void>(
        (_) {
          _inflight.remove(model.id);
          _errors.remove(model.id);
          _setStatusFor(model.id, OfflineSttStatus.ready);
        },
        onError: (Object e, StackTrace st) {
          _inflight.remove(model.id);
          _errors[model.id] = e;
          logger.error(
            '[OfflineSTT] ensureModel failed for ${model.id}: $e',
            e,
            st,
          );
          _setStatusFor(model.id, OfflineSttStatus.failed);
        },
      ),
    );
    return future;
  }

  Future<OfflineSttResolvedFiles> _ensureFiles(OfflineSttModel model) async {
    logger.info('[OfflineSTT] ensureFiles: model=${model.id}');
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory(
      p.join(supportDir.path, 'speech', 'stt', model.id),
    );
    await modelDir.create(recursive: true);
    final resolved = resolveOfflineSttFiles(model, modelDir.path);
    if (resolved.allExist) {
      logger.info('[OfflineSTT] ensureFiles: cache hit at ${modelDir.path}');
      _setStatusFor(model.id, OfflineSttStatus.ready);
      return resolved;
    }

    logger.info(
      '[OfflineSTT] ensureFiles: cache miss; '
      'will download into ${modelDir.path}',
    );
    _errors.remove(model.id);
    _setStatusFor(model.id, OfflineSttStatus.downloading);
    await _downloadAndExtract(model, modelDir);
    final after = resolveOfflineSttFiles(model, modelDir.path);
    if (!after.allExist) {
      final missing = model.requiredFiles
          .where((name) => !File(p.join(modelDir.path, name)).existsSync())
          .join(', ');
      throw OfflineDictationException(
        'Offline speech model incomplete after extract'
        '${missing.isEmpty ? '' : ': missing $missing'}',
      );
    }
    logger.info('[OfflineSTT] ensureFiles: ready at ${modelDir.path}');
    return after;
  }

  Future<void> _downloadAndExtract(
    OfflineSttModel model,
    Directory modelDir,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final archiveFile = File(
      p.join(tempDir.path, 'sherpa_stt_${model.id}.tar.bz2'),
    );

    try {
      await _downloadModelArchive(
        modelId: model.id,
        url: model.archiveUrl,
        target: archiveFile,
        approximateBytes: model.approximateBytes,
      );
      _setProgressFor(
        model.id,
        OfflineSttDownloadProgress(
          modelId: model.id,
          phase: 'extracting',
        ),
      );
      // Hoist plain strings so the isolate closure never captures `this`.
      final archivePath = archiveFile.path;
      final modelDirPath = modelDir.path;
      final archiveRoot = model.archiveRoot;
      final sha = model.archiveSha256;
      final required = model.requiredFiles.toList(growable: false);
      await Isolate.run(
        () => _verifyAndExtractModelArchive(
          archivePath: archivePath,
          modelDirPath: modelDirPath,
          archiveRoot: archiveRoot,
          expectedSha256: sha,
          requiredFiles: required,
        ),
      );
    } on OfflineDictationException {
      rethrow;
    } catch (error, stack) {
      logger.warning('Offline speech model download failed', error, stack);
      throw OfflineDictationException(
        'Failed to download offline speech model: $error',
      );
    } finally {
      _clearProgressFor(model.id);
      if (archiveFile.existsSync()) {
        await archiveFile.delete();
      }
    }
  }

  Future<void> _downloadModelArchive({
    required String modelId,
    required String url,
    required File target,
    required int approximateBytes,
  }) async {
    logger.info('[OfflineSTT] download: GET $url -> ${target.path}');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 5)
      ..userAgent = 'happy_flutter/offline-stt';
    try {
      final request = await client.getUrl(Uri.parse(url))
        // Explicit so a future Dart change doesn't break GitHub
        // release-asset redirects (302 → release-assets.githubusercontent).
        ..followRedirects = true
        ..maxRedirects = 5;
      final response = await request.close();
      logger.info(
        '[OfflineSTT] download: status=${response.statusCode} '
        'contentLength=${response.contentLength}',
      );
      if (response.statusCode == 404) {
        throw OfflineDictationException(
          'Speech model not found on upstream mirror (HTTP 404): $url',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OfflineDictationException(
          'Speech model download failed: HTTP ${response.statusCode} from $url',
        );
      }

      final contentLength = response.contentLength;
      final totalBytes = contentLength > 0
          ? contentLength
          : (approximateBytes > 0 ? approximateBytes : null);
      var received = 0;
      var lastEmitMs = 0;
      final sink = target.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          // Throttle UI updates to ~8/s so rebuilds stay cheap.
          if (nowMs - lastEmitMs < 120 &&
              (totalBytes == null || received < totalBytes)) {
            continue;
          }
          lastEmitMs = nowMs;
          final fraction = totalBytes == null
              ? null
              : (received / totalBytes).clamp(0.0, 1.0);
          _setProgressFor(
            modelId,
            OfflineSttDownloadProgress(
              modelId: modelId,
              phase: 'downloading',
              receivedBytes: received,
              totalBytes: totalBytes,
              fraction: fraction,
            ),
          );
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received <= 0) {
        throw const OfflineDictationException(
          'Speech model download returned empty body',
        );
      }
      // Final 100% tick if we know the size.
      if (totalBytes != null) {
        _setProgressFor(
          modelId,
          OfflineSttDownloadProgress(
            modelId: modelId,
            phase: 'downloading',
            receivedBytes: received,
            totalBytes: totalBytes,
            fraction: 1.0,
          ),
        );
      }
      logger.info(
        '[OfflineSTT] download: completed '
        '${(received / (1024 * 1024)).toStringAsFixed(1)}MB',
      );
    } on OfflineDictationException {
      rethrow;
    } catch (error, stack) {
      logger.warning('[OfflineSTT] download transport failed', error, stack);
      throw OfflineDictationException(
        'Speech model download transport failed: $error',
      );
    } finally {
      client.close(force: true);
    }
  }

  void _setStatusFor(String modelId, OfflineSttStatus status) {
    final next = Map<String, OfflineSttStatus>.from(_statuses.value);
    next[modelId] = status;
    _statuses.value = next;
  }

  void _setProgressFor(String modelId, OfflineSttDownloadProgress progress) {
    final next = Map<String, OfflineSttDownloadProgress>.from(_progress.value);
    next[modelId] = progress;
    _progress.value = next;
  }

  void _clearProgressFor(String modelId) {
    if (!_progress.value.containsKey(modelId)) return;
    final next = Map<String, OfflineSttDownloadProgress>.from(
      _progress.value,
    )..remove(modelId);
    _progress.value = next;
  }
}

/// Stream-extract a `.tar.bz2` without loading the full archive into RAM.
///
/// Previous `readAsBytes` + `BZip2Decoder().decodeBytes` path doubled
/// ~500MB models in memory and OOM'd phones on Parakeet / turbo.
Future<void> _verifyAndExtractModelArchive({
  required String archivePath,
  required String modelDirPath,
  required String archiveRoot,
  required String expectedSha256,
  required List<String> requiredFiles,
}) async {
  // Stream the SHA so we never hold the whole archive as a byte list.
  final digest = await sha256.bind(File(archivePath).openRead()).single;
  final actualSha = digest.toString();
  if (actualSha != expectedSha256) {
    throw OfflineDictationException(
      'Offline speech model checksum mismatch '
      '(expected ${expectedSha256.substring(0, 12)}…, '
      'got ${actualSha.substring(0, 12)}…)',
    );
  }

  final tempDir = Directory.systemTemp.createTempSync('stt_extract_');
  final tarPath = p.join(tempDir.path, 'model.tar');
  try {
    // Stage 1: stream-decompress bz2 → temp tar on disk.
    final bzInput = InputFileStream(archivePath);
    final bzOutput = OutputFileStream(tarPath);
    try {
      final ok = BZip2Decoder().decodeStream(bzInput, bzOutput, verify: true);
      if (!ok) {
        throw const OfflineDictationException(
          'Failed to decompress speech model archive (bzip2)',
        );
      }
    } finally {
      await bzInput.close();
      await bzOutput.close();
    }

    // Stage 2: stream-read tar and write only required basenames.
    final tarInput = InputFileStream(tarPath);
    try {
      final archive = TarDecoder().decodeStream(tarInput);
      final required = requiredFiles.toSet();
      final extracted = <String>{};

      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = p.basename(file.name);
        if (!required.contains(name) || !file.name.contains(archiveRoot)) {
          continue;
        }
        final outPath = p.join(modelDirPath, name);
        final out = OutputFileStream(outPath);
        try {
          file.writeContent(out);
        } finally {
          await out.close();
        }
        extracted.add(name);
      }

      if (extracted.length != required.length) {
        final missing = required.difference(extracted);
        throw OfflineDictationException(
          'Offline speech model archive is missing files: '
          '${missing.join(', ')}',
        );
      }
    } finally {
      await tarInput.close();
    }
  } on OfflineDictationException {
    rethrow;
  } catch (error) {
    throw OfflineDictationException(
      'Failed to extract speech model archive: $error',
    );
  } finally {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {
      // best effort
    }
  }
}

String _transcribeInWorker(_OfflineTranscriptionRequest request) {
  sherpa.initBindings();
  final files = request.files;
  final sherpa.OfflineModelConfig modelConfig;
  switch (files.family) {
    case OfflineSttFamily.moonshine:
      modelConfig = sherpa.OfflineModelConfig(
        moonshine: sherpa.OfflineMoonshineModelConfig(
          preprocessor: files.preprocessor,
          encoder: files.encoder,
          uncachedDecoder: files.uncachedDecoder,
          cachedDecoder: files.cachedDecoder,
        ),
        tokens: files.tokens,
        numThreads: 2,
        debug: false,
      );
    case OfflineSttFamily.transducer:
      modelConfig = sherpa.OfflineModelConfig(
        transducer: sherpa.OfflineTransducerModelConfig(
          encoder: files.encoder,
          decoder: files.decoder,
          joiner: files.joiner,
        ),
        tokens: files.tokens,
        numThreads: 2,
        debug: false,
        modelType: files.modelType.isEmpty
            ? 'nemo_transducer'
            : files.modelType,
      );
    case OfflineSttFamily.whisper:
      modelConfig = sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: files.encoder,
          decoder: files.decoder,
        ),
        tokens: files.tokens,
        numThreads: 2,
        debug: false,
        modelType: files.modelType.isEmpty ? 'whisper' : files.modelType,
      );
    case OfflineSttFamily.senseVoice:
      modelConfig = sherpa.OfflineModelConfig(
        senseVoice: sherpa.OfflineSenseVoiceModelConfig(
          model: files.model,
          language: 'auto',
          useInverseTextNormalization: true,
        ),
        tokens: files.tokens,
        numThreads: 2,
        debug: false,
      );
  }

  final config = sherpa.OfflineRecognizerConfig(model: modelConfig);
  final recognizer = sherpa.OfflineRecognizer(config);
  final stream = recognizer.createStream();
  try {
    final audioPath = request.audioPath;
    final samples = request.samples;
    if (samples != null) {
      stream.acceptWaveform(samples: samples, sampleRate: request.sampleRate);
    } else if (audioPath != null) {
      final wave = sherpa.readWave(audioPath);
      if (wave.samples.isEmpty || wave.sampleRate <= 0) {
        throw const OfflineDictationException('No recording was captured');
      }
      stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
    } else {
      throw const OfflineDictationException('No recording was captured');
    }
    recognizer.decode(stream);
    return recognizer.getResult(stream).text.trim();
  } finally {
    stream.free();
    recognizer.free();
  }
}

class _OfflineTranscriptionRequest {
  const _OfflineTranscriptionRequest({
    required this.files,
    this.audioPath,
    this.samples,
    this.sampleRate = 16000,
  });

  final String? audioPath;
  final Float32List? samples;
  final int sampleRate;
  final OfflineSttResolvedFiles files;
}
