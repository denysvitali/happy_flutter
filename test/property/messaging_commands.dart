/// Stateful property-based testing for the messaging contract.
///
/// We model the lifecycle of a single chat session as a small
/// command grammar:
///
///     Send / Retry / SocketEcho / RestAck / Suspend / Resume /
///     FetchPage / Disconnect
///
/// A "world" is a sequence of these commands plus a model that tracks
/// the *intended* outcome — every distinct user tap should yield
/// exactly one logical message identified by a stable [LocalId].
///
/// This file deliberately avoids spinning up a real [Sync] singleton.
/// We model the merge invariants directly as pure data so the property
/// tests run fast and deterministic in CI.  The same command grammar
/// can later drive the deterministic simulator (item #1) once it
/// exists.
import 'dart:math';

import 'package:happy_flutter/core/types/identity_types.dart';
import 'package:happy_flutter/core/types/message_state.dart';

/// Identifier for a logical user tap in the test world.  Distinct
/// from [LocalId] because we want to assert that every tap maps to
/// exactly one [LocalId] — re-using the same value would assume
/// the property under test.
typedef TapId = int;

/// One step in the modelled lifecycle.
sealed class MessagingCommand {
  const MessagingCommand();
}

/// User tapped send with [text].  The model assigns a [LocalId] and
/// inserts an optimistic row.  Repeated identical text is allowed —
/// each [Send] gets a fresh [LocalId].
class Send extends MessagingCommand {
  const Send({required this.tapId, required this.text});
  final TapId tapId;
  final String text;
  @override
  String toString() => 'Send(tap=$tapId, text="$text")';
}

/// User tapped retry on a previously-failed message.  Must reuse the
/// same [LocalId] that was minted in the original [Send] — that is the
/// invariant under test.
class RetrySend extends MessagingCommand {
  const RetrySend({required this.tapId});
  final TapId tapId;
  @override
  String toString() => 'RetrySend(tap=$tapId)';
}

/// REST endpoint returned 2xx for [tapId].  Marks the message as
/// [MessageSent].
class RestAck extends MessagingCommand {
  const RestAck({required this.tapId, required this.serverId});
  final TapId tapId;
  final String serverId;
  @override
  String toString() => 'RestAck(tap=$tapId, server=$serverId)';
}

/// Socket forwarded an echo for [tapId] (with a [serverId] from the
/// authoritative store).  Must replace the optimistic row by [LocalId],
/// never by text similarity or list position.
class SocketEcho extends MessagingCommand {
  const SocketEcho({required this.tapId, required this.serverId});
  final TapId tapId;
  final String serverId;
  @override
  String toString() => 'SocketEcho(tap=$tapId, server=$serverId)';
}

/// REST send failed — outbox flips the row to [MessagePending] and
/// will retry.
class RestFail extends MessagingCommand {
  const RestFail({required this.tapId});
  final TapId tapId;
  @override
  String toString() => 'RestFail(tap=$tapId)';
}

/// App suspended (lifecycle background).  No new commands run until
/// [Resume].
class Suspend extends MessagingCommand {
  const Suspend();
  @override
  String toString() => 'Suspend()';
}

class Resume extends MessagingCommand {
  const Resume();
  @override
  String toString() => 'Resume()';
}

/// Socket disconnected.  REST and outbox should still drive identity
/// preservation.
class Disconnect extends MessagingCommand {
  const Disconnect();
  @override
  String toString() => 'Disconnect()';
}

class Reconnect extends MessagingCommand {
  const Reconnect();
  @override
  String toString() => 'Reconnect()';
}

/// Server returns a page that includes some previously-acked rows.
/// Must merge by [LocalId], never duplicate.
class FetchPage extends MessagingCommand {
  const FetchPage({required this.tapIds});
  final List<TapId> tapIds;
  @override
  String toString() => 'FetchPage(taps=$tapIds)';
}

/// A single row in the modelled session message list.
class ModelRow {
  ModelRow({
    required this.tapId,
    required this.localId,
    required this.text,
    this.serverId,
    this.state = const MessageSending(),
  });

