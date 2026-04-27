import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../services/logger_service.dart' show logger;
import '../services/performance_context_service.dart';
import '../services/power_diagnostics_service.dart';

/// Returns true for transient network errors (DNS failure,
/// connection timeout, TLS handshake interruption, etc.) that are
/// expected during brief connectivity loss on mobile.
bool _isTransientSocketError(String error) {
  final lower = error.toLowerCase();
  return error.contains('ERR_NAME_NOT_RESOLVED') ||
      error.contains('ERR_CONNECTION_TIMED_OUT') ||
      error.contains('ERR_CONNECTION_ABORTED') ||
      error.contains('ERR_CONNECTION_RESET') ||
      error.contains('ERR_NETWORK_CHANGED') ||
      error.contains('ERR_INTERNET_DISCONNECTED') ||
      error.contains('ERR_ADDRESS_UNREACHABLE') ||
      error.contains('Failed host lookup') ||
      error.contains('No address associated') ||
      error.contains('Connection closed') ||
      error.contains('Software caused connection abort') ||
      error.contains('xhr poll error') ||
      // TLS handshake interrupted by network drop or server restart —
      // these are transient and resolve on the next reconnect attempt.
      lower.contains('handshakeexception') ||
      lower.contains('connection terminated during handshake') ||
      lower.contains('bad certificate') ||
      lower.contains('not upgraded to websocket') ||
      lower.contains('http status code: 503') ||
      // Socket.IO internal timeout (ACK timeout or ping timeout)
      lower.contains('timeout') ||
      lower.contains('socket.io error: timeout');
}

/// Represents a decoded Socket.io message
class SocketMessage {
  SocketMessage({required this.event, required this.data});
  final String event;
  final dynamic data;
}

/// Exception thrown when [SocketIoClient.emitWithAck] cannot deliver the
/// event because the socket is not connected (connection timeout or
/// explicitly disconnected).
class SocketNotConnectedException implements Exception {
  const SocketNotConnectedException(this.event);
  final String event;

  @override
  String toString() =>
      'SocketNotConnectedException: socket not connected, cannot emit '
      'event "$event"';
}

/// Exception thrown when [SocketIoClient.emitWithAck] times out waiting
/// for an ACK from the server.
class SocketAckTimeoutException implements Exception {
  const SocketAckTimeoutException(this.event);
  final String event;

  @override
  String toString() =>
      'SocketAckTimeoutException: ACK timeout for event "$event"';
}

/// WebSocket connection state
enum ConnectionStatus { disconnected, connecting, connected, error }

/// Socket.io compatible WebSocket client
/// Matches React Native's apiSocket.ts behavior
class SocketIoClient {
  factory SocketIoClient() => _instance;
  SocketIoClient._();
  static final SocketIoClient _instance = SocketIoClient._();

  sio.Socket? _socket;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _serverUrl;
  String? _authToken;
  String? _clientType;
  bool _hasConnectedOnce = false;
  int? _lastConnectStartedAtMs;
  int? _lastDisconnectAtMs;

  // Listeners notified when Socket.IO exhausts all reconnection attempts.
  final _reconnectFailedListeners = <void Function()>[];

  // Rate-limit Sentry captures for non-transient socket errors.
  // A reconnection storm can fire dozens of identical errors within
  // seconds; we capture at most one per 60-second window to avoid
  // flooding the error tracker.
  DateTime? _lastSentryErrorCapturedAt;
  static const _sentryCaptureWindow = Duration(seconds: 60);

  bool _shouldCaptureSentryForSocketError() {
    final now = DateTime.now();
    final last = _lastSentryErrorCapturedAt;
    if (last == null || now.difference(last) >= _sentryCaptureWindow) {
      _lastSentryErrorCapturedAt = now;
      return true;
    }
    return false;
  }

  // Error flood throttle — track last-logged error text + timestamp so
  // that a burst of identical errors (e.g. 100+ "timeout" events fired
  // within 5 ms by the Socket.IO ping-timeout machinery) collapses to a
  // single log + Sentry event instead of flooding the ring buffer and
  // Sentry's event quota.
  String? _lastErrorStr;
  int? _lastErrorAtMs;
  int _suppressedErrorCount = 0;
  static const int _errorThrottleWindowMs = 5000;

