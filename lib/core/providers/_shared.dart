import 'dart:async';

import '../sync/invalidate_sync.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

/// Typed sentinel used in [copyWith]-style methods to distinguish
/// "parameter not provided" from an explicit [null] value.
///
/// Use [identical] for comparison — never `==`.
final class Unset {
  const Unset();
}

const Unset unset = Unset();

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

/// Returns true if [a] and [b] have the same length and `identical()`
/// values for every key. Used as a fast-path in `loadFromSync()` when
/// state is rebuilt from a source map: most refreshes are no-ops, so
/// reference-equal entries let the notifier skip the state assignment.
bool mapValuesIdentical<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final entry in b.entries) {
    if (!identical(a[entry.key], entry.value)) return false;
  }
  return true;
}

/// Standard sync-domain refresh: short-circuits when Sync isn't
/// initialized, invalidates the [InvalidateSync] returned by [invalidate],
/// swallows + logs any failure under the [name] label, and then calls
/// [reload] (typically the notifier's `loadFromSync`).
///
/// [invalidate] is a getter (not a value) so the `LateInitializationError`
/// from accessing `sync.fooSync` before init is avoided when the
/// isInitialized check returns false.
Future<void> refreshSyncDomain({
  required InvalidateSync Function() invalidate,
  required String name,
  required FutureOr<void> Function() reload,
}) async {
  if (!sync.isInitialized) return;
  try {
    await invalidate().invalidateAndAwait();
  } catch (e, stack) {
    logger.warning('Failed to refresh $name', e, stack);
  }
  await reload();
}
