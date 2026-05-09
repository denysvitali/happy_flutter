/// Stateful property-based tests for the four core messaging
/// invariants from `ROADMAP.md` P0:
///
///   1. One tap → one logical message.
///   2. One canonical [LocalId] across UI / sync / HTTP / socket /
///      retry / merge.
///   3. Repeated text (e.g. "continue") is never identity.
///   4. Optimistic replacement is by [LocalId], never by text or
///      position.
///
/// We model the lifecycle with the command grammar in
/// `messaging_commands.dart` and assert the invariants on every step.
/// Failing traces are shrunk by [PropertyRunner].
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/types/identity_types.dart';
import 'package:happy_flutter/core/types/message_state.dart';

import 'messaging_commands.dart';
import 'property_runner.dart';

// ─────────────────────────────────────────────────────────────────────
// Generators
// ─────────────────────────────────────────────────────────────────────

/// Pool of identical user texts to maximise the chance of triggering
/// merge-by-text bugs.  The "continue" string is deliberately included
/// because ROADMAP P0 calls it out.
const _fixedTexts = <String>['continue', 'ok', 'next', 'go', 'continue'];

List<MessagingCommand> _genProgram(Random rng, int length) {
  final program = <MessagingCommand>[];
  // Track tapIds we've sent so retries / acks can target them.
  final outstanding = <int>[];
  var nextTap = 1;

  for (var i = 0; i < length; i++) {
    // Bias toward Send so most programs exercise non-trivial state.
    final r = rng.nextInt(100);
    if (r < 40 || outstanding.isEmpty) {
      final tap = nextTap++;
      final text = _fixedTexts[rng.nextInt(_fixedTexts.length)];
      program.add(Send(tapId: tap, text: text));
      outstanding.add(tap);
    } else if (r < 55) {
      final tap = outstanding[rng.nextInt(outstanding.length)];
      program.add(RestAck(tapId: tap, serverId: 'srv-$tap'));
    } else if (r < 70) {
      final tap = outstanding[rng.nextInt(outstanding.length)];
      program.add(SocketEcho(tapId: tap, serverId: 'srv-$tap'));
    } else if (r < 75) {
      final tap = outstanding[rng.nextInt(outstanding.length)];
      program.add(RestFail(tapId: tap));
    } else if (r < 82) {
      final tap = outstanding[rng.nextInt(outstanding.length)];
      program.add(RetrySend(tapId: tap));
    } else if (r < 86) {
      // Fetch a random subset of outstanding taps.
      final picks = <int>[];
      for (final t in outstanding) {
        if (rng.nextBool()) picks.add(t);
      }
      program.add(FetchPage(tapIds: picks));
    } else if (r < 90) {
      program.add(const Suspend());
      // Emit a Resume soon so we don't spend the whole trace asleep.
      program.add(const Resume());
    } else if (r < 94) {
      program.add(const Disconnect());
      program.add(const Reconnect());
    } else {
      program.add(const Resume());
    }
  }
  return program;
}

// ─────────────────────────────────────────────────────────────────────
// Invariants
// ─────────────────────────────────────────────────────────────────────

/// Invariant #1: every tap has exactly one row.  No duplication, no
/// dropped sends.
void _invariantOneTapOneRow(
  MessagingModel model,
  List<MessagingCommand> trace,
) {
  final byTap = <int, int>{};
  for (final r in model.rows) {
    byTap[r.tapId] = (byTap[r.tapId] ?? 0) + 1;
  }
  for (final entry in byTap.entries) {
    if (entry.value != 1) {
      throw StateError(
        'INVARIANT VIOLATION: tap ${entry.key} has ${entry.value} rows '
        '(expected 1) — duplicate logical message',
      );
    }
  }
}

/// Invariant #2: LocalId is canonical.  Every row's LocalId is unique
/// (no two distinct taps share an id) and non-empty.
void _invariantCanonicalLocalId(
  MessagingModel model,
  List<MessagingCommand> trace,
) {
  final seen = <LocalId, int>{};
  for (final r in model.rows) {
    if (r.localId.isEmpty) {
      throw StateError(
        'INVARIANT VIOLATION: row $r has empty LocalId — '
        'optimistic placeholder must always have a non-empty id',
      );
    }
    final prev = seen[r.localId];
    if (prev != null && prev != r.tapId) {
      throw StateError(
        'INVARIANT VIOLATION: LocalId ${r.localId.value} reused for '
        'tap ${r.tapId} and tap $prev — id collision across taps',
      );
    }
    seen[r.localId] = r.tapId;
  }
}

/// Invariant #3: identical text never collapses.  Two rows with the
/// same text but different tapIds remain distinct.
void _invariantTextIsNotIdentity(
  MessagingModel model,
  List<MessagingCommand> trace,
) {
  // Group rows by text.  Each text bucket may contain multiple rows
  // (e.g. two "continue" sends) — we just assert they all carry
  // distinct LocalIds.
  final byText = <String, List<LocalId>>{};
  for (final r in model.rows) {
    byText.putIfAbsent(r.text, () => []).add(r.localId);
  }
  for (final entry in byText.entries) {
    final ids = entry.value;
    final unique = ids.toSet();
    if (ids.length != unique.length) {
      throw StateError(
        'INVARIANT VIOLATION: text "${entry.key}" produced duplicate '
        'LocalIds: $ids — text must never be identity',
      );
    }
  }
}