  final TapId tapId;
  final LocalId localId;
  final String text;
  ServerMessageId? serverId;
  MessageSendState state;

  @override
  String toString() =>
      'Row(tap=$tapId, lcl=${localId.value}, '
      'srv=${serverId?.value ?? '-'}, st=${state.wireString})';
}

/// The pure model the property tests exercise.  No async, no real
/// network, no Sync singleton — just the merge invariants under test.
class MessagingModel {
  MessagingModel({int seed = 0xDEADBEEF}) : _rng = Random(seed);

  final Random _rng;

  /// In-flight rows in chat order.  We never remove a row: the
  /// invariants assert that lifecycle changes happen in place.
  final List<ModelRow> rows = <ModelRow>[];

  /// `tapId → LocalId` mapping observed when the user first sent.
  /// Property #2: the same [LocalId] is reused on retry.
  final Map<TapId, LocalId> _tapToLocal = <TapId, LocalId>{};

  /// Suspended state — Apply uses this to fail-fast on illegal moves.
  bool suspended = false;

  /// Disconnected state — only relevant for chaos sequencing.
  bool socketConnected = true;

  /// Mints a fresh [LocalId].  Prefixes a counter to keep traces
  /// human-readable in failing-trace shrinking output.
  LocalId _newLocalId() {
    final n = _rng.nextInt(1 << 31);
    return LocalId('lcl-${rows.length}-$n');
  }

  void apply(MessagingCommand cmd) {
    if (suspended &&
        cmd is! Resume &&
        cmd is! Suspend &&
        cmd is! Reconnect) {
      // While suspended, ignore everything — mirrors `Sync.suspend()`'s
      // cancellation of timers + InvalidateSync.isBackgrounded gating.
      return;
    }
    switch (cmd) {
      case Send(:final tapId, :final text):
        // Fresh tap — must mint a brand new LocalId.  Repeated taps
        // (including identical text) get distinct ids.
        final lid = _newLocalId();
        _tapToLocal[tapId] = lid;
        rows.add(ModelRow(tapId: tapId, localId: lid, text: text));
      case RetrySend(:final tapId):
        // Retries MUST reuse the original LocalId — never mint a new
        // one.  This is the canonical invariant from ROADMAP P0.
        final existing = _tapToLocal[tapId];
        if (existing == null) return; // no-op, can't retry an unsent
        // Find the row and flip back to "sending" without changing id.
        final row = rows.firstWhere(
          (r) => r.tapId == tapId,
          orElse: () => throw StateError('Retry without row'),
        );
        if (row.state is MessageFailed || row.state is MessagePending) {
          row.state = const MessageSending();
        }
      case RestAck(:final tapId, :final serverId):
        final row = _findRow(tapId);
        if (row == null) return;
        row.serverId = ServerMessageId(serverId);
        row.state = const MessageSent();
      case SocketEcho(:final tapId, :final serverId):
        if (!socketConnected) return;
        final row = _findRow(tapId);
        if (row == null) return;
        // Must replace by LocalId — duplicate detection.
        row.serverId = ServerMessageId(serverId);
        row.state = const MessageSent();
      case RestFail(:final tapId):
        final row = _findRow(tapId);
        if (row == null) return;
        row.state = const MessagePending();
      case FetchPage(:final tapIds):
        // Server returns rows by serverId.  We must NOT add new
        // rows for tapIds we already have — merge by LocalId.
        for (final tapId in tapIds) {
          final row = _findRow(tapId);
          if (row == null) continue;
          row.state = const MessageSent();
          row.serverId ??= ServerMessageId('srv-fetch-$tapId');
        }
      case Suspend():
        suspended = true;
      case Resume():
        suspended = false;
      case Disconnect():
        socketConnected = false;
      case Reconnect():
        socketConnected = true;
    }
  }

  ModelRow? _findRow(TapId tapId) {
    for (final r in rows) {
      if (r.tapId == tapId) return r;
    }
    return null;
  }
}
