import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/offline_tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');

  tearDown(() async {
    await TtsService().dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
  });

  test('Linux unavailable speech never calls the system plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
          calls.add(call.method);
          return 1;
        });
    final service = TtsService();
    expect(service.isUnavailable, isTrue);
    expect(OfflineTtsService().isSupported, isFalse);
    for (var i = 0; i < 3; i++) {
      await service.init();
      await service.speak('Hello');
      await service.enqueueSpeak('Hello');
      expect(await service.getEngines(), isEmpty);
      expect(await service.getLanguages(), isEmpty);
    }
    expect(calls, isEmpty);
    expect(service.currentToken.value, isNull);
    expect(service.queuedCount, 0);
    expect(
      logger.getLogsByLevel(LogLevel.info).where(
        (entry) => entry.message == '[TTS] speech unavailable on this platform',
      ),
      hasLength(1),
    );
  });

  test('getEngines accepts string payloads from plugin', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
          switch (call.method) {
            case 'getEngines':
              return <String>['engine.one', 'engine.two'];
            default:
              return 1;
          }
        });

    final engines = await TtsService().getEngines();

    expect(engines, [
      {'name': 'engine.one', 'identifier': 'engine.one'},
      {'name': 'engine.two', 'identifier': 'engine.two'},
    ]);
  });

  test('getLanguages preserves map payloads from plugin', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, (call) async {
          switch (call.method) {
            case 'getLanguages':
              return <Map<String, String>>[
                {'name': 'English (US)', 'locale': 'en-US'},
              ];
            default:
              return 1;
          }
        });

    final languages = await TtsService().getLanguages();

    expect(languages, [
      {'name': 'English (US)', 'locale': 'en-US'},
    ]);
  });
}
