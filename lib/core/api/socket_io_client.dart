import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../services/logger_service.dart' show LogLevel, logger;
import '../services/opentelemetry_service.dart';
import '../services/performance_context_service.dart';
import '../services/power_diagnostics_service.dart';

/// Returns true for transient network errors (DNS failure,
/// connection timeout, TLS handshake interruption, etc.) that are
/// expected during brief connectivity loss on mobile.
bool _isTransientSocketError(String error) {
  final lower = error.toLowerCase();
  return error.contains('ERR_NAME_NOT_RESOLVED') ||
      error.contains('ERR_CONNECTION_TIMED_OUT') ||
      error.contains('ERR_CONNECTION_ABORTED') ||
      error.contains('ERR_CONNECTION_RESET') ||
      error.contains('ERR_NETWORK_CHANGED') ||
      error.contains('ERR_INTERNET_DISCONNECTED') ||
      error.contains('ERR_ADDRESS_UNREACHABLE') ||
      error.contains('Failed host lookup') ||
      error.contains('No address associated') ||
      error.contains('Connection closed') ||
      error.contains('Software caused connection abort') ||
      error.contains('xhr poll error') ||
      // TLS handshake interrupted by network drop or server restart —
      // these are transient and resolve on the next reconnect attempt.
      lower.contains('handshakeexception') ||
      lower.contains('connection terminated during handshake') ||
      lower.contains('bad certificate') ||
      lower.contains('not upgraded to websocket') ||
      lower.contains('http status code: 503') ||
      // Server temporarily down or restarting — resolves on reconnect.
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      // Socket.IO internal timeout (ACK timeout or ping timeout)
      lower.contains('timeout') ||
      lower.contains('socket.io error: timeout');
}

/// Represents a decoded Socket.io message
class SocketMessage {
  SocketMessage({required this.event, required this.data});
  final String event;
  final dynamic data;
}

/// Exception thrown when [SocketIoClient.emitWithAck] cannot deliver the
/// event because the socket is not connected (connection timeout or
/// explicitly disconnected).
class SocketNotConnectedException implements Exception {
  const SocketNotConnectedException(this.event);
  final String event;

  @override
  String toString() =>
      'SocketNotConnectedException: socket not connected, cannot emit '
      'event "$event"';
}

/// Exception thrown when [SocketIoClient.emitWithAck] times out waiting
/// for an ACK from the server.
class SocketAckTimeoutException implements Exception {
  const SocketAckTimeoutException(this.event);
  final String event;

  @override
  String toString() =>
      'SocketAckTimeoutException: ACK timeout for event "$event"';
}

/// WebSocket connection state
enum ConnectionStatus { disconnected, connecting, connected, error }

/// Bounded set of reasons a dial was started.
///
/// Emitted as the `websocket.dial_reason` span attribute.  Keep this list
/// small: it is a span attribute, so every value becomes a distinct
/// Jaeger/Sentry facet.
abstract final class DialReason {
  /// First dial of the app process.
  static const String coldStart = 'cold_start';

  /// App returned to the foreground.
  static const String lifecycleResume = 'lifecycle_resume';

  /// Platform connectivity change reported the network is back.
  static const String networkRestored = 'network_restored';

  /// The Sync reconnect watchdog fired while still disconnected.
  static const String watchdog = 'watchdog';

  /// User tapped "Reconnect now".
  static const String userManual = 'user_manual';

  /// Auth token was rotated and the live socket still holds the old one.
  static const String tokenRefresh = 'token_refresh';

  /// Resume found a socket that still claims "connected" after a
  /// background stay long enough for the server session to have died.
  static const String zombieDetected = 'zombie_detected';

  /// Server URL changed under a live socket.
  static const String serverUrlChanged = 'server_url_changed';

  /// Socket.IO's own Manager retried internally — this never enters
  /// [SocketIoClient.connect], so it is reported as a standalone span.
  static const String libraryRetry = 'library_retry';

  /// Caller did not say.
  static const String unspecified = 'unspecified';
}

/// Bounded set of Socket.IO disconnect reasons.
///
/// Socket.IO emits a free-form string; it becomes a span attribute and a
/// metric-adjacent facet, so anything unrecognised collapses to [other]
/// rather than opening an unbounded label space.
abstract final class DisconnectReason {
  static const String ioServerDisconnect = 'io_server_disconnect';
  static const String ioClientDisconnect = 'io_client_disconnect';
  static const String pingTimeout = 'ping_timeout';
  static const String transportClose = 'transport_close';
  static const String transportError = 'transport_error';
  static const String parseError = 'parse_error';
  static const String other = 'other';
  static const String unknown = 'unknown';

  /// App-initiated teardowns. Socket.IO never reports these itself: the
  /// library's own `disconnect` event is raised after
  /// [SocketIoClient.disconnect] has already bumped the connection
  /// generation, so the guarded handler returns before emitting anything.
  /// They are emitted from the call site instead — see
  /// [SocketIoClient.disconnect].
  static const String clientReconnect = 'client_reconnect';
  static const String lifecycleSuspend = 'lifecycle_suspend';
  static const String appShutdown = 'app_shutdown';
  static const String userDisconnect = 'user_disconnect';

