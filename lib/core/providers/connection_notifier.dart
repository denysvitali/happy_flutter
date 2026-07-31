import 'package:riverpod/riverpod.dart';

import '../api/socket_io_client.dart' as socket_io;

class ConnectionNotifier extends Notifier<socket_io.ConnectionStatus> {
  void Function()? _unsubscribe;

  @override
  socket_io.ConnectionStatus build() {
    // Initialize subscription reactively in build() to avoid race condition
    _unsubscribe = socket_io.socketIoClient.onStatusChange((status) {
      state = status;
    });
    ref.onDispose(() => _unsubscribe?.call());
    // Return the actual current status rather than a hardcoded disconnected
    // state, avoiding a brief flash of "disconnected" before the real status
    // arrives via the onStatusChange callback.
    return socket_io.socketIoClient.connectionStatus;
  }

  void connect(String serverUrl, String token) {
    socket_io.socketIoClient.connect(serverUrl: serverUrl, token: token);
  }

  void disconnect() {
    socket_io.socketIoClient.disconnect(
      reason: socket_io.DisconnectReason.userDisconnect,
    );
  }
}

final connectionNotifierProvider =
    NotifierProvider<ConnectionNotifier, socket_io.ConnectionStatus>(() {
      return ConnectionNotifier();
    });
