import 'dart:async';

import 'package:dio/dio.dart';

/// One deadline and cancellation token for every attempt of a logical request.
/// The adapter's timeout may combine phases or restart for each body chunk;
/// this timer also bounds those paths and the retry backoff between attempts.
class RequestBudget {
  RequestBudget(this.options, Duration duration, this.onFinished) {
    final callerToken = options.cancelToken;
    options.cancelToken = token;
    token.requestOptions = options;
    if (callerToken != null) {
      // Detach the subscription on completion, even if the caller never cancels.
      _callerSubscription = callerToken.whenCancel.asStream().listen((error) {
        token.cancel(error.error);
      });
      if (callerToken.isCancelled) token.cancel(callerToken.cancelError?.error);
    }
    _timer = Timer(
      duration,
      () => token.cancel('HTTP request deadline exceeded'),
    );
  }

  static const extraKey = '_requestBudget';
  final RequestOptions options;
  final void Function(RequestBudget) onFinished;
  final CancelToken token = CancelToken();
  Timer? _timer;
  StreamSubscription<DioException>? _callerSubscription;
  bool _finished = false;

  Future<void> wait(Duration delay) async {
    if (token.isCancelled) throw token.cancelError!;
    final ready = Completer<void>();
    final timer = Timer(delay, ready.complete);
    final cancellation = token.whenCancel.asStream().listen((error) {
      if (!ready.isCompleted) ready.completeError(error);
    });
    try {
      await ready.future;
      if (token.isCancelled) throw token.cancelError!;
    } finally {
      timer.cancel();
      await cancellation.cancel();
    }
  }

  void finish() {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    unawaited(_callerSubscription?.cancel());
    onFinished(this);
  }
}
