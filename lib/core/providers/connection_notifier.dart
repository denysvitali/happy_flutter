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
    // Return initial state; onStatusChange callback will update immediately
    // with current status since it calls listener(_status) on registration
    return socket_io.ConnectionStatus.disconnected;
  }

  void connect(String serverUrl, String token) {
    socket_io.socketIoClient.connect(serverUrl: serverUrl, token: token);
  }

  void disconnect() {
    socket_io.socketIoClient.disconnect();
  }
}

final connectionNotifierProvider =
    NotifierProvider<ConnectionNotifier, socket_io.ConnectionStatus>(() {
      return ConnectionNotifier();
    });
