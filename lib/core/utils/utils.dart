import 'dart:convert';
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
  return data.map((b) => b.toRadixString(16).padStart(2, '0')).join();
}

/// Hex decode
Uint8List hexDecode(String input) {
  final cleanInput = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  final bytes = <int>[];
  for (int i = 0; i < cleanInput.length; i += 2) {
    bytes.add(int.parse(cleanInput.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

/// UUID generation
String generateUUID() {
  return const Uuid().v4();
}

/// Timestamp utilities
int timestampNow() => DateTime.now().millisecondsSinceEpoch;

/// Format timestamp for display
String formatTimestamp(int timestamp, {bool relative = false}) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final now = DateTime.now();

  if (relative) {
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
  }

  return '${date.month}/${date.day}/${date.year}';
}

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

/// Deep copy JSON
dynamic deepCopyJson(dynamic json) {
  return jsonDecode(jsonEncode(json));
}

/// Compact JSON
String compactJson(dynamic json) {
  return jsonEncode(json);
}

/// Pretty JSON
String prettyJson(dynamic json) {
  return JsonEncoder.withIndent('  ').convert(json);
}

/// Rate limiter
class RateLimiter {
  final Duration window;
  final int maxRequests;
  final _timestamps = <int>[];

  RateLimiter({required this.window, required this.maxRequests});

  bool tryAcquire() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowStart = now - window.inMilliseconds;

    // Remove old timestamps
    _timestamps.removeWhere((t) => t < windowStart);

    if (_timestamps.length >= maxRequests) {
      return false;
    }

    _timestamps.add(now);
    return true;
  }

  int get remainingRequests => maxRequests - _timestamps.length;
}

/// Debouncer
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

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
  final Duration interval;
  int _lastRun = 0;

  Throttler({required this.interval});

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
