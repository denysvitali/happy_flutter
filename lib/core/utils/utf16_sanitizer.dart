/// Replaces unpaired UTF-16 surrogate code units with the Unicode replacement
/// character so malformed remote/tool output cannot crash Flutter text layout.
String sanitizeUtf16(String value) {
  StringBuffer? output;
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    final isHigh = unit >= 0xD800 && unit <= 0xDBFF;
    final isLow = unit >= 0xDC00 && unit <= 0xDFFF;
    if (isHigh &&
        index + 1 < value.length &&
        value.codeUnitAt(index + 1) >= 0xDC00 &&
        value.codeUnitAt(index + 1) <= 0xDFFF) {
      if (output != null) output.write(value.substring(index, index + 2));
      index++;
      continue;
    }
    if (!isHigh && !isLow) {
      output?.writeCharCode(unit);
      continue;
    }

    output ??= StringBuffer()..write(value.substring(0, index));
    output.writeCharCode(0xFFFD);
  }
  return output?.toString() ?? value;
}

/// Recursively sanitizes JSON-shaped decrypted message content.
dynamic sanitizeJsonUtf16(dynamic value) {
  if (value is String) return sanitizeUtf16(value);
  if (value is List<dynamic>) return value.map(sanitizeJsonUtf16).toList();
  if (value is Map<String, dynamic>) {
    return <String, dynamic>{
      for (final entry in value.entries)
        sanitizeUtf16(entry.key): sanitizeJsonUtf16(entry.value),
    };
  }
  return value;
}
