/// Typed sentinel used in [copyWith]-style methods to distinguish
/// "parameter not provided" from an explicit [null] value.
///
/// Use [identical] for comparison — never `==`.
final class _Unset {
  const _Unset();
}

const _Unset unset = _Unset();

bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    final aVal = a[key];
    final bVal = b[key];
    if (identical(aVal, bVal)) continue;
    if (aVal != bVal) return false;
  }
  return true;
}
