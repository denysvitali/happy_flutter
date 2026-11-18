import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../platform_io.dart'
    if (dart.library.js_interop) '../../platform_stub.dart';
import 'logger_service.dart' show logger;

/// Keeps the display awake during foreground session work and TTS playback.
///
/// Callers declare that they *want* the screen awake ([setEnabled]); the
/// service only holds it while someone is plausibly watching: within
/// [idleRelease] of the last touch or key press. An agent turn can run for
/// an hour, and holding the panel on for all of it after the phone was put
/// down was the app's largest battery cost. Once released, the OS screen
/// timeout applies again; the next input re-arms the hold.
class ScreenAwakeService {
  factory ScreenAwakeService() => _instance;
  ScreenAwakeService._();

  static final ScreenAwakeService _instance = ScreenAwakeService._();
  static const MethodChannel _channel = MethodChannel(
    'com.example.happy_flutter/screen_awake',
  );

  /// How long after the last user input the hold survives.
  static const Duration idleRelease = Duration(minutes: 5);

  bool _wanted = false;
  bool _enabled = false;
  bool _inputAttached = false;
  int _lastInputMs = 0;
  Timer? _idleTimer;

  @visibleForTesting
  int Function() debugNowMs = () => DateTime.now().millisecondsSinceEpoch;

  @visibleForTesting
  bool? debugSupportsOverride;

  /// Whether the native keep-awake flag is currently set.
  @visibleForTesting
  bool get debugNativeEnabled => _enabled;

  bool get _supportsScreenAwake =>
      debugSupportsOverride ?? (!kIsWeb && (isAndroid || isIOS || isLinux));

  Future<void> setEnabled(bool enabled) async {
    if (!_supportsScreenAwake || enabled == _wanted) return;
    _wanted = enabled;
    if (enabled) _attachInput();
    await _sync();
  }

  /// Records user input. Wired to the global pointer route and keyboard.
  @visibleForTesting
  void recordUserInput() {
    _lastInputMs = debugNowMs();
    // Pointer moves arrive at display rate, so only a released hold re-syncs
    // here. A held one re-arms from the new timestamp when its timer fires.
    if (_wanted && !_enabled) unawaited(_sync());
  }

  void _attachInput() {
    if (_inputAttached) return;
    _inputAttached = true;
    // The first request usually follows the tap that sent a message or
    // opened the chat, before this route existed to see it.
    _lastInputMs = debugNowMs();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  void _onPointer(PointerEvent _) => recordUserInput();

  bool _onKey(KeyEvent _) {
    recordUserInput();
    return false;
  }

  Future<void> _sync() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final idleMs = debugNowMs() - _lastInputMs;
    final remainingMs = idleRelease.inMilliseconds - idleMs;
    final effective = _wanted && remainingMs > 0;
    if (effective) {
      _idleTimer = Timer(
        Duration(milliseconds: remainingMs),
        () => unawaited(_sync()),
      );
    }
    await _applyNative(effective);
  }

  Future<void> _applyNative(bool enabled) async {
    if (enabled == _enabled) return;
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

  @visibleForTesting
  void debugReset() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _wanted = false;
    _enabled = false;
    _lastInputMs = 0;
    if (_inputAttached) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
      HardwareKeyboard.instance.removeHandler(_onKey);
      _inputAttached = false;
    }
    debugSupportsOverride = null;
    debugNowMs = () => DateTime.now().millisecondsSinceEpoch;
  }
}
