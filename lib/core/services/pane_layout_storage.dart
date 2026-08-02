import 'cached_storage.dart';
import 'mmkv_storage.dart';

/// MMKV-backed storage for user-chosen master-pane widths in the
/// tablet/desktop split layouts.
///
/// Backed by [CachedStorage], which provides the in-memory cache and the
/// 500 ms debounced MMKV write, so a drag gesture that emits dozens of
/// updates still results in a single persisted write.
///
/// Widths are stored per pane id (e.g. `'sessions'`) so several split views
/// can remember independent widths.
class PaneLayoutStorage extends CachedStorage<Map<String, double>> {
  PaneLayoutStorage({super.storage});

  /// Shared instance used by the app; tests may construct their own with an
  /// injected [MMKVStorage].
  static final PaneLayoutStorage instance = PaneLayoutStorage();

  @override
  String get key => 'pane-layout-widths';

  @override
  String get logLabel => 'PaneLayoutStorage';

  @override
  Map<String, double> empty() => <String, double>{};

  @override
  Map<String, double> decode(dynamic json) {
    final map = json as Map<dynamic, dynamic>;
    return <String, double>{
      for (final entry in map.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toDouble(),
    };
  }

  @override
  dynamic encode(Map<String, double> value) => value;

  /// Returns the persisted width for [paneId], or null when the user has
  /// never resized that pane.
  double? widthFor(String paneId) => cache[paneId];

  /// Records a new width for [paneId] and schedules a debounced write.
  void setWidth(String paneId, double width) =>
      mutate((value) => value[paneId] = width);
}