  static const Map<String, String> _known = {
    'io server disconnect': ioServerDisconnect,
    'io client disconnect': ioClientDisconnect,
    'ping timeout': pingTimeout,
    'transport close': transportClose,
    'transport error': transportError,
    'parse error': parseError,
  };

  /// Normalize a raw Socket.IO disconnect payload to a bounded facet.
  static String normalize(Object? payload) {
    if (payload == null) return unknown;
    final raw = payload.toString().trim().toLowerCase();
    if (raw.isEmpty || raw == 'null') return unknown;
    return _known[raw] ?? other;
  }
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
  bool _hasConnectedOnce = false;

  /// Number of times [reconnect] was requested (including no-op calls made
  /// before [connect] ever stored credentials). Test-only observability for
  /// lifecycle contracts — e.g. resume() forcing a fresh socket for a zombie
  /// connection, or the reconnect watchdog re-arming.
  int _reconnectRequests = 0;

  /// Number of times [reconnect] short-circuited because a dial was
  /// already in flight. Test-only observability for the in-flight guard.
  int _reconnectSkipped = 0;

  /// Dials started since the last successful connect. Reported as the
  /// `websocket.dial_attempt` span attribute so a redial storm is visible
  /// as a rising index instead of N indistinguishable spans.
  int _dialAttempt = 0;
  int _connectionGeneration = 0;
  int? _lastConnectStartedAtMs;
  int? _lastDisconnectAtMs;
  int? _lastEventAtMs;
  String? _lastDisconnectReason;
  Stopwatch? _connectStopwatch;
  int? _connectSpanGeneration;
  String? _connectSpanReason;
  ISentrySpan? _connectTransaction;
  OTelSpan? _connectOtelSpan;

  // Listeners notified when Socket.IO exhausts all reconnection attempts.
  final _reconnectFailedListeners = <void Function()>[];

  // Rate-limit Sentry captures for non-transient socket errors.
  // A reconnection storm can fire dozens of identical errors within
  // seconds; we capture at most one per 60-second window to avoid
  // flooding the error tracker.
  DateTime? _lastSentryErrorCapturedAt;
  static const _sentryCaptureWindow = Duration(seconds: 60);

  bool _shouldCaptureSentryForSocketError() {
    final now = DateTime.now();
    final last = _lastSentryErrorCapturedAt;
    if (last == null || now.difference(last) >= _sentryCaptureWindow) {
      _lastSentryErrorCapturedAt = now;
      return true;
    }
    return false;
  }

  // Error flood throttle — track last-logged error text + timestamp so
  // that a burst of identical errors (e.g. 100+ "timeout" events fired
  // within 5 ms by the Socket.IO ping-timeout machinery) collapses to a
  // single log + Sentry event instead of flooding the ring buffer and
  // Sentry's event quota.
  String? _lastErrorStr;
  int? _lastErrorAtMs;
  int _suppressedErrorCount = 0;
  static const int _errorThrottleWindowMs = 5000;

  // Stream controllers for events
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  // Emits the expected delay (in whole seconds) before the next internal
  // reconnect attempt, so UI can display a countdown.  Computed from the
  // same exponential-backoff formula the socket library uses
  // (initial=2s, max=10s, factor=2).
  final _nextReconnectDelayController = StreamController<int>.broadcast();

  // Event handlers - supports multiple handlers per event
  final Map<String, List<void Function(dynamic)>> _messageHandlers = {};

  // Connection listeners
  final _reconnectedListeners = <void Function()>[];
  final _statusListeners = <void Function(ConnectionStatus)>[];

  // Reconnection backoff constants — must match the values passed to
  // sio.OptionBuilder in connect().
  //
  // Initial delay lowered 2s -> 1s: Jaeger traced websocket.reconnect
  // spans averaging ~4.4s on resume, and the first internal attempt is
  // the one that matters most for perceived recovery. Backoff still
  // grows exponentially to the 10s cap (1,2,4,8,10...), so only the
  // first dial is more aggressive — battery impact is negligible while
  // a healthy network is reached ~1s sooner.
  static const int _reconnectDelayInitialMs = 1000;
  static const int _reconnectDelayMaxMs = 10000;

  /// Per-attempt connect timeout passed to the Socket.IO Manager.
  ///
  /// The server allows 20s for the handshake
  /// (`internal/server/ws/server.go`, `SetConnectTimeout(20s)`).  The
  /// previous 8s abandoned handshakes the server would have completed —
  /// the client gave up mid-negotiation and the server then booked the
  /// half-open connection as an involuntary disconnect, inflating both
  /// sides of the churn numbers.  15s stays comfortably under the server
  /// bound while surviving a cold cellular TLS negotiation.
  static const int _connectTimeoutMs = 15000;

  /// Minimum spacing between externally requested dials.
  ///
  /// Five independent callers (lifecycle resume, reconnect watchdog,
  /// forceReconnect, network-restored, reconnect-exhausted) can fire
  /// within the same second.  Without this guard each one tears down a
  /// half-open socket and immediately starts another, so the server sees
  /// overlapping connections and counts the abandoned ones as involuntary
  /// disconnects.
  static const int _dialInFlightWindowMs = _connectTimeoutMs;

