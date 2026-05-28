import 'package:flutter_gemma/flutter_gemma.dart' show ModelType;

/// Configuration for the on-device model used by smart features.
///
/// The model is downloaded on demand (far too large to bundle) from a
/// configurable URL. The default is a non-gated model so download works with
/// no HuggingFace token. Gated models (e.g. Gemma) can be used by supplying a
/// URL plus `--dart-define=HUGGINGFACE_TOKEN=...` at build time.
class GemmaModelConfig {
  const GemmaModelConfig._();

  /// Default model: Qwen2.5 0.5B Instruct, MediaPipe `.task` format, ~520 MB.
  /// Non-gated on HuggingFace — downloads without a token. Override at build
  /// time with `--dart-define=GEMMA_MODEL_URL=...`.
  static const String modelUrl = String.fromEnvironment(
    'GEMMA_MODEL_URL',
    defaultValue:
        'https://huggingface.co/litert-community/Qwen2.5-0.5B-Instruct/resolve/main/Qwen2.5-0.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
  );

  /// Model family, used by flutter_gemma to select the right chat template.
  /// Override with `--dart-define=GEMMA_MODEL_TYPE=gemmaIt|qwen|llama|...`.
  static const String _modelTypeName = String.fromEnvironment(
    'GEMMA_MODEL_TYPE',
    defaultValue: 'qwen',
  );

  static ModelType get modelType => ModelType.values.firstWhere(
    (t) => t.name == _modelTypeName,
    orElse: () => ModelType.qwen,
  );

  /// HuggingFace access token for gated downloads. Empty when not provided.
  static const String huggingFaceToken = String.fromEnvironment(
    'HUGGINGFACE_TOKEN',
  );

  /// Filename the model is stored under on device. Derived from [modelUrl].
  static String get modelFilename => modelUrl.split('/').last;

  /// Context window for inference. Small to keep memory/latency reasonable
  /// for the short ranking/classification prompts we issue.
  static const int maxTokens = 1024;

  /// Human-readable approximate download size, shown in the UI.
  static const String approxDownloadSize = '~520 MB';

  /// Token passed to the downloader, or null when none was configured.
  static String? get token =>
      huggingFaceToken.isEmpty ? null : huggingFaceToken;
}
