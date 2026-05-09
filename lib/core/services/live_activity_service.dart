import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../../platform_io.dart'
    if (dart.library.js_interop) '../../platform_stub.dart';
import 'logger_service.dart';

/// Feature flag for the iOS Live Activity / Dynamic Island slot.
///
/// Live Activities require a Swift WidgetExtension target wired up in
/// the host iOS project (see `ios/HappyLiveActivity/`). Until that
/// target is added we keep the Dart side stubbed behind this flag so
/// the Android ongoing notification (which is fully implemented) is
/// the only thing actually shipping.
///
/// Flip to `true` once the Swift target lands.
const bool kEnableIosLiveActivities = false;

/// Method channel name shared with the iOS host.
const String _kChannelName = 'happy/live_activities';

/// Service that drives an iOS Live Activity / Dynamic Island slot
/// reflecting one currently-running session. The Live Activity itself
/// is implemented in Swift (ActivityKit + WidgetExtension) — this
/// class only sends `start`/`update`/`end` messages over a method
/// channel.
///
/// All entry points are no-ops when [kEnableIosLiveActivities] is
/// `false` or when not running on iOS, so callers can use this from
/// shared code without platform branching.
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const MethodChannel _channel = MethodChannel(_kChannelName);

  String? _activeSessionId;

  bool get _enabled =>
      kEnableIosLiveActivities && !kIsWeb && isIOS;

  /// Whether a Live Activity is currently believed to be running.
  bool get isActive => _activeSessionId != null;

  /// Whether the iOS Live Activity feature has been enabled at compile
  /// time. Useful for tests / dev tools.
  bool get featureEnabled => kEnableIosLiveActivities;

  /// Start (or replace) the Live Activity with [sessionId] / [toolName].
  // TODO(denysvitali): wire to Swift Live Activity target.
  Future<void> start({
    required String sessionId,
    required String toolName,
    required DateTime startedAt,
    String? sessionName,
  }) async {
    if (!_enabled) return;
    try {
      await _channel.invokeMethod<void>('start', <String, Object?>{
        'sessionId': sessionId,
        'toolName': toolName,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'sessionName': sessionName,
      });
      _activeSessionId = sessionId;
    } on MissingPluginException {
      // iOS host hasn't registered the channel yet (Swift target not
      // wired up in this build) — silently no-op.
    } catch (e) {
      logger.warning('LiveActivityService.start failed: $e');
    }
  }

  /// Update the Live Activity content. Safe to call frequently — the
  /// Swift side coalesces.
  Future<void> update({
    required String sessionId,
    required String toolName,
    required Duration elapsed,
    int? progressPercent,
  }) async {
    if (!_enabled) return;
    if (_activeSessionId != sessionId) return;
    try {
      await _channel.invokeMethod<void>('update', <String, Object?>{
        'sessionId': sessionId,
        'toolName': toolName,
        'elapsedMs': elapsed.inMilliseconds,
        'progressPercent': progressPercent,
      });
    } on MissingPluginException {
      // ignore — see [start]
    } catch (e) {
      logger.warning('LiveActivityService.update failed: $e');
    }
  }

  /// End the Live Activity for [sessionId]. No-op if [sessionId] is
  /// not the currently-active activity.
  Future<void> end(String sessionId) async {
    if (!_enabled) return;
    if (_activeSessionId != sessionId) return;
    try {
      await _channel.invokeMethod<void>('end', <String, Object?>{
        'sessionId': sessionId,
      });
    } on MissingPluginException {
      // ignore — see [start]
    } catch (e) {
      logger.warning('LiveActivityService.end failed: $e');
    } finally {
      _activeSessionId = null;
    }
  }

  /// Visible for tests — clears the active session bookkeeping.
  void debugReset() {
    _activeSessionId = null;
  }
}
