part of 'sync_service.dart';

extension SyncHistoryTransport on Sync {
  /// Retry a body timeout against a smaller range ending at the same cursor.
  /// Reusing the old after_seq with a smaller limit would skip the newer half.
  Future<({Response<dynamic> response, int afterSeq})> _fetchOlderMessagePage(
    String sessionId,
    int firstLoaded,
    int requestedSize,
    int generation,
  ) async {
    var size = requestedSize.clamp(1, Sync._orphanFetchOlderPageSize).toInt();
    size = min(size, _olderHistoryPageSizeLimits[sessionId] ?? size);
    final clock = Stopwatch()..start();
    while (true) {
      if (generation != _runtimeGeneration) {
        throw StateError('History runtime changed');
      }
      final afterSeq = (firstLoaded - 1 - size).clamp(0, firstLoaded - 1);
      final remaining = Sync._messageFetchBudget - clock.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('History fetch deadline exceeded');
      }
      try {
        final Response<dynamic> response;
        final override = testFetchOlderMessagesOverride;
        if (override != null) {
          final data = await override(sessionId, afterSeq, size);
          response = Response<dynamic>(
            requestOptions: RequestOptions(path: ''),
            statusCode: 200,
            data: data,
          );
        } else {
          response = await ApiClient().get(
            '/v3/sessions/$sessionId/messages',
            queryParameters: {'after_seq': afterSeq, 'limit': size},
            options: Options(
              extra: {
                'bypassCache': true,
                'disableRetry': true,
                RetryInterceptor.requestBudgetMsKey: remaining.inMilliseconds,
              },
              connectTimeout: Sync._messageFetchConnectTimeout,
              receiveTimeout: Sync._messageFetchReceiveTimeout,
            ),
          );
        }
        return (response: response, afterSeq: afterSeq);
      } on DioException catch (error) {
        if (generation != _runtimeGeneration ||
            error.type != DioExceptionType.receiveTimeout ||
            size <= 100) {
          rethrow;
        }
        size = max(100, size ~/ 2);
        _olderHistoryPageSizeLimits[sessionId] = size;
        logger.info(
          '[fetchOlderMessages] body timeout; '
          'retrying same history boundary with limit=$size',
        );
      }
    }
  }
}
