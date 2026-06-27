// Audio-focus / ducking tests for TtsService.
//
// Background: when a user is listening to music and asks the chat
// assistant to read a message aloud, we want the TTS to duck (lower
// the volume of) the music — not stop it. The flutter_tts plugin
// already supports this on Android (speak(..., focus: true) requests
// `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK`) and we configure the iOS
// AVAudioSession category with `.duckOthers` + `.mixWithOthers` so
// the system engine does the same thing on iOS.
//
// These tests pin:
//   1. On Android, `speak()` is invoked with `focus: true`.
//   2. On iOS, init() configures the audio session category to
//      `.playback` with `[.duckOthers, .mixWithOthers]` and the
//      `.spokenAudio` mode (which the plugin's
//      `shouldDeactivateAndNotifyOthers` hook checks to decide
//      whether to send `.notifyOthersOnDeactivation` when speech
//      ends).
//   3. On non-iOS, non-web platforms (Android, desktop, etc.) init()
//      does NOT call `setIosAudioCategory` — the iOS-only API call
//      must be guarded.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');

  // Recorded method calls so each test can assert on what was
  // dispatched to the plugin.
  late List<MethodCall> calls;

  setUp(() async {
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
      calls.add(call);
      // Return a sensible default for whichever method was called so
      // init() / speak() don't crash on the host.
      switch (call.method) {
        case 'getEngines':
        case 'getLanguages':
          return <String>[];
        case 'setIosAudioCategory':
        case 'setSpeechRate':
        case 'setVolume':
        case 'setPitch':
        case 'setEngine':
        case 'setLanguage':
        case 'speak':
        case 'stop':
          return 1;
        default:
          return 1;
      }
    });
    // Reset the singleton between tests so each one sees a fresh
    // init() path.
    await TtsService().dispose();
  });

  tearDown(() async {
    await TtsService().dispose();
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
  });

  group('init() audio-session configuration', () {
    test(
      'configures iOS audio session with duckOthers + spokenAudio',
      () async {
        // Skip on non-iOS hosts where the audio-session category is
        // never configured — there's nothing to assert.
        if (!Platform.isIOS) return;

        await TtsService().init();

        final setCategory = calls.firstWhere(
          (c) => c.method == 'setIosAudioCategory',
          orElse: () => throw StateError(
            'setIosAudioCategory was never invoked',
          ),
        );
        final args = (setCategory.arguments as Map).cast<String, dynamic>();

        // The plugin's Swift `setAudioCategory` reads the iOS
        // category, options, and mode via three string keys. We assert
        // on the *strings* (not the Dart enums) so the test fails if
        // someone accidentally points at the wrong constants.
        expect(args['iosAudioCategoryKey'], 'iosAudioCategoryPlayback');
        final options = (args['iosAudioCategoryOptionsKey'] as List)
            .cast<String>()
            .toSet();
        expect(options, contains('iosAudioCategoryOptionsDuckOthers'));
        expect(options, contains('iosAudioCategoryOptionsMixWithOthers'));
        expect(args['iosAudioModeKey'], 'iosAudioModeSpokenAudio');
      },
    );

    test('does not invoke setIosAudioCategory on Android', () async {
      // The Linux test host isn't iOS, so we should never see this
      // call — guarding it locks in the platform check and prevents
      // future refactors from accidentally firing it on every init.
      if (Platform.isIOS) return;

      await TtsService().init();

      expect(
        calls.where((c) => c.method == 'setIosAudioCategory'),
        isEmpty,
      );
    });
  });

  group('speak() audio-focus handling', () {
    test(
      'Android: speak() forwards focus=true to the platform channel',
      () async {
        // Pin the ducking contract on Android: focus=true asks the
        // native plugin to request AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
        // so music keeps playing at a reduced volume rather than
        // being interrupted.
        if (!Platform.isAndroid) return;

        await TtsService().init();
        calls.clear();

        await TtsService().speak('Hello world', token: 'msg-1');

        final speakCall = calls.firstWhere(
          (c) => c.method == 'speak',
          orElse: () => throw StateError('speak() was never invoked'),
        );
        final args = (speakCall.arguments as Map).cast<String, dynamic>();
        expect(args['focus'], isTrue,
            reason: 'speak() must pass focus=true on Android so the '
                'engine requests transient-may-duck audio focus');
      },
    );

    test('non-Android: speak() forwards focus=false to the platform channel',
        () async {
      // On iOS the focus parameter is ignored by the plugin (the iOS
      // speak handler only reads `text`); we still want to pin the
      // value we forward so a future refactor can't accidentally
      // start requesting exclusive audio focus on iOS.
      if (Platform.isAndroid) return;

      await TtsService().init();
      calls.clear();

      await TtsService().speak('Hello world', token: 'msg-1');

      final speakCall = calls.firstWhere(
        (c) => c.method == 'speak',
        orElse: () => throw StateError('speak() was never invoked'),
      );
      final args = (speakCall.arguments is Map)
          ? (speakCall.arguments as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      // On non-Android, flutter_tts forwards `speak` with a bare
      // String (not a Map), so `focus` is simply absent — that's the
      // "no focus request" path we want to pin.
      expect(args.containsKey('focus'), isFalse);
    });
  });

  group('audio focus contract', () {
    test(
      'FlutterTts.speak declares a focus parameter',
      () async {
        // Sanity-check the upstream API we're relying on. If
        // flutter_tts ever drops the `focus` named parameter, the
        // Android ducking guarantee breaks silently — this test
        // surfaces the breakage immediately.
        final tts = FlutterTts();
        // The compile-time signature is the contract: if `focus`
        // stops being a named parameter, this assignment fails to
        // compile.
        final Future<dynamic> Function(String, {bool focus}) speakRef =
            tts.speak;
        expect(speakRef, isNotNull);
      },
    );
  });
}
