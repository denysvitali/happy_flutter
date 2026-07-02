import 'package:happy_flutter/core/models/loop.dart';
import 'package:happy_flutter/core/providers/loops_notifier.dart';

class StubLoopsNotifier extends LoopsNotifier {
  StubLoopsNotifier({
    Map<String, List<Loop>> initial = const {},
    this.deleteError,
    this.deleteCalls,
    this.actionCalls,
  }) : _initial = initial;

  final Map<String, List<Loop>> _initial;
  final Object? deleteError;
  final List<String>? deleteCalls;
  final List<String>? actionCalls;

  @override
  Map<String, List<Loop>> build() => _initial;

  @override
  void loadFromSync() {}

  @override
  Future<void> refreshFromSync() async {}

  @override
  Future<Loop> createLoop({
    required String sessionId,
    required String expression,
    required String prompt,
    required bool recurring,
  }) async {
    throw UnimplementedError();
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
  }
}
