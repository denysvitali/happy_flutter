/// Stub Gemma service for platforms without on-device inference (web).
/// All methods return empty/fallback values; callers use heuristics instead.
class GemmaService {
  GemmaService();

  /// Never available on unsupported platforms.
  bool get isAvailable => false;

  /// No model can be downloaded here.
  Future<bool> isModelDownloaded() async => false;

  /// No-op.
  Future<void> initialize() async {}

  /// Emits an error immediately — downloads are unsupported here.
  Stream<double> downloadModel() =>
      Stream<double>.error(UnsupportedError('On-device model unsupported'));

  /// Returns sessions unchanged (no semantic ranking).
  Future<List<Map<String, dynamic>>> rankSessions(
    String query,
    List<Map<String, dynamic>> sessions,
  ) async => sessions;

  /// Returns empty list (no auto-tags).
  Future<List<String>> classifySession(Map<String, dynamic> session) async =>
      [];

  /// No-op.
  void dispose() {}
}
