part of 'sync_service.dart';

/// Per-machine git author/committer identity.
///
/// The daemon injects it as `GIT_AUTHOR_*` / `GIT_COMMITTER_*` into every
/// session it spawns afterwards, which is what lets a fresh Kubernetes pod
/// (no `~/.gitconfig`) commit. Both calls are idempotent, so a reconnecting
/// handler is retried once with the identical payload.
extension SyncGitIdentityOperations on Sync {
  static const Duration _gitIdentityTimeout = Duration(seconds: 15);

  Future<GitIdentityResponse> machineGetGitIdentity({
    required String machineId,
  }) => _retryIdempotentMachineRPC(
    machineId,
    'git-identity-get',
    const <String, dynamic>{},
    GitIdentityResponse.fromJson,
    timeout: _gitIdentityTimeout,
  );

  /// Stores the identity. Both fields empty removes the app-set identity and
  /// the daemon falls back to its own configuration, if any.
  Future<GitIdentityResponse> machineSetGitIdentity({
    required String machineId,
    required String name,
    required String email,
  }) => _retryIdempotentMachineRPC(
    machineId,
    'git-identity-set',
    <String, dynamic>{'name': name.trim(), 'email': email.trim()},
    GitIdentityResponse.fromJson,
    timeout: _gitIdentityTimeout,
  );
}
