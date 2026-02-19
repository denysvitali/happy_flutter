import 'dart:async';
import 'package:flutter/foundation.dart';
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

  // Stream controllers for events
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _updateController = StreamController<ApiUpdate>.broadcast();
  final _messageController = StreamController<SocketMessage>.broadcast();

  // Event handlers - matches React Native's messageHandlers Map pattern
  final Map<String, void Function(dynamic)> _messageHandlers = {};

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
    if (_socket != null && _status == ConnectionStatus.connected) return;

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
      if (!(_socket?.recovered ?? false)) {
        _notifyReconnected();
      }
    });

    _socket!.onDisconnect((_) {
      _updateStatus(ConnectionStatus.disconnected);
    });

    _socket!.onConnectError((error) {
      if (kDebugMode) print('Socket.IO connect error: $error');
      _updateStatus(ConnectionStatus.error);
    });

    _socket!.onError((error) {
      if (kDebugMode) print('Socket.IO error: $error');
      _updateStatus(ConnectionStatus.error);
    });

    _socket!.onAny((event, data) {
      _messageController.add(
        SocketMessage(event: event, data: data),
      );

      final handler = _messageHandlers[event];
      if (handler != null) handler(data);

      if (event == 'update' && data is Map<String, dynamic>) {
        try {
          _updateController.add(ApiUpdate.fromJson(data));
        } catch (e) {
          if (kDebugMode) print('Failed to parse update: $e');
        }
      }
    });
  }

  /// Disconnect from Socket.IO
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateStatus(ConnectionStatus.disconnected);
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

  /// Register message handler for specific event
  /// Matches React Native's `onMessage` pattern
  void Function() onMessage(String event, void Function(dynamic) handler) {
    _messageHandlers[event] = handler;
    return () => _messageHandlers.remove(event);
  }

  /// Unregister message handler
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
