import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status_codes;

import '../../core/models/api_update.dart';
import '../utils/backoff.dart';

/// Socket.io packet types
/// https://socket.io/docs/v4/engine-io-protocol/
class SocketPacket {
  /// Ping packet - sent by client to check connection
  static const int ping = 2;

  /// Pong packet - sent in response to ping
  static const int pong = 3;

  /// Message packet - used for events
  static const int message = 4;

  /// Encode a Socket.io event packet
  /// Format: `4["event",data]`
  static String encodeEvent(String event, dynamic data) {
    final payload = jsonEncode([event, data]);
    return '$message$payload';
  }

  /// Decode a Socket.io message packet
  /// Returns null if not a valid message packet
  static SocketMessage? decode(String raw) {
    if (raw.isEmpty) {
      return null;
    }

    final packetType = raw.codeUnitAt(0);
    if (packetType != message) {
      return null;
    }

    final payload = raw.substring(1);
    if (payload.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as List;
      if (decoded.length >= 2) {
        return SocketMessage(
          event: decoded[0] as String,
          data: decoded[1],
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to decode Socket.io message: $e');
      }
    }

    return null;
  }
}

/// Represents a decoded Socket.io message
class SocketMessage {
  final String event;
  final dynamic data;

  SocketMessage({required this.event, required this.data});
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
  static final SocketIoClient _instance = SocketIoClient._();
  factory SocketIoClient() => _instance;
  SocketIoClient._();

  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _serverUrl;
  String? _authToken;
  String? _clientType;

  // Exponential backoff for reconnection
  ExponentialBackoff? _backoff;

  // Timer for reconnection attempts
  Timer? _reconnectTimer;

  // Stream controllers for events
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _updateController = StreamController<ApiUpdate>.broadcast();
  final _messageController = StreamController<SocketMessage>.broadcast();

  // Event handlers - matches React Native's messageHandlers Map pattern
  final Map<String, void Function(dynamic)> _messageHandlers = {};

  // Connection listeners
  final _reconnectedListeners = <void Function()>[];
  final _statusListeners = <void Function(ConnectionStatus)>[];

  // Pending acknowledgements
  final Map<String, Completer<dynamic>> _pendingAcks = {};

  /// Get connection status stream
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Get updates stream
  Stream<ApiUpdate> get updateStream => _updateController.stream;

  /// Get raw message stream
  Stream<SocketMessage> get messageStream => _messageController.stream;

  /// Initialize and connect to WebSocket with Socket.io protocol
  void connect({
    required String serverUrl,
    required String token,
    String clientType = 'user-scoped',
  }) {
    if (_channel != null && _status == ConnectionStatus.connected) {
      return;
    }

    _serverUrl = serverUrl;
    _authToken = token;
    _clientType = clientType;
    _updateStatus(ConnectionStatus.connecting);

    // Initialize exponential backoff for reconnection
    _backoff = ExponentialBackoff.websocket(
      minDelayMs: 1000,
      maxDelayMs: 5000,
    );

    _connectWithBackoff();
  }

  void _connectWithBackoff() {
    if (_serverUrl == null || _authToken == null) {
      return;
    }

    final wsUrl = _buildWebSocketUrl(_serverUrl!);
    if (kDebugMode) {
      print('Connecting to WebSocket (Socket.io): $wsUrl');
    }

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
      );

      _channel!.ready.then((_) {
        _updateStatus(ConnectionStatus.connected);
        _resetBackoff();
        _notifyReconnected();
        _startPingTimer();
      }).catchError((error) {
        if (kDebugMode) {
          print('WebSocket connection error: $error');
        }
        _handleConnectionError(error);
      });

