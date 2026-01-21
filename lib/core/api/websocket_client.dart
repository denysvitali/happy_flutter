import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status_codes;

import '../../core/models/api_update.dart';

/// WebSocket connection state
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

/// WebSocket client for real-time updates
class WebSocketClient {
  static final WebSocketClient _instance = WebSocketClient._();
  factory WebSocketClient() => _instance;
  WebSocketClient._();

  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _serverUrl;
  String? _authToken;

  // Stream controllers for events
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _updateController = StreamController<ApiUpdate>.broadcast();
  final _messageController = StreamController<dynamic>.broadcast();

  // Connection handlers
  final _reconnectedListeners = <void Function()>[];
  final _statusListeners = <void Function(ConnectionStatus)>[];

  /// Get connection status stream
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Get updates stream
  Stream<ApiUpdate> get updateStream => _updateController.stream;

  /// Get raw message stream
  Stream<dynamic> get messageStream => _messageController.stream;

  /// Initialize and connect to WebSocket
  void connect({required String serverUrl, required String token}) {
    if (_channel != null && _status == ConnectionStatus.connected) {
      return;
    }

    _serverUrl = serverUrl;
    _authToken = token;
    _updateStatus(ConnectionStatus.connecting);

    final wsUrl = _buildWebSocketUrl(serverUrl);
    debugPrint('Connecting to WebSocket: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      _channel!.ready.then((_) {
        _updateStatus(ConnectionStatus.connected);
        _notifyReconnected();
      }).catchError((error) {
        debugPrint('WebSocket connection error: $error');
        _updateStatus(ConnectionStatus.error);
      });

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('WebSocket stream error: $error');
          _updateStatus(ConnectionStatus.error);
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          if (_status == ConnectionStatus.connected) {
            _updateStatus(ConnectionStatus.disconnected);
          }
        },
      );
    } catch (e) {
      debugPrint('Failed to create WebSocket connection: $e');
      _updateStatus(ConnectionStatus.error);
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _channel?.sink.close(status_codes.goingAway);
    _channel = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Send message through WebSocket
  void send(String event, dynamic data) {
    if (_channel == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket not connected');
    }
    _channel!.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  /// Send message and wait for response
  Future<dynamic> sendWithAck(String event, dynamic data, {Duration? timeout}) async {
    if (_channel == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket not connected');
    }

    final completer = Completer<dynamic>();
    final subscription = _messageController.stream
        .where((msg) => msg['event'] == '${event}_ack')
        .timeout(timeout ?? const Duration(seconds: 30))
        .listen((msg) {
      completer.complete(msg['data']);
    });

    _channel!.sink.add(jsonEncode({'event': event, 'data': data}));

    try {
      return await completer.future;
    } finally {
      await subscription.cancel();
    }
  }

  /// Register reconnection listener
  void Function() onReconnected(void Function() listener) {
    _reconnectedListeners.add(listener);
    return () => _reconnectedListeners.remove(listener);
  }

  /// Register status change listener
  void Function() onStatusChange(void Function(ConnectionStatus) listener) {
    _statusListeners.add(listener);
    return () => _statusListeners.remove(listener);
  }

  /// Register message handler for specific event
  void Function() onMessage(String event, void Function(dynamic) handler) {
    final subscription = _messageController.stream
        .where((msg) => msg['event'] == event)
        .listen(handler);
    return subscription.cancel;
  }

  String _buildWebSocketUrl(String serverUrl) {
    // Convert http/https to ws/wss
    final wsProtocol = serverUrl.startsWith('https') ? 'wss' : 'ws';
    final baseUrl = serverUrl.replaceFirst(RegExp(r'^https?://'), '$wsProtocol://');
    return '$baseUrl/v1/updates?token=$_authToken';
  }

  void _handleMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String);
      final event = decoded['event'] as String?;
      final data = decoded['data'];

      if (event != null) {
        // Emit to specific event handlers
        _messageController.add({'event': event, 'data': data});

        // Handle update events
        if (event == 'update' && data is Map<String, dynamic>) {
          try {
            final update = ApiUpdate.fromJson(data);
            _updateController.add(update);
          } catch (e) {
            debugPrint('Failed to parse update: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to parse WebSocket message: $e');
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
  }
}
