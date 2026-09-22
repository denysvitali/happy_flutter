import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/provider_versions.dart';

void main() {
  group('CodingAgent', () {
    test('maps supported providers to their RPC names and UI labels', () {
      expect(CodingAgent.codex.wireValue, 'codex');
      expect(CodingAgent.codex.displayName, 'Codex');
      expect(CodingAgent.claude.wireValue, 'claude');
      expect(CodingAgent.claude.displayName, 'Claude Code');
      expect(CodingAgent.fromWire('codex'), CodingAgent.codex);
      expect(CodingAgent.fromWire('claude'), CodingAgent.claude);
      expect(CodingAgent.fromWire('future-agent'), isNull);
      expect(CodingAgent.fromWire(null), isNull);
    });
  });

  group('ProviderVersion', () {
    test('parses installed version and supported update details', () {
      final provider = ProviderVersion.fromJson({
        'provider': 'codex',
        'installed': true,
        'version': '1.0.0',
        'latestVersion': '1.1.0',
        'updateAvailable': true,
        'canUpdate': true,
        'installMethod': 'npm',
        'updateStatus': 'running',
        'updateMessage': 'Updating Codex',
      });

      expect(provider.provider, CodingAgent.codex);
      expect(provider.installed, isTrue);
      expect(provider.version, '1.0.0');
      expect(provider.latestVersion, '1.1.0');
      expect(provider.updateAvailable, isTrue);
      expect(provider.canUpdate, isTrue);
      expect(provider.installMethod, 'npm');
      expect(provider.updateStatus, 'running');
      expect(provider.isUpdating, isTrue);
      expect(provider.updateMessage, 'Updating Codex');
      expect(provider.error, isNull);
      expect(provider.updateError, isNull);
    });

    test('missing status fields do not enable an update', () {
      final provider = ProviderVersion.fromJson({'provider': 'claude'});

      expect(provider.provider, CodingAgent.claude);
      expect(provider.installed, isFalse);
      expect(provider.version, isNull);
      expect(provider.latestVersion, isNull);
      expect(provider.updateAvailable, isFalse);
      expect(provider.canUpdate, isFalse);
      expect(provider.installMethod, isNull);
      expect(provider.updateStatus, 'idle');
      expect(provider.isUpdating, isFalse);
      expect(provider.error, isNull);
      expect(provider.updateError, isNull);
      expect(provider.updateMessage, isNull);
    });

    test(
      'keeps installation status independent from registry availability',
      () {
        final provider = ProviderVersion.fromJson({
          'provider': 'claude',
          'installed': false,
          'latestVersion': '2.1.0',
          'error': 'Claude Code is not installed',
        });

        expect(provider.installed, isFalse);
        expect(provider.version, isNull);
        expect(provider.latestVersion, '2.1.0');
        expect(provider.canUpdate, isFalse);
        expect(provider.error, 'Claude Code is not installed');
      },
    );

    test('retains installed version when latest-version lookup fails', () {
      final provider = ProviderVersion.fromJson({
        'provider': 'codex',
        'installed': true,
        'version': '1.0.0',
        'error': 'Could not check the latest version',
      });

      expect(provider.installed, isTrue);
      expect(provider.version, '1.0.0');
      expect(provider.latestVersion, isNull);
      expect(provider.updateAvailable, isFalse);
      expect(provider.error, 'Could not check the latest version');
    });

    test('preserves an update failure separately from a check failure', () {
      final provider = ProviderVersion.fromJson({
        'provider': 'claude',
        'installed': true,
        'version': '2.0.0',
        'updateStatus': 'failed',
        'error': 'Latest version unavailable',
        'updateError': 'Installation directory is not writable',
        'updateMessage': 'Update failed',
      });

      expect(provider.updateStatus, 'failed');
      expect(provider.isUpdating, isFalse);
      expect(provider.error, 'Latest version unavailable');
      expect(provider.updateError, 'Installation directory is not writable');
      expect(provider.updateMessage, 'Update failed');
    });

    test('succeeded updates are not treated as running', () {
      final provider = ProviderVersion.fromJson({
        'provider': 'codex',
        'installed': true,
        'version': '1.1.0',
        'latestVersion': '1.1.0',
        'updateStatus': 'succeeded',
        'updateMessage': 'Codex updated',
      });

      expect(provider.isUpdating, isFalse);
      expect(provider.updateAvailable, isFalse);
      expect(provider.updateMessage, 'Codex updated');
    });
  });

  group('ProviderVersionsResponse', () {
    test('preserves partial results and per-provider failures', () {
      final response = ProviderVersionsResponse.fromJson({
        'success': true,
        'providers': [
          {'provider': 'codex', 'installed': true, 'version': '1.0.0'},
          {
            'provider': 'claude',
            'installed': false,
            'error': 'Claude Code is not installed',
          },
        ],
      });

      expect(response.success, isTrue);
      expect(response.providers, hasLength(2));
      expect(response.providers.first.provider, CodingAgent.codex);
      expect(response.providers.first.version, '1.0.0');
      expect(response.providers.last.provider, CodingAgent.claude);
      expect(response.providers.last.installed, isFalse);
      expect(response.providers.last.error, 'Claude Code is not installed');
      expect(response.error, isNull);
    });

    test('filters unknown providers without dropping supported providers', () {
      final response = ProviderVersionsResponse.fromJson({
        'success': true,
        'providers': [
          {'provider': 'future-agent', 'installed': true},
          {'provider': 'claude', 'installed': true, 'version': '2.0.0'},
          {'installed': true},
        ],
      });

      expect(response.providers, hasLength(1));
      expect(response.providers.single.provider, CodingAgent.claude);
    });

    test('preserves overall failure and defaults an absent list to empty', () {
      final response = ProviderVersionsResponse.fromJson({
        'success': false,
        'error': 'Provider version checks are unavailable',
      });

      expect(response.success, isFalse);
      expect(response.providers, isEmpty);
      expect(response.error, 'Provider version checks are unavailable');
      expect(ProviderVersionsResponse.fromJson({}).success, isFalse);
      expect(ProviderVersionsResponse.fromJson({}).providers, isEmpty);
    });
  });

  group('ProviderUpdateResponse', () {
    test('parses an accepted update with its running provider status', () {
      final response = ProviderUpdateResponse.fromJson({
        'success': true,
        'provider': {
          'provider': 'codex',
          'installed': true,
          'version': '1.0.0',
          'updateStatus': 'running',
        },
      });

      expect(response.success, isTrue);
      expect(response.provider?.provider, CodingAgent.codex);
      expect(response.provider?.isUpdating, isTrue);
      expect(response.error, isNull);
    });

    test('preserves rejection errors without requiring a provider status', () {
      final response = ProviderUpdateResponse.fromJson({
        'success': false,
        'error': 'Unsupported installation method',
      });

      expect(response.success, isFalse);
      expect(response.provider, isNull);
      expect(response.error, 'Unsupported installation method');
      expect(ProviderUpdateResponse.fromJson({}).success, isFalse);
      expect(ProviderUpdateResponse.fromJson({}).provider, isNull);
    });
  });
}
