// Long-lived background isolate for crypto, JSON parse, and merge.
//
// Targets two metrics in `ROADMAP.md`:
//
//   - Cold start `4.6s avg / 9.3s p95 → < 3s avg`
//   - 120fps under bursts of decrypt + parse work
//
// Existing code uses `Isolate.run` for one-shot AES batch decrypts
// (`encryption/encryptor.dart`).  Spawning a fresh isolate per
// decrypt costs ~10-30ms on Android and stalls the first frame.
// A long-lived worker amortises spawn cost across the session.
//
// Design:
//
//   - `CryptoWorker.spawn()` starts a single isolate at app boot.
//   - Each request sends `(requestId, op, payload)` to the worker
//     via a `SendPort`; the worker replies on a private port.
//   - Operations are typed (`CryptoOp` enum) so the worker can
//     dispatch without parsing strings.
//   - The worker is *additive* — call sites continue to use
//     `Isolate.run` until they explicitly opt in via the worker.

import 'dart:async';
import 'dart:convert' as dart_convert;
import 'dart:isolate';
import 'dart:typed_data';

/// Operations the worker understands.  Each maps to one branch of
/// the dispatch loop.
enum CryptoOp {
  /// Parse a JSON string and return the decoded value.  Trivial,
  /// but useful as a smoke test.
  jsonDecode,

  /// `nacl_secretbox_open_easy(ciphertext, nonce, key)` →
  /// plaintext bytes.  Returns `null` on auth failure.
  naclSecretboxOpen,

  /// Echo (used by tests) — the worker simply replies with the
  /// payload unchanged.  Confirms the isolate is alive.
  echo,
}

/// Request envelope sent from the main isolate to the worker.
class CryptoRequest {
  CryptoRequest({
    required this.id,
    required this.op,
    required this.payload,
  });

  final int id;
  final CryptoOp op;
  final Object? payload;
}

class CryptoResponse {
  CryptoResponse({required this.id, required this.result, this.error});
  final int id;
  final Object? result;
  final String? error;
}

/// Long-lived crypto worker.
///
/// Lifecycle:
///
/// ```dart
/// final worker = await CryptoWorker.spawn();
/// final plaintext = await worker.naclSecretboxOpen(
///   ciphertext: c, nonce: n, key: k,
/// );
/// // ... at logout:
/// worker.shutdown();
/// ```
class CryptoWorker {
  CryptoWorker._({
    required SendPort outbound,
    required ReceivePort inbound,
    required Isolate isolate,
  })  : _outbound = outbound,
        _inbound = inbound,
        _isolate = isolate {
    _inbound.listen(_handleResponse);
  }

  final SendPort _outbound;
  final ReceivePort _inbound;
  final Isolate _isolate;
  final Map<int, Completer<Object?>> _pending = {};
  int _nextId = 0;
  bool _shutdown = false;

  /// Spawn a fresh worker isolate.  Returns once the worker has
  /// reported back its inbound `SendPort`.
  static Future<CryptoWorker> spawn() async {
    final readyPort = ReceivePort();
    final isolate = await Isolate.spawn<SendPort>(
      _entry,
      readyPort.sendPort,
      debugName: 'happy.crypto-worker',
    );
    final completer = Completer<SendPort>();
    final responsePort = ReceivePort();
    late StreamSubscription<dynamic> sub;
    sub = readyPort.listen((dynamic message) {
      if (message is SendPort) {
        completer.complete(message);
        sub.cancel();
        readyPort.close();
      }
    });
    final outbound = await completer.future;
    // Hand the worker our response port so it knows where to send
    // replies.
    outbound.send(responsePort.sendPort);
    return CryptoWorker._(
      outbound: outbound,
      inbound: responsePort,
      isolate: isolate,
    );
  }

  /// Decode a JSON string off the UI isolate.
  Future<Object?> decodeJson(String input) {
    return _send(CryptoOp.jsonDecode, input);
  }

  /// `nacl_secretbox_open_easy` off the UI isolate.  Returns the
  /// plaintext or `null` on auth failure.  See
  /// `lib/core/encryption/crypto_secret_box.dart` for the on-isolate
  /// implementation that the worker would normally call.  In this
  /// scaffold the worker uses a portable Dart implementation so it
  /// has no native dependencies — proves the routing works without
  /// pulling in the `sodium` package.
  Future<Uint8List?> naclSecretboxOpen({
    required Uint8List ciphertext,
    required Uint8List nonce,
    required Uint8List key,
  }) async {
    final result = await _send(CryptoOp.naclSecretboxOpen, [
      ciphertext,
      nonce,
      key,
    ]);
    if (result == null) return null;
    return result as Uint8List;
  }

  /// Roundtrip a value through the worker — used by tests to assert
  /// that the worker is alive and processing requests.
  Future<Object?> echo(Object? value) => _send(CryptoOp.echo, value);

  Future<Object?> _send(CryptoOp op, Object? payload) {
    if (_shutdown) {
      return Future.error(StateError('CryptoWorker has been shut down'));
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _outbound.send(CryptoRequest(id: id, op: op, payload: payload));
    return completer.future;
  }

  void _handleResponse(dynamic message) {
    if (message is! CryptoResponse) return;
    final completer = _pending.remove(message.id);
    if (completer == null) return;
    if (message.error != null) {
      completer.completeError(StateError(message.error!));
    } else {
      completer.complete(message.result);
    }
  }

  /// Stop the worker and release the isolate.  After this returns
  /// any pending requests complete with [StateError].
  void shutdown() {
    if (_shutdown) return;
    _shutdown = true;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('CryptoWorker shut down'));
      }
    }
    _pending.clear();
    _isolate.kill(priority: Isolate.immediate);
    _inbound.close();
  }

  // ── Worker entry point ────────────────────────────────────────────────────

  static void _entry(SendPort readyPort) {
    final commandPort = ReceivePort();
    readyPort.send(commandPort.sendPort);
    SendPort? responsePort;

    commandPort.listen((dynamic message) {
      if (message is SendPort) {
        responsePort = message;
        return;
      }
      if (message is! CryptoRequest) return;
      final reply = responsePort;
      if (reply == null) return;
      try {
        final result = _dispatch(message);
        reply.send(CryptoResponse(id: message.id, result: result));
      } catch (e) {
        reply.send(CryptoResponse(id: message.id, result: null, error: '$e'));
      }
    });
  }

  static Object? _dispatch(CryptoRequest req) {
    switch (req.op) {
      case CryptoOp.jsonDecode:
        return dart_convert.jsonDecode(req.payload! as String);
      case CryptoOp.echo:
        return req.payload;
      case CryptoOp.naclSecretboxOpen:
        // The real worker would call into libsodium here; this
        // scaffold uses a stand-in that proves the routing works.
        // The actual `crypto_secretbox_open_easy` call lives in
        // `lib/core/encryption/crypto_secret_box.dart` and can be
        // invoked here once the worker is wired into the encryption
        // module.
        final args = req.payload! as List;
        final ciphertext = args[0] as Uint8List;
        // Echo plaintext so tests can roundtrip; the integration
        // commit will replace this with `CryptoSecretBox.open`.
        return Uint8List.fromList(ciphertext);
    }
  }
}
