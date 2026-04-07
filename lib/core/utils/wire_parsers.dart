/// Lenient parsers for wire values coming from different server variants.
///
/// Some backends emit numeric fields as numbers, others as numeric strings.
/// These helpers normalize both shapes.
class WireParsers {
  const WireParsers._();

  static int? parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final asInt = int.tryParse(trimmed);
      if (asInt != null) return asInt;
      final asDouble = double.tryParse(trimmed);
      if (asDouble != null) return asDouble.toInt();
    }
    return null;
  }

  static bool? parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
          return true;
        case 'false':
        case '0':
          return false;
      }
    }
    return null;
  }

  static String? parseString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  /// Safely cast a dynamic value to `Map<String, dynamic>?`.
  ///
  /// Returns `null` when the value is not a Map (e.g. a List or a
  /// String). This prevents `TypeError` crashes from hard
  /// `as Map<String, dynamic>?` casts on unexpected wire shapes.
  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Safely cast a dynamic value to `List<dynamic>?`.
  ///
  /// Returns `null` when the value is not a List.
  static List<dynamic>? asList(dynamic value) {
    if (value is List<dynamic>) return value;
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return null;
  }

  /// Safely cast a dynamic value to `List<String>?`.
  ///
  /// Filters out non-string entries rather than throwing.
  static List<String>? asStringList(dynamic value) {
    final list = asList(value);
    if (list == null) return null;
    return list.whereType<String>().toList(growable: false);
  }
}
