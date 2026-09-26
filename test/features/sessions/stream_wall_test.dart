import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_types.dart';
import 'package:happy_flutter/features/sessions/widgets/stream_wall.dart';

/// The Live wire is a pure snapshot diff: no fetches, no timers. Opening
/// the board seeds a baseline (no flood), then every visible change
/// between snapshots becomes exactly one coalesced event.
void main() {
  const base = WireSessionState(
    name: 'api-fix',
    workspaceKey: 'm:/repo',
    live: true,
    lane: MissionLane.live,
    unreadCount: 0,
    createdAt: 1000,
    activeAt: 1000,
    lastMessageAt: 1000,
    preview: 'thinking',
    role: 'agent',
    isError: false,
  );

  group('diffWireEvents', () {
    test('the first snapshot only seeds the baseline', () {
      final next = {'s1': base};
      expect(
        diffWireEvents(previous: null, next: next, nowMs: 5000, sinceMs: 0),
        isEmpty,
      );
    });

    test('a session entering the active set is joined', () {
      final previous = <String, WireSessionState>{};
      final next = <String, WireSessionState>{'s1': base};
      final events = diffWireEvents(
        previous: previous,
        next: next,
        nowMs: 5000,
        sinceMs: 0,
      );
      expect(events, hasLength(1));
      expect(events.single.kind, WireEventKind.joined);
      expect(events.single.sessionId, 's1');
    });

    test('an advanced agent message is inbound with its preview', () {
      final previous = {'s1': base};
      final next = {
        's1': _with(base, lastMessageAt: 6000, preview: 'fixed the parser'),
      };
      final events = diffWireEvents(
        previous: previous,
        next: next,
        nowMs: 6000,
        sinceMs: 0,
      );
      expect(events.single.kind, WireEventKind.inbound);
      expect(events.single.detail, 'fixed the parser');
    });

    test('a user-role advance routes to sent, an error to error', () {
      final previous = {'u': base, 'e': base};
      final next = {
        'u': _with(base, lastMessageAt: 7000, role: 'user'),
        'e': _with(base, lastMessageAt: 7000, isError: true),
      };
      final events = diffWireEvents(
        previous: previous,
        next: next,
        nowMs: 7000,
        sinceMs: 0,
      );
      final kinds = {for (final e in events) e.sessionId: e.kind};
      expect(kinds['u'], WireEventKind.sent);
      expect(kinds['e'], WireEventKind.error);
    });

    test('a permission raise without new traffic fires blocked once', () {
      final previous = {'s1': base};
      final next = {'s1': _with(base, lane: MissionLane.blocked)};
      final events = diffWireEvents(
        previous: previous,
        next: next,
        nowMs: 8000,
        sinceMs: 0,
      );
      expect(events.single.kind, WireEventKind.blocked);
    });

    test('blocked stays silent while its message event already fired', () {
      // A permission raise that arrives with the message tick produces one
      // inbound line, not inbound + blocked for the same moment.
      final previous = {'s1': base};
      final next = {
        's1': _with(base, lastMessageAt: 9000, lane: MissionLane.blocked),
      };
      final events = diffWireEvents(
        previous: previous,
        next: next,
        nowMs: 9000,
        sinceMs: 0,
      );
      expect(events, hasLength(1));
      expect(events.single.kind, WireEventKind.inbound);
    });

    test('a settled stop is done; blocked/error stops are not', () {
      final previous = {'ok': base, 'err': base};
      final nowMs = 10 * 1000;
      final next = {
        'ok': _with(base, live: false, lane: MissionLane.quiet),
        'err': _with(base, live: false, lane: MissionLane.error, isError: true),
      };
      final events = diffWireEvents(
        previous: previous,
        next: next,
        nowMs: nowMs,
        sinceMs: 0,
      );
      final kinds = {for (final e in events) e.sessionId: e.kind};
      expect(kinds['ok'], WireEventKind.done);
      expect(kinds.containsKey('err'), isFalse);
    });

    test('unchanged snapshots produce nothing', () {
      final previous = {'s1': base};
      final next = {'s1': base};
      expect(
        diffWireEvents(previous: previous, next: next, nowMs: 9999, sinceMs: 0),
        isEmpty,
      );
    });

    test('a historical session loaded after mount is not started', () {
      final events = diffWireEvents(
        previous: const {},
        next: const {'s1': base},
        nowMs: 3 * 24 * 3600 * 1000,
        sinceMs: 2 * 24 * 3600 * 1000,
      );
      expect(events, isEmpty);
    });

    test('a session from just before mount is not started', () {
      final events = diffWireEvents(
        previous: const {},
        next: {'s1': _with(base, activeAt: 8500)},
        nowMs: 10000,
        sinceMs: 9000,
      );
      expect(events, isEmpty);
    });

    test('a historical message loaded after mount is not new', () {
      final events = diffWireEvents(
        previous: const {'s1': base},
        next: {'s1': _with(base, lastMessageAt: 2000)},
        nowMs: 3 * 24 * 3600 * 1000,
        sinceMs: 2 * 24 * 3600 * 1000,
      );
      expect(events, isEmpty);
    });

    test('a message from just before mount is not new', () {
      final events = diffWireEvents(
        previous: const {'s1': base},
        next: {'s1': _with(base, lastMessageAt: 8500)},
        nowMs: 10000,
        sinceMs: 9000,
      );
      expect(events, isEmpty);
    });

    test('a recent message keeps its real timestamp', () {
      final events = diffWireEvents(
        previous: const {'s1': base},
        next: {'s1': _with(base, lastMessageAt: 9500)},
        nowMs: 10000,
        sinceMs: 9000,
      );
      expect(events.single.atMs, 9500);
    });

    test('a recent session joining keeps its real active time', () {
      final events = diffWireEvents(
        previous: const {},
        next: {'s1': _with(base, activeAt: 9500)},
        nowMs: 10000,
        sinceMs: 9000,
      );
      expect(events.single.kind, WireEventKind.joined);
      expect(events.single.atMs, 9500);
    });
  });

  group('mergeWireEvents', () {
    WireEvent ev({
      required String id,
      int at = 0,
      WireEventKind kind = WireEventKind.inbound,
      String name = 'n',
    }) => WireEvent(
      sessionId: id,
      sessionName: name,
      workspaceKey: 'w',
      atMs: at,
      kind: kind,
    );

    test('coalesces an inbound burst from one session within two minutes', () {
      final existing = [ev(id: 's1', at: 60 * 1000)];
      final incoming = [ev(id: 's1', at: 90 * 1000)];
      final merged = mergeWireEvents(existing, incoming, nowMs: 91 * 1000);
      expect(merged, hasLength(1));
      expect(merged.single.atMs, 90 * 1000);
    });

    test('keeps bursts from different sessions as separate rows', () {
      final existing = [ev(id: 's1', at: 60 * 1000)];
      final incoming = [ev(id: 's2', at: 61 * 1000)];
      final merged = mergeWireEvents(existing, incoming, nowMs: 62 * 1000);
      expect(merged, hasLength(2));
    });

    test('drops events older than the two-hour window and caps at 40', () {
      final old = ev(id: 'old', at: 0);
      final merged = mergeWireEvents([old], const [], nowMs: 3 * 3600 * 1000);
      expect(merged, isEmpty);

      final flood = [
        for (var i = 0; i < 50; i++) ev(id: 'f$i', at: 1000 + i, name: 'n$i'),
      ];
      final capped = mergeWireEvents(const [], flood, nowMs: 200000);
      expect(capped, hasLength(40));
      // Newest first.
      expect(capped.first.atMs, greaterThan(capped.last.atMs));
    });

    test('does not insert old incoming events', () {
      final old = ev(id: 'old', at: 1000);
      final merged = mergeWireEvents(const [], [old], nowMs: 3 * 3600 * 1000);
      expect(merged, isEmpty);
    });
  });
}

WireSessionState _with(
  WireSessionState state, {
  int? lastMessageAt,
  int? activeAt,
  String? preview,
  String? role,
  bool? isError,
  bool? live,
  MissionLane? lane,
}) => WireSessionState(
  name: state.name,
  workspaceKey: state.workspaceKey,
  live: live ?? state.live,
  lane: lane ?? state.lane,
  unreadCount: state.unreadCount,
  createdAt: state.createdAt,
  activeAt: activeAt ?? state.activeAt,
  lastMessageAt: lastMessageAt ?? state.lastMessageAt,
  preview: preview ?? state.preview,
  role: role ?? state.role,
  isError: isError ?? state.isError,
);
