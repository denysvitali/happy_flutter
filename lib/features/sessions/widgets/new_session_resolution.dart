part of 'new_session_dialog.dart';

/// Resolves a stale machine selection to the freshest online registration for
/// the same host.
///
/// Daemon credential resets and interrupted database updates can leave more
/// than one machine record for a host. Never fall back to an unrelated host:
/// if no matching online registration exists, preserve the stale selection so
/// the dialog's offline guard keeps Create disabled.
String? resolveAvailableMachineId(
  String? selectedMachineId,
  Map<String, Machine> machines, {
  int? nowMs,
}) {
  if (selectedMachineId == null) return null;

  final selected = machines[selectedMachineId];
  if (selected == null) return selectedMachineId;

  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  if (selected.isOnlineAt(now)) return selectedMachineId;

  final host = selected.metadata?.host?.trim();
  if (host == null || host.isEmpty) return selectedMachineId;

  final replacements =
      machines.values
          .where(
            (machine) =>
                machine.id != selectedMachineId &&
                machine.metadata?.host?.trim() == host &&
                machine.isOnlineAt(now),
          )
          .toList()
        ..sort((a, b) {
          final activeComparison = b.activeAt.compareTo(a.activeAt);
          if (activeComparison != 0) return activeComparison;
          return a.id.compareTo(b.id);
        });

  return replacements.firstOrNull?.id ?? selectedMachineId;
}

/// Probes the selected registration and then other online registrations for
/// the same host, newest first.
///
/// A daemon restart or clustered launcher can keep emitting host activity
/// under one machine ID while its RPC handlers are registered under another.
/// Presence alone therefore cannot identify the registration that can spawn.
Future<String> resolveReachableMachineId(
  String selectedMachineId,
  Map<String, Machine> machines, {
  required Future<void> Function(String machineId) probe,
  int? nowMs,
}) async {
  final selected = machines[selectedMachineId];
  if (selected == null) {
    throw StateError('Machine is offline');
  }

  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final host = selected.metadata?.host?.trim();
  final candidates = <Machine>[
    selected,
    if (host != null && host.isNotEmpty)
      ...machines.values.where(
        (machine) =>
            machine.id != selectedMachineId &&
            machine.metadata?.host?.trim() == host &&
            machine.isOnlineAt(now),
      ),
  ];
  if (candidates.length > 1) {
    candidates.setRange(
      1,
      candidates.length,
      candidates.sublist(1)..sort((a, b) {
        final activeComparison = b.activeAt.compareTo(a.activeAt);
        if (activeComparison != 0) return activeComparison;
        return a.id.compareTo(b.id);
      }),
    );
  }

  Object? lastError;
  StackTrace? lastStack;
  for (final candidate in candidates) {
    try {
      await probe(candidate.id);
      return candidate.id;
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
    }
  }
  Error.throwWithStackTrace(
    lastError ?? StateError('Machine is unreachable'),
    lastStack ?? StackTrace.current,
  );
}

bool _machineSupportsKubernetes(Machine machine) =>
    machine.metadata?.spawnBackends?.contains('kubernetes') ?? false;

List<String> _spawnBackendsForMachine(Machine? machine) {
  final advertised = machine?.metadata?.spawnBackends ?? const <String>[];
  final supported = advertised
      .where((backend) => backend == 'local' || backend == 'kubernetes')
      .toList(growable: false);
  return supported.isEmpty ? const ['local'] : supported;
}

String _defaultSpawnBackendForMachine(Machine? machine) {
  final backends = _spawnBackendsForMachine(machine);
  final advertisedDefault = machine?.metadata?.defaultSpawnBackend;
  return backends.contains(advertisedDefault)
      ? advertisedDefault!
      : backends.first;
}

String _selectedSpawnBackendForMachine(Machine? machine, String? selected) {
  final backends = _spawnBackendsForMachine(machine);
  return backends.contains(selected)
      ? selected!
      : _defaultSpawnBackendForMachine(machine);
}

String? _spawnBackendRequestValueForMachine(
  Machine? machine,
  String? selected,
) {
  final advertised = machine?.metadata?.spawnBackends;
  if (advertised == null || advertised.isEmpty) return null;
  return _selectedSpawnBackendForMachine(machine, selected);
}

String kubernetesCheckoutPath(Machine machine, String repositoryUrl) {
  final advertisedBase = machine.metadata?.kubernetesCheckoutBaseDir?.trim();
  final base = advertisedBase != null && advertisedBase.isNotEmpty
      ? advertisedBase
      : '/workspace';
  var slug = repositoryUrl.trim().replaceAll(RegExp(r'[/\\]+$'), '');
  final slash = slug.lastIndexOf('/');
  final colon = slug.lastIndexOf(':');
  final separator = slash > colon ? slash : colon;
  if (separator >= 0) slug = slug.substring(separator + 1);
  if (slug.toLowerCase().endsWith('.git')) {
    slug = slug.substring(0, slug.length - 4);
  }
  slug = slug
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  if (slug.isEmpty) slug = 'repository';
  return '${base.replaceAll(RegExp(r'/+$'), '')}/$slug';
}

/// Mirrors Sync._isClaudeModelAlias so the create dialog can reject
/// lastUsedModelMode values that would trip the daemon's
/// provider_model_mismatch guard.
bool _isClaudeModelAliasForDialog(String modelMode) {
  final separator = modelMode.lastIndexOf(':');
  final slug = separator > 0 ? modelMode.substring(0, separator) : modelMode;
  return slug == 'opus' ||
      slug == 'sonnet' ||
      slug == 'haiku' ||
      slug == 'fable' ||
      slug.startsWith('claude-') ||
      slug.contains('/claude-');
}
