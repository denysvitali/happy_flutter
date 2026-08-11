import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/models/auth.dart';
import 'package:happy_flutter/core/services/auth_service.dart';
import 'package:happy_flutter/core/services/encryption_service.dart';
import 'package:happy_flutter/core/utils/backup_key_utils.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([ApiClient, EncryptionService])
import 'auth_service_test.mocks.dart';

class _MemoryCredentials implements AuthCredentialStore {
  AuthCredentials? value;

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
    value = credentials;
    return true;
  }
}

class _FakeCrypto implements AuthCrypto {
  final seed = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final boxPublicKey = Uint8List.fromList(List<int>.filled(32, 7));
  final signingPublicKey = Uint8List.fromList(List<int>.filled(32, 9));
  final signature = Uint8List.fromList(List<int>.filled(64, 11));
  Uint8List decrypted = Uint8List.fromList(List<int>.filled(32, 13));
  final disposed = <Object>[];

  @override
  Future<AuthBoxKeyPair> boxKeypairFromSeed(Uint8List value) async =>
      AuthBoxKeyPair(publicKey: boxPublicKey, secretKey: Object());

  @override
  Future<Uint8List?> decrypt(Uint8List data, Object secretKey) async =>
      decrypted;

  @override
  void disposeKey(Object secretKey) => disposed.add(secretKey);

  @override
  Future<Uint8List> encrypt(Uint8List data, Uint8List publicKey) async =>
      Uint8List.fromList(data.reversed.toList());

  @override
  Future<AuthBoxKeyPair> generateBoxKeypair() async =>
      AuthBoxKeyPair(publicKey: boxPublicKey, secretKey: Object());

  @override
  Future<AuthSigningKeyPair> generateSigningKeypair(Uint8List value) async =>
      AuthSigningKeyPair(publicKey: signingPublicKey, secretKey: Object());

  @override
  Uint8List randomBytes(int length) =>
      Uint8List.fromList(seed.take(length).toList());

  @override
  Future<Uint8List> sign(Uint8List challenge, Object secretKey) async =>
      signature;
}

