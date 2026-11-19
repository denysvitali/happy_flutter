/// Synced, nested session folders (happy-cli-go
/// `docs/operations/session-folders.md`).
///
/// [sessionFoldersProvider] mirrors the encrypted `session-folders` KV
/// document: loaded when the socket connects (start and every reconnect),
/// replaced by `kv-batch-update` events, and given any missing reader wraps
/// (account, legacy, every data-key machine this app can open) on load.
/// User edits go through [sessionFolderOperationsProvider]: they show at
/// once ([sessionFolderDocProvider] overlays pending edits) and are written
/// in the background with compare-and-set; a failure drops the overlay and
/// is reported by `OperationFailureListener`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod/riverpod.dart';

import '../api/kv_api.dart';
import '../api/socket_io_client.dart' show ConnectionStatus;
import '../encryption/encryption_manager.dart';
import '../folders/session_folders_doc.dart';
import '../folders/session_folders_envelope.dart';
import '../folders/session_folders_repository.dart';
import '../folders/session_folders_tree.dart';
import '../operations/operation_store.dart';
import '../services/logger_service.dart' show logger;
import '../services/sync_service.dart';
import 'connection_notifier.dart';
import 'sessions_notifier.dart';

@immutable
class SessionFoldersState {
  const SessionFoldersState({
    this.access = FolderAccess.absent,
    this.doc = FolderDoc.empty,
    this.loaded = false,
  });

  final FolderAccess access;
  final FolderDoc doc;

  /// Whether the document was read at least once for this account.
  final bool loaded;

  /// Edits are refused: a newer writer's document, or one this app cannot
  /// decrypt (which it must never overwrite).
  bool get readOnly =>
      access == FolderAccess.readOnly || access == FolderAccess.unreadable;

  bool get unreadable => access == FolderAccess.unreadable;
}

/// Builds the repository for the signed-in account. Override in tests.
final sessionFoldersRepositoryFactoryProvider =
    Provider<SessionFoldersRepository Function(Encryption encryption)>(
      (ref) =>
          (encryption) => SessionFoldersRepository(
            kv: KvApi(),
            codec: SessionFoldersCodec(
              EncryptionFolderKeyring(encryption, () => sync.machineDataKeys),
            ),
          ),
    );

class SessionFoldersNotifier extends Notifier<SessionFoldersState> {
  FolderSnapshot _snapshot = FolderSnapshot.absent;
  SessionFoldersRepository? _repository;
  Encryption? _repositoryEncryption;
  Future<void> _queue = Future<void>.value();

  @override
  SessionFoldersState build() {
    final kv = sync.onKvChanges.listen(_onKvChanges);
    final machines = sync.onDomainChanged
        .where((domain) => domain == SyncDomain.machines)
        .listen((_) => _onMachinesChanged());
    ref.listen(connectionNotifierProvider, (previous, next) {
      if (next == ConnectionStatus.connected &&
          previous != ConnectionStatus.connected) {
        unawaited(refresh());
      }
    });
    ref.onDispose(() {
      unawaited(kv.cancel());
      unawaited(machines.cancel());
    });
    scheduleMicrotask(() => unawaited(refresh()));
    return const SessionFoldersState();
  }

  /// The repository for the current account; a new account starts over.
  SessionFoldersRepository? _repo() {
    if (!sync.isInitialized || !sync.isEncryptionInitialized) return null;
    final encryption = sync.encryption;
    if (!identical(encryption, _repositoryEncryption)) {
      _repositoryEncryption = encryption;
      _repository = ref.read(sessionFoldersRepositoryFactoryProvider)(
        encryption,
      );
      _snapshot = FolderSnapshot.absent;
      state = const SessionFoldersState();
    }
    return _repository;
  }

  /// Runs [task] after every earlier read/write, so a write never races a
  /// load of the same document.
  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void _publish(FolderSnapshot snapshot) {
    _snapshot = snapshot;
    if (!ref.mounted) return;
    state = SessionFoldersState(
      access: snapshot.access,
      doc: snapshot.doc,
      loaded: true,
    );
  }

  /// Reloads the document and adds missing wraps. Never throws.
  Future<void> refresh() => _serial(() async {
    final repo = _repo();
    if (repo == null) return;
    try {
      final loaded = await repo.load();
      if (!identical(repo, _repository)) return;
      _publish(loaded);
      if (loaded.access == FolderAccess.unreadable) {
        logger.warning('SessionFolders: document cannot be decrypted');
      }
      await _addMissingWraps(repo);
    } catch (e, st) {
      logger.warning('SessionFolders: load failed', e, st);
    }
  });

