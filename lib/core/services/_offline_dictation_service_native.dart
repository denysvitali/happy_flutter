import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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
  static const _modelUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'sherpa-onnx-moonshine-tiny-en-int8.tar.bz2';
  static const _modelSha256 =
      'd5fe6ec4334fef36255b2a4010412cad4c007e33103fec62fb5d17cad88086f2';
  static const _archiveRoot = 'sherpa-onnx-moonshine-tiny-en-int8';
  static const _modelFileNames = {
    'preprocess.onnx',
    'encode.int8.onnx',
    'uncached_decode.int8.onnx',
    'cached_decode.int8.onnx',
    'tokens.txt',
  };

  final AudioRecorder _recorder;

  String? _recordingPath;

  Stream<double> levels({
    Duration interval = const Duration(milliseconds: 200),
  }) {
    return _recorder
        .onAmplitudeChanged(interval)
        .map((amplitude) => amplitude.current);
  }

  Future<void> start() async {
    if (await _recorder.isRecording()) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const OfflineDictationException(
        'Microphone permission is required',
      );
    }

    const encoder = AudioEncoder.wav;
    if (!await _recorder.isEncoderSupported(encoder)) {
      throw const OfflineDictationException(
        'Offline dictation requires WAV recording support',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final path = p.join(
      tempDir.path,
      'happy_dictation_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: encoder,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
      path: path,
    );
    _recordingPath = path;
  }

  Future<String?> stop() async {
    if (!await _recorder.isRecording()) {
      return _recordingPath;
    }
    final path = await _recorder.stop();
    _recordingPath = path;
    return path;
  }

  Future<void> cancel() async {
    if (await _recorder.isRecording()) {
      await _recorder.cancel();
    }
    _recordingPath = null;
  }

  Future<String> transcribe({required String audioPath}) async {
    try {
      final files = await _ensureModelFiles();
      final text = await Isolate.run(
        () => _transcribeInWorker(
          _OfflineTranscriptionRequest(audioPath: audioPath, files: files),
        ),
      );
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
    await _recorder.dispose();
  }

  Future<_MoonshineModelFiles> _ensureModelFiles() async {
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory(
      p.join(supportDir.path, 'speech', 'moonshine_tiny_en_int8'),
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

  _MoonshineModelFiles _modelFiles(Directory modelDir) {
    return _MoonshineModelFiles(
      preprocessor: p.join(modelDir.path, 'preprocess.onnx'),
      encoder: p.join(modelDir.path, 'encode.int8.onnx'),
      uncachedDecoder: p.join(modelDir.path, 'uncached_decode.int8.onnx'),
      cachedDecoder: p.join(modelDir.path, 'cached_decode.int8.onnx'),
      tokens: p.join(modelDir.path, 'tokens.txt'),
    );
  }

  Future<void> _downloadAndExtractModel(Directory modelDir) async {
    final tempDir = await getTemporaryDirectory();
    final archiveFile = File(
      p.join(tempDir.path, 'sherpa_moonshine_tiny_en_int8.tar.bz2'),
    );

    try {
      await _downloadModelArchive(archiveFile);
      final bytes = await archiveFile.readAsBytes();
      final actualSha = sha256.convert(bytes).toString();
      if (actualSha != _modelSha256) {
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
        if (!_modelFileNames.contains(name) ||
            !file.name.contains(_archiveRoot)) {
          continue;
        }

        await File(
          p.join(modelDir.path, name),
        ).writeAsBytes(file.content, flush: true);
        extracted.add(name);
      }

      if (extracted.length != _modelFileNames.length) {
        throw const OfflineDictationException(
          'Offline speech model archive is missing files',
        );
      }
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

String _transcribeInWorker(_OfflineTranscriptionRequest request) {
  sherpa.initBindings();
  final config = sherpa.OfflineRecognizerConfig(
    model: sherpa.OfflineModelConfig(
      moonshine: sherpa.OfflineMoonshineModelConfig(
        preprocessor: request.files.preprocessor,
        encoder: request.files.encoder,
        uncachedDecoder: request.files.uncachedDecoder,
        cachedDecoder: request.files.cachedDecoder,
      ),
      tokens: request.files.tokens,
      numThreads: 2,
      debug: false,
    ),
  );

  final recognizer = sherpa.OfflineRecognizer(config);
  final stream = recognizer.createStream();
  try {
    final wave = sherpa.readWave(request.audioPath);
    stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);
    recognizer.decode(stream);
    return recognizer.getResult(stream).text.trim();
  } finally {
    stream.free();
    recognizer.free();
  }
}

class _OfflineTranscriptionRequest {
  const _OfflineTranscriptionRequest({
    required this.audioPath,
    required this.files,
  });

  final String audioPath;
  final _MoonshineModelFiles files;
}

class _MoonshineModelFiles {
  const _MoonshineModelFiles({
    required this.preprocessor,
    required this.encoder,
    required this.uncachedDecoder,
    required this.cachedDecoder,
    required this.tokens,
  });

  final String preprocessor;
  final String encoder;
  final String uncachedDecoder;
  final String cachedDecoder;
  final String tokens;

  bool get allExist =>
      File(preprocessor).existsSync() &&
      File(encoder).existsSync() &&
      File(uncachedDecoder).existsSync() &&
      File(cachedDecoder).existsSync() &&
      File(tokens).existsSync();
}
