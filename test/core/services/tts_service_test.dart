import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');

  tearDown(() async {
    await TtsService().dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ttsChannel, null);
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
