import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../services/logger_service.dart' show logger;
import '../services/token_refresh_manager.dart';

/// Returns true for transient connection errors that are not actionable
/// (e.g. Cronet aborting a request because the OS killed the connection
/// while the app was backgrounded).
bool isTransientConnectionError(DioException error) {
  final inner = error.error?.toString() ?? '';
  return inner.contains('ERR_CONNECTION_ABORTED') ||
      inner.contains('ERR_CONNECTION_RESET') ||
      inner.contains('ERR_NAME_NOT_RESOLVED') ||
      inner.contains('ERR_CONNECTION_TIMED_OUT') ||
      inner.contains('ERR_NETWORK_CHANGED') ||
      inner.contains('ERR_INTERNET_DISCONNECTED') ||
      inner.contains('ERR_ADDRESS_UNREACHABLE') ||
      inner.contains('Failed host lookup') ||
      inner.contains('No address associated') ||
      inner.contains('Connection closed') ||
      inner.contains('Software caused connection abort');
}

/// Retry interceptor for Dio with exponential backoff.
///
/// **Status failures never reach [onError].** [ApiClient] configures Dio
/// with `validateStatus: (_) => true` so every call site can inspect a
/// [Response] for any status instead of catching a [DioException] — which
/// also means Dio never raises for a 500/503/429 and the error chain only
/// ever sees transport failures (timeouts, connection errors, cancel).
/// Status-code classification therefore lives in [onResponse]; [onError]
/// keeps handling transport failures. Both funnel into the same
/// backoff-and-refetch path.
///
/// Retries:
/// - 5xx server errors (500-599)
/// - 429 (rate limit)
/// - Network timeouts (connection, receive, send)
/// - Connection errors (SocketException, HttpException, Cronet aborts)
///
/// Does NOT retry:
/// - 4xx client errors (400-499) except 429
/// - 401 Unauthorized — see [_handleUnauthorized]; the server has no
///   refresh endpoint, so a 401 means "sign in again", not "retry"
/// - Cancellation errors
/// - Requests carrying `extra['disableRetry'] == true`
///
/// The whole retry sequence is additionally bounded by
/// [maxTotalElapsedMs], measured from the start of the FIRST attempt
/// ([retryStartKey], stamped in [onRequest]): without it, 4 attempts plus
/// 1s+2s+4s of backoff (plus per-attempt timeouts) could keep a single
/// logical send in flight for the better part of a minute. The budget is an
/// admission check — an attempt that is already in flight is bounded by its
/// own Dio timeouts, not by the budget — so the sequence can overrun it by
/// at most one attempt's timeout.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio Function() dioGetter,
    int maxRetries = 3,
    int baseDelayMs = 1000,
    int maxDelayMs = 10000,
    int maxTotalElapsedMs = 20000,
  }) : _dioGetter = dioGetter,
       _maxRetries = maxRetries,
       _baseDelayMs = baseDelayMs,
       _maxDelayMs = maxDelayMs,
       _maxTotalElapsedMs = maxTotalElapsedMs;

  final Dio Function() _dioGetter;
  final int _maxRetries;
  final int _baseDelayMs;
  final int _maxDelayMs;
  final int _maxTotalElapsedMs;
  final Random _jitterRng = Random();

  /// [RequestOptions.extra] key holding the number of retries already
  /// performed for this request.
  static const retryCountKey = '_retryCount';

  /// [RequestOptions.extra] key holding the status code of the attempt
  /// that was just retried (null when the attempt failed at the transport
  /// level). Read by the tracing interceptor to close the failed attempt's
  /// span before the next attempt opens a new one.
  static const lastStatusKey = '_retryLastStatus';

  /// [RequestOptions.extra] key holding the [DioExceptionType] name of the
  /// attempt that was just retried.
  static const lastErrorTypeKey = '_retryLastErrorType';

  /// [RequestOptions.extra] key holding the epoch-ms timestamp at which the
  /// FIRST attempt of this request started.
  ///
  /// Stamped in [onRequest] rather than lazily at the first retry decision:
  /// stamping it late excluded the initial attempt's own duration from
  /// [maxTotalElapsedMs], so a black-holed route could burn a full
  /// receive-timeout, then be admitted for another one, with the budget
  /// never able to deny anything.
  static const retryStartKey = '_retryStartedAtMs';

  /// Requests under this prefix are part of the (re-)authentication flow
  /// itself and must not trigger another re-auth notification.
  static const _authPathPrefix = '/v1/auth/';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // A retried attempt re-enters onRequest with the same RequestOptions,
    // so only the first attempt stamps the budget clock.
    options.extra[retryStartKey] ??= DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    final statusCode = response.statusCode;

    if (statusCode == null || statusCode < 400) {
      return handler.next(response);
    }

    if (statusCode == 401) {
      _handleUnauthorized(options);
      return handler.next(response);
    }

    if (options.extra['disableRetry'] == true ||
        !_isRetryableStatus(statusCode)) {
      return handler.next(response);
    }

    final delay = _nextRetryDelay(options, statusCode: statusCode);
    if (delay == null) {
      return handler.next(response);
    }

    await Future<void>.delayed(delay);
    _markAttempt(options, statusCode: statusCode);

    try {
      // `fetch` replays the full interceptor chain, so the retried attempt
      // gets its own span / tracker entry; resolve (not next) here so the
      // outer attempt does not record the same response a second time.
      return handler.resolve(await _dioGetter().fetch<dynamic>(options));
    } on DioException catch (e) {
      // `true` = keep running the following error interceptors, so the
      // tracing / request-tracker interceptors still close the attempt.
      // Plain reject() completes the request without them and leaks the
      // span opened for this attempt.
      return handler.reject(e, true);
    } catch (e, s) {
      return handler.reject(_unexpectedRetryError(options, e, s), true);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Don't retry if request was cancelled
    if (err.type == DioExceptionType.cancel) {
      return handler.next(err);
    }

    final options = err.requestOptions;
    final statusCode = err.response?.statusCode;

    // Reachable only for adapters/tests that do raise on status codes —
    // the app's own Dio never does (see the class doc).
    if (statusCode == 401) {
      _handleUnauthorized(options);
      return handler.next(err);
    }

    if (options.extra['disableRetry'] == true) {
      return handler.next(err);
    }

    // Don't retry 4xx client errors except 429 (rate limit).
    if (statusCode != null && !_isRetryableStatus(statusCode)) {
      return handler.next(err);
    }

    // Check if this error is retryable
    if (!_isRetryable(err)) {
      return handler.next(err);
    }

    final delay = _nextRetryDelay(
      options,
      statusCode: statusCode,
      errorType: err.type,
    );
    if (delay == null) {
      return handler.next(err);
    }

    await Future<void>.delayed(delay);
    _markAttempt(options, statusCode: statusCode, errorType: err.type);

    try {
      final response = await _dioGetter().fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      // If retry fails, pass through onError again for potential retry
      return handler.next(e);
    } catch (e, s) {
      // Non-Dio errors should not be retried; log since this is unexpected
      return handler.next(_unexpectedRetryError(options, e, s));
    }
  }

  /// Handles a 401 by telling the app to re-authenticate.
  ///
  /// SERVER CONTRACT (verified against the happy-server Go implementation):
  /// there is no `POST /v1/auth/refresh` route — such a request falls
  /// through to the grpc-gateway catch-all and returns 404 — and issued
  /// tokens carry no `exp` claim, so they never expire
  /// (`internal/server/auth/tokens.go`). A 401 therefore never means
  /// "token expired": it means the signature no longer verifies (rotated
  /// server secret, revoked or foreign token). Neither retrying nor
  /// refreshing can fix that, so the only honest response is to surface
  /// "re-authentication required" and let the request fail.
  void _handleUnauthorized(RequestOptions options) {
    if (options.path.startsWith(_authPathPrefix)) {
      // The re-auth listener re-verifies the token via /v1/auth/verify;
      // notifying from there would loop.
      logger.info(
        'RetryInterceptor: 401 on ${options.path} - '
        'auth flow already in progress',
      );
      return;
    }
    logger.warning(
      'RetryInterceptor: 401 on ${options.method} ${options.path} - '
      're-authentication required (server tokens never expire, so this is '
      'a revoked or otherwise unverifiable token)',
    );
    tokenRefreshManager.notifyReauthRequired();
  }

  /// Returns the backoff to wait before the next attempt, or null when the
  /// request has exhausted its attempt count or its total time budget.
  Duration? _nextRetryDelay(
    RequestOptions options, {
    int? statusCode,
    DioExceptionType? errorType,
  }) {
    final label = '${options.method} ${options.path}';
    final currentRetry = options.extra[retryCountKey] as int? ?? 0;
    if (currentRetry >= _maxRetries) {
      logger.warning(
        'RetryInterceptor: max retries ($_maxRetries) exceeded for $label',
      );
      return null;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Normally stamped by onRequest on the first attempt; the fallback only
    // covers interceptor-less unit setups.
    final startedAtMs = options.extra[retryStartKey] as int? ?? nowMs;
    options.extra[retryStartKey] = startedAtMs;
    final elapsedMs = nowMs - startedAtMs;

    // Exponential backoff with jitter, clamped to the per-wait maximum.
    final backoffMs = min(
      (_baseDelayMs * pow(2, currentRetry)).toInt() + _jitterRng.nextInt(251),
      _maxDelayMs,
    );

    if (elapsedMs + backoffMs > _maxTotalElapsedMs) {
      logger.warning(
        'RetryInterceptor: retry budget ($_maxTotalElapsedMs ms) exhausted '
        'after $elapsedMs ms for $label (giving up after $currentRetry '
        'retries)',
      );
      return null;
    }

    logger.info(
      'RetryInterceptor: retry ${currentRetry + 1}/$_maxRetries for $label '
      'after $backoffMs ms '
      '(status: $statusCode, error: $errorType)',
    );
    return Duration(milliseconds: backoffMs);
  }

  /// Records that the attempt described by [statusCode]/[errorType] failed
  /// and a new one is about to start.
  void _markAttempt(
    RequestOptions options, {
    int? statusCode,
    DioExceptionType? errorType,
  }) {
    final currentRetry = options.extra[retryCountKey] as int? ?? 0;
    options.extra[retryCountKey] = currentRetry + 1;
    if (statusCode != null) {
      options.extra[lastStatusKey] = statusCode;
    } else {
      options.extra.remove(lastStatusKey);
    }
    if (errorType != null) {
      options.extra[lastErrorTypeKey] = errorType.name;
    } else {
      options.extra.remove(lastErrorTypeKey);
    }
  }

  DioException _unexpectedRetryError(
    RequestOptions options,
    Object error,
    StackTrace stackTrace,
  ) {
    logger.error(
      'RetryInterceptor: unexpected non-Dio error during retry for '
      '${options.method} ${options.path}: $error',
      error,
      stackTrace,
    );
    unawaited(Sentry.captureException(error, stackTrace: stackTrace));
    return DioException(
      requestOptions: options,
      error: error,
      type: DioExceptionType.unknown,
    );
  }

  /// 5xx and 429 are worth another attempt; every other 4xx is a client
  /// error that will fail identically on retry.
  static bool _isRetryableStatus(int statusCode) {
    if (statusCode == 429) return true;
    return statusCode >= 500 && statusCode < 600;
  }

  bool _isRetryable(DioException err) {
    // Cronet transient errors (ERR_NETWORK_CHANGED, ERR_CONNECTION_ABORTED,
    // etc.) are surfaced as DioExceptionType.unknown — check the inner
    // error string so mobile network transitions get retried immediately.
    if (isTransientConnectionError(err)) {
      return true;
    }

    // Retry on retryable status codes (only reachable when an adapter does
    // raise for status; see the class doc).
    final statusCode = err.response?.statusCode;
    if (statusCode != null && _isRetryableStatus(statusCode)) {
      return true;
    }

    // Retry on network timeouts
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      return true;
    }

    // Retry on connection errors
    if (err.type == DioExceptionType.connectionError) {
      return true;
    }

    return false;
  }
}
