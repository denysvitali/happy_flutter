/// App-local permission decisions (allow / deny), sent to the session in the
/// background on the shared [OperationStore] machine.
///
/// A decision takes effect on screen the moment it is made: the pending bar,
/// inline row actions and the tool card treat the request as answered while
/// it is in flight and until the session's own state catches up. A failure
/// returns the request to pending and is reported app-wide (see
/// `OperationFailureListener`).
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod/riverpod.dart';

import '../operations/operation_store.dart';
import '../rpc/rpc_types.dart';
import 'permissions_notifier.dart';

@immutable
class PermissionDecision {
  const PermissionDecision({
    required this.sessionId,
    required this.permissionId,
    required this.allow,
    this.mode,
    this.allowTools,
    this.decision,
  });

  final String sessionId;
  final String permissionId;

  /// Approve (true) or deny (false).
  final bool allow;
  final String? mode;
  final List<String>? allowTools;

  /// Codex decision string (`approved`, `approved_for_session`, `abort`).
  final String? decision;
}

typedef PermissionOperation = Operation<PermissionDecision>;

String permissionOperationKey(String sessionId, String permissionId) =>
    '$sessionId/$permissionId';

extension PermissionOperationView on PermissionOperation {
  /// The daemon's receipt for a successful decision.
  PermissionResponse? get receipt => switch (result) {
    final PermissionResponse response => response,
    _ => null,
  };
}

class PermissionOperationsNotifier extends OperationStore<PermissionDecision> {
  /// Long enough for the session's agent state to drop the request.
  @override
  Duration get confirmationTimeout => const Duration(seconds: 30);

  @override
  String get logName => 'Permission';

  @override
  String keyOf(PermissionDecision request) =>
      permissionOperationKey(request.sessionId, request.permissionId);

  @override
  Future<Object?> perform(PermissionDecision request) async {
    final permissions = ref.read(permissionsNotifierProvider.notifier);
    final response = request.allow
        ? await permissions.allow(
            request.sessionId,
            request.permissionId,
            mode: request.mode,
            allowTools: request.allowTools,
            decision: request.decision,
          )
        : await permissions.deny(
            request.sessionId,
            request.permissionId,
            decision: request.decision,
          );
    if (!response.success) {
      throw OperationRejected(response.error ?? 'not applied');
    }
    return response;
  }
}

/// Permission decisions made this app session, keyed by
/// `sessionId/permissionId`.
final permissionOperationsNotifierProvider =
    NotifierProvider<
      PermissionOperationsNotifier,
      Map<String, PermissionOperation>
    >(PermissionOperationsNotifier.new);

/// The decision shown for [permissionId] while it syncs: true = allowed,
/// false = denied, null = still undecided (or the decision failed).
bool? decidedPermission(
  Map<String, PermissionOperation> operations,
  String sessionId,
  String permissionId,
) {
  final operation = operations[permissionOperationKey(sessionId, permissionId)];
  if (operation == null || !operation.overlays) return null;
  return operation.request.allow;
}
