import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutterrific_opentelemetry/flutterrific_opentelemetry.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'logger_service.dart';

class OpenTelemetryService {
  factory OpenTelemetryService() => _instance;
  OpenTelemetryService._();

  static final OpenTelemetryService _instance = OpenTelemetryService._();

  static const String _serviceName = 'happy-flutter';
  static const String _nativeEndpoint = 'opentelemetry.k2.k8s.best:4317';
  static const String _webEndpoint = 'https://opentelemetry.k2.k8s.best:4318';
  static const bool _nativeEnabled = bool.fromEnvironment(
    'HAPPY_ENABLE_NATIVE_OPENTELEMETRY',
  );

  bool _initialized = false;

  bool get isInitialized => _initialized;

  NavigatorObserver? get routeObserver {
    if (!_initialized) return null;
    return FlutterOTel.routeObserver;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_nativeEnabled) {
      logger.info(
        '[OpenTelemetry] initialization skipped; '
        'set HAPPY_ENABLE_NATIVE_OPENTELEMETRY=true to enable',
      );
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await FlutterOTel.initialize(
        appName: _serviceName,
        endpoint: kIsWeb ? _webEndpoint : _nativeEndpoint,
        secure: true,
        serviceName: _serviceName,
        serviceVersion: packageInfo.version,
        tracerName: 'happy_flutter',
        tracerVersion: packageInfo.version,
      );
      _initialized = true;
      logger.info(
        '[OpenTelemetry] initialized endpoint='
        '${kIsWeb ? _webEndpoint : _nativeEndpoint}',
      );
    } catch (e, stack) {
      logger.warning('[OpenTelemetry] initialization failed: $e', e, stack);
    }
  }
}
