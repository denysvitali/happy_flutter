import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only bearer renewal honors a captured Authorization header', () async {
    final client = ApiClient();
    await client.initialize(serverUrl: 'https://example.test');
    client.updateToken('current-token');
    addTearDown(() {
      client
        ..clearToken()
        ..dispose();
    });
    final authorizations = <Object?>[];
    client.testDio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          authorizations.add(options.headers['Authorization']);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: <String, dynamic>{},
            ),
          );
        },
      ),
    );

    await client.post(
      '/v1/auth/refresh',
      options: Options(headers: {'Authorization': 'Bearer captured-token'}),
    );
    await client.get(
      '/v1/profile',
      options: Options(headers: {'Authorization': 'Bearer unrelated-token'}),
    );

    expect(authorizations, ['Bearer captured-token', 'Bearer current-token']);
  });
}
