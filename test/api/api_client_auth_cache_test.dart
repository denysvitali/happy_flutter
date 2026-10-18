// Pins the HTTP response cache to the authenticated identity.
//
// `HttpResponseCache.generateKey` is method + path + query only: nothing
// in the key names the account the response belongs to. Sign-out keeps
// the same `ApiClient` and only drops the Authorization header, so a
// cached `GET /v2/sessions` from the previous account would still be
// served (default max-age five minutes) to whoever signs in next.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';

Response<dynamic> _sessionsResponse() {
  return Response<dynamic>(
    data: const {'sessions': <dynamic>[]},
    statusCode: 200,
    requestOptions: RequestOptions(path: '/v2/sessions', method: 'GET'),
  );
}

void main() {
  late ApiClient client;

  setUp(() {
    client = ApiClient()..clearAllCache();
  });

  tearDown(() {
    ApiClient()
      ..clearAllCache()
      ..clearToken();
  });

  test('sign-out drops responses cached for the previous account', () {
    client
      ..updateToken('token-account-a')
      ..debugSeedCache(_sessionsResponse());
    expect(client.getCacheStats()['totalEntries'], 1);

    client.clearToken();

    expect(
      client.getCacheStats()['totalEntries'],
      0,
      reason: 'the account is not part of the cache key',
    );
  });

  test('switching accounts drops the previous account responses', () {
    client
      ..updateToken('token-account-a')
      ..debugSeedCache(_sessionsResponse());
    expect(client.getCacheStats()['totalEntries'], 1);

    client.updateToken('token-account-b');

    expect(
      client.getCacheStats()['totalEntries'],
      0,
      reason: 'the account is not part of the cache key',
    );
  });

  test('re-applying the same token keeps the cache warm', () {
    client
      ..updateToken('token-account-a')
      ..debugSeedCache(_sessionsResponse())
      ..updateToken('token-account-a');

    expect(client.getCacheStats()['totalEntries'], 1);
  });
}
