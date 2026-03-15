const Object unset = Object();

bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    final aVal = a[key];
    final bVal = b[key];
    if (identical(aVal, bVal)) continue;
    if (bVal == null || aVal != bVal) return false;
  }
  return true;
}
