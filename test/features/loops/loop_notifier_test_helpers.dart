import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/providers/loops_notifier.dart';

Loop testLoop({
  String id = 'aabbccdd',
  String sessionId = 's1',
  String expression = '*/5 * * * *',
  String prompt = 'check the deploy',
  bool recurring = true,
  bool paused = false,
  int? createdAt,
  int? expiresAt,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Loop(
    id: id,
    sessionId: sessionId,
    expression: expression,
    prompt: prompt,
    recurring: recurring,
    createdAt: createdAt ?? now - 60000,
    expiresAt: expiresAt ?? now + 7 * 24 * 60 * 60 * 1000,
    paused: paused,
  );
}

class StubLoopsNotifier extends LoopsNotifier {
  StubLoopsNotifier({
    Map<String, List<Loop>> initial = const {},
    Map<String, List<Loop>>? cached,
    this.createError,
    this.createdLoopId = 'createdid',
    this.deleteError,
    this.deleteCalls,
    this.pauseError,
    this.refreshError,
    this.refreshCalls,
    this.refreshOverride,
    this.actionCalls,
  }) : _initial = initial,
       _cached = cached;

  final Map<String, List<Loop>> _initial;
  final Map<String, List<Loop>>? _cached;
  final Object? createError;
  final String createdLoopId;
  final Object? deleteError;
  final List<String>? deleteCalls;
  final Object? pauseError;
  final Object? refreshError;
  final List<String>? refreshCalls;
  final Future<void> Function()? refreshOverride;
  final List<String>? actionCalls;

  @override
  Map<String, List<Loop>> build() => _initial;

  @override
  void loadFromSync() {}

  @override
  bool hydrateFromCache() {
    final cached = _cached;
    if (cached == null) return false;
    state = cached;
    return cached.values.any((loops) => loops.isNotEmpty);
  }

  @override
  Future<void> refreshFromSync() async {
    refreshCalls?.add('refresh');
    final override = refreshOverride;
    if (override != null) {
      await override();
      return;
    }
    final error = refreshError;
    if (error is Error) throw error;
    if (error is Exception) throw error;
    if (error != null) throw StateError(error.toString());
  }

  @override
  Future<Loop> createLoop({
    required String sessionId,
    required String expression,
    required String prompt,
    required bool recurring,
  }) async {
    final error = createError;
    if (error is Error) throw error;
    if (error is Exception) throw error;
    if (error != null) throw StateError(error.toString());

    return testLoop(
      id: createdLoopId,
      sessionId: sessionId,
      expression: expression,
      prompt: prompt,
      recurring: recurring,
      createdAt: 0,
      expiresAt: 7 * 24 * 60 * 60 * 1000,
    );
  }

  @override
  Future<void> deleteLoop({
    required String sessionId,
    required String loopId,
  }) async {
    deleteCalls?.add('$sessionId:$loopId');
    actionCalls?.add('delete:$sessionId:$loopId');
    final error = deleteError;
    if (error is Error) throw error;
    if (error is Exception) throw error;
    if (error != null) throw StateError(error.toString());
  }

  @override
  Future<void> pauseLoop({
    required String sessionId,
    required String loopId,
    required bool paused,
  }) async {
    actionCalls?.add('pause:$sessionId:$loopId:$paused');
    final error = pauseError;
    if (error is Error) throw error;
    if (error is Exception) throw error;
    if (error != null) throw StateError(error.toString());
  }
}
