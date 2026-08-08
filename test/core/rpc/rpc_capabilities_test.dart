import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/rpc/rpc_capabilities.dart';

void main() {
  test('parses and gates methods from the live handler manifest', () {
    final capabilities = RpcCapabilities.fromJson(const <String, dynamic>{
      'protocolVersion': 2,
      'scope': 'session-1',
      'methods': <String>['permission', 'workflow-list'],
    });

    expect(capabilities.supports('workflow-list'), isTrue);
    expect(capabilities.supports('loop-list'), isFalse);
    expect(capabilities.protocolVersion, 2);
    expect(
      capabilities.statusFor('workflow-list'),
      RpcCapabilityStatus.supported,
    );
    expect(
      capabilities.statusFor('loop-list'),
      RpcCapabilityStatus.methodUnsupported,
    );
  });

  test('rejects manifests outside the supported protocol range', () {
    final old = RpcCapabilities.fromJson(const <String, dynamic>{
      'protocolVersion': 1,
      'scope': 'machine-1',
      'methods': <String>['bash'],
    });
    final future = RpcCapabilities.fromJson(const <String, dynamic>{
      'protocolVersion': 3,
      'scope': 'machine-1',
      'methods': <String>['bash'],
    });

    expect(old.statusFor('bash'), RpcCapabilityStatus.protocolTooOld);
    expect(future.statusFor('bash'), RpcCapabilityStatus.protocolTooNew);
    expect(old.supports('bash'), isFalse);
    expect(future.supports('bash'), isFalse);
  });

  test('treats structurally incomplete manifests as legacy/unknown', () {
    expect(
      RpcCapabilities.tryFromJson(const <String, dynamic>{
        'protocolVersion': 2,
      }),
      isNull,
    );
    expect(
      RpcCapabilities.tryFromJson(const <String, dynamic>{
        'methods': <String>['bash'],
      }),
      isNull,
    );
  });
}
