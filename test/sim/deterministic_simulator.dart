/// Single-threaded deterministic simulator for `_sync_messaging*` and
/// related lifecycle code paths.
///
/// Goal
/// ----
///
/// Reproduce schedule-dependent bugs (e.g. the `InvalidateSync.dispose`
/// race that produced 55 fatal/day in production) by running the
/// system under test against a *virtual* clock + fake socket + fake
/// REST.  Every random choice is seeded so a failing run is replayable.
///
/// This file ships the *simulator harness* only; integrating it with
/// the real Sync singleton requires test-side scaffolding that the
/// architecture branch will help land in a follow-up.  A small
/// self-test (see `simulator_self_test.dart`) demonstrates the
/// harness can deterministically reproduce a known race in a tiny
/// abstract model.
import 'dart:async';
import 'dart:collection';
import 'dart:math';

/// A scheduled callback inside [VirtualClock].  Sortable by [dueAt]
/// to allow the priority queue to dequeue the next due task.
class _Task {
  _Task({required this.dueAt, required this.action, required this.id});
  final int dueAt;
  final FutureOr<void> Function() action;

  /// Insertion order — used as the tie-breaker so two tasks with
  /// identical [dueAt] still execute in a deterministic order.
  final int id;
}

/// Virtual monotonic clock used by the simulator.  Runs in millisecond
/// resolution.  All `Future.delayed` / `Timer` calls inside the system
/// under test must be redirected to [schedule] for the clock to
/// govern them.
class VirtualClock {
  VirtualClock({int initialMs = 0}) : _now = initialMs;

  int _now;
  int _nextId = 0;

  /// Queue ordered by `(dueAt, id)`.  We use a List + sort because the
  /// expected workload is small (< 1000 entries).
  final List<_Task> _queue = [];

  /// Current virtual time in milliseconds since simulator start.
  int get nowMs => _now;

  /// Schedule [action] to run at time `now + delay`.
  void schedule(Duration delay, FutureOr<void> Function() action) {
    _queue.add(
      _Task(
        dueAt: _now + delay.inMilliseconds,
        action: action,
        id: _nextId++,
      ),
    );
  }

  /// Run until the queue is empty or [maxSteps] tasks have run.
  ///
  /// Returns the number of tasks executed.
  ///
  /// Tasks are kicked off without awaiting them — so an outer task
  /// that schedules an inner task and then awaits its completion will
  /// not deadlock the drain loop.  Microtasks between tasks are
  /// flushed by yielding to the event loop.
  Future<int> drain({int maxSteps = 10000}) async {
    var steps = 0;
    while (_queue.isNotEmpty && steps < maxSteps) {
      _queue.sort((a, b) {
        final byDue = a.dueAt.compareTo(b.dueAt);
        if (byDue != 0) return byDue;
        return a.id.compareTo(b.id);
      });
      final next = _queue.removeAt(0);
      _now = max(_now, next.dueAt);
      // Fire-and-forget: we deliberately do NOT await the action.
      // Otherwise an outer task that schedules + awaits an inner one
      // would deadlock (drain would wait on the outer's future, which
      // waits on the inner task being dequeued by drain).
      final maybeFuture = next.action();
      // Fire-and-forget the future — see drain() doc comment.
      if (maybeFuture is Future) {
        // ignore: unawaited_futures
        maybeFuture;
      }
      // Yield so microtasks (Completer continuations) flush before
      // the next dequeue.
      await Future<void>.delayed(Duration.zero);
      steps++;
    }
    return steps;
  }
}

/// Fake REST client used by the simulator.  Each registered route
/// can either succeed, fail, or be "suspended" until manually
/// released by the test.  Latency is configurable per request.
class FakeRest {
  FakeRest({required this.clock, this.defaultLatency = const Duration(milliseconds: 50)});

  final VirtualClock clock;
  final Duration defaultLatency;

