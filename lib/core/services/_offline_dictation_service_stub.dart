import 'package:flutter/foundation.dart';

/// Offline ASR model family (stub mirror of the native enum).
enum OfflineSttFamily {
  moonshine,
  transducer,
  whisper,
  senseVoice,
}

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

  final String id;
  final String displayName;
  final String languages;
  final String tier;
  final String archiveUrl;
  final String archiveSha256;
  final int approximateBytes;
  final String archiveRoot;
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
  final String modelType;

  String get sizeLabel => '';
}

class OfflineSttCatalog {
  const OfflineSttCatalog._();

  static final List<OfflineSttModel> all = <OfflineSttModel>[
    const OfflineSttModel(
      id: 'parakeet-tdt-0.6b-v3-int8-v1',
      displayName: 'Parakeet TDT 0.6B v3',
      languages: '25 EU',
      tier: 'quality',
      archiveUrl: '',
      archiveSha256: '',
      approximateBytes: 0,
      archiveRoot: '',
      requiredFiles: {},
      family: OfflineSttFamily.transducer,
      tokensRelPath: 'tokens.txt',
      modelType: 'nemo_transducer',
    ),
  ];

  static OfflineSttModel get defaultModel => all.first;

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

class OfflineSttDownloadProgress {
  const OfflineSttDownloadProgress({
    required this.modelId,
    required this.phase,
    this.receivedBytes = 0,
    this.totalBytes,
    this.fraction,
  });

  final String modelId;
  final String phase;
  final int receivedBytes;
  final int? totalBytes;
  final double? fraction;

  String get label => 'Starting download…';
}

class OfflineDictationException implements Exception {
  const OfflineDictationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolved on-disk paths for one catalog model (stub mirror).
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

  bool get allExist => false;

  Map<String, Object?> toConfigDescriptor() => <String, Object?>{
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

OfflineSttResolvedFiles resolveOfflineSttFiles(
  OfflineSttModel model,
  String modelDirPath,
) {
  String join(String? rel) {
    if (rel == null || rel.isEmpty) return '';
    return '$modelDirPath/$rel';
  }

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
  OfflineDictationService();

  final ValueNotifier<Map<String, OfflineSttStatus>> _statuses =
      ValueNotifier<Map<String, OfflineSttStatus>>(const {});
  final ValueNotifier<Map<String, OfflineSttDownloadProgress>> _progress =
      ValueNotifier<Map<String, OfflineSttDownloadProgress>>(const {});

  ValueListenable<Map<String, OfflineSttStatus>> get statuses => _statuses;

  ValueListenable<Map<String, OfflineSttDownloadProgress>> get progress =>
      _progress;

  OfflineSttDownloadProgress? progressFor(String modelId) => null;

  List<OfflineSttModel> get models => OfflineSttCatalog.all;

  String get selectedModelId => OfflineSttCatalog.defaultModel.id;

  OfflineSttModel get selectedModel => OfflineSttCatalog.defaultModel;

  OfflineSttStatus statusFor(String modelId) => OfflineSttStatus.notDownloaded;

  Object? errorFor(String modelId) => null;

  void selectModel(String? modelId) {}

  Future<void> initialize() async {
    throw const OfflineDictationException(
      'Offline dictation is not supported on this platform',
    );
  }

  Future<void> refreshStatuses() async {}

  Future<void> ensureReady() async {
    throw const OfflineDictationException(
      'Offline dictation is not supported on this platform',
    );
  }

  Future<void> ensureModel(String modelId) async {
    throw const OfflineDictationException(
      'Offline dictation is not supported on this platform',
    );
  }

  Future<void> deleteModel(String modelId) async {}

  Future<void> start({void Function(String text)? onTranscript}) async {
    throw const OfflineDictationException(
      'Offline dictation is not supported on this platform',
    );
  }

  Future<String?> stop() async => null;

  Future<String> stopAndTranscribe() async {
    throw const OfflineDictationException(
      'Offline dictation is not supported on this platform',
    );
  }

  Future<void> cancel() async {}

  Stream<double> levels({
    Duration interval = const Duration(milliseconds: 200),
  }) {
    return const Stream<double>.empty();
  }

  Future<String> transcribe({required String audioPath}) async {
    throw const OfflineDictationException(
      'Offline dictation is not supported on this platform',
    );
  }

  Future<void> dispose() async {
    _statuses.dispose();
    _progress.dispose();
  }
}
