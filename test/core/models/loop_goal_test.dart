import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/loop.dart';

/// Wire payload for a goal loop exactly as the daemon publishes it inside
/// `daemonState.machineLoops` (Go `omitempty`: absent, not null, when empty).
Map<String, dynamic> _goalLoopJson({
  String id = 'cafef00d',
  String status = 'running',
}) => <String, dynamic>{
  'id': id,
  'sessionId': '',
  'expression': '',
  'prompt': 'Never push to main.',
  'recurring': true,
  'createdAt': 1700000000000,
  'expiresAt': 1702592000000,
  'fireCount': 2,
  'machineId': 'machine-1',
  'directory': '/home/user/project',
  'agent': 'claude',
  'lastSessionId': 'run-1-session',
  'activeSessionId': 'run-2-session',
  'goal': 'Get the integration suite passing',
  'maxIterations': 25,
  'status': status,
  'statusDetail': 'fixing the flaky shard',
  'stalledRuns': 0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Loop goal-loop parsing', () {
    test('parses a goal loop from the daemon wire shape', () {
      final loop = Loop.tryFromJson(_goalLoopJson());
      expect(loop, isNotNull);
      expect(loop!.isGoalLoop, isTrue);
      expect(loop.isMachineLoop, isTrue);
      expect(loop.goal, 'Get the integration suite passing');
      expect(loop.machineId, 'machine-1');
      expect(loop.directory, '/home/user/project');
      expect(loop.agent, 'claude');
      expect(loop.maxIterations, 25);
      expect(loop.loopStatus, LoopStatus.running);
      expect(loop.isTerminal, isFalse);
      expect(loop.isIterating, isTrue);
      expect(loop.statusDetail, 'fixing the flaky shard');
    });

    test('a plain session loop is neither a machine loop nor a goal loop', () {
      final loop = Loop.tryFromJson(<String, dynamic>{
        'id': 'aaaaaaaa',
        'sessionId': 's1',
        'expression': '*/5 * * * *',
        'prompt': 'check',
        'createdAt': 1700000000000,
        'expiresAt': 1700604800000,
      });
      expect(loop, isNotNull);
      expect(loop!.isGoalLoop, isFalse);
      expect(loop.isMachineLoop, isFalse);
      expect(loop.loopStatus, LoopStatus.running);
      expect(loop.isTerminal, isFalse);
      expect(loop.effectiveProgressFile, 'PROGRESS.md');
    });

    test('every terminal wire status maps to its enum value', () {
      final cases = <String, LoopStatus>{
        'complete': LoopStatus.complete,
        'blocked': LoopStatus.blocked,
        'stalled': LoopStatus.stalled,
        'exhausted': LoopStatus.exhausted,
      };
      for (final entry in cases.entries) {
        final loop = Loop.tryFromJson(_goalLoopJson(status: entry.key));
        expect(
          loop!.loopStatus,
          entry.value,
          reason: 'wire status ${entry.key}',
        );
        expect(loop.isTerminal, isTrue, reason: 'wire status ${entry.key}');
      }
    });

    test('an unknown or absent status means running, never finished', () {
      // The safe default: a loop is only shown as done when the daemon says
      // so explicitly. A status the app does not recognize must not freeze
      // the loop's controls.
      for (final status in <String>['', 'whatever-the-future-adds']) {
        final loop = Loop.tryFromJson(_goalLoopJson(status: status));
        expect(loop!.loopStatus, LoopStatus.running);
        expect(loop.isTerminal, isFalse);
      }
    });

    test('completedIterations trails fireCount while a run is in flight', () {
      final inFlight = Loop.tryFromJson(_goalLoopJson())!;
      expect(inFlight.fireCount, 2);
      expect(inFlight.completedIterations, 1);

      final idle = Loop.tryFromJson(
        _goalLoopJson()..remove('activeSessionId'),
      )!;
      expect(idle.isIterating, isFalse);
      expect(idle.completedIterations, 2);
    });

    test('toJson omits empty goal-loop fields, matching Go omitempty', () {
      final loop = Loop.tryFromJson(<String, dynamic>{
        'id': 'aaaaaaaa',
        'sessionId': 's1',
        'expression': '*/5 * * * *',
        'prompt': 'check',
        'createdAt': 1700000000000,
        'expiresAt': 1700604800000,
      })!;
      final json = loop.toJson();
      for (final key in <String>[
        'goal',
        'machineId',
        'directory',
        'agent',
        'progressFile',
        'maxIterations',
        'status',
        'statusDetail',
        'completedAt',
        'lastSessionId',
        'activeSessionId',
      ]) {
        expect(json.containsKey(key), isFalse, reason: key);
      }
    });

    test('goal loop survives a toJson/tryFromJson round-trip byte-faithfully', () {
      final original = Loop.tryFromJson(_goalLoopJson())!;
      final roundTripped = Loop.tryFromJson(original.toJson());
      expect(roundTripped, isNotNull);
      expect(roundTripped, equals(original));
    });
  });

  group('LoopStatus.fromWire', () {
    test('maps every daemon status constant', () {
      expect(LoopStatus.fromWire('running'), LoopStatus.running);
      expect(LoopStatus.fromWire('complete'), LoopStatus.complete);
      expect(LoopStatus.fromWire('blocked'), LoopStatus.blocked);
      expect(LoopStatus.fromWire('stalled'), LoopStatus.stalled);
      expect(LoopStatus.fromWire('exhausted'), LoopStatus.exhausted);
      expect(LoopStatus.fromWire(null), LoopStatus.running);
      expect(LoopStatus.fromWire('unrecognized'), LoopStatus.running);
    });

    test('isTerminal is true for everything except running', () {
      expect(LoopStatus.running.isTerminal, isFalse);
      expect(LoopStatus.complete.isTerminal, isTrue);
      expect(LoopStatus.blocked.isTerminal, isTrue);
      expect(LoopStatus.stalled.isTerminal, isTrue);
      expect(LoopStatus.exhausted.isTerminal, isTrue);
    });
  });
}
