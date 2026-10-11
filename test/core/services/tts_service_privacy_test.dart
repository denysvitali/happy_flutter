import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  const privateText = 'Private conversation content must stay on device';
  late List<MethodCall> calls;
  late List<LogEntry> exported;
  String? stopError;
  Object speakResult = 1;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = <MethodCall>[];
    exported = <LogEntry>[];
    stopError = null;
    speakResult = 1;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'stop' && stopError != null) {
            throw PlatformException(code: 'speech-error', message: stopError);
          }
          if (call.method == 'speak') return speakResult;
          return 1;
        });
    await TtsService().dispose();
    logger
      ..clear()
      ..setMinLevel(LogLevel.debug)
      ..installOtelSink(exported.add);
  });

  tearDown(() async {
    await TtsService().dispose();
    logger
      ..removeOtelSink()
      ..setDeveloperMode(false)
      ..debugReleaseModeOverride = null;
    logger.clear();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final release in <bool>[false, true]) {
    for (final offline in <bool>[false, true]) {
      test(
        'speech logs are content-free (release=$release, offline=$offline)',
        () async {
          logger
            ..debugReleaseModeOverride = release
            ..setDeveloperMode(release);
          await TtsService().init();
          await TtsService().speak(
            '**$privateText**',
            token: 'private-message-id',
            useOffline: offline,
          );

          expect(calls.where((call) => call.method == 'speak'), hasLength(1));
          final logs = exported
              .map((entry) => entry.toFormattedString())
              .join();
          expect(logs, contains('${privateText.length} chars'));
          expect(logs, isNot(contains(privateText)));
          expect(logs, isNot(contains('private-message-id')));
        },
      );
    }
  }

  test('plugin speech results do not export plugin-supplied content', () async {
    speakResult = privateText;
    await TtsService().init();
    await TtsService().speak(privateText);

    expect(
      exported.map((entry) => entry.toFormattedString()).join(),
      isNot(contains(privateText)),
    );
  });

  test('speech stop errors do not export plugin-supplied content', () async {
    await TtsService().init();
    stopError = privateText;
    await TtsService().speak(privateText);

    expect(
      exported.where((entry) => entry.level == LogLevel.warning),
      isNotEmpty,
    );
    expect(
      exported.map((entry) => entry.toFormattedString()).join(),
      isNot(contains(privateText)),
    );
  });

  test('plugin speech errors do not export plugin-supplied content', () async {
    await TtsService().init();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('speak.onError', privateText),
          ),
          (_) {},
        );

    expect(
      exported.where((entry) => entry.level == LogLevel.error),
      isNotEmpty,
    );
    expect(
      exported.map((entry) => entry.toFormattedString()).join(),
      isNot(contains(privateText)),
    );
  });
}
