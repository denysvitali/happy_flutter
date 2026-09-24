/// Aggregate timing and transfer sizes for one HTTP endpoint.
class PowerDiagnosticHttpEndpointStats {
  const PowerDiagnosticHttpEndpointStats({
    required this.count,
    required this.failures,
    required this.slowRequests,
    required this.requestBytes,
    required this.responseBytes,
    required this.totalDurationMs,
  });

  final int count;
  final int failures;
  final int slowRequests;
  final int requestBytes;
  final int responseBytes;
  final int totalDurationMs;

  int get averageDurationMs => count == 0 ? 0 : totalDurationMs ~/ count;
}
