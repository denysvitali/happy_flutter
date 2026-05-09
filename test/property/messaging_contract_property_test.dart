// Property-based tests that mirror the TLA+ specification at
// spec/messaging.tla. We run randomized but seeded action sequences
// against an in-memory model that implements the same Tap/Ack/Fail/
// Retry/Resend rules and assert the four invariants on every step.
//
// This is a deliberately minimal generator written without external
// property-testing dependencies (glados / fast_check are not present
// in pubspec.yaml). Every test seeds its own PRNG so failures are
// reproducible by reading the seed printed in the test name.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

enum MsgState { draft, sending, sent, pending, failed, merged }

class _Msg {
  _Msg({required this.text, required this.state, this.retryOf});
  final String text;
  MsgState state;
  final int? retryOf;
}

class MessagingModel {
  final Map<int, _Msg> _messages = {};
  final Set<int> _optimistic = {};
  final Set<int> _acked = {};
  int _nextLocalId = 0;
  int _taps = 0;

  Map<int, _Msg> get messages => Map.unmodifiable(_messages);
  Set<int> get optimistic => Set.unmodifiable(_optimistic);
  Set<int> get acked => Set.unmodifiable(_acked);
  int get taps => _taps;

  int tap(String text) {
    final id = _nextLocalId++;
    _messages[id] =
        _Msg(text: text, state: MsgState.sending, retryOf: null);
    _optimistic.add(id);
    _taps++;
    return id;
  }

  void ack(int id) {
    final m = _messages[id];
    if (m == null || m.state != MsgState.sending) return;
    if (!_optimistic.contains(id)) return;
    if (_acked.contains(id)) return;
    m.state = MsgState.merged;
    _optimistic.remove(id);
    _acked.add(id);
  }

  void fail(int id) {
    final m = _messages[id];
    if (m == null || m.state != MsgState.sending) return;
    m.state = MsgState.failed;
  }

  /// Explicit retry — preserves the original localId.
  void retry(int id) {
    final m = _messages[id];
    if (m == null || m.state != MsgState.failed) return;
    m.state = MsgState.sending;
  }

  /// Fresh resend — creates a new logical message that points at the
  /// parent via retryOf but otherwise has its own localId.
  int resend(int parent) {
    final p = _messages[parent];
    if (p == null) return -1;
    if (p.state != MsgState.failed && p.state != MsgState.merged) return -1;
    final id = _nextLocalId++;
    _messages[id] =
        _Msg(text: p.text, state: MsgState.sending, retryOf: parent);
    _optimistic.add(id);
    _taps++;
    return id;
  }

  /// I1 — identity. Every entry is uniquely keyed by localId.
  void checkIdentity() {
    final ids = _messages.keys.toSet();
    expect(ids.length, _messages.length,
        reason: 'localId keys are not unique');
  }

  /// I2 — no two taps collapse. taps == |messages|.
  void checkNoDup() {
    expect(_messages.length, _taps,
        reason: 'distinct taps must produce distinct logical messages '
            '(taps=$_taps, messages=${_messages.length})');
  }

  /// I3 — optimistic and acked sets never overlap; acked is always merged.
  void checkReplacement() {
    final overlap = _optimistic.intersection(_acked);
    expect(overlap, isEmpty,
        reason: 'optimistic row was acked without removing it');
    for (final id in _acked) {
      expect(_messages[id]?.state, MsgState.merged,
          reason: 'acked id $id is not merged');
    }
  }

  /// I4 — retry preserves identity; resend allocates a strictly new id
  /// pointing at the parent.
  void checkRetry() {
    for (final entry in _messages.entries) {
      final retryOf = entry.value.retryOf;
      if (retryOf == null) continue;
      expect(retryOf < entry.key, isTrue,
          reason: 'resend child ${entry.key} has parent $retryOf >= self');
      expect(_messages.containsKey(retryOf), isTrue,
          reason: 'resend parent $retryOf is missing from model');
    }
  }

  void checkAll() {
    checkIdentity();
    checkNoDup();
    checkReplacement();
    checkRetry();
  }
}

enum _Action { tap, ack, fail, retry, resend }

void main() {
  group('messaging contract — TLA+ mirror', () {
    test('hand-crafted scenarios', () {
      final m = MessagingModel();
      final id1 = m.tap('continue');
      final id2 = m.tap('continue');
      expect(id1, isNot(id2), reason: 'distinct taps must mint distinct ids');
      m.ack(id1);
      m.fail(id2);
      m.retry(id2);
      m.ack(id2);
      final id3 = m.resend(id2);
      expect(id3, greaterThan(id2));
      expect(m.messages[id3]!.retryOf, id2);
      m.checkAll();
    });

    // Seeded randomized exploration. We run a handful of seeds; each
    // seed deterministically replays its action trace on failure.
    for (final seed in const [1, 7, 42, 1337, 90_210]) {
      test('random trace seed=$seed maintains invariants', () {
        final rng = Random(seed);
        final m = MessagingModel();
        const steps = 200;
        for (var step = 0; step < steps; step++) {
          final ids = m.messages.keys.toList();
          final actions = <_Action>[
            _Action.tap,
            if (m.optimistic.isNotEmpty) _Action.ack,
            if (m.optimistic.isNotEmpty) _Action.fail,
            if (ids.any(
                (id) => m.messages[id]!.state == MsgState.failed))
              _Action.retry,
            if (ids.any((id) =>
                m.messages[id]!.state == MsgState.failed ||
                m.messages[id]!.state == MsgState.merged))
              _Action.resend,
          ];
          final action = actions[rng.nextInt(actions.length)];
          switch (action) {
            case _Action.tap:
              m.tap(rng.nextBool() ? 'continue' : 'hi');
            case _Action.ack:
              final pool = m.optimistic.toList();
              m.ack(pool[rng.nextInt(pool.length)]);
            case _Action.fail:
              final pool = m.optimistic.toList();
              m.fail(pool[rng.nextInt(pool.length)]);
            case _Action.retry:
              final pool = ids
                  .where(
                      (id) => m.messages[id]!.state == MsgState.failed)
                  .toList();
              if (pool.isNotEmpty) {
                m.retry(pool[rng.nextInt(pool.length)]);
              }
            case _Action.resend:
              final pool = ids
                  .where((id) =>
                      m.messages[id]!.state == MsgState.failed ||
                      m.messages[id]!.state == MsgState.merged)
                  .toList();
              if (pool.isNotEmpty) {
                m.resend(pool[rng.nextInt(pool.length)]);
              }
          }
          m.checkAll();
        }
      });
    }
  });
}
