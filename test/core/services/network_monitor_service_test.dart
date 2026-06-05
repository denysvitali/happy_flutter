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
    test('initialize does not block on first connectivity check', () async {
      // Regression guard for GlitchTip app.deferredInit: the
      // initial Connectivity.checkConnectivity() platform-channel
      // round-trip must NOT be awaited by initialize() because
      // app.deferredInit awaits the result.  Blocking here adds
      // 100–1000ms to cold start on devices where the platform
      // channel is slow on first use.
      final service = NetworkMonitorService.testCreate();
      var resolved = false;
      // Swallow the test platform's checkConnectivity so the
      // promise only completes when we explicitly complete the
      // completer below — proving initialize() did not await it.
      final pending = Completer<List<ConnectivityResult>>();

      addTearDown(() {
        if (!pending.isCompleted) pending.complete(<ConnectivityResult>[]);
      });

      fakePlatform.checkConnectivityOverride = () => pending.future;
      // Start the init — it must return before pending completes.
      final initFuture = service.initialize();
      // Give the event loop one turn.  The unawaited check
      // should still be pending, so initialize() should already
      // have returned.
      await Future<void>.delayed(Duration.zero);
      expect(initFuture, isNotNull);
      // Resolve the platform call so the test can clean up.
      pending.complete(const <ConnectivityResult>[ConnectivityResult.wifi]);
      await initFuture;
      resolved = true;
      expect(resolved, isTrue);
    });

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

  /// Test override for [checkConnectivity] — when set, replaces
  /// the default behavior.  Used by the
  /// "initialize does not block on first connectivity check" test
  /// to inject a Completer-backed future and prove that
  /// initialize() does not await the platform call.
  Future<List<ConnectivityResult>> Function()? checkConnectivityOverride;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    final override = checkConnectivityOverride;
    if (override != null) return override();
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
