import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Utility functions for encoding/decoding

/// Base64 encode
String base64EncodeBytes(Uint8List data) {
  return base64Encode(data);
}

/// Base64 decode
Uint8List base64DecodeBytes(String input) {
  return base64Decode(input);
}

/// Hex encode
String hexEncode(Uint8List data) {
  return data.map((b) {
    final hex = b.toRadixString(16);
    return hex.length == 1 ? '0$hex' : hex;
  }).join();
}

/// Hex decode
Uint8List hexDecode(String input) {
  final cleanInput = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final bytes = <int>[];
  for (var i = 0; i < cleanInput.length; i += 2) {
    bytes.add(int.parse(cleanInput.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

/// UUID generation - simple version
String generateUUID() {
  final a = _generateHex(8);
  final b = _generateHex(4);
  final c = _generateHex(4);
  final d = _generateHex(4);
  final e = _generateHex(12);
  return '$a-$b-$c-$d-$e';
}

String _generateHex(int length) {
  final chars = '0123456789abcdef';
  final random = Random();
  return List.generate(length, (i) => chars[random.nextInt(16)]).join();
}

/// Timestamp utilities
int timestampNow() => DateTime.now().millisecondsSinceEpoch;

/// Format timestamp for display.
///
/// When [relative] is true, returns human-friendly strings:
/// - Under 1 min  -> "Just now"
/// - Under 1 hour -> "2m ago"
/// - Same day     -> "3h ago"
/// - Yesterday    -> "Yesterday"
/// - Under 7 days -> "3d ago"
/// - Otherwise    -> "M/d/yyyy"
String formatTimestamp(
  int timestamp, {
  bool relative = false,
}) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  if (!relative) return _shortDate(date);
  return formatRelativeTime(date, useYesterdayLabel: true);
}

/// Format a point in time relative to [now] (defaults to the current time).
///
/// - Under 1 min  -> "Just now"
/// - Under 1 hour -> "2m ago"  (compact: "2m")
/// - Under 1 day  -> "3h ago"  (compact: "3h")
/// - Under 7 days -> "3d ago"  (compact: "3d")
/// - Otherwise    -> [absoluteFallback], or "M/d/yyyy"
///
/// [useYesterdayLabel] swaps the day bucket for "Yesterday" when [when] falls
/// on the previous calendar day, matching the session list's wording.
///
/// This is the single implementation behind what used to be six drifting
/// per-screen copies (machine detail, SFTP log/connection cards, linked
/// devices, sidebar, session cards).
String formatRelativeTime(
  DateTime when, {
  DateTime? now,
  bool compact = false,
  bool useYesterdayLabel = false,
  String Function(DateTime)? absoluteFallback,
}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(when);
  final suffix = compact ? '' : ' ago';

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m$suffix';
  if (diff.inHours < 24) return '${diff.inHours}h$suffix';

  if (useYesterdayLabel) {
    // Compare calendar dates, not elapsed hours: 25h ago can still be today.
    final today = DateTime(reference.year, reference.month, reference.day);
    final thatDay = DateTime(when.year, when.month, when.day);
    if (today.difference(thatDay).inDays == 1) return 'Yesterday';
  }

  if (diff.inDays < 7) return '${diff.inDays}d$suffix';
  return (absoluteFallback ?? _shortDate)(when);
}

String _shortDate(DateTime date) =>
    '${date.month}/${date.day}/${date.year}';

/// Format duration
String formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }
  return '${duration.inSeconds}s';
}

/// Format a byte count for display (B / KB / MB / GB / TB).
///
/// Shared by machine detail, SFTP, tool views, the HTTP logger, etc. so size
/// strings do not drift across features.
///
/// - [decimals] — fixed fraction digits for scaled units.
/// - [spaced] — insert a space before the unit ("1.5 KB" vs "1.5KB").
/// - [adaptivePrecision] — drop the fraction once the value reaches 10
///   ("9.8 MB", "12 MB"), for dense dashboard rows.
String formatBytes(
  int bytes, {
  int decimals = 1,
  bool spaced = true,
  bool adaptivePrecision = false,
}) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  final gap = spaced ? ' ' : '';
  if (bytes <= 0) return '0${gap}B';
  if (bytes < 1024) return '$bytes${gap}B';

  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final precision = adaptivePrecision && value >= 10 ? 0 : decimals;
  return '${value.toStringAsFixed(precision)}$gap${units[unit]}';
}

/// Sanitize string for display
String sanitizeForDisplay(String input) {
  return input.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
}

/// Truncate string
String truncate(String input, int maxLength, {String suffix = '...'}) {
  if (input.length <= maxLength) return input;
  return '${input.substring(0, maxLength - suffix.length)}$suffix';
}

/// URL validation
bool isValidUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.scheme == 'http' || uri.scheme == 'https';
  } catch (e) {
    return false;
  }
}

/// Parse query parameters
Map<String, String> parseQueryParams(String query) {
  final params = <String, String>{};
  final pairs = query.split('&');
  for (final pair in pairs) {
    final parts = pair.split('=');
    if (parts.length == 2) {
      params[Uri.decodeComponent(parts[0])] = Uri.decodeComponent(parts[1]);
    }
  }
  return params;
}

/// Deep copy JSON without serialization roundtrip.
dynamic deepCopyJson(dynamic json) {
  if (json is Map) {
    return Map<String, dynamic>.fromEntries(
      json.entries.map((e) => MapEntry(e.key, deepCopyJson(e.value))),
    );
  }
  if (json is List) {
    return json.map(deepCopyJson).toList();
  }
  return json;
}

/// Compact JSON
String compactJson(dynamic json) {
  return jsonEncode(json);
}

/// Pretty JSON
String prettyJson(dynamic json) {
  return JsonEncoder.withIndent('  ').convert(json);
}

/// Debouncer
class Debouncer {

  Debouncer({required this.delay});
  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Throttler
class Throttler {

  Throttler({required this.interval});
  final Duration interval;
  int _lastRun = 0;

  bool tryRun(void Function() action) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastRun >= interval.inMilliseconds) {
      _lastRun = now;
      action();
      return true;
    }
    return false;
  }
}
