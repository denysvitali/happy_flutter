import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sync_service.dart';

/// Consolidated sync subscription mixin for screens that need
/// to subscribe to [sync.onDataChanged] updates.
///
/// This mixin provides a standard pattern for managing sync subscriptions
/// with automatic deduplication prevention via data change counter.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with SyncSubscriptionMixin {
///   @override
///   void initState() {
///     super.initState();
///     // Initial data fetch
///     Future<void>.microtask(() async {
///       await ref.read(myProvider.notifier).refreshFromSync();
///     });
///     // Subscribe to sync updates
///     subscribeToDataChanged(ref, () {
///       ref.read(myProvider.notifier).loadFromSync();
///     });
///   }
/// }
/// ```
mixin SyncSubscriptionMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  StreamSubscription<void>? _syncSubscription;
  int _lastDataChangeCounter = -1;

  /// Subscribe to [sync.onDataChanged] with deduplication.
  ///
  /// The [onDataChanged] callback is invoked when data changes,
  /// but skipped if the data change counter hasn't changed
  /// (prevents duplicate work).
  ///
  /// Call this in [initState] after your initial data fetch.
  void subscribeToDataChanged(
    WidgetRef ref,
    VoidCallback onDataChanged,
  ) {
    _syncSubscription = sync.onDataChanged.listen((_) {
      if (!mounted) return;
      final counter = sync.dataChangeCounter;
      if (counter == _lastDataChangeCounter) return;
      _lastDataChangeCounter = counter;
      onDataChanged();
    });
  }

  /// Subscribe to [sync.onSessionMessagesChanged] for a specific session.
  ///
  /// Only chat-related screens should use this method. Other screens
  /// should use [subscribeToDataChanged] instead.
  ///
  /// The [onMessagesChanged] callback is invoked when messages for
  /// the given [sessionId] change.
  ///
  /// Call this in [initState] after your initial data fetch.
  StreamSubscription<String> subscribeToSessionMessagesChanged(
    String sessionId,
    void Function() onMessagesChanged,
  ) {
    return sync.onSessionMessagesChanged
        .where((id) => id == sessionId)
        .listen((_) {
      if (!mounted) return;
      onMessagesChanged();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }
}