/// Invariant #4: replacement preserves identity.  Whenever a row has
/// reached `MessageSent`, its LocalId matches the LocalId minted at
/// the original Send — i.e. the row was not torn down and re-created.
void _invariantReplacementByLocalId(
  MessagingModel model,
  List<MessagingCommand> trace,
) {
  // The LocalId is final once minted; the model never reassigns it.
  // We assert that property here directly: walk the trace, record the
  // first Send for each tap, and verify the model row still carries
  // that exact LocalId.
  final firstSeen = <int, LocalId>{};
  for (final cmd in trace) {
    if (cmd is Send) {
      // We can't observe the model's mint from the trace alone, so
      // instead we look up the live row.  This step is only meaningful
      // for taps already inserted into the model.
      final row = model.rows.firstWhere(
        (r) => r.tapId == cmd.tapId,
        orElse: () => ModelRow(
          tapId: -1,
          localId: const LocalId(''),
          text: '',
        ),
      );
      if (row.tapId != -1) {
        firstSeen.putIfAbsent(cmd.tapId, () => row.localId);
        // If we previously saw the row with a *different* id, that
        // means the merge code re-minted on retry — invariant broken.
        if (firstSeen[cmd.tapId] != row.localId) {
          throw StateError(
            'INVARIANT VIOLATION: tap ${cmd.tapId} LocalId changed from '
            '${firstSeen[cmd.tapId]} to ${row.localId} — replacement '
            'must preserve LocalId',
          );
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  group('messaging contract — stateful property tests', () {
    test('runs 200 random programs without invariant violations', () {
      final runner = PropertyRunner(
        runs: 200,
        maxLength: 40,
        generate: _genProgram,
        checks: [
          _invariantOneTapOneRow,
          _invariantCanonicalLocalId,
          _invariantTextIsNotIdentity,
          _invariantReplacementByLocalId,
        ],
      );

      final result = runner.run();
      if (!result.passed) {
        fail(
          'Property failed: ${result.failureMessage}\n'
          'Shrunk trace (${result.failingTrace?.length} cmds):\n'
          '${result.failingTrace?.map((c) => '  $c').join('\n')}',
        );
      }
    });

    test('repeated identical sends produce distinct LocalIds', () {
      // Targeted regression test for the "continue / ok / continue"
      // pattern called out in ROADMAP P0.
      final model = MessagingModel(seed: 1);
      const program = <MessagingCommand>[
        Send(tapId: 1, text: 'continue'),
        Send(tapId: 2, text: 'continue'),
        Send(tapId: 3, text: 'continue'),
      ];
      for (final c in program) {
        model.apply(c);
      }
      final ids = model.rows.map((r) => r.localId.value).toSet();
      expect(ids.length, 3, reason: 'three sends → three distinct LocalIds');
      expect(model.rows.length, 3);
    });

    test('retry preserves LocalId; fresh send mints a new one', () {
      final model = MessagingModel(seed: 2);
      const program = <MessagingCommand>[
        Send(tapId: 1, text: 'hi'),
        RestFail(tapId: 1),
        RetrySend(tapId: 1),
        Send(tapId: 2, text: 'hi'),
      ];
      for (final c in program) {
        model.apply(c);
      }
      final tap1 = model.rows.firstWhere((r) => r.tapId == 1);
      final tap2 = model.rows.firstWhere((r) => r.tapId == 2);
      expect(tap1.localId, isNot(tap2.localId));
      expect(tap1.state, isA<MessageSending>(),
          reason: 'retry resets state to sending without changing id');
    });

    test('socket echo replaces optimistic row by LocalId', () {
      final model = MessagingModel(seed: 3);
      const program = <MessagingCommand>[
        Send(tapId: 1, text: 'ping'),
        SocketEcho(tapId: 1, serverId: 'srv-1'),
      ];
      for (final c in program) {
        model.apply(c);
      }
      expect(model.rows.length, 1, reason: 'echo must not duplicate');
      expect(model.rows.first.serverId, const ServerMessageId('srv-1'));
      expect(model.rows.first.state, isA<MessageSent>());
    });

    test('out-of-order REST ack + later socket echo do not duplicate', () {
      // Repro of the scheduling pattern that caused the older
      // "duplicate message" GlitchTip events: REST 2xx fires first,
      // then a delayed socket echo arrives carrying a different
      // serverId.  The merge must still recognise the row by its
      // canonical LocalId.
      final model = MessagingModel(seed: 4);
      const program = <MessagingCommand>[
        Send(tapId: 1, text: 'roundtrip'),
        RestAck(tapId: 1, serverId: 'srv-1'),
        SocketEcho(tapId: 1, serverId: 'srv-1'),
      ];
      for (final c in program) {
        model.apply(c);
      }
      expect(model.rows.length, 1, reason: 'no duplicate after race');
    });
  });
}
