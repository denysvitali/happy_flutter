import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'logger_service.dart' show logger;

class OfflineDictationException implements Exception {
  const OfflineDictationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineDictationService {
  OfflineDictationService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const _sampleRate = 16000;
  // NVIDIA Parakeet TDT 0.6B v3 (int8) via sherpa-onnx — 25 European
  // languages, punctuation + casing. Much larger than the old Moonshine
  // tiny (~640 MB on disk) but far more accurate for dictation.
  static const _modelUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8.tar.bz2';
  static const _modelSha256 =
      '5793d0fd397c5778d2cf2126994d58e9d56b1be7c04d13c7a15bb1b4eafb16bf';
  static const _archiveRoot =
      'sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8';
  static const _modelFileNames = {
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'joiner.int8.onnx',
    'tokens.txt',
  };

  final AudioRecorder _recorder;

  final List<Float32List> _sampleChunks = [];
  int _sampleCount = 0;
  StreamSubscription<Uint8List>? _audioSub;
  Timer? _liveTranscriptionTimer;
  Future<_ParakeetModelFiles>? _modelFilesFuture;
  void Function(String)? _onTranscript;
  bool _isTranscribingLive = false;
  String _lastTranscript = '';

  Stream<double> levels({
    Duration interval = const Duration(milliseconds: 200),
  }) {
    return _recorder
        .onAmplitudeChanged(interval)
        .map((amplitude) => amplitude.current);
  }

  Future<void> initialize() async {
    await _ensureModelFilesOnce();
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
    unawaited(_ensureModelFilesOnce());

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
      final files = await _ensureModelFilesOnce();
      // Build the request before spawning the isolate so the closure
      // captures only this sendable object — never `this`, which has
      // a `Future<_ParakeetModelFiles>? _modelFilesFuture` field
      // that would surface as
      // "Illegal argument in isolate message: object is unsendable
      // Library:'dart:async' Class: _Future".
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
    final files = await _ensureModelFilesOnce();
    // Build the request before spawning the isolate so the closure
    // captures only this sendable object — never `this`, which has a
    // `Future<_ParakeetModelFiles>? _modelFilesFuture` field that
    // would surface as
    // "Illegal argument in isolate message: object is unsendable
    // Library:'dart:async' Class: _Future" on production builds.
    final req = _OfflineTranscriptionRequest(
      files: files,
      samples: samples,
      sampleRate: sampleRate,
    );
    return Isolate.run(() => _transcribeInWorker(req));
  }

  Future<_ParakeetModelFiles> _ensureModelFilesOnce() {
    final existing = _modelFilesFuture;
    if (existing != null) {
      return existing;
    }

    final future = _ensureModelFiles();
    _modelFilesFuture = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {
          if (identical(_modelFilesFuture, future)) {
            _modelFilesFuture = null;
          }
        },
      ),
    );
    return future;
  }

  Future<_ParakeetModelFiles> _ensureModelFiles() async {
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory(
      p.join(supportDir.path, 'speech', 'parakeet_tdt_0_6b_v3_int8'),
    );
    await modelDir.create(recursive: true);
    var files = _modelFiles(modelDir);
    if (files.allExist) {
      return files;
    }

    await _downloadAndExtractModel(modelDir);
    files = _modelFiles(modelDir);
    if (!files.allExist) {
      throw const OfflineDictationException(
        'Offline speech model download is incomplete',
      );
    }

    return files;
  }

  _ParakeetModelFiles _modelFiles(Directory modelDir) {
    return _ParakeetModelFiles(
      encoder: p.join(modelDir.path, 'encoder.int8.onnx'),
      decoder: p.join(modelDir.path, 'decoder.int8.onnx'),
      joiner: p.join(modelDir.path, 'joiner.int8.onnx'),
      tokens: p.join(modelDir.path, 'tokens.txt'),
    );
  }

  Future<void> _downloadAndExtractModel(Directory modelDir) async {
    final tempDir = await getTemporaryDirectory();
    final archiveFile = File(
      p.join(tempDir.path, 'sherpa_parakeet_tdt_0_6b_v3_int8.tar.bz2'),
    );

    try {
      await _downloadModelArchive(archiveFile);
      // Hoist plain-string paths into locals so the closure captures
      // only sendable Strings — never `this`, which has a
      // `Future<_ParakeetModelFiles>? _modelFilesFuture` field that
      // is not sendable across an isolate boundary.
      final archivePath = archiveFile.path;
      final modelDirPath = modelDir.path;
      await Isolate.run(
        () => _verifyAndExtractModelArchive(
          archivePath: archivePath,
          modelDirPath: modelDirPath,
        ),
      );
    } on OfflineDictationException {
      rethrow;
    } catch (error, stack) {
      logger.warning('Offline speech model download failed', error, stack);
      throw const OfflineDictationException(
        'Failed to download offline speech model',
      );
    } finally {
      if (archiveFile.existsSync()) {
        await archiveFile.delete();
      }
    }
  }

  Future<void> _downloadModelArchive(File target) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(_modelUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OfflineDictationException(
          'Speech model download failed (${response.statusCode})',
        );
      }

      await response.pipe(target.openWrite());
    } finally {
      client.close(force: true);
    }
  }
}

Future<void> _verifyAndExtractModelArchive({
  required String archivePath,
  required String modelDirPath,
}) async {
  final bytes = await File(archivePath).readAsBytes();
  final actualSha = sha256.convert(bytes).toString();
  if (actualSha != OfflineDictationService._modelSha256) {
    throw const OfflineDictationException(
      'Offline speech model checksum mismatch',
    );
  }

  final tarBytes = BZip2Decoder().decodeBytes(bytes, verify: true);
  final archive = TarDecoder().decodeBytes(tarBytes);
  final extracted = <String>{};

  for (final file in archive.files) {
    if (!file.isFile) {
      continue;
    }

    final name = p.basename(file.name);
    if (!OfflineDictationService._modelFileNames.contains(name) ||
        !file.name.contains(OfflineDictationService._archiveRoot)) {
      continue;
    }

    await File(
      p.join(modelDirPath, name),
    ).writeAsBytes(file.content, flush: true);
    extracted.add(name);
  }

  if (extracted.length != OfflineDictationService._modelFileNames.length) {
    throw const OfflineDictationException(
      'Offline speech model archive is missing files',
    );
  }
}

String _transcribeInWorker(_OfflineTranscriptionRequest request) {
  sherpa.initBindings();
  final config = sherpa.OfflineRecognizerConfig(
    model: sherpa.OfflineModelConfig(
      transducer: sherpa.OfflineTransducerModelConfig(
        encoder: request.files.encoder,
        decoder: request.files.decoder,
        joiner: request.files.joiner,
      ),
      tokens: request.files.tokens,
      numThreads: 2,
      debug: false,
      // Required for NeMo Parakeet TDT — without this, sherpa may try
      // the wrong transducer layout and produce garbage / crash.
      modelType: 'nemo_transducer',
    ),
  );

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
  final _ParakeetModelFiles files;
}

class _ParakeetModelFiles {
  const _ParakeetModelFiles({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
  });

  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;

  bool get allExist =>
      File(encoder).existsSync() &&
      File(decoder).existsSync() &&
      File(joiner).existsSync() &&
      File(tokens).existsSync();
}
