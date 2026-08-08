import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/sandbox_policy.dart';
import 'package:happy_flutter/core/types/remote_feature_failure.dart';

void main() {
  group('SandboxPolicyResponse.fromJson', () {
    test('reads a configured project', () {
      final response = SandboxPolicyResponse.fromJson({
        'success': true,
        'machineEnabled': true,
        'available': true,
        'backend': 'boxy',
        'network': 'public',
        'directory': '/home/u/proj',
        'enabled': true,
        'effectiveEnabled': true,
        'grants': [
          {'path': '/home/u/go/pkg/mod', 'mode': 'ro'},
          {'path': '/srv/data', 'mode': 'rw'},
        ],
        'allowHosts': ['github.com'],
        'updatedAt': 1730000000000,
      });

      expect(response.success, isTrue);
      expect(response.available, isTrue);
      expect(response.grants, hasLength(2));
      expect(response.grants.first.mode, SandboxGrantMode.readOnly);
      expect(response.allowHosts, ['github.com']);
    });

    // A project that has never been configured has no explicit choice; the
    // editor has to show "following the machine default" rather than an off
    // switch, so null must survive the decode.
    test('leaves enabled null for an unconfigured project', () {
      final response = SandboxPolicyResponse.fromJson({
        'success': true,
        'machineEnabled': true,
        'available': true,
        'effectiveEnabled': true,
        'directory': '/home/u/fresh',
      });

      expect(response.enabled, isNull);
      expect(response.effectiveEnabled, isTrue);
      expect(response.grants, isEmpty);
    });

    test('reports why sandboxing is unavailable', () {
      final response = SandboxPolicyResponse.fromJson({
        'success': true,
        'machineEnabled': true,
        'available': false,
        'reason': 'boxy not found on PATH',
      });

      expect(response.available, isFalse);
      expect(response.reason, 'boxy not found on PATH');
    });

    test('reads the project list', () {
      final response = SandboxPolicyResponse.fromJson({
        'success': true,
        'projects': [
          {
            'directory': '/home/u/a',
            'effectiveEnabled': true,
            'grants': <dynamic>[],
          },
          {'directory': '/home/u/b', 'enabled': false},
          {'directory': ''},
        ],
      });

      expect(response.projects, hasLength(2));
      expect(response.projects[1].enabled, isFalse);
    });

    test('survives a malformed payload', () {
      final response = SandboxPolicyResponse.fromJson({
        'success': false,
        'error': 'machine offline',
        'grants': 'not-a-list',
        'projects': 42,
      });

      expect(response.success, isFalse);
      expect(response.failureKind, RemoteFeatureFailureKind.rejected);
      expect(response.error, 'machine offline');
      expect(response.grants, isEmpty);
      expect(response.projects, isEmpty);
    });
  });

  group('SandboxGrant', () {
    test('defaults an unknown mode to read-write', () {
      final grant = SandboxGrant.fromJson({'path': '/srv', 'mode': 'rwx'});
      expect(grant.mode, SandboxGrantMode.readWrite);
    });

    test('round-trips through json', () {
      const grant = SandboxGrant(
        path: '/srv/data',
        mode: SandboxGrantMode.readOnly,
      );
      expect(SandboxGrant.fromJson(grant.toJson()), grant);
    });
  });
}
