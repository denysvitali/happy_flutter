// SentryEnvelopeItemHeader is not part of the public API of the `sentry`
// package, but sentry_flutter itself imports it from this same path. We use
// it here to build a new envelope item with shrunk ANR payload without
// round-tripping through SentryEvent.toJson() twice.
// ignore_for_file: depend_on_referenced_packages, implementation_imports

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:sentry/src/sentry_envelope_item_header.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger_service.dart';

const _sentrySendTimeout = Duration(seconds: 10);

/// Hard cap on the serialized envelope size accepted by [DartSentryTransport].
///
/// Native Android ANR envelopes can exceed GlitchTip's 5 MiB decompressed
/// intake limit on real devices, so we cap before sending. Tunable via
/// `--dart-define=SENTRY_MAX_ENVELOPE_BYTES=<bytes>` for local validation.
const int _defaultMaxEnvelopeBytes = 2 * 1024 * 1024; // 2 MiB

const int sentryMaxEnvelopeBytes = int.fromEnvironment(
  'SENTRY_MAX_ENVELOPE_BYTES',
  defaultValue: _defaultMaxEnvelopeBytes,
);

/// Sends Sentry envelopes through Dart HTTP.
///
/// On mobile, sentry_flutter defaults to FileSystemTransport, which hands Dart
/// envelopes to the native SDK. This transport keeps Dart-originated delivery
/// observable in app logs and bounded by explicit timeouts while still relying
/// on the platform trust store for TLS validation.
class DartSentryTransport implements Transport {
  DartSentryTransport(
    this._options, {
    http.Client? client,
    int? maxEnvelopeBytes,
  }) : _client = client ?? IOClient(_sentryHttpClient()),
       _dsn = Dsn.parse(_options.dsn ?? ''),
       _maxEnvelopeBytes = maxEnvelopeBytes ?? sentryMaxEnvelopeBytes;

  final SentryOptions _options;
  final http.Client _client;
  final Dsn _dsn;
  final int _maxEnvelopeBytes;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelope.header.sentAt = DateTime.now().toUtc();
    final envelopeId = envelope.header.eventId;
    logger.info('[Sentry] Dart transport sending envelope id=$envelopeId');

    final Uint8List body;
    try {
      body = await _envelopeBytesWithinCap(envelope);
    } on TimeoutException catch (error, stackTrace) {
      logger.warning('[Sentry] Dart transport timed out for id=$envelopeId');
      _options.log(
        SentryLevel.error,
        'Timed out sending Sentry envelope with Dart transport',
        exception: error,
        stackTrace: stackTrace,
      );
      return SentryId.empty();
    } catch (error, stackTrace) {
      logger.warning('[Sentry] Dart transport send failed: $error');
      _options.log(
        SentryLevel.error,
        'Failed to send Sentry envelope with Dart transport',
        exception: error,
        stackTrace: stackTrace,
      );
      return SentryId.empty();
    }