  /// Compute the backoff delay (ms) for the given attempt index (0-based).
  static int _backoffDelayMs(int attempt) {
    final ms = (_reconnectDelayInitialMs * _pow2(attempt).clamp(1, 1 << 20))
        .clamp(0, _reconnectDelayMaxMs);
    return ms;
  }

  static int _pow2(int n) {
    if (n <= 0) return 1;
    return 1 << n;
  }

  /// Get connection status stream
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  /// Stream that emits the expected wait (whole seconds) before the next
  /// internal reconnect attempt.  Useful for showing a countdown in UI.
  Stream<int> get nextReconnectDelayStream =>
      _nextReconnectDelayController.stream;

  /// Current connection status
  ConnectionStatus get connectionStatus => _status;

  /// Initialize and connect using the official Socket.IO protocol.
  ///
  /// [reason] is a [DialReason] constant recorded on the `websocket.dial`
  /// span so redial storms can be attributed to the caller that caused
  /// them.
  void connect({
    required String serverUrl,
    required String token,
    String clientType = 'user-scoped',
    String reason = DialReason.coldStart,
  }) {
    if (_socket != null) {
      logger.info(
        'Socket.IO connect() skipped — socket already exists '
        '(status=$_status)',
      );
      return;
    }

    logger.info('Socket.IO connecting to $serverUrl (reason=$reason)');
    _serverUrl = serverUrl;
    _authToken = token;
    _clientType = clientType;
    _lastConnectStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _connectStopwatch = Stopwatch()..start();
    _dialAttempt++;
    final generation = ++_connectionGeneration;
    _lastEventAtMs = null;
    _updateStatus(ConnectionStatus.connecting);
    _startConnectionSpans(generation, reason: reason);

    _socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setPath('/v1/updates')
          .setAuth({'token': token, 'clientType': clientType})
          .setTransports(['websocket'])
          .enableReconnection()
          // 1s initial (was 2s) for faster first-attempt recovery on
          // resume; must match _reconnectDelayInitialMs. Exponential
          // backoff to the 10s cap keeps later attempts battery-friendly.
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000) // 10s max — 30s is too slow on mobile
          // Cap each connection attempt just under the server's own
          // handshake budget — see [_connectTimeoutMs].
          .setTimeout(_connectTimeoutMs)
          // Cap internal reconnection attempts so a persistent server-side
          // TLS failure (e.g. cert renewal, rolling restart) does not produce
          // an unbounded storm of retries.  SocketIoClient.reconnect() resets
          // the Manager and will restart the counter when called externally
          // (e.g. on app resume).
          .setReconnectionAttempts(10)
          .enableForceNew() // bypass global Manager cache on reconnect
          .setTransportOptions({
            'websocket': {
              'perMessageDeflate': {'threshold': 1024},
            },
          })
          .disableAutoConnect()
          .build(),
    );

    _setupEventHandlers(generation);
    _socket!.connect();
  }

  bool _isCurrentGeneration(int generation) =>
      generation == _connectionGeneration;

  void _setupEventHandlers(int generation) {
    _socket!.onConnect((_) async {
      if (!_isCurrentGeneration(generation)) return;
      logger.info('Socket.IO connected');
      powerDiagnostics.recordSocketStatus(ConnectionStatus.connected);
      _dialAttempt = 0;
      _resetErrorThrottle();
      _updateStatus(ConnectionStatus.connected);

      _finishConnectionSpans(generation);

      // Always notify reconnection handlers when this is not the first
      // connection — even when Socket.IO reports successful state recovery
      // (recovered=true).  The recovered flag only guarantees that Socket.IO
      // replayed missed transport-level events, but server-side state (room
      // memberships, auth context) may have changed during the disconnect gap.
      // Skipping _notifyReconnected on recovery caused persistent stale-data
      // bugs where sessions couldn't be created and messages weren't delivered
      // until app restart.
      if (_hasConnectedOnce) {
        _notifyReconnected();
      }
      _hasConnectedOnce = true;
    });

    _socket!.onDisconnect((payload) {
      if (!_isCurrentGeneration(generation)) return;
      // Socket.IO hands back the reason string ('ping timeout',
      // 'transport close', 'io server disconnect', ...). Without it a 1:1
      // connect/disconnect ratio in Prometheus is unattributable: a server
      // eviction and a backgrounded radio look identical.
      _recordDisconnect(DisconnectReason.normalize(payload));
    });

    _socket!.onConnectError((error) async {
      if (!_isCurrentGeneration(generation)) return;
      _updateStatus(ConnectionStatus.error);

      final errorStr = error.toString();
      final isTransient = _isTransientSocketError(errorStr);
      _finishConnectionSpans(
        generation,
        ok: false,
        status: const SpanStatus.internalError(),
        error: error,
        stackTrace: StackTrace.current,
      );

      // Check transient BEFORE throttle so transient errors are logged at
      // info level and do NOT consume throttle budget — this prevents a
      // burst of timeout errors from silencing subsequent real errors.
      if (isTransient) {
        // Throttle transient errors too so a burst doesn't spam the log.
        if (_shouldThrottleError(errorStr)) return;
        powerDiagnostics.recordSocketError(errorStr);
        logger.info('Socket.IO transient connect error: $error');
        return;
      }

      if (_shouldThrottleError(errorStr)) return;

      powerDiagnostics.recordSocketError(errorStr);
      logger.warning('Socket.IO connect error: $error');

      final transaction =
          Sentry.startTransaction(
              'websocket.connect_error',
              'connection',
              bindToScope: false,
            )
            ..setData('error', errorStr)
            ..setData(
              'connectDurationMs',
              _elapsedSince(_lastConnectStartedAtMs),
            )
            ..setData(
              'currentRoute',
              PerformanceContextService().currentRoute ?? 'unknown',
            );
      await transaction.finish(status: const SpanStatus.internalError());

      if (_shouldCaptureSentryForSocketError()) {
        unawaited(
          Sentry.captureException(
            Exception('Socket.IO connect error: $error'),
            stackTrace: StackTrace.current,
          ),
        );
      }
    });

    _socket!.onError((error) async {
      if (!_isCurrentGeneration(generation)) return;
      _updateStatus(ConnectionStatus.error);

      final errorStr = error.toString();
      final isTransient = _isTransientSocketError(errorStr);
      _finishConnectionSpans(
        generation,
        ok: false,
        status: const SpanStatus.internalError(),
        error: error,
        stackTrace: StackTrace.current,
      );

      // Check transient BEFORE throttle so transient errors are logged at
      // info level and do NOT consume throttle budget — this prevents a
      // burst of timeout errors from silencing subsequent real errors.
      if (isTransient) {
        // Throttle transient errors too so a burst doesn't spam the log.
        if (_shouldThrottleError(errorStr)) return;
        powerDiagnostics.recordSocketError(errorStr);
        logger.info('Socket.IO transient error: $error');
        return;
      }

      if (_shouldThrottleError(errorStr)) return;

      powerDiagnostics.recordSocketError(errorStr);
      logger.warning('Socket.IO error: $error');

      final transaction =
          Sentry.startTransaction(
              'websocket.error',
              'connection',
              bindToScope: false,
            )
            ..setData('error', errorStr)
            ..setData(
              'connectDurationMs',
              _elapsedSince(_lastConnectStartedAtMs),
            )
            ..setData(
              'currentRoute',
              PerformanceContextService().currentRoute ?? 'unknown',
            );
      await transaction.finish(status: const SpanStatus.internalError());

      if (_shouldCaptureSentryForSocketError()) {
        unawaited(
          Sentry.captureException(
            Exception('Socket.IO error: $error'),
            stackTrace: StackTrace.current,
          ),
        );
      }
    });

    _socket!.onReconnectFailed((_) {
      if (!_isCurrentGeneration(generation)) return;
      powerDiagnostics.recordSocketError('reconnect_failed');
      logger.warning('Socket.IO reconnection attempts exhausted');
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'Socket.IO reconnect_failed — attempts exhausted',
            category: 'websocket',
            level: SentryLevel.warning,
          ),
        ),
      );
      _updateStatus(ConnectionStatus.disconnected);
      for (final listener in _reconnectFailedListeners) {
        listener();
      }
    });

    // Track reconnection attempts so the UI can show a countdown for the
    // *next* attempt.  The attempt index is 1-based from Socket.IO; convert
    // to 0-based for our backoff formula.
    _socket!.onReconnectAttempt((attempt) {
      if (!_isCurrentGeneration(generation)) return;
      // The Manager owns this retry cycle. Keep the public state aligned
      // with it so lifecycle/network/watchdog callers do not interpret the
      // preceding connect_error as permission to dispose this Manager and
      // start an overlapping generation.
      _lastConnectStartedAtMs = DateTime.now().millisecondsSinceEpoch;
      _updateStatus(ConnectionStatus.connecting);
      final attemptIndex = attempt is int
          ? attempt
          : int.tryParse('$attempt') ?? 1;
      // Compute delay before the NEXT attempt (index = current attempt).
      final nextDelayMs = _backoffDelayMs(attemptIndex);
      final nextDelaySecs = (nextDelayMs / 1000).ceil();
      if (!_nextReconnectDelayController.isClosed) {
        _nextReconnectDelayController.add(nextDelaySecs);
      }
      // The Manager's own retries never pass through [connect], so they
      // used to produce NO span at all — the dial spans undercounted real
      // dials by up to the reconnection-attempt cap. Emit a zero-duration
      // marker span so trace-side dial counts match reality.
      OpenTelemetryService()
          .startTrace(
            'websocket.dial',
            attributes: {
              'websocket.dial_reason': DialReason.libraryRetry,
              'websocket.dial_attempt': attemptIndex,
              'current_route':
                  PerformanceContextService().currentRoute ?? 'unknown',
            },
          )
          ?.end();
    });

    _socket!.onAny((event, data) {
      if (!_isCurrentGeneration(generation)) return;
      _lastEventAtMs = DateTime.now().millisecondsSinceEpoch;
      String? updateType;
      if (data is Map<String, dynamic>) {
        updateType = data['t'] as String?;
      }
      powerDiagnostics.recordSocketEvent(event, updateType: updateType);

      // Only record non-streaming events as Sentry breadcrumbs.
      // During AI streaming, 'update' events with new-message arrive
      // at 10-50/sec — recording each one floods Sentry's ring buffer
      // with useless breadcrumbs and adds allocation pressure.
      final isStreamingUpdate =
          event == 'update' &&
          data is Map<String, dynamic> &&
          data['t'] == 'new-message';
      if (!isStreamingUpdate) {
        final breadcrumbData = <String, dynamic>{'event': event};
        if (data is Map<String, dynamic>) {
          final updateType = data['t'] as String?;
          if (updateType != null) {
            breadcrumbData['type'] = updateType;
          }
          final sid = data['d'] is Map
              ? (data['d'] as Map)['sid'] as String?
              : null;
          if (sid != null) breadcrumbData['sessionId'] = sid;
        }
        Sentry.addBreadcrumb(
          Breadcrumb(
            message: 'ws event: $event',
            category: 'websocket',
            level: SentryLevel.info,
            data: breadcrumbData,
          ),
        );
      }

      final handlers = _messageHandlers[event];
      if (handlers != null) {
        for (final h in handlers) {
          h(data);
        }
      }
    });
  }

  /// Emit every signal a disconnect owes its observers, exactly once.
  ///
  /// Shared by the library's own `disconnect` event and by
  /// [disconnect] — see the generation-guard note there. Deliberately
  /// synchronous: [disconnect] is a sync teardown, and neither the Sentry
  /// transaction nor the OTel span has a result worth awaiting.
  void _recordDisconnect(String reason) {
    // Measured from dial start (see [_lastConnectStartedAtMs]), which is the
    // figure that separates "died during handshake" from "lived for hours".
    final sinceDialMs = _lastConnectStartedAtMs == null
        ? null
        : _elapsedSince(_lastConnectStartedAtMs);
    logger.info(
      'Socket.IO disconnected reason=$reason '
      'sinceDialMs=${sinceDialMs ?? -1}',
    );
    powerDiagnostics.recordSocketStatus(ConnectionStatus.disconnected);
    _lastDisconnectAtMs = DateTime.now().millisecondsSinceEpoch;
    _lastDisconnectReason = reason;
    _updateStatus(ConnectionStatus.disconnected);

    final route = PerformanceContextService().currentRoute ?? 'unknown';
    // Track disconnection as a transaction
    final transaction =
        Sentry.startTransaction(
            'websocket.disconnect',
            'connection',
            bindToScope: false,
          )
          ..setData('currentRoute', route)
          ..setData('reason', reason);
    unawaited(transaction.finish());
    OpenTelemetryService()
        .startTrace(
          'websocket.disconnect',
          attributes: {
            'current_route': route,
            'websocket.disconnect_reason': reason,
            'websocket.since_dial_ms': ?sinceDialMs,
          },
        )
        ?.end();
  }

  /// Disconnect from Socket.IO.
  ///
  /// By default this is a full teardown and resets connection history so the
  /// next connect is treated as a first connection. Lifecycle suspends can
  /// preserve the history so the next foreground connect still runs
  /// reconnection recovery.
  ///
  /// [reason] is emitted as `websocket.disconnect_reason`; pass one of the
  /// app-initiated [DisconnectReason] facets so a suspend, a logout and a
  /// reconnect are distinguishable in Jaeger.
  void disconnect({
    bool preserveConnectionHistory = false,
    String reason = DisconnectReason.ioClientDisconnect,
  }) {
    _finishConnectionSpans(
      _connectionGeneration,
      ok: false,
      status: const SpanStatus.cancelled(),
    );
    _connectionGeneration++;
    // `Socket.dispose()` already calls `disconnect()` internally
    // (socket_io_client/src/socket.dart), so an explicit `disconnect()`
    // before it was redundant. (It was not harmful: the second call is a
    // no-op because the first already set `connected = false`.)
    _socket?.dispose();
    _socket = null;
    if (!preserveConnectionHistory) {
      _hasConnectedOnce = false;
    }
    // Bumping the connection generation above means the underlying
    // socket.io library's own 'disconnect' event is dropped by the
    // generation guard in _setupEventHandlers, so NOTHING downstream of that
    // handler ran for an app-initiated disconnect: no power-diagnostics
    // count, no `_lastDisconnectAtMs` (which made `disconnect_gap_ms` on the
    // next dial measure from the last *involuntary* disconnect — the source
    // of the 27-minute gaps in the traces), and no `websocket.disconnect`
    // span or Sentry transaction at all. Jaeger showed 79 `websocket.dial`
    // spans against zero disconnects in the same window. Emit the whole set
    // here instead.
    if (_status != ConnectionStatus.disconnected) {
      _recordDisconnect(reason);
    }
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Reconnect using previously stored credentials.
  ///
  /// No-op if [connect] was never called (no credentials stored).
  ///
  /// Also a no-op while the Socket.IO Manager is opening/retrying, or while
  /// a fresh dial remains inside the connection-timeout window. Independent
  /// callers used to tear down that Manager and start another generation, so
  /// the server saw overlapping connections and ACK callers were stranded on
  /// an abandoned socket. Pass [force] only when the current dial is known to
  /// be useless (for example, it is using a rotated token).
  ///
  /// Preserves [_hasConnectedOnce] so the [onConnect] handler fires
  /// [_notifyReconnected] instead of treating the reconnection as a
  /// first-ever connection.  Without this, [disconnect] resets the
  /// flag and the Sync reconnected handler never fires on app resume.
  void reconnect({String reason = DialReason.unspecified, bool force = false}) {
    _reconnectRequests++;
    final url = _serverUrl;
    final token = _authToken;
    final clientType = _clientType;
    if (url == null || token == null || clientType == null) return;
    if (!force && _isDialInFlight()) {
      _reconnectSkipped++;
      OpenTelemetryService().recordCount(
        'app.socket.reconnect_requests',
        attributes: <String, Object?>{
          'outcome': 'active_dial_preserved',
          'reason': reason,
          'current_route':
              PerformanceContextService().currentRoute ?? 'unknown',
        },
        description: 'External socket reconnect request policy',
      );
      logger.info(
        'Socket.IO reconnect($reason) skipped — a dial started '
        '${_elapsedSince(_lastConnectStartedAtMs)}ms ago is still in flight',
      );
      return;
    }
    OpenTelemetryService().recordCount(
      'app.socket.reconnect_requests',
      attributes: <String, Object?>{
        'outcome': force ? 'forced' : 'started',
        'reason': reason,
        'current_route': PerformanceContextService().currentRoute ?? 'unknown',
      },
      description: 'External socket reconnect request policy',
    );
    final hadConnectedOnce = _hasConnectedOnce;
    disconnect(
      preserveConnectionHistory: true,
      reason: DisconnectReason.clientReconnect,
    );
    connect(
      serverUrl: url,
      token: token,
      clientType: clientType,
      reason: reason,
    );
    _hasConnectedOnce = hadConnectedOnce;
  }

  /// True while a dial is still negotiating inside the in-flight window.
  bool _isDialInFlight() {
    final socket = _socket;
    if (socket != null) {
      final manager = socket.io;
      if (manager.reconnecting || manager.readyState == 'opening') {
        return true;
      }
    }
    if (_status != ConnectionStatus.connecting) return false;
    final startedAt = _lastConnectStartedAtMs;
    if (startedAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch - startedAt <
        _dialInFlightWindowMs;
  }

  /// Emit event through Socket.IO
  void send(String event, dynamic data) {
    if (_socket == null || _status != ConnectionStatus.connected) {
      throw StateError('WebSocket not connected');
    }
    powerDiagnostics.recordSocketSend(event);
    _socket!.emit(event, data);
  }

  /// Waits for the socket to reach [ConnectionStatus.connected].
  /// Returns immediately if already connected. Returns normally
  /// (with false) if socket is null or [timeout] elapses.
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_socket != null && _status == ConnectionStatus.connected) return true;
    if (_socket == null) {
      return false;
    }
    // Socket exists but isn't connected yet (e.g. reconnecting after
    // app resume). Wait for it rather than failing immediately.
    try {
      await statusStream
          .firstWhere((s) => s == ConnectionStatus.connected)
          .timeout(timeout);
      return true;
    } on TimeoutException {
      logger.info('Socket.IO connection wait timeout');
      return false;
    }
  }

  /// Emit event and wait for acknowledgement.
  ///
  /// [timeout] is the TOTAL budget: it covers both waiting for the socket
  /// to reach [ConnectionStatus.connected] and waiting for the ACK.
  /// Previously the wait leg always used [waitForConnection]'s 10s default
  /// and the ACK leg got the full [timeout] on top, so a 30s caller could
  /// burn 40s of wall clock.
  Future<dynamic> emitWithAck(
    String event,
    dynamic data, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    final connected = await waitForConnection(timeout: timeout);
    if (!connected) {
      // Throw a typed exception instead of returning null — null propagates
      // silently and produces confusing "RPC failed: null" errors that are
      // hard to distinguish from other failures.
      throw SocketNotConnectedException(event);
    }
    // Re-read the socket AFTER the await: a lifecycle suspend or a
    // watchdog-driven reconnect landing in the await gap sets
    // `_socket = null`, and dereferencing `_socket!` here was a live
    // "Null check operator used on a null value" crash class.
    final socket = _socket;
    if (socket == null) {
      throw SocketNotConnectedException(event);
    }
    // Check the remaining budget BEFORE emitting: emitting and then
    // immediately declaring an ACK timeout would put the payload on the
    // wire while telling the caller it never went out, and the caller's
    // retry layer treats SocketAckTimeoutException as transient — that is
    // a duplicate write, not a timeout.
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw SocketAckTimeoutException(event);
    }
    powerDiagnostics.recordSocketSend(event, ack: true);
    final completer = Completer<dynamic>();
    socket.emitWithAck(
      event,
      data,
      ack: (response) {
        if (!completer.isCompleted) completer.complete(response);
      },
    );
    try {
      return await completer.future.timeout(remaining);
    } on TimeoutException {
      // Treat ACK timeout as transient — Socket.IO will retry or reconnect.
      throw SocketAckTimeoutException(event);
    }
  }

  /// Register reconnection listener
  void Function() onReconnected(void Function() listener) {
    _reconnectedListeners.add(listener);
    return () => _reconnectedListeners.remove(listener);
  }

  /// Register a listener for when Socket.IO exhausts all reconnection
  /// attempts.  The caller can use this to schedule a fresh [reconnect]
  /// after a delay.
  void Function() onReconnectExhausted(void Function() listener) {
    _reconnectFailedListeners.add(listener);
    return () => _reconnectFailedListeners.remove(listener);
  }

  /// Register status change listener
  void Function() onStatusChange(void Function(ConnectionStatus) listener) {
    _statusListeners.add(listener);
    // Immediately notify with current status
    listener(_status);
    return () => _statusListeners.remove(listener);
  }

  /// Register message handler for a specific event. Multiple handlers per
  /// event are supported. Returns an unsubscribe callback that removes only
  /// the registered handler (not all handlers for the event).
  void Function() onMessage(String event, void Function(dynamic) handler) {
    _messageHandlers.putIfAbsent(event, () => []).add(handler);
    return () {
      final list = _messageHandlers[event];
      if (list != null) {
        list.remove(handler);
        if (list.isEmpty) _messageHandlers.remove(event);
      }
    };
  }

  /// Unregister all handlers for an event.
  void offMessage(String event) {
    _messageHandlers.remove(event);
  }

  /// Update the auth token for the current connection.
  ///
  /// If a socket exists, it is torn down and redialled with the new
  /// token.  Mutating `socket.auth` alone is not enough: the live
  /// connection keeps the credential it handshook with, so a socket whose
  /// token the server has already rejected would keep retrying forever
  /// with a credential that can never work.
  void updateToken(String token) {
    if (_authToken == token) return;
    _authToken = token;
    if (_socket == null || _serverUrl == null) return;
    // Update auth first so the redial (and any internal Manager retry)
    // handshakes with the new credential.
    _socket!.auth = {
      'token': token,
      'clientType': _clientType ?? 'user-scoped',
    };
    // force: the in-flight dial is using the stale token, so waiting it
    // out only delays recovery.
    reconnect(reason: DialReason.tokenRefresh, force: true);
  }

  /// Update server URL and reconnect if already connected.
  void refreshServerUrl(String newUrl) {
    if (_serverUrl != newUrl) {
      _serverUrl = newUrl;

      if (_socket != null && _authToken != null) {
        disconnect();
        connect(
          serverUrl: newUrl,
          token: _authToken!,
          clientType: _clientType ?? 'user-scoped',
          reason: DialReason.serverUrlChanged,
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

  /// Start the dial spans.
  ///
  /// One span name for every dial (`websocket.dial`) with the caller's
  /// [reason] as an attribute.  The previous split on `_hasConnectedOnce`
  /// produced exactly ONE `websocket.connect` per app process and labelled
  /// every later dial — including deliberate foreground resumes —
  /// `websocket.reconnect`, which is what made the connect/reconnect ratio
  /// unreadable.
  void _startConnectionSpans(int generation, {required String reason}) {
    const name = 'websocket.dial';
    final attributes = _connectionAttributes(reason: reason);
    _connectSpanGeneration = generation;
    _connectTransaction = Sentry.startTransaction(
      name,
      'connection',
      bindToScope: false,
    );
    for (final entry in attributes.entries) {
      _connectTransaction?.setData(entry.key, entry.value);
    }
    _connectOtelSpan = OpenTelemetryService().startTrace(
      name,
      attributes: _otelConnectionAttributes(attributes),
    );
    _connectSpanReason = reason;
  }

  void _finishConnectionSpans(
    int generation, {
    bool ok = true,
    SpanStatus? status,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_connectSpanGeneration != generation) return;

    final elapsedMs =
        _connectStopwatch?.elapsedMilliseconds ??
        _elapsedSince(_lastConnectStartedAtMs);
    final attributes = _connectionAttributes(
      reason: _connectSpanReason ?? DialReason.unspecified,
      connectDurationMs: elapsedMs,
    );
    final transaction = _connectTransaction;
    final otelSpan = _connectOtelSpan;
    _connectTransaction = null;
    _connectOtelSpan = null;
    _connectSpanGeneration = null;
    _connectSpanReason = null;
    _connectStopwatch = null;

    for (final entry in attributes.entries) {
      transaction?.setData(entry.key, entry.value);
    }
    for (final entry in _otelConnectionAttributes(attributes).entries) {
      otelSpan?.setAttribute(entry.key, entry.value);
    }
    if (error != null) {
      otelSpan?.recordError(error, stackTrace);
    }
    unawaited(transaction?.finish(status: status));
    otelSpan?.end(ok: ok);
  }

  // NOTE: `recovered` is deliberately NOT reported. It mirrors
  // `Socket.recovered`, which requires Socket.IO connection state
  // recovery — the Go server never calls `SetConnectionStateRecovery`
  // (`internal/server/ws/server.go`), so the flag was a constant `false`
  // carrying zero information, and it was sampled after failed dials
  // where it is false by construction. Every reconnect is therefore a
  // cold rejoin; Sync compensates with a forced invalidation.
  Map<String, Object?> _connectionAttributes({
    required String reason,
    int? connectDurationMs,
  }) {
    return {
      'reason': reason,
      'attempt': _dialAttempt,
      'connectDurationMs': connectDurationMs,
      'disconnectGapMs':
          _lastConnectStartedAtMs != null && _lastDisconnectAtMs != null
          ? _lastConnectStartedAtMs! - _lastDisconnectAtMs!
          : null,
      'currentRoute': PerformanceContextService().currentRoute ?? 'unknown',
    };
  }

  static Map<String, Object?> _otelConnectionAttributes(
    Map<String, Object?> attributes,
  ) {
    return {
      'websocket.dial_reason': attributes['reason'],
      'websocket.dial_attempt': attributes['attempt'],
      'websocket.connect_duration_ms': attributes['connectDurationMs'],
      'websocket.disconnect_gap_ms': attributes['disconnectGapMs'],
      'current_route': attributes['currentRoute'],
    };
  }

  /// Test-only accessor for the reconnect backoff curve so the
  /// initial-delay / cap constants can be locked without dialing a
  /// real server.
  @visibleForTesting
  static int testBackoffDelayMs(int attempt) => _backoffDelayMs(attempt);

  @visibleForTesting
  bool get testHasConnectedOnce => _hasConnectedOnce;

  @visibleForTesting
  int get testReconnectRequests => _reconnectRequests;

  /// Number of [reconnect] calls short-circuited by the in-flight guard.
  @visibleForTesting
  int get testReconnectSkipped => _reconnectSkipped;

  @visibleForTesting
  int get testDialAttempt => _dialAttempt;

  /// Test-only hook to simulate "a dial started N ms ago" without
  /// dialing a real server.
  @visibleForTesting
  set testLastConnectStartedAtMs(int? value) => _lastConnectStartedAtMs = value;

  /// Test-only hook to install stored credentials so [reconnect] takes
  /// its real path without a live Socket.IO Manager.
  @visibleForTesting
  void testSetCredentials({
    String? serverUrl,
    String? token,
    String? clientType,
  }) {
    _serverUrl = serverUrl;
    _authToken = token;
    _clientType = clientType;
  }

  /// Test-only hook to force [_status] without a real Socket.IO
  /// connection, so disconnect-telemetry tests can set up a "currently
  /// connected" precondition without dialing a real server.
  @visibleForTesting
  set testConnectionStatus(ConnectionStatus value) => _status = value;

  @visibleForTesting
  set testHasConnectedOnce(bool value) => _hasConnectedOnce = value;

  /// Test-only control for the Socket.IO Manager's internal retry ownership.
  @visibleForTesting
  set testManagerReconnecting(bool value) {
    _socket?.io.reconnecting = value;
  }

  @visibleForTesting
  int get testConnectionGeneration => _connectionGeneration;

  /// Monotonic socket generation used to scope connection-bound caches.
  int get connectionGeneration => _connectionGeneration;

  /// Latest bounded disconnect reason for user-facing diagnostics.
  String? get lastDisconnectReason => _lastDisconnectReason;

  /// Epoch milliseconds of the most recent disconnect.
  int? get lastDisconnectAtMs => _lastDisconnectAtMs;

  /// Epoch milliseconds of the latest event accepted by the current socket
  /// generation. Payloads and event names are intentionally not retained.
  int? get lastEventAtMs => _lastEventAtMs;

  /// Current dial attempt within this connection generation.
  int get dialAttempt => _dialAttempt;

  /// Test-only hook to fire the reconnection listeners without a live
  /// server round-trip.
  @visibleForTesting
  void testNotifyReconnected() => _notifyReconnected();

  /// Dispose resources
  void dispose() {
    disconnect();
    _statusController.close();
    _nextReconnectDelayController.close();
    _messageHandlers.clear();
    _reconnectedListeners.clear();
    _reconnectFailedListeners.clear();
    _statusListeners.clear();
  }

  /// Returns true when the error should be suppressed to prevent a flood of
  /// identical entries.  The first occurrence of each distinct error string
  /// is always logged; subsequent identical errors within
  /// [_errorThrottleWindowMs] are counted and silently dropped.  When the
  /// window expires the suppression count is emitted as a single summary
  /// line so no information is permanently lost.
  bool _shouldThrottleError(String errorStr) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_lastErrorStr == errorStr &&
        _lastErrorAtMs != null &&
        nowMs - _lastErrorAtMs! < _errorThrottleWindowMs) {
      _suppressedErrorCount++;
      return true;
    }
    // Window expired or different error — flush suppression summary first.
    if (_suppressedErrorCount > 0) {
      if (logger.shouldLog(LogLevel.info)) {
        logger.info(
          'Socket.IO error suppressed $_suppressedErrorCount× '
          'within ${_errorThrottleWindowMs}ms: $_lastErrorStr',
        );
      }
      _suppressedErrorCount = 0;
    }
    _lastErrorStr = errorStr;
    _lastErrorAtMs = nowMs;
    return false;
  }

  /// Reset error-throttle state (called on clean connect so the first error
  /// after a successful reconnection is always logged).
  void _resetErrorThrottle() {
    if (_suppressedErrorCount > 0) {
      if (logger.shouldLog(LogLevel.info)) {
        logger.info(
          'Socket.IO error suppressed $_suppressedErrorCount× '
          'within ${_errorThrottleWindowMs}ms: $_lastErrorStr',
        );
      }
    }
    _lastErrorStr = null;
    _lastErrorAtMs = null;
    _suppressedErrorCount = 0;
  }

  static int? _elapsedSince(int? startedAtMs) {
    if (startedAtMs == null) return null;
    return DateTime.now().millisecondsSinceEpoch - startedAtMs;
  }
}

/// Singleton instance - exported for compatibility
final socketIoClient = SocketIoClient();
