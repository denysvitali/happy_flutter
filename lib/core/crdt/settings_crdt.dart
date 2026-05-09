/// Settings-as-CRDT: replaces the pessimistic apply-then-await-server
/// round-trip in `SettingsNotifier.updateSetting` with an LWW map.
///
/// This is the *end-to-end domain* for item #3 of the architecture
/// overhaul. The other CRDT-eligible domains (profiles, todos,
/// artifacts) are stubbed with the same shape — see
/// `lib/core/crdt/crdt_stubs.dart`.
///
/// Behavior
/// --------
/// `updateSetting(key, value)` patches the LWW map immediately and
/// returns; the local UI sees the change synchronously. The wire
/// patch is the single cell `{key: LwwCell<T>}`, which the server
/// (or a peer) merges into its own copy of the map. Convergence
/// happens regardless of arrival order: identical merges produce
/// identical maps.
///
/// Plug-in points
/// --------------
///   * Riverpod side: `SettingsNotifier` reads `SettingsCrdt.snapshot`
///     into its existing `Settings` model.
///   * Wire side: `Sync.applySettings` ships `cell.toJson()` instead
///     of just the new value.
library;

import 'lww_register.dart';

class SettingsCrdt {
  SettingsCrdt({
    required String replicaId,
    int Function()? clock,
  }) : _map = LwwMap<Object?>(
          replicaId: replicaId,
          clock: clock ?? _defaultClock,
        );

  SettingsCrdt._fromMap(this._map);

  final LwwMap<Object?> _map;

  String get replicaId => _map.replicaId;

  static int _defaultClock() => DateTime.now().microsecondsSinceEpoch;

  Object? get(String key) => _map.get(key);

  /// Snapshot as a plain `Map<String, Object?>` ready to copy into the
  /// existing [Settings] model.
  Map<String, Object?> snapshot() {
    return {
      for (final entry in _map.cells.entries) entry.key: entry.value.value,
    };
  }

  /// Local mutation. Returns the wire payload to broadcast.
  Map<String, Object?> updateSetting(String key, Object? value) {
    _map.set(key, value);
    final cell = _map.cells[key]!;
    return {key: cell.toJson()};
  }

  /// Apply a remote patch (received from the server or a peer).
  /// Idempotent and commutative.
  void applyRemote(Map<String, Object?> patch) {
    for (final entry in patch.entries) {
      if (entry.value is! Map) continue;
      final cellJson = (entry.value! as Map).cast<String, Object?>();
      final cell = LwwCell.fromJson<Object?>(cellJson);
      _map.mergeCell(entry.key, cell);
    }
  }

  Map<String, Object?> toJson() => _map.toJson();

  static SettingsCrdt fromJson(
    Map<String, Object?> json, {
    required String replicaId,
    int Function()? clock,
  }) {
    final map = LwwMap.fromJson<Object?>(
      json,
      replicaId: replicaId,
      clock: clock ?? _defaultClock,
    );
    return SettingsCrdt._fromMap(map);
  }
}