  // Stream controllers for events
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  // Event handlers - supports multiple handlers per event
  final Map<String, List<void Function(dynamic)>> _messageHandlers = {};

  // Connection listeners
  final _reconnectedListeners = <void Function()>[];
  final _statusListeners = <void Function(ConnectionStatus)>[];

  /// Get connection status stream
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Current connection status
  ConnectionStatus get connectionStatus => _status;

  /// Initialize and connect using the official Socket.IO protocol
  void connect({
    required String serverUrl,
    required String token,
    String clientType = 'user-scoped',
  }) {
    if (_socket != null) {
      logger.info(
        'Socket.IO connect() skipped — socket already exists '
        '(status=$_status)',
      );
      return;
    }

    logger.info('Socket.IO connecting to $serverUrl');
    _serverUrl = serverUrl;
    _authToken = token;
    _clientType = clientType;
    _lastConnectStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _updateStatus(ConnectionStatus.connecting);

    _socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setPath('/v1/updates')
          .setAuth({'token': token, 'clientType': clientType})
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionDelay(2000) // 2s initial for better battery
          .setReconnectionDelayMax(10000) // 10s max — 30s is too slow on mobile
          // Cap internal reconnection attempts so a persistent server-side
          // TLS failure (e.g. cert renewal, rolling restart) does not produce
          // an unbounded storm of retries.  SocketIoClient.reconnect() resets
          // the Manager and will restart the counter when called externally
          // (e.g. on app resume).
          .setReconnectionAttempts(10)
          .enableForceNew() // bypass global Manager cache on reconnect
          .setTransportOptions({
            'websocket': {
              'perMessageDeflate': {'threshold': 1024},
            },
          })
          .disableAutoConnect()
          .build(),
    );

