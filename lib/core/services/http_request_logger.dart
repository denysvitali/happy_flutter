import 'dart:async';

import '../utils/utils.dart' as utils;

/// A single recorded HTTP request/response pair.
class HttpRequestEntry {
  HttpRequestEntry({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.path,
    this.statusCode,
    this.requestBytes,
    this.responseBytes,
    this.durationMs,
    this.failureKind,
    this.errorType,
    this.networkCode,
    this.attempt = 1,
    this.totalDurationMs,
    this.fromCache = false,
    this.adapter,
    this.headersMs,
    this.bodyMs,
    this.callbackMs,
    this.failedAfterMs,
    this.lifecycleAtDispatch,
    this.lifecycleAtHeaders,
  });

  final int id;
  final DateTime timestamp;
  final String method;
  final String path;
  final int? statusCode;
  final int? requestBytes;
  final int? responseBytes;
  final int? durationMs;
  final String? failureKind;
  final String? errorType;
  final String? networkCode;
  final int attempt;
  final int? totalDurationMs;
  final bool fromCache;
  final String? adapter;
  final double? headersMs;
  final double? bodyMs;
  final double? callbackMs;
  final double? failedAfterMs;
  final String? lifecycleAtDispatch;
  final String? lifecycleAtHeaders;

  bool get failed => failureKind != null || (statusCode ?? 0) >= 400;
  String get result =>
      failureKind ??
      (statusCode == null
          ? 'unknown'
          : statusCode! >= 400
          ? 'http_status'
          : 'ok');

  /// Nullable, unspaced wrapper around the shared [formatBytes] so log lines
  /// stay compact and missing sizes render as '-'.
  static String formatBytes(int? bytes) =>
      bytes == null ? '-' : utils.formatBytes(bytes, spaced: false);

  String toFormattedString() {
    final ts = timestamp.toIso8601String();
    final status = statusCode?.toString().padRight(3) ?? '???';
    final reqB = formatBytes(requestBytes).padLeft(8);
    final resB = formatBytes(responseBytes).padLeft(8);
    final dur = durationMs != null ? '${durationMs}ms'.padLeft(7) : '      -';
    final detail = [
      if (failureKind != null) 'cause=$failureKind',
      if (networkCode != null) 'code=$networkCode',
      if (attempt > 1) 'attempt=$attempt',
      if (fromCache) 'cache=hit',
      if (totalDurationMs != null) 'total=${totalDurationMs}ms',
      if (adapter != null) 'adapter=$adapter',
      if (headersMs != null) 'headers=${headersMs!.toStringAsFixed(1)}ms',
      if (bodyMs != null) 'body=${bodyMs!.toStringAsFixed(1)}ms',
      if (callbackMs != null) 'callback=${callbackMs!.toStringAsFixed(1)}ms',
      if (failedAfterMs != null)
        'failedAfter=${failedAfterMs!.toStringAsFixed(1)}ms',
      if (lifecycleAtDispatch != null) 'lifecycle=$lifecycleAtDispatch',
      if (lifecycleAtHeaders != null) 'headersLifecycle=$lifecycleAtHeaders',
    ].join(' ');
    return '$ts  ${method.padRight(6)}  $status  '
        '$reqB  $resB  $dur  $path${detail.isEmpty ? '' : '  $detail'}';
  }
}

/// In-memory store for HTTP request logs with a max capacity.
class HttpRequestLogger {
  HttpRequestLogger._();

  static final HttpRequestLogger _instance = HttpRequestLogger._();

  static const int _maxEntries = 500;
  static const int _batchMs = 100;

  int _nextId = 1;
  final List<HttpRequestEntry> _entries = [];
  final _controller = StreamController<List<HttpRequestEntry>>.broadcast();
  Timer? _notifyTimer;

  List<HttpRequestEntry> get entries => List.unmodifiable(_entries);

  Stream<List<HttpRequestEntry>> get onChanged => _controller.stream;

  int takeNextId() => _nextId++;

  void record(HttpRequestEntry entry) {
    // Keep bounded metadata on production builds too: that is where the
    // intermittent mobile network failures need to be inspected. This never
    // retains headers, bodies or query parameters.
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    if (!_controller.hasListener || _notifyTimer != null) return;
    _notifyTimer = Timer(const Duration(milliseconds: _batchMs), () {
      _notifyTimer = null;
      if (_controller.hasListener) {
        _controller.add(List.unmodifiable(_entries));
      }
    });
  }

  void clear() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _entries.clear();
    _nextId = 1;
    _controller.add(const []);
  }

  int get totalRequestBytes =>
      _entries.fold(0, (sum, e) => sum + (e.requestBytes ?? 0));

  int get totalResponseBytes =>
      _entries.fold(0, (sum, e) => sum + (e.responseBytes ?? 0));
}

/// Global singleton — matches the pattern of [logger] and [sync].
final httpRequestLogger = HttpRequestLogger._instance;
