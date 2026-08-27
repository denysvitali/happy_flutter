import 'package:flutter_test/flutter_test.dart';

import 'package:happy_flutter/core/services/screen_awake_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing native implementation does not escape to callers', () async {
    await expectLater(ScreenAwakeService().setEnabled(true), completes);
  });
}
