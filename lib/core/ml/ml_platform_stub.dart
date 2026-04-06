/// Stub implementation of Gemma ML service for non-Android platforms.
/// On iOS/web, all methods return empty/fallback values.
class GemmaService {
  const GemmaService();

  /// Always false on non-Android platforms.
  bool get isAvailable => false;

  /// No-op on non-Android.
  Future<void> initialize() async {}

  /// Returns sessions unchanged (no semantic ranking).
  Future<List<Map<String, dynamic>>> rankSessions(
    String query,
    List<Map<String, dynamic>> sessions,
  ) async =>
      sessions;

  /// Returns empty list (no auto-tags).
  Future<List<String>> classifySession(Map<String, dynamic> session) async =>
      [];

  /// Always returns 0.0 (no Gemma score).
  Future<double> scoreSessionRelevance(Map<String, dynamic> session) async => 0.0;

  /// No-op.
  void dispose() {}
}
