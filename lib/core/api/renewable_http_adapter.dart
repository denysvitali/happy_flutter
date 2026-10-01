import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Replaces stale network pools without interrupting concurrent requests.
/// Retired transports close only after their response streams have drained.
class RenewableHttpAdapter implements HttpClientAdapter {
  RenewableHttpAdapter(this.create);
  final HttpClientAdapter Function() create;
  static const _leaseKey = '_httpTransportLease';
  final Set<_TransportLease> _leases = {};
  _TransportLease? _current;
  bool _closed = false;

  void renew() {
    final current = _current;
    _current = null;
    if (current == null) return;
    current.retired = true;
    _releaseIfIdle(current);
  }

  /// A delayed failure from an older pool must not retire its replacement.
  void renewForRequest(RequestOptions options) {
    if (identical(options.extra[_leaseKey], _current)) renew();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_closed) throw StateError('HTTP adapter is closed');
    final lease = _current ??= _TransportLease(create());
    _leases.add(lease);
    lease.active++;
    options.extra[_leaseKey] = lease;
    var released = false;
    void release() {
      if (released) return;
      released = true;
      lease.active--;
      _releaseIfIdle(lease);
    }

    // The caller can cancel while waiting for headers or consuming a body.
    // Native transports own cancellation; this only releases our lease.
    unawaited(cancelFuture?.then((_) => release()));
    try {
      final response = await lease.adapter.fetch(
        options,
        requestStream,
        cancelFuture,
      );
      response.stream = _drain(response.stream, release);
      return response;
    } catch (_) {
      release();
      rethrow;
    }
  }

  Stream<Uint8List> _drain(
    Stream<Uint8List> source,
    void Function() release,
  ) async* {
    try {
      yield* source;
    } finally {
      release();
    }
  }

  void _releaseIfIdle(_TransportLease lease) {
    if (lease.retired && lease.active == 0 && _leases.remove(lease)) {
      lease.adapter.close();
    }
  }

  @override
  void close({bool force = false}) {
    _closed = true;
    _current = null;
    for (final lease in _leases.toList()) {
      lease.retired = true;
      if (force) {
        lease.adapter.close(force: true);
        _leases.remove(lease);
      } else {
        _releaseIfIdle(lease);
      }
    }
  }
}

class _TransportLease {
  _TransportLease(this.adapter);
  final HttpClientAdapter adapter;
  int active = 0;
  bool retired = false;
}
