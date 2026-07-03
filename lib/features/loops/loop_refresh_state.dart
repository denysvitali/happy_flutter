import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart' show logger;

/// Shared cache-hydrate + server-refresh flow for loop list screens.
mixin LoopRefreshState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool initialLoading = true;
  String? refreshError;

  Future<void> refreshLoops({required String failureLogMessage}) async {
    final hasCached = ref
        .read(loopsNotifierProvider.notifier)
        .hydrateFromCache();
    if (mounted) {
      setState(() {
        initialLoading = !hasCached;
        refreshError = null;
      });
    }
    if (hasCached) {
      unawaited(ref.read(loopsNotifierProvider.notifier).refreshFromSync());
      return;
    }
    try {
      await ref.read(loopsNotifierProvider.notifier).refreshFromSync();
    } catch (e, st) {
      logger.warning('$failureLogMessage: $e', e, st);
      if (mounted) {
        setState(() => refreshError = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => initialLoading = false);
      }
    }
  }

  void clearLoopRefreshError() {
    if (mounted) {
      setState(() => refreshError = null);
    }
  }
}
