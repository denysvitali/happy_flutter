import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../services/logger_service.dart' show logger;

/// Returns true for transient network errors (DNS failure,
/// connection timeout, etc.) that are expected during brief
/// connectivity loss on mobile.
bool _isTransientSocketError(String error) {
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
      error.contains('xhr poll error');
}

/// Represents a decoded Socket.io message
class SocketMessage {

  SocketMessage({required this.event, required this.data});
  final String event;
  final dynamic data;
}

/// WebSocket connection state
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

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
    _updateStatus(ConnectionStatus.connecting);

    _socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setPath('/v1/updates')
          .setAuth({'token': token, 'clientType': clientType})
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionDelay(2000) // 2s initial for better battery
          .setReconnectionDelayMax(30000) // 30s max for unstable networks
          .setTransportOptions({
            'websocket': {
              'perMessageDeflate': {
                'threshold': 1024,
              },
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
      _updateStatus(ConnectionStatus.connected);

      // Track connection as a transaction for performance monitoring
      final transaction = Sentry.startTransaction(
        _hasConnectedOnce ? 'websocket.reconnect' : 'websocket.connect',
        'connection',
        bindToScope: false,
      )..setData('recovered', _socket?.recovered ?? false);
      await transaction.finish();

      if (_hasConnectedOnce && !(_socket?.recovered ?? false)) {
        _notifyReconnected();
      }
      _hasConnectedOnce = true;
    });

    _socket!.onDisconnect((_) async {
      logger.info('Socket.IO disconnected');
      _updateStatus(ConnectionStatus.disconnected);

      // Track disconnection as a transaction
      final transaction = Sentry.startTransaction(
        'websocket.disconnect',
        'connection',
        bindToScope: false,
      );
      await transaction.finish();
    });

    _socket!.onConnectError((error) async {
      _updateStatus(ConnectionStatus.error);

      final errorStr = error.toString();
      final isTransient = _isTransientSocketError(errorStr);

      // Downgrade transient network errors to info to avoid
      // Sentry noise when the device briefly loses connectivity.
      if (isTransient) {
        logger.info('Socket.IO transient connect error: $error');
      } else {
        logger.warning('Socket.IO connect error: $error');
      }

      final transaction = Sentry.startTransaction(
        'websocket.connect_error',
        'connection',
        bindToScope: false,
      )..setData('error', errorStr);
      await transaction.finish(
        status: const SpanStatus.internalError(),
      );

      if (!isTransient) {
        unawaited(Sentry.captureException(
          Exception('Socket.IO connect error: $error'),
          stackTrace: StackTrace.current,
        ));
      }
    });

    _socket!.onError((error) async {
      _updateStatus(ConnectionStatus.error);

      final errorStr = error.toString();
      final isTransient = _isTransientSocketError(errorStr);

      if (isTransient) {
        logger.info('Socket.IO transient error: $error');
      } else {
        logger.warning('Socket.IO error: $error');
      }

      final transaction = Sentry.startTransaction(
        'websocket.error',
        'connection',
        bindToScope: false,
      )..setData('error', errorStr);
      await transaction.finish(
        status: const SpanStatus.internalError(),
      );

      if (!isTransient) {
        unawaited(Sentry.captureException(
          Exception('Socket.IO error: $error'),
          stackTrace: StackTrace.current,
        ));
      }
    });

    _socket!.onAny((event, data) {
      // Only record non-streaming events as Sentry breadcrumbs.
      // During AI streaming, 'update' events with new-message arrive
      // at 10-50/sec — recording each one floods Sentry's ring buffer
      // with useless breadcrumbs and adds allocation pressure.
      final isStreamingUpdate = event == 'update' &&
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
        Sentry.addBreadcrumb(Breadcrumb(
          message: 'ws event: $event',
          category: 'websocket',
          level: SentryLevel.info,
          data: breadcrumbData,
        ));
      }

      final handlers = _messageHandlers[event];
      if (handlers != null) {
        for (final h in handlers) {
          h(data);
        }
      }
    });
  }

  /// Disconnect from Socket.IO
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _hasConnectedOnce = false;
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Reconnect using previously stored credentials.
  ///
  /// No-op if [connect] was never called (no credentials stored).
  void reconnect() {
    final url = _serverUrl;
    final token = _authToken;
    final clientType = _clientType;
    if (url == null || token == null || clientType == null) return;
    disconnect();
    connect(serverUrl: url, token: token, clientType: clientType);
  }

  /// Emit event through Socket.IO
  void send(String event, dynamic data) {
    if (_socket == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket not connected');
    }
    _socket!.emit(event, data);
  }

  /// Emit event and wait for acknowledgement
  Future<dynamic> emitWithAck(
    String event,
    dynamic data, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_socket == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket not connected');
    }
    final completer = Completer<dynamic>();
    _socket!.emitWithAck(event, data, ack: (response) {
      if (!completer.isCompleted) completer.complete(response);
    });
    return completer.future.timeout(timeout);
  }

  /// Register reconnection listener
  void Function() onReconnected(void Function() listener) {
    _reconnectedListeners.add(listener);
    return () => _reconnectedListeners.remove(listener);
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

  /// Dispose resources
  void dispose() {
    disconnect();
    _statusController.close();
    _messageHandlers.clear();
  }
}

/// Singleton instance - exported for compatibility
final socketIoClient = SocketIoClient();
