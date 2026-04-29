import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../models/auth.dart';
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

/// Retry interceptor for Dio with exponential backoff and token refresh.
///
/// Retries transient failures:
/// - 5xx server errors (500-599)
/// - Network timeouts (connection, receive, send)
/// - Connection errors (SocketException, HttpException)
/// - 401 Unauthorized (triggers token refresh, then retries)
///
/// Does NOT retry:
/// - 4xx client errors (400-499) except 429 (rate limit)
/// - 403 Forbidden (requires re-authentication)
/// - Cancellation errors
/// - Token refresh requests themselves
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio Function() dioGetter,
    int maxRetries = 3,
    int baseDelayMs = 1000,
    int maxDelayMs = 10000,
  }) : _dioGetter = dioGetter,
       _maxRetries = maxRetries,
       _baseDelayMs = baseDelayMs,
       _maxDelayMs = maxDelayMs;

  final Dio Function() _dioGetter;
  final int _maxRetries;
  final int _baseDelayMs;
  final int _maxDelayMs;
  final Random _jitterRng = Random();

  /// Path of the token refresh endpoint (to avoid infinite loops).
  static const _refreshPath = '/v1/auth/refresh';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Don't retry if request was cancelled
    if (err.type == DioExceptionType.cancel) {
      return handler.next(err);
    }

    final responseStatusCode = err.response?.statusCode;
    final requestPath = err.requestOptions.path;

    // Handle 401 Unauthorized: attempt token refresh then retry.
    if (responseStatusCode == 401) {
      // Don't attempt refresh on the refresh endpoint itself.
      if (requestPath == _refreshPath) {
        logger.warning(
          'RetryInterceptor: 401 on refresh endpoint - '
          'passing through (re-auth required)',
        );
        return handler.next(err);
      }

      // Don't retry if we've already attempted a token refresh for this
      // request (prevents infinite loops).
      final alreadyRefreshed =
          err.requestOptions.extra['_refreshedToken'] as bool? ?? false;
      if (alreadyRefreshed) {
        logger.warning(
          'RetryInterceptor: 401 after token refresh - '
          're-authentication required',
        );
        return handler.next(err);
      }

      // Attempt token refresh.
      logger.info(
        'RetryInterceptor: 401 received - attempting token refresh for '
        '${err.requestOptions.method} ${err.requestOptions.path}',
      );

      try {
        final newToken = await tokenRefreshManager.refreshToken();

        // Token refresh succeeded - update auth header and retry.
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        err.requestOptions.extra['_refreshedToken'] = true;

        logger.info(
          'RetryInterceptor: token refresh succeeded - retrying '
          '${err.requestOptions.method} ${err.requestOptions.path}',
        );

        final response = await _dioGetter().fetch(err.requestOptions);
        return handler.resolve(response);
      } on AuthForbiddenError {
        // Token refresh failed - credentials are invalid/expired.
        // Pass the error through so the app can handle re-authentication.
        logger.warning(
          'RetryInterceptor: token refresh failed - '
          're-authentication required',
        );
        return handler.next(err);
      } catch (e) {
        // Token refresh failed for other reasons (network, etc.).
        // Pass the original 401 error through.
        logger.warning(
          'RetryInterceptor: token refresh threw $e - '
          'passing through original 401',
        );
        return handler.next(err);
      }
    }

    // Don't retry 4xx client errors except 429 (rate limit)
    if (responseStatusCode != null &&
        responseStatusCode >= 400 &&
        responseStatusCode < 500 &&
        responseStatusCode != 429) {
      return handler.next(err);
    }

    // Don't retry auth errors (403)
    if (responseStatusCode == 403) {
      return handler.next(err);
    }

    // Check if this error is retryable
    if (!_isRetryable(err)) {
      return handler.next(err);
    }

    // Get current retry count from request options
    final currentRetry = err.requestOptions.extra['_retryCount'] as int? ?? 0;

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
    await Future<void>.delayed(Duration(milliseconds: clampedDelay));

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
      logger.error(
        'RetryInterceptor: unexpected non-Dio error during retry for '
        '${err.requestOptions.method} ${err.requestOptions.path}: $e',
        e,
        s,
      );
      unawaited(Sentry.captureException(e, stackTrace: s));
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
