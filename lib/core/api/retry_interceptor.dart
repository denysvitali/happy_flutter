import 'dart:math';

import 'package:dio/dio.dart';

import '../services/logger_service.dart' show logger;

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

/// Retry interceptor for Dio with exponential backoff
///
/// Retries transient failures:
/// - 5xx server errors (500-599)
/// - Network timeouts (connection, receive, send)
/// - Connection errors (SocketException, HttpException)
///
/// Does NOT retry:
/// - 4xx client errors (400-499) except 429 (rate limit)
/// - 401/403 auth errors (handled by auth layer)
/// - Cancellation errors
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio Function() dioGetter,
    int maxRetries = 3,
    int baseDelayMs = 1000,
    int maxDelayMs = 10000,
  })  : _dioGetter = dioGetter,
        _maxRetries = maxRetries,
        _baseDelayMs = baseDelayMs,
        _maxDelayMs = maxDelayMs;

  final Dio Function() _dioGetter;
  final int _maxRetries;
  final int _baseDelayMs;
  final int _maxDelayMs;
  final Random _jitterRng = Random();

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Don't retry if request was cancelled
    if (err.type == DioExceptionType.cancel) {
      return handler.next(err);
    }

    // Don't retry 4xx client errors except 429 (rate limit)
    final responseStatusCode = err.response?.statusCode;
    if (responseStatusCode != null &&
        responseStatusCode >= 400 &&
        responseStatusCode < 500 &&
        responseStatusCode != 429) {
      return handler.next(err);
    }

    // Don't retry auth errors (401, 403)
    if (responseStatusCode == 401 || responseStatusCode == 403) {
      return handler.next(err);
    }

    // Check if this error is retryable
    if (!_isRetryable(err)) {
      return handler.next(err);
    }

    // Get current retry count from request options
    final currentRetry =
        err.requestOptions.extra['_retryCount'] as int? ?? 0;

    if (currentRetry >= _maxRetries) {
      logger.warning(
        'RetryInterceptor: max retries ($_maxRetries) exceeded for '
        '${err.requestOptions.method} ${err.requestOptions.path}',
      );
      return handler.next(err);
    }

    // Calculate delay with exponential backoff and jitter
    final delay = (_baseDelayMs * pow(2, currentRetry)).toInt();
    final jitter = _jitterRng.nextInt(251); // 0–250ms
    final clampedDelay = min(delay + jitter, _maxDelayMs);

    logger.info(
      'RetryInterceptor: retry ${currentRetry + 1}/$_maxRetries for '
      '${err.requestOptions.method} ${err.requestOptions.path} '
      'after $clampedDelay ms '
      '(error: ${err.type}, status: $responseStatusCode)',
    );

    // Wait before retry
    await Future<void>.delayed(
      Duration(milliseconds: clampedDelay),
    );

    // Increment retry count and retry request
    final retryOptions = err.requestOptions;
    retryOptions.extra['_retryCount'] = currentRetry + 1;

    try {
      final response = await _dioGetter().fetch(retryOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      // If retry fails, pass through onError again for potential retry
      return handler.next(e);
    } catch (e, s) {
      // Non-Dio errors should not be retried; log since this is unexpected
      logger.warning(
        'RetryInterceptor: unexpected non-Dio error during retry for '
        '${err.requestOptions.method} ${err.requestOptions.path}: $e',
        e,
        s,
      );
      return handler.next(
        DioException(
          requestOptions: err.requestOptions,
          error: e,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  bool _isRetryable(DioException err) {
    // Retry on 5xx server errors
    if (err.response?.statusCode != null &&
        err.response!.statusCode! >= 500 &&
        err.response!.statusCode! < 600) {
      return true;
    }

    // Retry on 429 (rate limit)
    if (err.response?.statusCode == 429) {
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