      _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          if (kDebugMode) {
            print('WebSocket stream error: $error');
          }
          _updateStatus(ConnectionStatus.error);
        },
        onDone: () {
          if (kDebugMode) {
            print('WebSocket connection closed');
          }
          if (_status == ConnectionStatus.connected) {
            _updateStatus(ConnectionStatus.disconnected);
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create WebSocket connection: $e');
      }
      _handleConnectionError(e);
    }
  }

  void _handleConnectionError(dynamic error) {
    _updateStatus(ConnectionStatus.error);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_backoff == null || !_backoff!.canRetry) {
      if (kDebugMode) {
        print('Max reconnection attempts reached');
      }
      return;
    }

    final delay = _backoff!.next();
    if (kDebugMode) {
      print('Reconnection attempt ${_backoff!.attempts} in ${delay}ms');
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      _connectWithBackoff();
    });
  }

  void _resetBackoff() {
    _backoff?.reset();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Timer? _pingTimer;

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_status == ConnectionStatus.connected) {
        _sendPing();
      }
    });
  }

  void _sendPing() {
    if (_channel != null && _status == ConnectionStatus.connected) {
      _channel!.sink.add('${SocketPacket.ping}');
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channel?.sink.close(status_codes.goingAway);
    _channel = null;
    _resetBackoff();
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Send event through Socket.io protocol
  /// Format: `4["event",data]`
  void send(String event, dynamic data) {
    if (_channel == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket not connected');
    }
    final packet = SocketPacket.encodeEvent(event, data);
    _channel!.sink.add(packet);
  }

  /// Send message and wait for response with acknowledgement
  Future<dynamic> emitWithAck(
    String event,
    dynamic data, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_channel == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket not connected');
    }

    final ackId = _generateAckId();
    final completer = Completer<dynamic>();

    _pendingAcks[ackId] = completer;

    // Set timeout
    Timer(timeout, () {
      if (!completer.isCompleted) {
        _pendingAcks.remove(ackId);
        completer.completeError(TimeoutException('Acknowledgement timeout'));
      }
    });

    // Send with ack ID
    final payload = jsonEncode([event, data, {'ackId': ackId}]);
    _channel!.sink.add('${SocketPacket.message}$payload');

    return completer.future;
  }

  String _generateAckId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_pendingAcks.length}';
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

  String _buildWebSocketUrl(String serverUrl) {
    // Convert http/https to ws/wss
    final wsProtocol = serverUrl.startsWith('https') ? 'wss' : 'ws';
    final baseUrl =
        serverUrl.replaceFirst(RegExp(r'^https?://'), '$wsProtocol://');
    // Socket.io uses path /v1/updates with token in query
    return '$baseUrl/v1/updates?token=$_authToken';
  }

  void _handleMessage(dynamic message) {
    final rawMessage = message as String;

    // Handle ping/pong
    if (rawMessage == '${SocketPacket.ping}') {
      _channel?.sink.add('${SocketPacket.pong}');
      return;
    }

    if (rawMessage == '${SocketPacket.pong}') {
      return;
    }

    // Decode Socket.io message packet
    final socketMessage = SocketPacket.decode(rawMessage);
    if (socketMessage != null) {
      // Emit to raw message stream
      _messageController.add(socketMessage);

      // Call registered event handlers
      final handler = _messageHandlers[socketMessage.event];
      if (handler != null) {
        handler(socketMessage.data);
      }

      // Handle acknowledgement responses
      if (socketMessage.event == 'ack' && socketMessage.data is Map) {
        final ackData = socketMessage.data as Map<String, dynamic>;
        final ackId = ackData['ackId'] as String?;
        if (ackId != null) {
          final completer = _pendingAcks.remove(ackId);
          if (completer != null && !completer.isCompleted) {
            completer.complete(ackData['result']);
          }
        }
      }

      // Handle update events
      if (socketMessage.event == 'update' &&
          socketMessage.data is Map<String, dynamic>) {
        try {
          final update = ApiUpdate.fromJson(socketMessage.data);
          _updateController.add(update);
        } catch (e) {
          if (kDebugMode) {
            print('Failed to parse update: $e');
          }
        }
      }
    } else if (kDebugMode) {
      print('Unknown Socket.io packet: $rawMessage');
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

  /// Update auth token and reconnect if needed
  void updateToken(String newToken) {
    if (_authToken != newToken) {
      _authToken = newToken;

      if (_channel != null) {
        disconnect();
        connect(
          serverUrl: _serverUrl!,
          token: newToken,
          clientType: _clientType ?? 'user-scoped',
        );
      }
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _statusController.close();
    _updateController.close();
    _messageController.close();
    _pendingAcks.clear();
    _messageHandlers.clear();
  }
}

/// Singleton instance - exported for compatibility
final socketIoClient = SocketIoClient();