    _setupEventHandlers();
    _socket!.connect();
  }

  void _setupEventHandlers() {
    _socket!.onConnect((_) async {
      logger.info('Socket.IO connected');
      powerDiagnostics.recordSocketStatus(ConnectionStatus.connected);
      _resetErrorThrottle();
      _updateStatus(ConnectionStatus.connected);

      // Track connection as a transaction for performance monitoring
      final transaction =
          Sentry.startTransaction(
              _hasConnectedOnce ? 'websocket.reconnect' : 'websocket.connect',
              'connection',
              bindToScope: false,
            )
            ..setData('recovered', _socket?.recovered ?? false)
            ..setData(
              'connectDurationMs',
              _elapsedSince(_lastConnectStartedAtMs),
            )
            ..setData(
              'disconnectGapMs',
              _lastConnectStartedAtMs != null && _lastDisconnectAtMs != null
                  ? _lastConnectStartedAtMs! - _lastDisconnectAtMs!
                  : null,
            )
            ..setData(
              'currentRoute',
              PerformanceContextService().currentRoute ?? 'unknown',
            );
      await transaction.finish();

      // Always notify reconnection handlers when this is not the first
      // connection — even when Socket.IO reports successful state recovery
      // (recovered=true).  The recovered flag only guarantees that Socket.IO
      // replayed missed transport-level events, but server-side state (room
      // memberships, auth context) may have changed during the disconnect gap.
      // Skipping _notifyReconnected on recovery caused persistent stale-data
      // bugs where sessions couldn't be created and messages weren't delivered
      // until app restart.
      if (_hasConnectedOnce) {
        _notifyReconnected();
      }
      _hasConnectedOnce = true;
    });

    _socket!.onDisconnect((_) async {
      logger.info('Socket.IO disconnected');
      powerDiagnostics.recordSocketStatus(ConnectionStatus.disconnected);
      _lastDisconnectAtMs = DateTime.now().millisecondsSinceEpoch;
      _updateStatus(ConnectionStatus.disconnected);

      // Track disconnection as a transaction
      final transaction =
          Sentry.startTransaction(
            'websocket.disconnect',
            'connection',
            bindToScope: false,
          )..setData(
            'currentRoute',
            PerformanceContextService().currentRoute ?? 'unknown',
          );
      await transaction.finish();
    });

    _socket!.onConnectError((error) async {
      _updateStatus(ConnectionStatus.error);

      final errorStr = error.toString();
      final isTransient = _isTransientSocketError(errorStr);

      // Check transient BEFORE throttle so transient errors are logged at
      // info level and do NOT consume throttle budget — this prevents a
      // burst of timeout errors from silencing subsequent real errors.
      if (isTransient) {
        // Throttle transient errors too so a burst doesn't spam the log.
        if (_shouldThrottleError(errorStr)) return;
        powerDiagnostics.recordSocketError(errorStr);
        logger.info('Socket.IO transient connect error: $error');
        return;
      }

      if (_shouldThrottleError(errorStr)) return;

      powerDiagnostics.recordSocketError(errorStr);
      logger.warning('Socket.IO connect error: $error');

      final transaction =
          Sentry.startTransaction(
              'websocket.connect_error',
              'connection',
              bindToScope: false,
            )
            ..setData('error', errorStr)
            ..setData(
              'connectDurationMs',
              _elapsedSince(_lastConnectStartedAtMs),
            )
            ..setData(
              'currentRoute',
              PerformanceContextService().currentRoute ?? 'unknown',
            );
      await transaction.finish(status: const SpanStatus.internalError());

      if (_shouldCaptureSentryForSocketError()) {
        unawaited(
          Sentry.captureException(
            Exception('Socket.IO connect error: $error'),
            stackTrace: StackTrace.current,
          ),
        );
      }
    });

    _socket!.onError((error) async {
      _updateStatus(ConnectionStatus.error);

      final errorStr = error.toString();
      final isTransient = _isTransientSocketError(errorStr);

      // Check transient BEFORE throttle so transient errors are logged at
      // info level and do NOT consume throttle budget — this prevents a
      // burst of timeout errors from silencing subsequent real errors.
      if (isTransient) {
        // Throttle transient errors too so a burst doesn't spam the log.
        if (_shouldThrottleError(errorStr)) return;
        powerDiagnostics.recordSocketError(errorStr);
        logger.info('Socket.IO transient error: $error');
        return;
      }

      if (_shouldThrottleError(errorStr)) return;

      powerDiagnostics.recordSocketError(errorStr);
      logger.warning('Socket.IO error: $error');

      final transaction =
          Sentry.startTransaction(
              'websocket.error',
              'connection',
              bindToScope: false,
            )
            ..setData('error', errorStr)
            ..setData(
              'connectDurationMs',
              _elapsedSince(_lastConnectStartedAtMs),
            )
            ..setData(
              'currentRoute',
              PerformanceContextService().currentRoute ?? 'unknown',
            );
      await transaction.finish(status: const SpanStatus.internalError());

      if (_shouldCaptureSentryForSocketError()) {
        unawaited(
          Sentry.captureException(
            Exception('Socket.IO error: $error'),
            stackTrace: StackTrace.current,
          ),
        );
      }
    });

    _socket!.onReconnectFailed((_) {
      powerDiagnostics.recordSocketError('reconnect_failed');
      logger.warning('Socket.IO reconnection attempts exhausted');
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Socket.IO reconnect_failed — attempts exhausted',
            category: 'websocket',
            level: SentryLevel.warning,
          ),
        ),
      );
      _updateStatus(ConnectionStatus.disconnected);
      for (final listener in _reconnectFailedListeners) {
        listener();
      }
    });

    _socket!.onAny((event, data) {
      String? updateType;
      if (data is Map<String, dynamic>) {
        updateType = data['t'] as String?;
      }
      powerDiagnostics.recordSocketEvent(event, updateType: updateType);

      // Only record non-streaming events as Sentry breadcrumbs.
      // During AI streaming, 'update' events with new-message arrive
      // at 10-50/sec — recording each one floods Sentry's ring buffer
      // with useless breadcrumbs and adds allocation pressure.
      final isStreamingUpdate =
          event == 'update' &&
          data is Map<String, dynamic> &&
          data['t'] == 'new-message';
      if (!isStreamingUpdate) {
        final breadcrumbData = <String, dynamic>{'event': event};
        if (data is Map<String, dynamic>) {
          final updateType = data['t'] as String?;
          if (updateType != null) {
            breadcrumbData['type'] = updateType;
          }
          final sid = data['d'] is Map
              ? (data['d'] as Map)['sid'] as String?
              : null;
          if (sid != null) breadcrumbData['sessionId'] = sid;
        }
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'ws event: $event',
            category: 'websocket',
            level: SentryLevel.info,
            data: breadcrumbData,
          ),
        );
      }

      final handlers = _messageHandlers[event];
      if (handlers != null) {
        for (final h in handlers) {
          h(data);
        }
      }
    });
  }

  /// Disconnect from Socket.IO.
  ///
  /// By default this is a full teardown and resets connection history so the
  /// next connect is treated as a first connection. Lifecycle suspends can
  /// preserve the history so the next foreground connect still runs
  /// reconnection recovery.
  void disconnect({bool preserveConnectionHistory = false}) {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    if (!preserveConnectionHistory) {
      _hasConnectedOnce = false;
    }
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Reconnect using previously stored credentials.
  ///
  /// No-op if [connect] was never called (no credentials stored).
  ///
  /// Preserves [_hasConnectedOnce] so the [onConnect] handler fires
  /// [_notifyReconnected] instead of treating the reconnection as a
  /// first-ever connection.  Without this, [disconnect] resets the
  /// flag and the Sync reconnected handler never fires on app resume.
  void reconnect() {
    final url = _serverUrl;
    final token = _authToken;
    final clientType = _clientType;
    if (url == null || token == null || clientType == null) return;
    final hadConnectedOnce = _hasConnectedOnce;
    disconnect(preserveConnectionHistory: true);
    connect(serverUrl: url, token: token, clientType: clientType);
    _hasConnectedOnce = hadConnectedOnce;
  }

  /// Emit event through Socket.IO
  void send(String event, dynamic data) {
    if (_socket == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket not connected');
    }
    powerDiagnostics.recordSocketSend(event);
    _socket!.emit(event, data);
  }

  /// Waits for the socket to reach [ConnectionStatus.connected].
  /// Returns immediately if already connected. Returns normally
  /// (with false) if socket is null or [timeout] elapses.
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_socket != null && _status == ConnectionStatus.connected) return true;
    if (_socket == null) {
      return false;
    }
    // Socket exists but isn't connected yet (e.g. reconnecting after
    // app resume). Wait for it rather than failing immediately.
    try {
      await statusStream
          .firstWhere((s) => s == ConnectionStatus.connected)
          .timeout(timeout);
      return true;
    } on TimeoutException {
      logger.info('Socket.IO connection wait timeout');
      return false;
    }
  }

  /// Emit event and wait for acknowledgement
  Future<dynamic> emitWithAck(
    String event,
    dynamic data, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final connected = await waitForConnection();
    if (!connected) {
      // Throw a typed exception instead of returning null — null propagates
      // silently and produces confusing "RPC failed: null" errors that are
      // hard to distinguish from other failures.
      throw SocketNotConnectedException(event);
    }
    powerDiagnostics.recordSocketSend(event, ack: true);
    final completer = Completer<dynamic>();
    _socket!.emitWithAck(
      event,
      data,
      ack: (response) {
        if (!completer.isCompleted) completer.complete(response);
      },
    );
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      // Treat ACK timeout as transient — Socket.IO will retry or reconnect.
      throw SocketAckTimeoutException(event);
    }
  }

  /// Register reconnection listener
  void Function() onReconnected(void Function() listener) {
    _reconnectedListeners.add(listener);
    return () => _reconnectedListeners.remove(listener);
  }

  /// Register a listener for when Socket.IO exhausts all reconnection
  /// attempts.  The caller can use this to schedule a fresh [reconnect]
  /// after a delay.
  void Function() onReconnectExhausted(void Function() listener) {
    _reconnectFailedListeners.add(listener);
    return () => _reconnectFailedListeners.remove(listener);
  }

  /// Register status change listener
  void Function() onStatusChange(void Function(ConnectionStatus) listener) {
    _statusListeners.add(listener);
    // Immediately notify with current status
    listener(_status);
    return () => _statusListeners.remove(listener);
  }

  /// Register message handler for a specific event. Multiple handlers per
  /// event are supported. Returns an unsubscribe callback that removes only
  /// the registered handler (not all handlers for the event).
  void Function() onMessage(String event, void Function(dynamic) handler) {
    _messageHandlers.putIfAbsent(event, () => []).add(handler);
    return () {
      final list = _messageHandlers[event];
      if (list != null) {
        list.remove(handler);
        if (list.isEmpty) _messageHandlers.remove(event);
      }
    };
  }

  /// Unregister all handlers for an event.
  void offMessage(String event) {
    _messageHandlers.remove(event);
  }

  /// Update the auth token for the current connection.
  ///
  /// If connected, disconnects and reconnects with the new token
  /// to ensure the server accepts the updated credentials.
  void updateToken(String token) {
    if (_authToken == token) return;
    _authToken = token;
    if (_socket != null && _serverUrl != null) {
      // Update auth on existing socket for next reconnect
      _socket!.auth = {
        'token': token,
        'clientType': _clientType ?? 'user-scoped',
      };
    }
  }

  /// Update server URL and reconnect if already connected.
  void refreshServerUrl(String newUrl) {
    if (_serverUrl != newUrl) {
      _serverUrl = newUrl;

      if (_socket != null && _authToken != null) {
        disconnect();
        connect(
          serverUrl: newUrl,
          token: _authToken!,
          clientType: _clientType ?? 'user-scoped',
        );
      }
    }
  }

  void _updateStatus(ConnectionStatus status) {
    if (_status != status) {
      _status = status;
      _statusController.add(status);
      for (final listener in _statusListeners) {
        listener(status);
      }
    }
  }

  void _notifyReconnected() {
    for (final listener in _reconnectedListeners) {
      listener();
    }
  }

  @visibleForTesting
  bool get testHasConnectedOnce => _hasConnectedOnce;

  @visibleForTesting
  set testHasConnectedOnce(bool value) => _hasConnectedOnce = value;

  /// Dispose resources
  void dispose() {
    disconnect();
    _statusController.close();
    _messageHandlers.clear();
    _reconnectedListeners.clear();
    _reconnectFailedListeners.clear();
    _statusListeners.clear();
  }

  /// Returns true when the error should be suppressed to prevent a flood of
  /// identical entries.  The first occurrence of each distinct error string
  /// is always logged; subsequent identical errors within
  /// [_errorThrottleWindowMs] are counted and silently dropped.  When the
  /// window expires the suppression count is emitted as a single summary
  /// line so no information is permanently lost.
  bool _shouldThrottleError(String errorStr) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastErrorStr == errorStr &&
        _lastErrorAtMs != null &&
        nowMs - _lastErrorAtMs! < _errorThrottleWindowMs) {
      _suppressedErrorCount++;
      return true;
    }
    // Window expired or different error — flush suppression summary first.
    if (_suppressedErrorCount > 0) {
      logger.info(
        'Socket.IO error suppressed $_suppressedErrorCount× '
        'within ${_errorThrottleWindowMs}ms: $_lastErrorStr',
      );
      _suppressedErrorCount = 0;
    }
    _lastErrorStr = errorStr;
    _lastErrorAtMs = nowMs;
    return false;
  }

  /// Reset error-throttle state (called on clean connect so the first error
  /// after a successful reconnection is always logged).
  void _resetErrorThrottle() {
    if (_suppressedErrorCount > 0) {
      logger.info(
        'Socket.IO error suppressed $_suppressedErrorCount× '
        'within ${_errorThrottleWindowMs}ms: $_lastErrorStr',
      );
    }
    _lastErrorStr = null;
    _lastErrorAtMs = null;
    _suppressedErrorCount = 0;
  }

  static int? _elapsedSince(int? startedAtMs) {
    if (startedAtMs == null) return null;
    return DateTime.now().millisecondsSinceEpoch - startedAtMs;
  }
}

/// Singleton instance - exported for compatibility
final socketIoClient = SocketIoClient();
