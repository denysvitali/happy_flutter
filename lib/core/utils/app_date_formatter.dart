/// Utility class for formatting timestamps into human-readable strings.
class AppDateFormatter {
  /// Returns a relative time string: "just now", "5m", "2h", "3d", "4/5".
  static String relative(int timestampMs) {
    final now = DateTime.now();
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  /// Returns an absolute date string: "M/D/YYYY".
  static String absolute(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
