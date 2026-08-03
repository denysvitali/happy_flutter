import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../i18n/app_localizations.dart';

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

/// Format a date in the short numeric form for [locale].
///
/// `7/31/2026` in `en_US`, `31.7.2026` in `de`, `31/07/2026` in `en_GB`.
///
/// [locale] defaults to [Intl.defaultLocale], which `main()` seeds from the
/// platform locale, so context-free call sites still follow the device.
///
/// Never throws: intl reports an unknown or not-yet-initialized locale as an
/// `ArgumentError` (a subtype of `Error`, **not** `Exception`) once
/// `initializeDateFormatting` has run, and as a `LocaleDataException` before
/// it has. Both are caught here — an unusable locale degrades to `en_US` and
/// finally to a manual `M/d/yyyy` rather than crashing a widget build.
String formatShortDate(DateTime date, {String? locale}) =>
    _formatWithFallback(
      date,
      locale,
      DateFormat.yMd,
      (d) => '${d.month}/${d.day}/${d.year}',
    );

/// Format a date as day + month only, in the order [locale] uses.
///
/// `7/31` in `en_US`, `31.7.` in `de`. Same never-throws contract as
/// [formatShortDate].
String formatShortDayMonth(DateTime date, {String? locale}) =>
    _formatWithFallback(
      date,
      locale,
      DateFormat.Md,
      (d) => '${d.month}/${d.day}',
    );

String _formatWithFallback(
  DateTime date,
  String? locale,
  DateFormat Function([String?]) build,
  String Function(DateTime) manual,
) {
  try {
    return build(locale ?? Intl.defaultLocale).format(date);
  } catch (_) {
    // Deliberately catch-all: see [formatShortDate].
    try {
      return build('en_US').format(date);
    } catch (_) {
      return manual(date);
    }
  }
}

/// Format timestamp for display.
///
/// When [relative] is true, returns human-friendly strings:
/// - Under 1 min  -> "Just now"
/// - Under 1 hour -> "2m ago"
/// - Same day     -> "3h ago"
/// - Yesterday    -> "Yesterday"
/// - Under 7 days -> "3d ago"
/// - Otherwise    -> the short numeric date for [locale]
///
/// Pass [l10n] from a widget to localize the relative labels, and [locale] to
/// pin the date order (defaults to the device locale via
/// [Intl.defaultLocale]).
String formatTimestamp(
  int timestamp, {
  bool relative = false,
  String? locale,
  AppLocalizations? l10n,
}) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  if (!relative) return formatShortDate(date, locale: locale);
  return formatRelativeTime(
    date,
    useYesterdayLabel: true,
    locale: locale,
    l10n: l10n,
  );
}

/// Format a point in time relative to [now] (defaults to the current time).
///
/// - Under 1 min  -> "Just now"
/// - Under 1 hour -> "2m ago"  (compact: "2m")
/// - Under 1 day  -> "3h ago"  (compact: "3h")
/// - Under 7 days -> "3d ago"  (compact: "3d")
/// - Otherwise    -> [absoluteFallback], or the short numeric date
///
/// [useYesterdayLabel] swaps the day bucket for "Yesterday" when [when] falls
/// on the previous calendar day, matching the session list's wording.
///
/// Pass [l10n] to localize the relative labels; without it they fall back to
/// English. [locale] pins the date order of the absolute fallback and
/// defaults to the device locale via [Intl.defaultLocale].
///
/// This is the single implementation behind what used to be six drifting
/// per-screen copies (machine detail, SFTP log/connection cards, linked
/// devices, sidebar, session cards).
String formatRelativeTime(
  DateTime when, {
  DateTime? now,
  bool compact = false,
  bool useYesterdayLabel = false,
  String Function(DateTime, {String? locale})? absoluteFallback,
  String? locale,
  AppLocalizations? l10n,
}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(when);

  if (diff.inMinutes < 1) return l10n?.relativeJustNow ?? 'Just now';
  if (diff.inMinutes < 60) {
    final n = diff.inMinutes;
    if (compact) return l10n?.relativeMinutesCompact(n) ?? '${n}m';
    return l10n?.relativeMinutesAgo(n) ?? '${n}m ago';
  }
  if (diff.inHours < 24) {
    final n = diff.inHours;
    if (compact) return l10n?.relativeHoursCompact(n) ?? '${n}h';
    return l10n?.relativeHoursAgo(n) ?? '${n}h ago';
  }

  if (useYesterdayLabel) {
    // Compare calendar dates, not elapsed hours: 25h ago can still be today.
    final today = DateTime(reference.year, reference.month, reference.day);
    final thatDay = DateTime(when.year, when.month, when.day);
    if (today.difference(thatDay).inDays == 1) {
      return l10n?.relativeYesterday ?? 'Yesterday';
    }
  }

  if (diff.inDays < 7) {
    final n = diff.inDays;
    if (compact) return l10n?.relativeDaysCompact(n) ?? '${n}d';
    return l10n?.relativeDaysAgo(n) ?? '${n}d ago';
  }
  if (absoluteFallback != null) {
    return absoluteFallback(when, locale: locale);
  }
  return formatShortDate(when, locale: locale);
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
