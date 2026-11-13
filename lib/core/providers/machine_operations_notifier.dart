/// App-local machine operations (delete), synced to the server in the
/// background on the shared [OperationStore] machine.
///
/// A machine with a delete in flight leaves [machinesListProvider] at once;
/// a failure brings it back and is reported app-wide with Retry (see
/// `OperationFailureListener`).
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod/riverpod.dart';

import '../api/api_client.dart';
import '../operations/operation_store.dart';
import '../services/sync_service.dart';
import 'machines_notifier.dart';

enum MachineOperationAction { delete }

@immutable
class MachineRequest {
  const MachineRequest({required this.machineId, required this.action});

  final String machineId;
  final MachineOperationAction action;
}

typedef MachineOperation = Operation<MachineRequest>;

/// Deletes a machine on the server; returns the HTTP status, null on
/// success. Override in tests.
typedef MachineDeleteRunner = Future<int?> Function(String machineId);

Future<int?> _deleteViaApi(String machineId) async {
  final api = ApiClient();
  final response = await api.delete('/v1/machines/$machineId');
  return api.isSuccess(response) ? null : response.statusCode ?? 0;
}

final machineDeleteRunnerProvider = Provider<MachineDeleteRunner>(
  (ref) => _deleteViaApi,
);

class MachineOperationsNotifier extends OperationStore<MachineRequest> {
  @override
  String get logName => 'Machine';

  @override
  String keyOf(MachineRequest request) => request.machineId;

  /// Deletes [machineId] in the background; it leaves the lists at once.
  bool delete(String machineId) => submit(
    MachineRequest(machineId: machineId, action: MachineOperationAction.delete),
  );

  @override
  Future<Object?> perform(MachineRequest request) async {
    final failedStatus = await ref.read(machineDeleteRunnerProvider)(
      request.machineId,
    );
    // The status code is the message: the failure snack formats it.
    if (failedStatus != null) throw OperationRejected('$failedStatus');
    return null;
  }

  @override
  void onSucceeded(MachineOperation operation) {
    ref.read(machinesNotifierProvider.notifier).remove(operation.key);
    if (sync.isInitialized) sync.machinesSync.invalidate();
    dismiss(operation.key);
  }
}

/// Machine operations recorded this app session, keyed by machine id.
final machineOperationsNotifierProvider =
    NotifierProvider<MachineOperationsNotifier, Map<String, MachineOperation>>(
      MachineOperationsNotifier.new,
    );

/// Ids of machines hidden because a delete is in flight.
Set<String> machinesBeingDeleted(Map<String, MachineOperation> operations) => {
  for (final operation in operations.values)
    if (operation.overlays) operation.key,
};
