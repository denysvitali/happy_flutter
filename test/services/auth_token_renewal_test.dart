import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/services/auth_service.dart';
import 'package:mockito/mockito.dart';

import 'auth_service_test.mocks.dart';

class _Credentials implements AuthCredentialStore {
  AuthCredentials? value;
  bool writesFail = false;
  Completer<void>? writeGate;
  @override
  Future<AuthCredentials?> getCredentials() async => value;
  @override
  Future<bool> isAuthenticated() async => value != null;
  @override
  Future<bool> removeCredentials() async {
    value = null;
    return true;
  }

  @override
  Future<bool> setCredentials(AuthCredentials credentials) async {
    await writeGate?.future;
    if (writesFail) return false;
    value = credentials;
    return true;
  }
}

class _UnusedCrypto implements AuthCrypto {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _token(DateTime expiry, {String user = 'account', bool legacy = false}) {
  final payload = base64UrlEncode(
    utf8.encode(
      jsonEncode({
        'user': user,
        'sub': user,
        'iss': 'handy',
        if (!legacy) 'exp': expiry.millisecondsSinceEpoch ~/ 1000,
      }),
    ),
  ).replaceAll('=', '');
  return 'header.$payload.signature';
}

Response<dynamic> _response(int status, [dynamic data]) => Response<dynamic>(
  statusCode: status,
  data: data,
  requestOptions: RequestOptions(path: '/v1/auth/refresh'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockApiClient api;
  late MockEncryptionService encryption;
  late _Credentials store;
  late AuthService service;
  late DateTime now;
  late List<String> socketTokens;
  late AuthCredentials old;

  setUp(() {
    now = DateTime.utc(2026);
    api = MockApiClient();
    encryption = MockEncryptionService();
    store = _Credentials();
    socketTokens = [];
    old = AuthCredentials(
      token: _token(now.add(const Duration(days: 2))),
      secret: 'retained-secret',
    );
    store.value = old;
    service = AuthService.test(
      apiClient: api,
      encryption: encryption,
      credentials: store,
      crypto: _UnusedCrypto(),
      now: () => now,
      updateSocketToken: socketTokens.add,
    );
  });

  void respond(Future<Response<dynamic>> Function() response) {
    when(
      api.post('/v1/auth/refresh', options: anyNamed('options')),
    ).thenAnswer((_) => response());
  }

  test('renews a still-valid token and updates both transports', () async {
    final token = _token(now.add(const Duration(days: 30)));
    respond(() async => _response(200, {'token': token}));
    final result = await service.refreshCredentialsIfNeeded();
    expect(result, AuthCredentials(token: token, secret: old.secret));
    expect(store.value, result);
    expect(socketTokens, [token]);
    verify(api.updateToken(token)).called(1);
    final options =
        verify(
              api.post('/v1/auth/refresh', options: captureAnyNamed('options')),
            ).captured.single
            as Options;
    expect(options.headers?['Authorization'], 'Bearer ${old.token}');
    verifyNever(encryption.initialize(any));
    expect(service.nextTokenRefreshDelay(result!), const Duration(days: 23));
  });

  test('does not renew early or legacy tokens', () async {
    for (final token in [
      _token(now.add(const Duration(days: 20))),
      _token(now, legacy: true),
    ]) {
      store.value = AuthCredentials(token: token, secret: old.secret);
      expect(await service.refreshCredentialsIfNeeded(), store.value);
    }
    verifyNever(api.post('/v1/auth/refresh', options: anyNamed('options')));
  });

  test('expired credentials require sign-in and remain stored', () async {
    store.value = AuthCredentials(token: _token(now), secret: old.secret);
    final expired = store.value;
    await expectLater(
      service.refreshCredentialsIfNeeded(),
      throwsA(isA<AuthForbiddenError>()),
    );
    expect(store.value, expired);
    expect(service.lastAuthFailure, AuthFailureKind.rejected);
    verifyNever(api.post('/v1/auth/refresh', options: anyNamed('options')));
  });

  test(
    'wrong-account and expired responses never replace credentials',
    () async {
      for (final token in [
        _token(now.add(const Duration(days: 30)), user: 'other-account'),
        _token(now),
        'malformed',
      ]) {
        respond(() async => _response(200, {'token': token}));
        await expectLater(
          service.refreshToken(),
          throwsA(isA<AuthException>()),
        );
        expect(store.value, old);
        expect(socketTokens, isEmpty);
      }
      verifyNever(api.updateToken(any));
    },
  );

  test('concurrent renewals share one request', () async {
    final pending = Completer<Response<dynamic>>();
    respond(() => pending.future);
    final first = service.refreshToken();
    final second = service.refreshToken();
    await Future<void>.delayed(Duration.zero);
    final token = _token(now.add(const Duration(days: 30)));
    pending.complete(_response(200, {'token': token}));
    expect(await Future.wait([first, second]), [token, token]);
    verify(
      api.post('/v1/auth/refresh', options: anyNamed('options')),
    ).called(1);
  });

  test('sign-out fences a delayed renewal response', () async {
    final pending = Completer<Response<dynamic>>();
    respond(() => pending.future);
    final flight = service.refreshToken();
    await Future<void>.delayed(Duration.zero);
    await service.signOut();
    pending.complete(
      _response(200, {'token': _token(now.add(const Duration(days: 30)))}),
    );
    await expectLater(flight, throwsA(isA<AuthException>()));
    expect(store.value, isNull);
    expect(socketTokens, isEmpty);
    verifyNever(api.updateToken(any));
  });

  test(
    'sign-out waits for a pending credential write then removes it',
    () async {
      final gate = Completer<void>();
      store.writeGate = gate;
      respond(
        () async => _response(200, {
          'token': _token(now.add(const Duration(days: 30))),
        }),
      );
      final flight = service.refreshToken();
      final rejected = expectLater(flight, throwsA(isA<AuthException>()));
      await Future<void>.delayed(Duration.zero);
      final logout = service.signOut();
      gate.complete();
      await Future.wait([rejected, logout]);
      expect(store.value, isNull);
      expect(socketTokens, isEmpty);
    },
  );

  test('account replacement fences a delayed renewal', () async {
    final pending = Completer<Response<dynamic>>();
    respond(() => pending.future);
    final flight = service.refreshToken();
    await Future<void>.delayed(Duration.zero);
    when(encryption.initialize(any)).thenAnswer((_) async {});
    await service.completeAuth('replacement', Uint8List(32));
    final replacement = store.value;
    pending.complete(
      _response(200, {'token': _token(now.add(const Duration(days: 30)))}),
    );
    await expectLater(flight, throwsA(isA<AuthException>()));
    expect(store.value, replacement);
    expect(socketTokens, isEmpty);
  });

  test(
    'failed persistence leaves transports and credentials unchanged',
    () async {
      store.writesFail = true;
      respond(
        () async => _response(200, {
          'token': _token(now.add(const Duration(days: 30))),
        }),
      );
      await expectLater(service.refreshToken(), throwsA(isA<AuthException>()));
      expect(store.value, old);
      expect(socketTokens, isEmpty);
      verifyNever(api.updateToken(any));
    },
  );

  test('account replacement follows a pending renewal write', () async {
    final gate = Completer<void>();
    store.writeGate = gate;
    respond(
      () async =>
          _response(200, {'token': _token(now.add(const Duration(days: 30)))}),
    );
    final flight = service.refreshToken();
    final rejected = expectLater(flight, throwsA(isA<AuthException>()));
    await Future<void>.delayed(Duration.zero);
    when(encryption.initialize(any)).thenAnswer((_) async {});
    final replacement = service.completeAuth('replacement', Uint8List(32));
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await rejected;
    await replacement;
    expect(store.value?.token, 'replacement');
    expect(socketTokens, isEmpty);
  });

  test(
    'temporary HTTP failures retain the valid token and renewal retry',
    () async {
      for (final status in [404, 408, 429, 500, 503]) {
        respond(() async => _response(status));
        expect(await service.refreshCredentialsIfNeeded(), old);
        expect(service.nextTokenRefreshDelay(old), const Duration(hours: 1));
        expect(store.value, old);
        expect(socketTokens, isEmpty);
      }
    },
  );

  test(
    'HTTP exceptions distinguish temporary and permanent failures',
    () async {
      for (final status in [408, 429, 400, 401, 403]) {
        respond(
          () async => throw DioException(
            requestOptions: RequestOptions(path: '/v1/auth/refresh'),
            type: DioExceptionType.badResponse,
            response: _response(status),
          ),
        );
        if (status == 408 || status == 429) {
          expect(await service.refreshCredentialsIfNeeded(), old);
        } else {
          await expectLater(
            service.refreshCredentialsIfNeeded(),
            throwsA(
              status == 400 ? isA<AuthException>() : isA<AuthForbiddenError>(),
            ),
          );
        }
        expect(store.value, old);
      }
    },
  );

  test('transport failure retains still-valid credentials', () async {
    respond(
      () async => throw DioException(
        requestOptions: RequestOptions(path: '/v1/auth/refresh'),
        type: DioExceptionType.connectionError,
      ),
    );
    expect(await service.refreshCredentialsIfNeeded(), old);
    expect(store.value, old);
    expect(socketTokens, isEmpty);
  });

  test('temporary responses never extend the original expiry', () async {
    for (final status in [408, 429]) {
      final start = DateTime.utc(2026);
      now = start;
      final expiring = AuthCredentials(
        token: _token(now.add(const Duration(minutes: 20))),
        secret: old.secret,
      );
      store.value = expiring;
      expect(
        service.nextTokenRefreshDelay(expiring),
        const Duration(minutes: 20),
      );
      respond(() async {
        now = now.add(const Duration(minutes: 21));
        return _response(status);
      });
      await expectLater(
        service.refreshCredentialsIfNeeded(),
        throwsA(isA<AuthForbiddenError>()),
      );
      expect(store.value, expiring);
    }
  });

  test('failure after expiry requires reauthentication', () async {
    respond(() async {
      now = now.add(const Duration(days: 3));
      return _response(404);
    });
    await expectLater(
      service.refreshCredentialsIfNeeded(),
      throwsA(isA<AuthForbiddenError>()),
    );
    expect(store.value, old);
  });
}