Response<dynamic> _response(int statusCode, [dynamic data]) =>
    Response<dynamic>(
      data: data,
      statusCode: statusCode,
      requestOptions: RequestOptions(path: ''),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService injected authentication flows', () {
    late MockApiClient api;
    late MockEncryptionService encryption;
    late _MemoryCredentials credentials;
    late _FakeCrypto crypto;
    late AuthService service;
    late DateTime now;

    setUp(() {
      api = MockApiClient();
      encryption = MockEncryptionService();
      credentials = _MemoryCredentials();
      crypto = _FakeCrypto();
      now = DateTime.utc(2026);
      when(encryption.initialize(any)).thenAnswer((_) async {});
      service = AuthService.test(
        apiClient: api,
        encryption: encryption,
        credentials: credentials,
        crypto: crypto,
        now: () => now,
        delay: (duration) async => now = now.add(duration),
        approvalTimeout: const Duration(seconds: 2),
      );
    });

    test('QR request sends the generated public key', () async {
      when(
        api.post('/v1/auth/account/request', data: anyNamed('data')),
      ).thenAnswer((_) async => _response(200));

      final publicKey = await service.startQRAuth();

      expect(publicKey, crypto.boxPublicKey);
      final captured =
          verify(
                api.post(
                  '/v1/auth/account/request',
                  data: captureAnyNamed('data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['publicKey'], base64Encode(crypto.boxPublicKey));
    });

    test('QR request propagates a transport failure', () async {
      when(
        api.post('/v1/auth/account/request', data: anyNamed('data')),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      await expectLater(service.startQRAuth(), throwsA(isA<DioException>()));
    });

    test('QR approval decrypts and persists credentials', () async {
      when(
        api.post('/v1/auth/account/request', data: anyNamed('data')),
      ).thenAnswer((_) async => _response(200));
      await service.startQRAuth();
      when(
        api.post(
          '/v1/auth/account/request',
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer(
        (_) async => _response(200, {
          'state': 'authorized',
          'token': 'qr-token',
          'response': base64Encode([1, 2, 3]),
        }),
      );

      final result = await service.waitForAuthApproval(crypto.boxPublicKey);

      expect(result.token, 'qr-token');
      expect(credentials.value, result);
      verify(encryption.initialize(crypto.decrypted)).called(1);
      verify(api.updateToken('qr-token')).called(1);
    });

    test('QR approval reports a server rejection immediately', () async {
      when(
        api.post(
          '/v1/auth/account/request',
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer((_) async => _response(403, {'error': 'denied'}));

      await expectLater(
        service.waitForAuthApproval(crypto.boxPublicKey),
        throwsA(isA<AuthForbiddenError>()),
      );
    });

    test(
      'device linking uses seeded key material and formats QR data',
      () async {
        when(api.getCurrentServerUrl()).thenReturn('https://example.test');
        when(
          api.post('/v1/auth/account/request', data: anyNamed('data')),
        ).thenAnswer((_) async => _response(200));

        final result = await service.startDeviceLinking();

        expect(result.publicKey, crypto.boxPublicKey);
        expect(result.secret, crypto.seed);
        expect(result.getQRData(), startsWith('happy:///account?'));
      },
    );

    test('device approval timeout is deterministic without waiting', () async {
      when(
        api.post(
          '/v1/auth/account/request',
          data: anyNamed('data'),
          options: anyNamed('options'),
        ),
      ).thenAnswer((_) async => _response(200, {'state': 'pending'}));

      await expectLater(
        service.waitForLinkingApproval(base64Encode(crypto.boxPublicKey)),
        throwsA(isA<ExpiredError>()),
      );
    });

    test('account creation signs request and stores returned token', () async {
      when(
        api.post('/v1/auth', data: anyNamed('data')),
      ).thenAnswer((_) async => _response(200, {'token': 'new-token'}));

      await service.createAccount();

      final request =
          verify(
                api.post('/v1/auth', data: captureAnyNamed('data')),
              ).captured.single
              as Map<String, dynamic>;
      expect(request['publicKey'], base64Encode(crypto.signingPublicKey));
      expect(request['signature'], base64Encode(crypto.signature));
      expect(credentials.value?.token, 'new-token');
    });

    test('account creation maps a conflict', () async {
      when(
        api.post('/v1/auth', data: anyNamed('data')),
      ).thenAnswer((_) async => _response(409));

      await expectLater(
        service.createAccount(),
        throwsA(
          isA<AuthRequestError>().having((e) => e.statusCode, 'status', 409),
        ),
      );
    });

    test('restore uses decoded backup secret and persists result', () async {
      final secret = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final key = BackupKeyUtils.encodeKey(secret);
      when(
        api.post('/v1/auth', data: anyNamed('data')),
      ).thenAnswer((_) async => _response(200, {'token': 'restored'}));

      final result = await service.restoreAccount(key);

      expect(result.secret, base64Encode(secret));
      expect(credentials.value, result);
    });

    test('completeAuth and signOut use injected stores', () async {
      await service.completeAuth('token', crypto.seed);
      expect(await service.isAuthenticated(), isTrue);

      await service.signOut();

      expect(await service.isAuthenticated(), isFalse);
    });
  });

  group('AuthService.parseAuthUrl', () {
    test('accepts terminal and account URL formats', () {
      final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final encoded = base64UrlEncode(key).replaceAll('=', '');

      expect(AuthService.parseAuthUrl('happy://terminal?$encoded'), key);
      expect(AuthService.parseAuthUrl('happy:///account?$encoded'), key);
    });

    test('rejects malformed URLs and keys of the wrong size', () {
      expect(AuthService.parseAuthUrl('https://example.test'), isNull);
      expect(AuthService.parseAuthUrl('happy:///account?AA'), isNull);
    });
  });
}
