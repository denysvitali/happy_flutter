import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:happy_flutter/core/services/screen_awake_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.happy_flutter/screen_awake');
  final service = ScreenAwakeService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    service.debugReset();
  });

  test('missing native implementation does not escape to callers', () async {
    await expectLater(service.setEnabled(true), completes);
  });

  testWidgets('releases the hold after idle and re-arms on input', (
    tester,
  ) async {
    final calls = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.arguments);
          return null;
        });
    var now = 0;
    service
      ..debugSupportsOverride = true
      ..debugNowMs = () => now;

    await service.setEnabled(true);
    expect(calls, [true]);

    // Input during the hold extends it past the original deadline.
    now = ScreenAwakeService.idleRelease.inMilliseconds - 1000;
    service.recordUserInput();
    now = ScreenAwakeService.idleRelease.inMilliseconds;
    await tester.pump(ScreenAwakeService.idleRelease);
    expect(service.debugNativeEnabled, isTrue);
    expect(calls, [true]);

    // No input for the whole window: the OS screen timeout takes over.
    now += ScreenAwakeService.idleRelease.inMilliseconds;
    await tester.pump(ScreenAwakeService.idleRelease);
    expect(service.debugNativeEnabled, isFalse);
    expect(calls, [true, false]);

    // The next touch while work is still running re-arms it.
    service.recordUserInput();
    await tester.pump();
    expect(calls, [true, false, true]);

    await service.setEnabled(false);
    expect(calls, [true, false, true, false]);
    // Input without a caller wanting the hold never enables it.
    service.recordUserInput();
    await tester.pump();
    expect(calls, [true, false, true, false]);
  });
}
