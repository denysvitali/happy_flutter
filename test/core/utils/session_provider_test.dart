import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_provider.dart';

void main() {
  group('session provider identity', () {
    test('reads the daemon-recorded routing and profile', () {
      final metadata = Metadata.fromJson({
        'host': '',
        'flavor': 'claude',
        'model': 'opendesign/deepseek-v4.1-flash-eco[1m]',
        'clientProfileId': 'custom_1787554838941',
        'providerRoutingEnv': {
          'ANTHROPIC_API_KEY': 'foo',
          'ANTHROPIC_BASE_URL': 'http://llm-proxy.beago-bass.ts.net',
          'ANTHROPIC_MODEL': 'opendesign/deepseek-v4.1-flash-eco',
        },
      });

      expect(metadata.clientProfileId, 'custom_1787554838941');
      expect(
        metadata.providerRouting?.anthropicBaseUrl,
        'http://llm-proxy.beago-bass.ts.net',
      );
      // Credentials never enter the parsed shape.
      expect(
        Metadata.fromJson(metadata.toJson()).providerRouting?.anthropicBaseUrl,
        'http://llm-proxy.beago-bass.ts.net',
      );
      expect(sessionClientProfileId(metadata), 'custom_1787554838941');
      expect(metadataRecordsClientProfile(metadata), isTrue);
      expect(
        sessionRecordedModel(metadata),
        'opendesign/deepseek-v4.1-flash-eco[1m]',
      );
      expect(sessionUsesThirdPartyAnthropicBaseUrl(metadata), isTrue);
      expect(sessionUsesThirdPartyProvider(metadata), isTrue);
    });

    test(
      'explicit default profile and official endpoints are not gateways',
      () {
        final official = Metadata.fromJson({
          'host': '',
          'clientProfileId': 'default',
          'providerRoutingEnv': {
            'ANTHROPIC_BASE_URL': 'https://api.anthropic.com',
          },
        });

        expect(sessionClientProfileId(official), isNull);
        expect(metadataRecordsClientProfile(official), isTrue);
        expect(sessionUsesThirdPartyAnthropicBaseUrl(official), isFalse);
        expect(sessionUsesThirdPartyProvider(official), isFalse);
      },
    );

    test('sessions without recorded routing stay unknown', () {
      final metadata = Metadata.fromJson({'host': '', 'model': 'opus'});

      expect(metadata.providerRouting, isNull);
      expect(sessionUsesThirdPartyAnthropicBaseUrl(metadata), isFalse);
      expect(metadataRecordsClientProfile(metadata), isFalse);
      expect(sessionRecordedModels(metadata), ['opus']);
    });

    test(r'expands ${VAR:-default} routing refs before classification', () {
      final metadata = Metadata.fromJson({
        'host': '',
        'providerRoutingEnv': {
          'ANTHROPIC_BASE_URL':
              r'${DEEPSEEK_BASE_URL:-https://api.deepseek.com/anthropic}',
        },
      });

      expect(
        sessionAnthropicBaseUrl(metadata),
        'https://api.deepseek.com/anthropic',
      );
      expect(sessionUsesThirdPartyAnthropicBaseUrl(metadata), isTrue);
    });

    test('Codex routing only counts a third-party OpenAI endpoint', () {
      final metadata = Metadata.fromJson({
        'host': '',
        'providerRoutingEnv': {
          'OPENAI_BASE_URL': 'http://llm-proxy.beago-bass.ts.net/v1',
        },
      });

      expect(sessionUsesThirdPartyOpenAIBaseUrl(metadata), isTrue);
      expect(sessionUsesThirdPartyAnthropicBaseUrl(metadata), isFalse);
    });
  });
}