    final http.Response response;
    try {
      final request = http.Request('POST', _dsn.postUri)
        ..headers.addAll(_headers())
        ..bodyBytes = body;
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_sentrySendTimeout);
    } on TimeoutException catch (error, stackTrace) {
      logger.warning('[Sentry] Dart transport timed out for id=$envelopeId');
      _options.log(
        SentryLevel.error,
        'Timed out sending Sentry envelope with Dart transport',
        exception: error,
        stackTrace: stackTrace,
      );
      return SentryId.empty();
    } catch (error, stackTrace) {
      logger.warning('[Sentry] Dart transport send failed: $error');
      _options.log(
        SentryLevel.error,
        'Failed to send Sentry envelope with Dart transport',
        exception: error,
        stackTrace: stackTrace,
      );
      return SentryId.empty();
    }

    final responseContext = _responseContext(response);
    if (response.statusCode == 200) {
      final parsedEventId = _eventIdFrom(response.body);
      if (parsedEventId == null) {
        logger.warning(
          '[Sentry] Dart transport got 200 without response event id '
          '$responseContext',
        );
      }
      final eventId = parsedEventId ?? envelope.header.eventId;
      logger.info('[Sentry] Dart transport sent envelope id=$eventId');
      return eventId;
    }

    logger.warning(
      '[Sentry] Dart transport send failed: status=${response.statusCode} '
      '$responseContext',
    );
    _options.log(
      SentryLevel.error,
      'Failed to send Sentry envelope with Dart transport: '
      'statusCode=${response.statusCode}',
    );
    return SentryId.empty();
  }

  String _responseContext(http.Response response) {
    final contentType = response.headers['content-type'] ?? '-';
    final server = response.headers['server'] ?? '-';
    final body = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final snippet = body.length <= 180 ? body : '${body.substring(0, 180)}...';
    return 'contentType=$contentType server=$server '
        'bodyLen=${response.body.length} body="$snippet"';
  }

  Future<Uint8List> _envelopeBytes(SentryEnvelope envelope) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk
        in envelope.envelopeStream(_options).timeout(_sentrySendTimeout)) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  /// Serializes [envelope] and enforces [_maxEnvelopeBytes].
  ///
  /// If the serialized payload exceeds the cap, attempts to shrink ANR-shaped
  /// event items (the historical bloat source) by stripping breadcrumbs,
  /// stacktraces, and non-essential contexts. If still over the cap after a
  /// single shrink pass, the whole envelope is dropped and a warning is logged
  /// — we never send a payload larger than [_maxEnvelopeBytes].
  Future<Uint8List> _envelopeBytesWithinCap(SentryEnvelope envelope) async {
    final original = await _envelopeBytes(envelope);
    if (original.length <= _maxEnvelopeBytes) return original;

    final shrunk = await _tryShrinkAnrItems(envelope);
    if (shrunk != null) {
      logger.warning(
        '[Sentry] envelope ${envelope.header.eventId} exceeded '
        '${_maxEnvelopeBytes}B (${original.length}B); ANR items shrunk to '
        '${shrunk.length}B',
      );
      _options.log(
        SentryLevel.warning,
        'Sentry envelope shrunk to fit ${_maxEnvelopeBytes}B cap '
        '(anr items stripped)',
      );
      if (shrunk.length <= _maxEnvelopeBytes) return shrunk;
    }

    logger.warning(
      '[Sentry] envelope ${envelope.header.eventId} dropped: '
      '${original.length}B exceeds ${_maxEnvelopeBytes}B cap',
    );
    _options.log(
      SentryLevel.error,
      'Sentry envelope dropped: ${original.length}B exceeds '
      '${_maxEnvelopeBytes}B cap',
    );
    throw const _SentryEnvelopeTooLargeException();
  }

  /// Returns a re-serialized envelope with ANR-shaped event items shrunk, or
  /// `null` if the envelope contains no ANR items to shrink.
  Future<Uint8List?> _tryShrinkAnrItems(SentryEnvelope envelope) async {
    var mutated = false;
    final items = <SentryEnvelopeItem>[];
    for (final item in envelope.items) {
      final anr = _AnrShrinker.shrink(item);
      if (anr != null) {
        mutated = true;
        items.add(anr);
      } else {
        items.add(item);
      }
    }
    if (!mutated) return null;

    final shrunk = SentryEnvelope(envelope.header, items);
    return _envelopeBytes(shrunk);
  }

  Map<String, String> _headers() {
    var auth =
        'Sentry sentry_version=7, '
        'sentry_client=${_options.sentryClientName}, '
        'sentry_key=${_dsn.publicKey}';
    final secretKey = _dsn.secretKey;
    if (secretKey != null) {
      auth += ', sentry_secret=$secretKey';
    }

    return <String, String>{
      'Content-Type': 'application/x-sentry-envelope',
      'User-Agent': _options.sentryClientName,
      'X-Sentry-Auth': auth,
    };
  }

  SentryId? _eventIdFrom(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, Object?>) {
        final id = decoded['id'];
        if (id is String && id.isNotEmpty) {
          return SentryId.fromId(id);
        }
      }
    } catch (_) {
      // Older/self-hosted Sentry-compatible servers may return an empty body
      // for accepted envelopes; the envelope header still has the event id.
    }
    return null;
  }
}

HttpClient _sentryHttpClient() {
  return HttpClient()..connectionTimeout = _sentrySendTimeout;
}

class _SentryEnvelopeTooLargeException implements Exception {
  const _SentryEnvelopeTooLargeException();
}

/// Strips noisy payload from ANR-shaped event items so a single oversized
/// envelope fits the transport cap.
///
/// Detection: a `SentryItemType.event` item whose JSON contains an exception
/// of type `ApplicationNotResponding`. Shrink strategy (in order):
///   1. drop `breadcrumbs`
///   2. drop every `threads.values[].stacktrace` and
///      `exception.values[].stacktrace`
///   3. drop `sdk`, `packages`, `integrations`
///
/// We never modify a non-ANR event; the function returns `null` in that case
/// so the caller can keep the original item untouched.
class _AnrShrinker {
  static const _eventType = 'event';
  static const _anrExceptionType = 'ApplicationNotResponding';

  static SentryEnvelopeItem? shrink(SentryEnvelopeItem item) {
    if (item.header.type != _eventType) return null;

    final original = item.originalObject;
    if (original is! SentryEvent) return null;
    if (!_isAnrEvent(original)) return null;

    final json = _shrunkJson(original.toJson());
    final header = SentryEnvelopeItemHeader(
      _eventType,
      itemCount: item.header.itemCount,
      contentType: item.header.contentType,
      fileName: item.header.fileName,
      attachmentType: item.header.attachmentType,
    );
    return SentryEnvelopeItem(
      header,
      () => Uint8List.fromList(utf8.encode(json)),
      originalObject: original,
    );
  }

  static bool _isAnrEvent(SentryEvent event) {
    for (final ex in event.exceptions ?? <SentryException>[]) {
      if (ex.type == _anrExceptionType) return true;
    }
    return false;
  }

  static String _shrunkJson(Map<String, dynamic> json) {
    json
      ..remove('breadcrumbs')
      ..remove('sdk')
      ..remove('packages')
      ..remove('integrations');

    final threads = json['threads'];
    if (threads is Map && threads['values'] is List) {
      for (final t in (threads['values'] as List)) {
        if (t is Map) t.remove('stacktrace');
      }
    }

    final exception = json['exception'];
    if (exception is Map && exception['values'] is List) {
      for (final e in (exception['values'] as List)) {
        if (e is Map) e.remove('stacktrace');
      }
    }

    return jsonEncode(json);
  }
}
