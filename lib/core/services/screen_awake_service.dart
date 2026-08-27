import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../platform_io.dart'
    if (dart.library.js_interop) '../../platform_stub.dart';
import 'logger_service.dart' show logger;

/// Keeps the display awake during foreground session work and TTS playback.
class ScreenAwakeService {
  factory ScreenAwakeService() => _instance;
  ScreenAwakeService._();

  static final ScreenAwakeService _instance = ScreenAwakeService._();
  static const MethodChannel _channel = MethodChannel(
    'com.example.happy_flutter/screen_awake',
  );

  bool _enabled = false;

  static bool get _supportsScreenAwake =>
      !kIsWeb && (isAndroid || isIOS || isLinux);

  Future<void> setEnabled(bool enabled) async {
    if (!_supportsScreenAwake || enabled == _enabled) return;
    _enabled = enabled;
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on PlatformException catch (error, stack) {
      _enabled = !enabled;
      logger.warning('[ScreenAwake] native update failed', error, stack);
    } on MissingPluginException catch (error, stack) {
      _enabled = !enabled;
      logger.info('[ScreenAwake] native channel unavailable', error, stack);
    }
  }
}