  /// Routes are matched by exact path.  Each handler returns a
  /// [FakeRestResponse].
  final Map<String, FakeRestResponse Function(Map<String, dynamic>)> _routes = {};

  /// Pending in-flight calls — used by tests to assert race
  /// conditions where dispose() is called mid-flight.
  final Set<int> _inFlight = {};
  int _nextRequestId = 0;

  void register(
    String path,
    FakeRestResponse Function(Map<String, dynamic>) handler,
  ) {
    _routes[path] = handler;
  }

  Set<int> get inFlight => Set.unmodifiable(_inFlight);

  /// Simulate a POST.  Returns a future that completes after
  /// `latency` virtual ms.
  Future<FakeRestResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Duration? latency,
  }) {
    final completer = Completer<FakeRestResponse>();
    final requestId = _nextRequestId++;
    _inFlight.add(requestId);
    clock.schedule(latency ?? defaultLatency, () {
      _inFlight.remove(requestId);
      final handler = _routes[path];
      if (handler == null) {
        completer.complete(FakeRestResponse.notFound(path));
        return;
      }
      completer.complete(handler(body ?? const {}));
    });
    return completer.future;
  }
}

class FakeRestResponse {
  FakeRestResponse({required this.statusCode, this.body = const {}});

  factory FakeRestResponse.notFound(String path) =>
      FakeRestResponse(statusCode: 404, body: {'error': 'no route: $path'});

  factory FakeRestResponse.ok([Map<String, dynamic> body = const {}]) =>
      FakeRestResponse(statusCode: 200, body: body);

  factory FakeRestResponse.serverError() =>
      FakeRestResponse(statusCode: 500);

  final int statusCode;
  final Map<String, dynamic> body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// Fake socket — tests push events and the system under test drains
/// them through a [Stream].  Latency, drops, and duplicates are
/// configurable per event.
class FakeSocket {
  FakeSocket({required this.clock});

  final VirtualClock clock;
  final StreamController<Map<String, dynamic>> _events = StreamController.broadcast();
  bool _connected = true;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get connected => _connected;

  void disconnect() => _connected = false;
  void reconnect() => _connected = true;

  /// Schedule an event to arrive after [delay] virtual ms.  Drops
  /// silently if the socket is disconnected when the event fires.
  void emit(Map<String, dynamic> event, {Duration delay = Duration.zero}) {
    clock.schedule(delay, () {
      if (!_connected) return;
      if (_events.isClosed) return;
      _events.add(event);
    });
  }

  Future<void> close() async {
    if (!_events.isClosed) await _events.close();
  }
}

/// Top-level simulator that bundles a virtual clock, fake REST and
/// fake socket with a seeded [Random].
class DeterministicSimulator {
  DeterministicSimulator({int seed = 0xCAFEBABE})
      : rng = Random(seed),
        clock = VirtualClock() {
    rest = FakeRest(clock: clock);
    socket = FakeSocket(clock: clock);
  }

  final Random rng;
  final VirtualClock clock;
  late final FakeRest rest;
  late final FakeSocket socket;

  /// Pick a random duration in `[min, max]` ms — convenience for tests
  /// that want to inject jitter while staying seed-deterministic.
  Duration jitter(int minMs, int maxMs) {
    final delta = maxMs - minMs;
    return Duration(milliseconds: minMs + rng.nextInt(delta + 1));
  }

  Future<void> close() async {
    await socket.close();
  }
}

/// FIFO queue of arbitrary `T` values used by simulator tests to
/// model in-flight responses awaiting a release signal.  Exposed
/// here so individual tests don't have to roll their own.
class PendingQueue<T> {
  final Queue<Completer<T>> _waiters = Queue();
  final Queue<T> _ready = Queue();

  Future<T> take() {
    if (_ready.isNotEmpty) return Future.value(_ready.removeFirst());
    final completer = Completer<T>();
    _waiters.add(completer);
    return completer.future;
  }

  void add(T value) {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(value);
    } else {
      _ready.add(value);
    }
  }
}
