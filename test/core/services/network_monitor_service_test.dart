import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/network_monitor_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectivityPlatform previousPlatform;
  late _FakeConnectivityPlatform fakePlatform;

  setUp(() {
    previousPlatform = ConnectivityPlatform.instance;
    fakePlatform = _FakeConnectivityPlatform();
    ConnectivityPlatform.instance = fakePlatform;
  });

  tearDown(() {
    ConnectivityPlatform.instance = previousPlatform;
  });

  group('NetworkMonitorService lifecycle', () {
    test('suspend cancels native connectivity subscription', () async {
      final service = NetworkMonitorService.testCreate();

      await service.initialize();

      expect(service.testHasActiveSubscription, isTrue);
      expect(fakePlatform.listenerCount, 1);

      service.suspend();

      expect(service.testHasActiveSubscription, isFalse);
      expect(fakePlatform.listenerCount, 0);
    });

    test('resume restarts connectivity subscription', () async {
      final service = NetworkMonitorService.testCreate();

      await service.initialize();
      service.suspend();
      service.resume();

      expect(service.testHasActiveSubscription, isTrue);
      expect(fakePlatform.listenerCount, 1);
    });

    test('suspended connectivity events do not emit app events', () async {
      final service = NetworkMonitorService.testCreate();
      final emitted = <bool>[];
      final sub = service.onConnectivityChanged.listen(emitted.add);
      addTearDown(sub.cancel);

      await service.initialize();
      service.suspend();

      fakePlatform.emit([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
    });

    test(
      'resume publishes connectivity changes from suspended period',
      () async {
        final service = NetworkMonitorService.testCreate();
        final emitted = <bool>[];
        final sub = service.onConnectivityChanged.listen(emitted.add);
        addTearDown(sub.cancel);

        await service.initialize();
        service.suspend();

        fakePlatform.current = [ConnectivityResult.none];
        service.resume();
        await Future<void>.delayed(Duration.zero);

        expect(emitted, [false]);
        expect(service.isOnline, isFalse);
      },
    );
  });
}

class _FakeConnectivityPlatform extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  _FakeConnectivityPlatform()
    : _controller = StreamController<List<ConnectivityResult>>.broadcast();

  final StreamController<List<ConnectivityResult>> _controller;
  var current = <ConnectivityResult>[ConnectivityResult.wifi];
  var listenerCount = 0;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return current;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _controller.stream
        .transform(
          StreamTransformer<
            List<ConnectivityResult>,
            List<ConnectivityResult>
          >.fromHandlers(handleData: (data, sink) => sink.add(data)),
        )
        .asBroadcastStream(
          onListen: (_) => listenerCount++,
          onCancel: (_) => listenerCount--,
        );
  }

  void emit(List<ConnectivityResult> results) {
    current = results;
    _controller.add(results);
  }
}
