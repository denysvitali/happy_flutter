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

  /// Asks the machine what GitHub knows about [repoUrl], and whether [ref]
  /// resolves in it, so a mistyped branch is corrected before a pod exists.
  /// Daemons without the RPC, or without a GitHub token, yield
  /// [RepoBranchesResponse.unavailable].
  Future<RepoBranchesResponse> machineRepoBranches({
    required String machineId,
    required String repoUrl,
    String? ref,
  }) async {
    try {
      return await _retryIdempotentMachineRPC(
        machineId,
        'repo-branches',
        <String, dynamic>{
          'repoUrl': repoUrl.trim(),
          if (ref != null && ref.trim().isNotEmpty) 'ref': ref.trim(),
        },
        RepoBranchesResponse.fromJson,
        timeout: _gitIdentityTimeout,
      );
    } catch (error) {
      logger.debug('repo-branches unavailable on $machineId: $error');
      return const RepoBranchesResponse(success: false, unavailable: true);
    }
  }
}
