import 'dart:convert';

import '../services/logger_service.dart' show logger;

/// Centralizes the repeated "safe-decode JSON, cast, try/catch, log" pattern
/// scattered across storage and cache code.
///
/// Each helper swallows malformed input and logs a warning rather than
/// throwing, so a single corrupt persisted blob can never crash a caller.
abstract final class JsonDecoders {
  /// Decodes [raw] into a single object via [fromJson].
  ///
  /// Returns null when [raw] is null/blank, not a JSON object, or [fromJson]
  /// throws. A [context] label is included in the warning log for triage.
  static T? tryDecode<T>(
    String? raw,
    T Function(Map<String, dynamic> json) fromJson, {
    String? context,
  }) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        logger.warning('${_prefix(context)}expected JSON object');
        return null;
      }
      return fromJson(decoded);
    } catch (e) {
      logger.warning('${_prefix(context)}failed to decode: $e');
      return null;
    }
  }

  /// Decodes [raw] into a list, mapping each JSON object via [fromJson].
  ///
  /// Returns an empty list when [raw] is null/blank, not a JSON array, or
  /// decoding throws. Non-object elements are skipped.
  static List<T> tryDecodeList<T>(
    String? raw,
    T Function(Map<String, dynamic> json) fromJson, {
    String? context,
  }) {
    if (raw == null || raw.isEmpty) return <T>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        logger.warning('${_prefix(context)}expected JSON array');
        return <T>[];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    } catch (e) {
      logger.warning('${_prefix(context)}failed to decode list: $e');
      return <T>[];
    }
  }

  /// Decodes [raw] into a plain `List<dynamic>`, returning [fallback]
  /// (default empty) on any failure. Useful for primitive arrays such as
  /// lists of strings where no [fromJson] mapper is needed.
  static List<dynamic> tryDecodeRawList(
    String? raw, {
    List<dynamic> fallback = const <dynamic>[],
    String? context,
  }) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        logger.warning('${_prefix(context)}expected JSON array');
        return fallback;
      }
      return decoded;
    } catch (e) {
      logger.warning('${_prefix(context)}failed to decode list: $e');
      return fallback;
    }
  }

  /// Decodes [raw] into a `Map<String, dynamic>`, returning [fallback]
  /// (default empty) on any failure.
  static Map<String, dynamic> tryDecodeRawMap(
    String? raw, {
    Map<String, dynamic> fallback = const <String, dynamic>{},
    String? context,
  }) {
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        logger.warning('${_prefix(context)}expected JSON object');
        return fallback;
      }
      return decoded;
    } catch (e) {
      logger.warning('${_prefix(context)}failed to decode map: $e');
      return fallback;
    }
  }

  /// Like [tryDecodeRawMap] but returns null (rather than a fallback) when
  /// [raw] is null/blank, not a JSON object, or decoding throws.
  static Map<String, dynamic>? tryDecodeRawMapOrNull(
    String? raw, {
    String? context,
  }) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        logger.warning('${_prefix(context)}expected JSON object');
        return null;
      }
      return decoded;
    } catch (e) {
      logger.warning('${_prefix(context)}failed to decode map: $e');
      return null;
    }
  }

  static String _prefix(String? context) =>
      context == null ? 'JsonDecoders: ' : '$context: ';
}
