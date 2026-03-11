import 'dart:async';

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
  });

  final int id;
  final DateTime timestamp;
  final String method;
  final String path;
  final int? statusCode;
  final int? requestBytes;
  final int? responseBytes;
  final int? durationMs;

  static String formatBytes(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String toFormattedString() {
    final ts = timestamp.toIso8601String();
    final status = statusCode?.toString().padRight(3) ?? '???';
    final reqB = formatBytes(requestBytes).padLeft(8);
    final resB = formatBytes(responseBytes).padLeft(8);
    final dur =
        durationMs != null ? '${durationMs}ms'.padLeft(7) : '      -';
    return '$ts  ${method.padRight(6)}  $status  '
        '$reqB  $resB  $dur  $path';
  }
}

/// In-memory store for HTTP request logs with a max capacity.
class HttpRequestLogger {
  HttpRequestLogger._();

  static final HttpRequestLogger _instance = HttpRequestLogger._();

  static const int _maxEntries = 500;

  int _nextId = 1;
  final List<HttpRequestEntry> _entries = [];
  final _controller =
      StreamController<List<HttpRequestEntry>>.broadcast();

  List<HttpRequestEntry> get entries => List.unmodifiable(_entries);

  Stream<List<HttpRequestEntry>> get onChanged => _controller.stream;

  int takeNextId() => _nextId++;

  void record(HttpRequestEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    if (_controller.hasListener) {
      _controller.add(List.unmodifiable(_entries));
    }
  }

  void clear() {
    _entries.clear();
    _nextId = 1;
    _controller.add(const []);
  }

  int get totalRequestBytes => _entries.fold(
        0,
        (sum, e) => sum + (e.requestBytes ?? 0),
      );

  int get totalResponseBytes => _entries.fold(
        0,
        (sum, e) => sum + (e.responseBytes ?? 0),
      );
}

/// Global singleton — matches the pattern of [logger] and [sync].
final httpRequestLogger = HttpRequestLogger._instance;
