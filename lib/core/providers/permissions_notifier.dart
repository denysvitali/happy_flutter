import 'package:riverpod/riverpod.dart';

import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';

/// Encapsulates permission approval/denial so screens don't call sync directly.
class PermissionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> allow(
    String sessionId,
    String permissionId, {
    String? mode,
    List<String>? allowTools,
    String? decision,
    Map<String, dynamic>? updatedInput,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    try {
      await sync.sessionAllow(
        sessionId,
        permissionId,
        mode: mode,
        allowTools: allowTools,
        decision: decision,
        updatedInput: updatedInput,
      );
    } catch (e, stack) {
      logger.warning(
        'PermissionsNotifier.allow($sessionId, $permissionId) failed',
        e,
        stack,
      );
      rethrow;
    }
  }

  Future<void> deny(
    String sessionId,
    String permissionId, {
    String? decision,
  }) async {
    if (!sync.isInitialized) {
      throw StateError('Sync is not initialized');
    }
    try {
      await sync.sessionDeny(
        sessionId,
        permissionId,
        decision: decision,
      );
    } catch (e, stack) {
      logger.warning(
        'PermissionsNotifier.deny($sessionId, $permissionId) failed',
        e,
        stack,
      );
      rethrow;
    }
  }
}

final permissionsNotifierProvider = NotifierProvider<PermissionsNotifier, void>(
  () => PermissionsNotifier(),
);
