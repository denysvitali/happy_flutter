// Regression test for GlitchTip HAPPY_FLUTTER-3C7:
// "Exception: Please initialize sherpa-onnx first".
//
// The per-message "Speak this message" path added in 8a87ecb could
// invoke the offline sherpa-onnx engine before its one-shot
// initialisation had completed. The fix gates every offline op behind
// `OfflineTtsService().initialize()` and has TtsService fall back to
// the system engine when init is still in flight and the requested
// voice isn't already on disk.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/offline_tts_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';

void main() {
  // The tests below talk to a singleton; ensure the platform channel
  // is silenced so `_tts.setSpeechRate` etc. don't crash on the host.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Stub flutter_tts platform channel so TtsService.init() doesn't
    // explode when running on the test host (no Android/iOS engine).
    const channel = MethodChannel('flutter_tts');
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => 1);
    // Stop any leftover speech from a previous test.
    await TtsService().stop();
  });

  tearDown(() async {
    const channel = MethodChannel('flutter_tts');
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await TtsService().stop();
  });

  group('OfflineTtsService.initialize', () {
    test(
      'completes even when the native sherpa-onnx library is missing',
      () async {
        // On the Linux test host the bundled .so almost certainly
        // won't load — the probe should still resolve gracefully and
        // flip isReady to true so callers don't get stuck.
        await OfflineTtsService().initialize();
        expect(OfflineTtsService().isReady, isTrue);
      },
    );

    test('is idempotent across repeated callers', () async {
      // Concurrent callers must share the same future so we never
      // probe sherpa more than once.
      final futures = await Future.wait<void>([
        OfflineTtsService().initialize(),
        OfflineTtsService().initialize(),
        OfflineTtsService().initialize(),
      ]);
      expect(futures, hasLength(3));
      expect(OfflineTtsService().isReady, isTrue);
    });
  });

  group('TtsService.speak before offline init resolves', () {
    test('does not throw when useOffline is true and engine not ready',
        () async {
      // Simulate a fresh launch where the user taps "Speak this
      // message" before initialize() has had time to resolve. The
      // service must fall back to the system engine (or no-op on
      // hosts without one) rather than letting the offline path
      // raise "Please initialize sherpa-onnx first".
      await expectLater(
        TtsService().speak(
          'Hello world',
          token: 'msg-1',
          useOffline: true,
          offlineVoiceId: 'vits-piper-en_US-amy-low-v1',
        ),
        completes,
      );
    });

    test('does not throw for repeated taps while init is in flight',
        () async {
      // Mirrors the user behaviour the regression report describes:
      // a fast double-tap on the speak row while the engine is
      // still booting. Both calls must complete without surfacing
      // the sherpa exception.
      await expectLater(
        Future.wait<void>([
          TtsService().speak(
            'First message',
            token: 'msg-a',
            useOffline: true,
          ),
          TtsService().speak(
            'Second message',
            token: 'msg-b',
            useOffline: true,
          ),
        ]),
        completes,
      );
    });
  });
}
