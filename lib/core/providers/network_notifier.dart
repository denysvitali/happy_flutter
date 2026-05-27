import 'dart:async';

import 'package:riverpod/riverpod.dart';

import '../services/network_monitor_service.dart';

/// Bridges [NetworkMonitorService] into Riverpod so widgets can
/// reactively watch network connectivity via
/// `ref.watch(networkNotifierProvider)`.
///
/// State is `true` when the device has network connectivity and
/// `false` when it does not.
class NetworkNotifier extends Notifier<bool> {
  StreamSubscription<bool>? _subscription;

  @override
  bool build() {
    final service = NetworkMonitorService();
    _subscription = service.onConnectivityChanged.listen((online) {
      if (state == online) return;
      state = online;
    });
    ref.onDispose(() => _subscription?.cancel());
    return service.isOnline;
  }
}

final networkNotifierProvider =
    NotifierProvider<NetworkNotifier, bool>(
  NetworkNotifier.new,
);
