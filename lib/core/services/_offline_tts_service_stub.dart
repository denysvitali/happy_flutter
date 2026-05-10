import 'package:flutter/foundation.dart';

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
  final String id;
  final String displayName;
  final String locale;
  final String gender;
  final String quality;
  final String archiveUrl;
  final String archiveSha256;
  final int approximateBytes;
  final String archiveRoot;
  final String modelRelPath;
  final String tokensRelPath;
  final String dataDirRelPath;
  final int expectedSampleRate;

  String get sizeLabel => '';
}

class OfflineTtsCatalog {
  const OfflineTtsCatalog._();
  static final List<OfflineTtsModel> all = const <OfflineTtsModel>[];
  static OfflineTtsModel? get defaultModel => null;
  static OfflineTtsModel? byId(String? id) => null;
}

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
  final ValueNotifier<Map<String, OfflineTtsStatus>> _statuses =
      ValueNotifier<Map<String, OfflineTtsStatus>>(
    const <String, OfflineTtsStatus>{},
  );

  ValueListenable<String?> get currentToken => _currentToken;
  ValueListenable<OfflineTtsStatus> get status => _status;
  ValueListenable<Map<String, OfflineTtsStatus>> get statuses => _statuses;
  Object? get lastError => null;
  Object? errorFor(String _) => null;
  bool get isSpeaking => false;
  bool get isSupported => false;
  List<OfflineTtsModel> get voices => const <OfflineTtsModel>[];
  String get selectedVoiceId => '';
  OfflineTtsModel? get selectedVoice => null;
  void selectVoice(String _) {}
  OfflineTtsStatus statusFor(String _) => OfflineTtsStatus.notDownloaded;
  Future<void> refreshStatuses() async {}

  Future<void> ensureReady() async {
    throw const OfflineTtsException(
      'Offline TTS is not supported on this platform',
    );
  }

  Future<void> ensureVoice(String _) async {
    throw const OfflineTtsException(
      'Offline TTS is not supported on this platform',
    );
  }

  Future<void> deleteVoice(String _) async {}

  Future<void> speak(String text, {String? token, String? voiceId}) async {
    throw const OfflineTtsException(
      'Offline TTS is not supported on this platform',
    );
  }

  Future<void> stop() async {}
  Future<void> dispose() async {}
}
