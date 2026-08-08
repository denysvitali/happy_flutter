import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/rpc/rpc_exception.dart';

void main() {
  test('parses a stable typed RPC error envelope', () {
    final error = RpcException.fromWire(const <String, dynamic>{
      'error': 'Method not found',
      'code': 'method_unsupported',
      'retryable': false,
      'scope': 'session-1',
      'method': 'workflow-list',
      'minProtocol': 2,
    }, fallbackMethod: 'fallback');

    expect(error.code, RpcErrorCode.methodUnsupported);
    expect(error.retryable, isFalse);
    expect(error.scope, 'session-1');
    expect(error.method, 'workflow-list');
    expect(error.minProtocol, 2);
  });

  test(
    'classifies legacy relay errors without substring checks at call sites',
    () {
      final error = RpcException.fromWire(const <String, dynamic>{
        'error':
            'RPC handler for "m:ping" is not registered on any reachable '
            'server replica',
      }, fallbackMethod: 'ping');

      expect(error.code, RpcErrorCode.handlerOffline);
      expect(error.retryable, isTrue);
      expect(error.method, 'ping');
    },
  );

  test('parses protocol incompatibility without relying on prose', () {
    final error = RpcException.fromWire(const <String, dynamic>{
      'error': 'Unsupported RPC protocol',
      'code': 'protocol_unsupported',
      'retryable': false,
      'scope': 'machine-1',
      'method': 'bash',
      'minProtocol': 2,
    });

    expect(error.code, RpcErrorCode.protocolUnsupported);
    expect(error.minProtocol, 2);
  });
}
