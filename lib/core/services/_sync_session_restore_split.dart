import 'package:happy_flutter/core/utils/wire_parsers.dart';

/// Result of [splitCachedSessionsForColdStart]: the most-recent
/// [recent] session JSON maps to be decoded synchronously on cold
/// start, and the [remaining] tail to be decoded by the deferred
/// pass once the first frame has rendered.
class CachedSessionRestoreSplit {
  CachedSessionRestoreSplit({
    required this.recent,
    required this.remaining,
  });

  final List<Map<String, dynamic>> recent;
  final List<Map<String, dynamic>> remaining;
}

/// Pure helper that sorts the raw cached session JSON entries by
/// `updatedAt` desc and partitions them into the [syncLimit] entries
/// to be restored synchronously and the rest to be deferred.
///
/// Extracted so it can be unit-tested without an initialized
/// MMKV/IDB stack.
CachedSessionRestoreSplit splitCachedSessionsForColdStart(
  List<dynamic> rawSessions, {
  required int syncLimit,
}) {
  final ordered = <Map<String, dynamic>>[];
  for (final item in rawSessions) {
    if (item is Map<String, dynamic>) {
      ordered.add(item);
    } else if (item is Map) {
      ordered.add(Map<String, dynamic>.from(item));
    }
  }
  ordered.sort((a, b) {
    final aUpdated = WireParsers.parseInt(a['updatedAt']) ?? 0;
    final bUpdated = WireParsers.parseInt(b['updatedAt']) ?? 0;
    return bUpdated.compareTo(aUpdated);
  });

  final effectiveLimit =
      ordered.length < syncLimit ? ordered.length : syncLimit;
  return CachedSessionRestoreSplit(
    recent: ordered.sublist(0, effectiveLimit),
    remaining: effectiveLimit < ordered.length
        ? ordered.sublist(effectiveLimit)
        : const <Map<String, dynamic>>[],
  );
}
