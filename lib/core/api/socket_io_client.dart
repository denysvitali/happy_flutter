import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../../core/models/api_update.dart';

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
  final _updateController = StreamController<ApiUpdate>.broadcast();
  final _messageController = StreamController<SocketMessage>.broadcast();

  // Event handlers - supports multiple handlers per event
  final Map<String, List<void Function(dynamic)>> _messageHandlers = {};

  // Connection listeners
  final _reconnectedListeners = <void Function()>[];
  final _statusListeners = <void Function(ConnectionStatus)>[];

  /// Get connection status stream
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Get updates stream
  Stream<ApiUpdate> get updateStream => _updateController.stream;

  /// Get raw message stream
  Stream<SocketMessage> get messageStream => _messageController.stream;

  /// Current connection status
  ConnectionStatus get connectionStatus => _status;

  /// Initialize and connect using the official Socket.IO protocol
  void connect({
    required String serverUrl,
    required String token,
    String clientType = 'user-scoped',
  }) {
    if (_socket != null) return;

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
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .disableAutoConnect()
          .build(),
    );

    _setupEventHandlers();
    _socket!.connect();
  }

  void _setupEventHandlers() {
    _socket!.onConnect((_) {
      _updateStatus(ConnectionStatus.connected);
      if (_hasConnectedOnce && !(_socket?.recovered ?? false)) {
        _notifyReconnected();
      }
      _hasConnectedOnce = true;
    });

    _socket!.onDisconnect((_) {
      _updateStatus(ConnectionStatus.disconnected);
    });

    _socket!.onConnectError((error) {
      _updateStatus(ConnectionStatus.error);
      if (kDebugMode) debugPrint('Socket.IO connect error: $error');
      unawaited(Sentry.captureException(
        Exception('Socket.IO connect error: $error'),
        stackTrace: StackTrace.current,
      ));
    });

    _socket!.onError((error) {
      _updateStatus(ConnectionStatus.error);
      if (kDebugMode) debugPrint('Socket.IO error: $error');
      unawaited(Sentry.captureException(
        Exception('Socket.IO error: $error'),
        stackTrace: StackTrace.current,
      ));
    });

    _socket!.onAny((event, data) {
      _messageController.add(
        SocketMessage(event: event, data: data),
      );

      final handlers = _messageHandlers[event];
      if (handlers != null) {
        for (final h in List.of(handlers)) {
        h(data);
      }
      }

      if (event == 'update' && data is Map<String, dynamic>) {
        try {
          _updateController.add(ApiUpdate.fromJson(data));
        } catch (e, s) {
          debugPrint('Failed to parse update: $e');
          unawaited(Sentry.captureException(e, stackTrace: s));
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

  /// Update auth token and reconnect if needed
  void updateToken(String newToken) {
    if (_authToken != newToken) {
      _authToken = newToken;

      if (_socket != null) {
        disconnect();
        connect(
          serverUrl: _serverUrl!,
          token: newToken,
          clientType: _clientType ?? 'user-scoped',
        );
      }
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
    _updateController.close();
    _messageController.close();
    _messageHandlers.clear();
  }
}

/// Singleton instance - exported for compatibility
final socketIoClient = SocketIoClient();
