import 'package:flutter/foundation.dart';

class OfflineTtsException implements Exception {
  const OfflineTtsException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum OfflineTtsStatus { notDownloaded, downloading, ready, failed }

/// Web stub: offline TTS isn't available on web (no isolate +
/// FFI), so the chat falls back to the system flutter_tts engine.
class OfflineTtsService {
  factory OfflineTtsService() => _instance;
  OfflineTtsService._();
  static final OfflineTtsService _instance = OfflineTtsService._();

  final ValueNotifier<String?> _currentToken = ValueNotifier<String?>(null);
  final ValueNotifier<OfflineTtsStatus> _status =
      ValueNotifier<OfflineTtsStatus>(OfflineTtsStatus.notDownloaded);

  ValueListenable<String?> get currentToken => _currentToken;
  ValueListenable<OfflineTtsStatus> get status => _status;
  Object? get lastError => null;
  bool get isSpeaking => false;
  bool get isSupported => false;

  Future<void> ensureReady() async {
    throw const OfflineTtsException(
      'Offline TTS is not supported on this platform',
    );
  }

  Future<void> speak(String text, {String? token}) async {
    throw const OfflineTtsException(
      'Offline TTS is not supported on this platform',
    );
  }

  Future<void> stop() async {}
  Future<void> dispose() async {}
}
