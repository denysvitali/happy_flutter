import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show rootBundle;
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
  static const _assetRoot = 'assets/speech/moonshine_tiny_en_int8';

  final AudioRecorder _recorder;

  sherpa.OfflineRecognizer? _recognizer;
  Future<sherpa.OfflineRecognizer>? _recognizerFuture;
  String? _recordingPath;
  bool _bindingsInitialized = false;

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
      final recognizer = await _ensureRecognizer();
      final wave = sherpa.readWave(audioPath);
      final stream = recognizer.createStream();
      try {
        stream.acceptWaveform(
          samples: wave.samples,
          sampleRate: wave.sampleRate,
        );
        recognizer.decode(stream);

        final text = recognizer.getResult(stream).text.trim();
        if (text.isEmpty) {
          throw const OfflineDictationException('No speech was transcribed');
        }
        return text;
      } finally {
        stream.free();
      }
    } on OfflineDictationException {
      rethrow;
    } catch (error, stack) {
      logger.warning('Offline dictation failed', error, stack);
      throw const OfflineDictationException('Transcription failed');
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
    _recognizer?.free();
    _recognizer = null;
  }

  Future<sherpa.OfflineRecognizer> _ensureRecognizer() {
    final existing = _recognizer;
    if (existing != null) {
      return Future.value(existing);
    }

    return _recognizerFuture ??= _createRecognizer().then((recognizer) {
      _recognizer = recognizer;
      _recognizerFuture = null;
      return recognizer;
    });
  }

  Future<sherpa.OfflineRecognizer> _createRecognizer() async {
    if (!_bindingsInitialized) {
      sherpa.initBindings();
      _bindingsInitialized = true;
    }

    final files = await _copyModelFiles();
    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        moonshine: sherpa.OfflineMoonshineModelConfig(
          preprocessor: files.preprocessor,
          encoder: files.encoder,
          uncachedDecoder: files.uncachedDecoder,
          cachedDecoder: files.cachedDecoder,
        ),
        tokens: files.tokens,
        numThreads: 2,
        debug: false,
      ),
    );

    return sherpa.OfflineRecognizer(config);
  }

  Future<_MoonshineModelFiles> _copyModelFiles() async {
    final supportDir = await getApplicationSupportDirectory();
    final modelDir = Directory(
      p.join(supportDir.path, 'speech', 'moonshine_tiny_en_int8'),
    );
    await modelDir.create(recursive: true);

    return _MoonshineModelFiles(
      preprocessor: await _copyAssetFile(
        '$_assetRoot/preprocess.onnx',
        modelDir,
      ),
      encoder: await _copyAssetFile('$_assetRoot/encode.int8.onnx', modelDir),
      uncachedDecoder: await _copyAssetFile(
        '$_assetRoot/uncached_decode.int8.onnx',
        modelDir,
      ),
      cachedDecoder: await _copyAssetFile(
        '$_assetRoot/cached_decode.int8.onnx',
        modelDir,
      ),
      tokens: await _copyAssetFile('$_assetRoot/tokens.txt', modelDir),
    );
  }

  Future<String> _copyAssetFile(String assetPath, Directory modelDir) async {
    final data = await _loadModelAsset(assetPath);
    final target = File(p.join(modelDir.path, p.basename(assetPath)));

    final shouldWrite =
        !target.existsSync() || target.lengthSync() != data.lengthInBytes;
    if (shouldWrite) {
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return target.path;
  }

  Future<ByteData> _loadModelAsset(String assetPath) async {
    try {
      return await rootBundle.load(assetPath);
    } on FlutterError {
      throw const OfflineDictationException(
        'Offline speech model is not bundled in this build',
      );
    }
  }
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
}
