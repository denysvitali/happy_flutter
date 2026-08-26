import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/provider_usage_storage.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('ProviderUsageStorage failure-state persistence', () {
    // GlitchTip issue 3658: an out-of-balance Kimi account answered HTTP
    // 429 forever and every app launch re-emitted warning stacks because
    // the strike/backoff map was process-local. It now round-trips through
    // secure storage so the cycle survives restarts.
    test('round-trips a per-account strike map', () async {
      final storage = ProviderUsageStorage();
      await storage.writeFailureState(<String, Map<String, dynamic>>{
        '4c83e655': <String, dynamic>{
          'failures': 3,
          'error':
              'ProviderUsageApiException: Kimi rate limited: HTTP 429 '
              '(insufficient balance)',
          'nextRetryAtMs': 1787770000000,
          'backoffUs': 900000000,
        },
      });

      final restored = await storage.readFailureState();
      expect(restored, hasLength(1));
      final strike = restored['4c83e655']!;
      expect(strike['failures'], 3);
      expect(strike['error'], contains('insufficient balance'));
      expect(strike['nextRetryAtMs'], 1787770000000);
      expect(strike['backoffUs'], 900000000);
    });

    test('writing an empty map clears the stored state', () async {
      final storage = ProviderUsageStorage();
      await storage.writeFailureState(<String, Map<String, dynamic>>{
        'a': <String, dynamic>{'failures': 1},
      });
      final cleared = await storage.writeFailureState(
        <String, Map<String, dynamic>>{},
      );
      expect(cleared, isTrue);
      expect(await storage.readFailureState(), isEmpty);
    });

    test('corrupt stored JSON degrades to an empty map', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'provider_usage_failures': '{not json',
      });
      final storage = ProviderUsageStorage();
      expect(await storage.readFailureState(), isEmpty);
    });

    test('non-map entries are dropped during read', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'provider_usage_failures':
            '{"good": {"failures": 2}, "bad": "not-a-map"}',
      });
      final storage = ProviderUsageStorage();
      final restored = await storage.readFailureState();
      expect(restored.keys, ['good']);
      expect(restored['good']!['failures'], 2);
    });
  });
}
