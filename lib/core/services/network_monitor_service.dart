import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../api/socket_io_client.dart';
import 'logger_service.dart';
import 'sync_service.dart';

/// Monitors native network connectivity and triggers immediate
/// socket reconnection when the network returns.
///
/// Unlike Socket.IO's built-in reconnection (2s–30s timer), this
/// service detects WiFi/cellular state changes via platform
/// channels, enabling sub-second recovery after a connection drop.
class NetworkMonitorService {
  factory NetworkMonitorService() => _instance;

  NetworkMonitorService._({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  static NetworkMonitorService _instance = NetworkMonitorService._();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _controller = StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool _isSuspended = false;
  bool _initialized = false;

  /// Whether the device currently has network connectivity.
  bool get isOnline => _isOnline;

  /// Stream that emits `true`/`false` only when the
  /// connectivity state actually changes.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Initialize the service — checks current state and starts
  /// listening for changes.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _refreshConnectivity();
    if (!_isSuspended) {
      _startListening();
    }
  }

  Future<void> _refreshConnectivity({bool notify = false}) async {
    try {
      final results = await _connectivity.checkConnectivity();
      _setOnline(_hasConnectivity(results), notify: notify);
    } catch (e) {
      // Assume online if the check fails (e.g. on desktop
      // where the plugin may not be fully supported).
      logger.warning('[Network] initial connectivity check failed: $e');
      _setOnline(true, notify: notify);
    }
  }

  void _startListening() {
    if (_subscription != null) return;
    _subscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = _hasConnectivity(results);
    if (!_setOnline(online, notify: true)) return;

    if (online) {
      logger.info('[Network] connectivity restored');
      _triggerReconnect();
    } else {
      logger.info('[Network] connectivity lost');
    }
  }

  /// Trigger immediate socket reconnection + sync refresh.
  ///
  /// Skipped when the app is suspended (backgrounded) to avoid
  /// waking up network I/O while the user isn't looking.
  void _triggerReconnect() {
    if (_isSuspended) return;

    final s = Sync();
    if (s.isInitialized) {
      s.resume();
      return;
    }

    final socket = socketIoClient;
    if (socket.connectionStatus != ConnectionStatus.connected) {
      socket.reconnect();
    }
  }

  /// Pause reconnection triggers while the app is backgrounded.
  void suspend() {
    _isSuspended = true;
    _subscription?.cancel();
    _subscription = null;
  }

  /// Resume reconnection triggers. If the network came back
  /// while suspended, the normal [Sync.resume] flow (called by
  /// the lifecycle observer) handles the catch-up.
  void resume() {
    _isSuspended = false;
    if (_initialized) {
      unawaited(_refreshConnectivity(notify: true));
      _startListening();
    }
  }

  /// Dispose resources.
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller.close();
    _initialized = false;
  }

  /// Replace the singleton for testing. Returns the previous
  /// instance so callers can restore it in tearDown.
  @visibleForTesting
  static NetworkMonitorService testReplaceInstance(
    NetworkMonitorService replacement,
  ) {
    final previous = _instance;
    _instance = replacement;
    return previous;
  }

  /// Create a test instance with a custom [Connectivity].
  @visibleForTesting
  static NetworkMonitorService testCreate({Connectivity? connectivity}) {
    return NetworkMonitorService._(connectivity: connectivity);
  }

  /// Override the online state for testing.
  @visibleForTesting
  void testSetOnline(bool online) {
    _setOnline(online, notify: true);
  }

  @visibleForTesting
  bool get testHasActiveSubscription => _subscription != null;

  bool _setOnline(bool online, {required bool notify}) {
    if (online == _isOnline) return false;
    _isOnline = online;
    if (notify && !_controller.isClosed) {
      _controller.add(online);
    }
    return true;
  }

  static bool _hasConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }
}
