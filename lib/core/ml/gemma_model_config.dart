/// Configuration for the on-device Gemma model used by smart features.
///
/// The model is downloaded on demand (it is far too large to bundle) from a
/// configurable URL. Gemma weights on HuggingFace are gated, so a token is
/// supplied at build time via `--dart-define=HUGGINGFACE_TOKEN=...`.
class GemmaModelConfig {
  const GemmaModelConfig._();

  /// Default model: Gemma 3 1B IT in LiteRT-LM format (~550 MB).
  /// Override at build time with `--dart-define=GEMMA_MODEL_URL=...`.
  static const String modelUrl = String.fromEnvironment(
    'GEMMA_MODEL_URL',
    defaultValue:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q8_ekv2048.litertlm',
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
  static const String approxDownloadSize = '~550 MB';

  /// Token passed to the downloader, or null when none was configured.
  static String? get token =>
      huggingFaceToken.isEmpty ? null : huggingFaceToken;
}
