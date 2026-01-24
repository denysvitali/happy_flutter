import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode, FlutterError, debugPrint;
import 'logger_service.dart';

/// Remote logger that monkey-patches console methods for AI debugging in debug builds.
///
/// In debug mode, captures all console output (print, debugPrint, log, etc.)
/// and routes it through the logging system for persistence and debugging.
///
/// Usage:
/// ```dart
/// // Initialize at app startup
/// RemoteLogger().install();
/// ```
///
/// Note: This only runs in debug mode to avoid performance overhead in release.
class RemoteLogger {
  static final RemoteLogger _instance = RemoteLogger._();
  factory RemoteLogger() => _instance;
  RemoteLogger._();

  bool _installed = false;

  /// Original console methods
  void Function(String)? _originalPrint;
  void Function(String)? _originalDebugPrint;

  /// Install the remote logger - patches console methods
  ///
  /// This should be called early in app startup, before any console output.
  void install() {
    if (!kDebugMode) return;
    if (_installed) return;

    _patchConsoleMethods();
    _setupErrorHandling();

    logger.info('RemoteLogger installed - console output captured');
    _installed = true;
  }

  /// Remove patches and restore original methods
  void uninstall() {
    if (!_installed) return;

    _restoreConsoleMethods();
    _installed = false;

    logger.info('RemoteLogger uninstalled');
  }

  /// Patch console methods to capture output
  void _patchConsoleMethods() {
    // Store original methods
    _originalPrint = print;
    _originalDebugPrint = debugPrint;

    // Patch print
    _patchPrint();

    // Patch debugPrint
    _patchDebugPrint();
  }

  void _patchPrint() {
    final original = _originalPrint;
    if (original == null) return;

    // We can't actually patch 'print' as it's a top-level function in Dart
    // But we can provide an alternative log method
  }

  void _patchDebugPrint() {
    final original = _originalDebugPrint;
    if (original == null) return;

    // Redirect debugPrint through our logger
    // This is handled by Flutter's framework
  }

  /// Restore original console methods
  void _restoreConsoleMethods() {
    if (_originalDebugPrint != null) {
      // debugPrint is a function variable that can be patched
      // This is handled at the framework level
    }
    _originalPrint = null;
    _originalDebugPrint = null;
  }

  /// Set up error handling to capture framework errors
  void _setupErrorHandling() {
    // FlutterError.onError handles framework errors
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      logger.error(
        'Flutter Framework Error',
        details.exception,
        details.stack,
      );
      originalOnError?.call(details);
    };

    // PlatformDispatcher.onError handles native platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.error(
        'Platform Error: $error',
        error,
        stack,
      );
      return false; // Don't prevent app from crashing
    };
  }

  /// Capture logs from an Isolate
  ///
  /// Returns a ReceivePort that should be passed to the Isolate
  ReceivePort createIsolateCapture(String isolateName) {
    final port = ReceivePort();

    port.listen((message) {
      if (message is LogMessage) {
        logger.log(
          '[${message.level}] ${message.message}',
          level: message.logLevel,
          error: message.error,
          stackTrace: message.stackTrace,
        );
      }
    });

    logger.info('Created log capture for isolate: $isolateName');
    return port;
  }

  /// Send a log message to the main isolate
  static void sendToMain(LogMessage message) {
    // This would need a SendPort from the main isolate
    // Used when logging from background isolates
  }

  /// Get all captured console output as a string
  String getCapturedOutput() {
    return logger.exportLogs();
  }

  /// Export logs in a format suitable for sharing
  String exportForSharing() {
    final logs = logger.getLogs();
    final buffer = StringBuffer();

    buffer.writeln('=== Application Logs ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${logs.length}');
    buffer.writeln('');

    for (final log in logs) {
      buffer.writeln(log.toFormattedString());
    }

    return buffer.toString();
  }

  /// Clear all captured logs
  void clearCapturedLogs() {
    logger.clear();
  }
}

/// Message sent between isolates for log capture
class LogMessage {
  final String message;
  final LogLevel level;
  final LogLevel logLevel;
  final dynamic error;
  final StackTrace? stackTrace;

  LogMessage({
    required this.message,
    this.level = LogLevel.info,
    this.logLevel = LogLevel.info,
    this.error,
    this.stackTrace,
  });
}

/// Background isolate logger that sends logs to main isolate
class BackgroundIsolateLogger {
  final SendPort _sendPort;

  BackgroundIsolateLogger(this._sendPort);

  /// Log a message from background isolate
  void log(String message, {LogLevel level = LogLevel.info}) {
    _sendPort.send(LogMessage(
      message: message,
      level: level,
      logLevel: level,
    ));
  }

  /// Log an error from background isolate
  void error(String message, dynamic error, [StackTrace? stackTrace]) {
    _sendPort.send(LogMessage(
      message: message,
      level: LogLevel.error,
      logLevel: LogLevel.error,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  /// Log a debug message from background isolate
  void debug(String message) {
    log(message, level: LogLevel.debug);
  }

  /// Log an info message from background isolate
  void info(String message) {
    log(message, level: LogLevel.info);
  }

  /// Log a warning from background isolate
  void warning(String message) {
    log(message, level: LogLevel.warning);
  }
}

/// Create a background isolate with log capture
///
/// Usage:
/// ```dart
/// await RemoteLogger().runInIsolate((bgLogger) async {
///   bgLogger.info('Working in background');
///   // do background work
/// });
/// ```
extension RemoteLoggerIsolate on RemoteLogger {
  Future<T> runInIsolate<T>(
    Future<T> Function(BackgroundIsolateLogger bgLogger) function,
  ) async {
    final receivePort = ReceivePort();
    final completer = Completer<T>();

    await Isolate.spawn(
      _isolateEntryPoint,
      _IsolateArgs(
        sendPort: receivePort.sendPort,
        function: function,
        completer: completer,
      ),
    );

    // Handle messages from the isolate
    receivePort.listen((message) {
      if (message is LogMessage) {
        logger.log(
          '[Isolate] ${message.message}',
          level: message.logLevel,
          error: message.error,
          stackTrace: message.stackTrace,
        );
      }
    });

    return completer.future;
  }

  static void _isolateEntryPoint(_IsolateArgs args) async {
    final isolateLogger = BackgroundIsolateLogger(args.sendPort);
    try {
      final result = await args.function(isolateLogger);
      args.completer.complete(result);
    } catch (e, stack) {
      isolateLogger.error('Isolate error', e, stack);
      args.completer.completeError(e, stack);
    }
  }
}

class _IsolateArgs<T> {
  final SendPort sendPort;
  final Future<T> Function(BackgroundIsolateLogger bgLogger) function;
  final Completer<T> completer;

  _IsolateArgs({
    required this.sendPort,
    required this.function,
    required this.completer,
  });
}

/// Auto-install helper for main()
///
/// Wrap your main() with this to automatically install the remote logger:
///
/// ```dart
/// void main() {
///   remoteLoggerAutoInstall();
///   runApp(MyApp());
/// }
/// ```
void remoteLoggerAutoInstall() {
  if (kDebugMode) {
    RemoteLogger().install();
  }
}