  Future<void> _addMissingWraps(SessionFoldersRepository repo) async {
    if (!_snapshot.writable || _snapshot.opened.seal == null) return;
    try {
      final written = await repo.write(null, _snapshot);
      if (identical(repo, _repository)) _publish(written);
    } catch (e, st) {
      logger.warning('SessionFolders: adding reader wraps failed', e, st);
    }
  }

  void _onMachinesChanged() {
    if (!state.loaded) {
      unawaited(refresh());
      return;
    }
    unawaited(
      _serial(() async {
        final repo = _repo();
        if (repo != null) await _addMissingWraps(repo);
      }),
    );
  }

  void _onKvChanges(List<Map<String, dynamic>> changes) {
    for (final change in changes) {
      if (change['key'] != sessionFoldersKvKey) continue;
      final version = change['version'];
      final value = change['value'];
      if (version is! int || (value != null && value is! String)) continue;
      unawaited(
        _serial(() async {
          final repo = _repo();
          if (repo == null || version <= _snapshot.version) return;
          final next = await repo.decode(value as String?, version);
          if (identical(repo, _repository) && version > _snapshot.version) {
            _publish(next);
          }
        }),
      );
    }
  }

  /// Writes [edit] with compare-and-set (re-applied on a lost race).
  /// Throws [FolderRuleException], [FolderConflictException] or the KV
  /// error.
  Future<void> commit(FolderEdit edit) => _serial(() async {
    final repo = _repo();
    if (repo == null) throw StateError('not signed in');
    if (!state.loaded) _publish(await repo.load());
    final written = await repo.write(edit, _snapshot);
    if (identical(repo, _repository)) _publish(written);
  });

  /// A session was deleted: drop its assignment and the folders anchored
  /// at it. Best effort and silent.
  void forgetSession(String sessionId) {
    final edit = ForgetSession(sessionId);
    if (state.loaded && identical(edit.apply(state.doc), state.doc)) return;
    unawaited(
      commit(edit).catchError((Object e, StackTrace st) {
        logger.warning('SessionFolders: cleanup after delete failed', e, st);
      }),
    );
  }
}

final sessionFoldersProvider =
    NotifierProvider<SessionFoldersNotifier, SessionFoldersState>(
      SessionFoldersNotifier.new,
    );

/// One user folder edit; [seq] keeps every submission its own record.
@immutable
class FolderEditRequest {
  const FolderEditRequest(this.seq, this.edit);

  final int seq;
  final FolderEdit edit;
}

typedef FolderEditOperation = Operation<FolderEditRequest>;

class SessionFolderOperationsNotifier
    extends OperationStore<FolderEditRequest> {
  int _seq = 0;

  @override
  String get logName => 'SessionFolder';

  @override
  String keyOf(FolderEditRequest request) => 'folder-edit-${request.seq}';

  /// Applies [edit] at once and writes it in the background. Returns the
  /// rule it breaks against the shown tree (nothing is submitted then).
  FolderRule? edit(FolderEdit edit) {
    final shown = ref.read(sessionFolderDocProvider);
    if (ref.read(sessionFoldersProvider).readOnly) return FolderRule.readOnly;
    try {
      edit.apply(shown);
    } on FolderRuleException catch (e) {
      return e.rule;
    }
    submit(FolderEditRequest(++_seq, edit));
    return null;
  }

  @override
  Future<Object?> perform(FolderEditRequest request) async {
    await ref.read(sessionFoldersProvider.notifier).commit(request.edit);
    return null;
  }

  @override
  void onSucceeded(FolderEditOperation operation) => dismiss(operation.key);
}

final sessionFolderOperationsProvider =
    NotifierProvider<
      SessionFolderOperationsNotifier,
      Map<String, FolderEditOperation>
    >(SessionFolderOperationsNotifier.new);

/// The folder document as the user sees it: the stored one with pending
/// edits applied in submission order (an edit the newer document refuses
/// is skipped; its write will fail and be reported).
final sessionFolderDocProvider = Provider<FolderDoc>((ref) {
  final doc = ref.watch(sessionFoldersProvider.select((s) => s.doc));
  final pending =
      ref
          .watch(sessionFolderOperationsProvider)
          .values
          .where((op) => op.isPending)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  var shown = doc;
  for (final op in pending) {
    try {
      shown = op.request.edit.apply(shown);
    } on FolderRuleException {
      // Shown without it.
    }
  }
  return shown;
});

/// [sessionFolderDocProvider] resolved against the session catalog.
final sessionFolderTreeProvider = Provider<FolderTree>((ref) {
  final doc = ref.watch(sessionFolderDocProvider);
  if (doc.isEmpty) return FolderTree.empty;
  return FolderTree.build(doc, ref.watch(sessionsNotifierProvider));
});
