import 'dart:async';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'logger_service.dart' show logger;

class WhisperDictationException implements Exception {
  const WhisperDictationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WhisperDictationConfig {
  const WhisperDictationConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'whisper-1',
  });

  final String apiKey;
  final String baseUrl;
  final String model;
}

class WhisperDictationService {
  WhisperDictationService({Dio? dio, AudioRecorder? recorder})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
            ),
          ),
      _recorder = recorder ?? AudioRecorder();

  final Dio _dio;
  final AudioRecorder _recorder;

  String? _recordingPath;

  Future<void> start() async {
    if (await _recorder.isRecording()) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw const WhisperDictationException(
        'Microphone permission is required',
      );
    }

    final tempDir = await getTemporaryDirectory();
    final path = p.join(
      tempDir.path,
      'happy_dictation_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 16000,
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

  Future<String> transcribe({
    required String audioPath,
    required WhisperDictationConfig config,
  }) async {
    final endpoint = _transcriptionEndpoint(config.baseUrl);

    try {
      final response = await _dio.post<dynamic>(
        endpoint,
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            audioPath,
            filename: p.basename(audioPath),
          ),
          'model': config.model,
          'response_format': 'json',
        }),
        options: Options(
          headers: {'Authorization': 'Bearer ${config.apiKey}'},
          contentType: 'multipart/form-data',
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw WhisperDictationException(
          _errorMessage(response.data) ?? 'Transcription failed',
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final text = data['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }

      throw const WhisperDictationException('No speech was transcribed');
    } on WhisperDictationException {
      rethrow;
    } catch (error, stack) {
      logger.warning('Whisper dictation failed', error, stack);
      throw const WhisperDictationException('Transcription failed');
    }
  }

  Future<void> dispose() => _recorder.dispose();

  String _transcriptionEndpoint(String baseUrl) {
    final trimmed = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/audio/transcriptions')) {
      return trimmed;
    }
    return '$trimmed/audio/transcriptions';
  }

  String? _errorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }
}
