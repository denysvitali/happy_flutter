import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show visibleForTesting, setEquals;

import '../api/socket_io_client.dart';
import '../api/api_client.dart';
import 'logger_service.dart';
import 'power_diagnostics_otel_reporter.dart';
import 'sync_service.dart';

/// Monitors native network connectivity and triggers immediate
/// socket reconnection when the network returns.
///
/// Unlike Socket.IO's built-in reconnection (2s–30s timer), this
/// service detects WiFi/cellular state changes via platform
/// channels, enabling sub-second recovery after a connection drop.
class NetworkMonitorService {
  factory NetworkMonitorService() => _instance;

  NetworkMonitorService._({
    Connectivity? connectivity,
    void Function()? onReconnect,
  }) : _connectivity = connectivity ?? Connectivity(),
       _onReconnect = onReconnect;

  static NetworkMonitorService _instance = NetworkMonitorService._();

  final Connectivity _connectivity;
  final void Function()? _onReconnect;
  Set<ConnectivityResult>? _links;
  int _snapshotGeneration = 0;
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

  /// Initialize the service — starts listening for connectivity
  /// changes immediately and kicks off an initial state check in
  /// the background. Returns as soon as the subscription is wired
  /// so callers (e.g. `app.deferredInit`) don't pay the cold-start
  /// cost of a synchronous platform-channel round-trip before
  /// the first frame paints.
  ///
  /// The [connectivity_plus] stream emits the current state on
  /// first subscribe, so an explicit initial check is usually
  /// redundant; we still issue one in the background to cover
  /// platforms that don't emit a snapshot synchronously. Sync
  /// tolerates the brief "online" default while the check is
  /// in flight — it detects real offline state on the first
  /// HTTP attempt and triggers reconnection when the check
  /// later disagrees.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!_isSuspended) {
      _startListening();
    }
    // Background refresh — does not block the caller. Any
    // disagreement with the default-online state is published
    // via onConnectivityChanged and consumed by Sync.
    unawaited(_refreshConnectivity());
  }

  Future<void> _refreshConnectivity({bool notify = false}) async {
    final generation = _snapshotGeneration;
    try {
      final results = await _connectivity.checkConnectivity();
      if (generation != _snapshotGeneration) return;
      _links = results.toSet();
      _setOnline(_hasConnectivity(results), notify: notify);
    } catch (e) {
      if (generation != _snapshotGeneration) return;
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
    _snapshotGeneration++;
    final links = results.toSet();
    final changedLinks = _links != null && !setEquals(_links, links);
    _links = links;
    final online = _hasConnectivity(results);
    final changedOnline = _setOnline(online, notify: true);
    if (!changedOnline && !changedLinks) return;

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
    if (_onReconnect != null) {
      _onReconnect();
      return;
    }
    ApiClient().renewTransport();

    final s = Sync();
    if (s.isInitialized) {
      socketIoClient.reconnect(reason: DialReason.networkRestored);
      s.resume();
      return;
    }

    final socket = socketIoClient;
    if (socket.connectionStatus != ConnectionStatus.connected) {
      socket.reconnect(reason: DialReason.networkRestored);
    }
  }

  /// Pause reconnection triggers while the app is backgrounded.
  void suspend() {
    _snapshotGeneration++;
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
    _snapshotGeneration++;
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
  static NetworkMonitorService testCreate({
    Connectivity? connectivity,
    void Function()? onReconnect,
  }) {
    return NetworkMonitorService._(
      connectivity: connectivity,
      onReconnect: onReconnect,
    );
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
    PowerDiagnosticsOtelReporter.instance.recordNetworkLinkChange(
      online: online,
    );
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
